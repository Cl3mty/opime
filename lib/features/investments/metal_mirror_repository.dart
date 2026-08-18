import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../core/money_format.dart' show round2;
import 'document_storage.dart';
import 'investments_models.dart';
import 'metal_price_client.dart';

/// Entrée du miroir : une transaction de métal précieux, avec le compte et
/// l'investissement qui la portent (pour retrouver ses documents).
class _MirrorEntry {
  final InvestmentAccount account;
  final Investment investment;
  final Transaction transaction;

  const _MirrorEntry(this.account, this.investment, this.transaction);
}

/// Miroir lisible des transactions et documents des métaux précieux,
/// organisé pour l'utilisateur sous
/// `<vault>/investissements/metaux_precieux/<or|argent>/<AAAA-MM-JJ>/` :
///  * `transaction.json` — les transactions du jour pour ce métal (avec les
///    noms de fichiers des pièces justificatives à côté) ;
///  * les documents rattachés (facture, scellé, photo...) copiés sous leur
///    nom d'origine dans le même dossier daté.
///
/// `comptes.json` reste la source de vérité : ce miroir est une projection
/// en lecture seule, régénérée à chaque sauvegarde des comptes (voir
/// `InvestmentsRepository._writeAll`) et jamais modifiée par l'utilisateur
/// lui-même. Les fichiers ne sont réécrits que s'ils manquent ou ont changé
/// (l'id d'un document et son nom d'origine ne changent jamais), la
/// synchronisation est donc idempotente et sans coût sur les sauvegardes
/// successives. Un échec quelconque est avalé : un miroir ne doit jamais
/// faire échouer une sauvegarde de comptes.
class MetalMirrorRepository {
  final String vaultPath;

  MetalMirrorRepository(this.vaultPath);

  Directory get _root =>
      Directory(p.join(vaultPath, 'investissements', 'metaux_precieux'));

  /// Régénère le miroir pour refléter exactement [accounts] : les dossiers
  /// datés devenus sans objet (transaction supprimée, date modifiée) sont
  /// retirés, les nouveaux sont créés, et l'ensemble du dossier métal est
  /// supprimé si plus aucun métal n'est détenu.
  Future<void> sync(List<InvestmentAccount> accounts) async {
    try {
      final desired = <String, Map<String, List<_MirrorEntry>>>{};
      for (final account in accounts) {
        for (final investment in account.investments) {
          final effectiveClass = investment.assetClass ?? account.assetClass;
          if (effectiveClass != AssetClass.metauxPrecieux) continue;
          if (investment.transactions.isEmpty) continue;
          final metal = metalKindForInvestment(
            isin: investment.isin,
            label: investment.label,
          ).fileName;
          for (final transaction in investment.transactions) {
            desired
                .putIfAbsent(metal, () => {})
                .putIfAbsent(_dayKey(transaction.date), () => [])
                .add(_MirrorEntry(account, investment, transaction));
          }
        }
      }
      await _reconcile(desired);
    } catch (_) {
      // Ne jamais faire échouer une sauvegarde de comptes à cause du miroir.
    }
  }

  /// Applique l'écart entre l'état voulu ([desired]) et l'état actuel du
  /// dossier miroir sur disque.
  Future<void> _reconcile(
    Map<String, Map<String, List<_MirrorEntry>>> desired,
  ) async {
    if (await _root.exists()) {
      for (final metalDir in _root.listSync().whereType<Directory>()) {
        final metal = p.basename(metalDir.path);
        final desiredDays = desired[metal]?.keys ?? const <String>{};
        // Dossiers datés périmés (transaction supprimée, date modifiée...).
        for (final dateDir in metalDir.listSync().whereType<Directory>()) {
          if (!desiredDays.contains(p.basename(dateDir.path))) {
            await dateDir.delete(recursive: true);
          }
        }
        // Métal sans plus aucun jour (plus détenu) : dossier supprimé.
        if (metalDir.listSync().isEmpty) await metalDir.delete();
      }
    }

    if (desired.isEmpty) {
      if (await _root.exists() && _root.listSync().isEmpty) {
        await _root.delete();
      }
      return;
    }

    for (final metal in desired.keys) {
      final metalDir = Directory(p.join(_root.path, metal));
      for (final day in desired[metal]!.keys) {
        final dayDir = Directory(p.join(metalDir.path, day));
        await dayDir.create(recursive: true);
        final entries = desired[metal]![day]!
          ..sort((a, b) {
            final byDate = a.transaction.date.compareTo(b.transaction.date);
            if (byDate != 0) return byDate;
            return a.transaction.id.compareTo(b.transaction.id);
          });
        await _syncDay(dayDir, entries);
      }
    }
  }

  /// Synchronise un dossier daté : copie des pièces justificatives manquantes
  /// sous leur nom d'origine, réécriture de `transaction.json` si besoin,
  /// puis retrait des fichiers qui ne correspondent plus à rien (document
  /// supprimé).
  Future<void> _syncDay(
    Directory dayDir,
    List<_MirrorEntry> entries,
  ) async {
    final docStorage = DocumentStorage(vaultPath);
    final wantedFiles = <String>{};
    final docsByTransaction = <String, List<(VaultDocument, String)>>{};

    for (final entry in entries) {
      final docs = [
        for (final doc in entry.investment.documents)
          if (doc.transactionId == entry.transaction.id) doc,
      ];
      final resolved = <(VaultDocument, String)>[];
      for (final doc in docs) {
        final source = docStorage.fileFor(doc);
        if (!await source.exists()) continue;
        final targetName = _uniqueTargetName(dayDir, doc, wantedFiles);
        final target = File(p.join(dayDir.path, targetName));
        if (!await target.exists()) {
          // Jamais `source.copy` : ce fichier est chiffré dès que le vault
          // l'est, et ce miroir doit toujours rester lisible en clair —
          // voir `document_storage.dart`'s `readBytes`.
          await target.writeAsBytes(await docStorage.readBytes(doc));
        }
        wantedFiles.add(targetName);
        resolved.add((doc, targetName));
      }
      docsByTransaction[entry.transaction.id] = resolved;
    }

    final transactionFile = File(p.join(dayDir.path, 'transaction.json'));
    final newContent = const JsonEncoder.withIndent('  ').convert([
      for (final entry in entries)
        _transactionJson(entry, docsByTransaction[entry.transaction.id] ?? const []),
    ]);
    final existing = await transactionFile.exists()
        ? await transactionFile.readAsString()
        : null;
    if (existing != newContent) {
      await transactionFile.writeAsString(newContent);
    }
    wantedFiles.add('transaction.json');

    for (final file in dayDir.listSync().whereType<File>()) {
      if (!wantedFiles.contains(p.basename(file.path))) await file.delete();
    }
  }

  /// Nom de fichier sous lequel copier [doc] dans le dossier daté : son nom
  /// d'origine (sanitisé), désambiguïsé par l'id du document si un autre
  /// document du même jour porte déjà ce nom.
  String _uniqueTargetName(
    Directory dayDir,
    VaultDocument doc,
    Set<String> used,
  ) {
    var name = p.basename(doc.fileName);
    if (name.isEmpty) name = '${doc.id}.pdf';
    if (!used.contains(name)) return name;
    name = '${doc.id}_$name';
    if (!used.contains(name)) return name;
    var suffix = 2;
    while (used.contains('${doc.id}_${suffix}_$name')) {
      suffix++;
    }
    return '${doc.id}_${suffix}_$name';
  }

  Map<String, dynamic> _transactionJson(
    _MirrorEntry entry,
    List<(VaultDocument, String)> docs,
  ) => {
    'id': entry.transaction.id,
    'date': _dayKey(entry.transaction.date),
    'type': entry.transaction.isBuy ? 'achat' : 'vente',
    'quantite': round2(entry.transaction.quantity),
    'prixUnitaire': round2(entry.transaction.unitPrice),
    // Devise de cotation et taux de change (1 devise = X €) d'une
    // transaction saisie hors euros (ex : une pièce US achetée en USD) —
    // voir `Transaction.currency`/`Transaction.fxRateToEur`.
    if (entry.transaction.currency != 'EUR')
      'devise': entry.transaction.currency,
    if (entry.transaction.currency != 'EUR')
      'tauxEur': entry.transaction.fxRateToEur,
    'montant': round2(entry.transaction.amount),
    'investissement': entry.investment.label,
    'compte': entry.account.name,
    if (docs.isNotEmpty) 'documents': [for (final (_, name) in docs) name],
  };

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

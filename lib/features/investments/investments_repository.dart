import 'dart:convert';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';
import 'investments_models.dart';
import 'metal_mirror_repository.dart';

/// Persiste les comptes de placement réels de l'utilisateur (créés
/// manuellement, sans API de cours pour l'instant) — même pattern que
/// [BudgetRepository] (`lib/features/budget/budget_repository.dart`) :
/// un fichier JSON unique sous le dossier du profil, réécrit en entier à
/// chaque sauvegarde.
class InvestmentsRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  InvestmentsRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _relativePath = 'investissements/comptes.json';

  Future<List<InvestmentAccount>> _readAll() async {
    if (!await _storage.exists(_relativePath)) return [];
    final content = await _storage.readString(_relativePath);
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List;
    final accounts = list
        .map((e) => InvestmentAccount.fromJson(e as Map<String, dynamic>))
        .toList();
    return _migrateImmobilierAccountDocumentsIfNeeded(accounts);
  }

  /// Migration ponctuelle : les documents d'un bien immobilier vivaient
  /// auparavant au niveau du COMPTE (`account.documents`, partagés entre
  /// tous les biens qu'il contient) — désormais rattachés au bien lui-même
  /// (`Investment.documents`), pour pouvoir les catégoriser (Facture/Plan/
  /// Photo/Quittance, voir `VaultDocument.category`) et les retrouver bien
  /// par bien plutôt que noyés dans une liste commune. Seuls les octets
  /// physiques restent inchangés (`DocumentStorage` les indexe par id de
  /// document, indépendamment de qui référence ses métadonnées) : cette
  /// migration ne déplace que la liste dans le JSON, jamais de fichier.
  ///
  /// Un compte avec EXACTEMENT un bien migre sans ambiguïté (le cas
  /// courant, un compte par enveloppe). Un compte sans bien ou avec
  /// plusieurs (rare) ne sait pas lequel des biens un document concerne —
  /// ses documents restent au niveau compte plutôt que de deviner à tort.
  /// Réécrit sur disque une seule fois (comme `ProfileRepository
  /// ._migrateLegacyDataIfNeeded`) dès qu'un changement est détecté, pour
  /// que les lectures suivantes n'aient plus rien à migrer.
  Future<List<InvestmentAccount>> _migrateImmobilierAccountDocumentsIfNeeded(
    List<InvestmentAccount> accounts,
  ) async {
    var changed = false;
    final migrated = <InvestmentAccount>[];
    for (final account in accounts) {
      if (account.assetClass == AssetClass.immobilier &&
          account.documents.isNotEmpty &&
          account.investments.length == 1) {
        changed = true;
        final property = account.investments.single;
        migrated.add(
          account.copyWith(
            documents: const [],
            investments: [
              property.copyWith(
                documents: [...property.documents, ...account.documents],
              ),
            ],
          ),
        );
      } else {
        migrated.add(account);
      }
    }
    if (changed) await _writeAll(migrated);
    return migrated;
  }

  Future<void> _writeAll(List<InvestmentAccount> all) async {
    final jsonList = all.map((a) => a.toJson()).toList();
    await _storage.writeString(
      _relativePath,
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
    // Projette les métaux précieux vers leur dossier miroir daté
    // (`metaux_precieux/<or|argent>/<date>/`, voir
    // `metal_mirror_repository.dart`) — à chaque écriture, pour que toute
    // modification (transaction, document, suppression) soit reflétée. Ce
    // miroir est volontairement laissé en clair même sur un vault chiffré :
    // c'est un "miroir lisible" explicitement conçu pour être consulté hors
    // de l'app (Finder/Explorer), voir sa documentation de tête.
    await MetalMirrorRepository(vaultPath).sync(all);
  }

  Future<List<InvestmentAccount>> listAll() => _readAll();

  Future<InvestmentAccount?> find(String id) async {
    final all = await _readAll();
    for (final account in all) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// Ajoute un nouveau compte, ou remplace un compte existant de même id
  /// (utilisé aussi pour persister l'ajout d'un investissement ou d'une
  /// transaction, construits via `copyWith` côté écran).
  Future<void> saveAccount(InvestmentAccount account) async {
    final all = await _readAll();
    final idx = all.indexWhere((a) => a.id == account.id);
    if (idx == -1) {
      all.add(account);
    } else {
      all[idx] = account;
    }
    await _writeAll(all);
  }

  Future<void> deleteAccount(String id) async {
    final all = await _readAll();
    all.removeWhere((a) => a.id == id);
    await _writeAll(all);
  }

  /// Retire une transaction par id, où qu'elle vive dans le vault (tous les
  /// comptes/investissements) — utilisée pour supprimer la contrepartie
  /// d'un transfert/arbitrage (voir `Transaction.linkedTransactionId`), qui
  /// peut se trouver dans un compte différent de celui affiché à l'écran.
  /// Sans effet si aucune transaction ne porte cet id (déjà supprimée, ou
  /// id invalide).
  Future<void> deleteTransaction(String transactionId) async {
    final all = await _readAll();
    for (var accountIndex = 0; accountIndex < all.length; accountIndex++) {
      final account = all[accountIndex];
      for (final investment in account.investments) {
        if (!investment.transactions.any((t) => t.id == transactionId)) {
          continue;
        }
        final updatedInvestment = investment.copyWith(
          transactions: [
            for (final t in investment.transactions)
              if (t.id != transactionId) t,
          ],
        );
        all[accountIndex] = account.copyWith(
          investments: [
            for (final i in account.investments)
              if (i.id == updatedInvestment.id) updatedInvestment else i,
          ],
        );
        await _writeAll(all);
        return;
      }
    }
  }
}

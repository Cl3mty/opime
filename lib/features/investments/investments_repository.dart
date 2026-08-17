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
    return list
        .map((e) => InvestmentAccount.fromJson(e as Map<String, dynamic>))
        .toList();
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
}

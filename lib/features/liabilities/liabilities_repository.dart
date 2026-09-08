import 'dart:convert';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';
import 'liabilities_models.dart';

/// Persiste les passifs réels de l'utilisateur — même pattern que
/// [InvestmentsRepository] (`features/investments/investments_repository.dart`) :
/// un fichier JSON unique sous le dossier du profil, réécrit en entier à
/// chaque sauvegarde.
class LiabilitiesRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  LiabilitiesRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _relativePath = 'passifs/emprunts.json';

  Future<List<Liability>> _readAll() async {
    if (!await _storage.exists(_relativePath)) return [];
    final content = await _storage.readString(_relativePath);
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list
        .map((e) => Liability.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<Liability> all) async {
    final jsonList = all.map((l) => l.toJson()).toList();
    await _storage.writeString(
      _relativePath,
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
  }

  Future<List<Liability>> listAll() => _readAll();

  /// Résout un seul passif par id — utile à un appelant qui n'a besoin que
  /// d'un élément précis (ex : l'éditeur de projet, `project_editor.dart`)
  /// sans charger tout l'écran Passifs.
  Future<Liability?> find(String id) async {
    final all = await _readAll();
    for (final liability in all) {
      if (liability.id == id) return liability;
    }
    return null;
  }

  /// Ajoute un nouveau passif, ou remplace un passif existant de même id.
  Future<void> saveLiability(Liability liability) async {
    final all = await _readAll();
    final idx = all.indexWhere((l) => l.id == liability.id);
    if (idx == -1) {
      all.add(liability);
    } else {
      all[idx] = liability;
    }
    await _writeAll(all);
  }

  Future<void> deleteLiability(String id) async {
    final all = await _readAll();
    all.removeWhere((l) => l.id == id);
    await _writeAll(all);
  }
}

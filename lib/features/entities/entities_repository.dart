import 'dart:convert';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';
import 'entities_models.dart';

/// Persiste les entités professionnelles (holdings, sociétés commerciales,
/// SCI, comptes pro) du profil — même pattern que [LiabilitiesRepository]
/// (`features/liabilities/liabilities_repository.dart`) : un fichier JSON
/// unique sous le dossier du profil, réécrit en entier à chaque
/// sauvegarde.
///
/// Lu par `dashboard_screen.dart` (uniquement pour un coffre-fort
/// professionnel, voir `VaultKind`) via `entities_patrimoine_adapter.dart`,
/// pour consolider la valeur nette détenue des entités dans le patrimoine
/// global — voir la doc de tête de `entities_models.dart`.
class EntityRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  EntityRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _relativePath = 'entites/entites.json';

  Future<List<BusinessEntity>> _readAll() async {
    if (!await _storage.exists(_relativePath)) return [];
    final content = await _storage.readString(_relativePath);
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list
        .map((e) => BusinessEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<BusinessEntity> all) async {
    final jsonList = all.map((e) => e.toJson()).toList();
    await _storage.writeString(
      _relativePath,
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
  }

  Future<List<BusinessEntity>> listAll() => _readAll();

  Future<BusinessEntity?> find(String id) async {
    final all = await _readAll();
    for (final entity in all) {
      if (entity.id == id) return entity;
    }
    return null;
  }

  /// Ajoute une nouvelle entité, ou remplace une entité existante de même
  /// id.
  Future<void> saveEntity(BusinessEntity entity) async {
    final all = await _readAll();
    final idx = all.indexWhere((e) => e.id == entity.id);
    if (idx == -1) {
      all.add(entity);
    } else {
      all[idx] = entity;
    }
    await _writeAll(all);
  }

  Future<void> deleteEntity(String id) async {
    final all = await _readAll();
    all.removeWhere((e) => e.id == id);
    await _writeAll(all);
  }
}

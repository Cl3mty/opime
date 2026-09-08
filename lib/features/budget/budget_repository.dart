import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';
import 'budget_models.dart';

class BudgetRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  BudgetRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _relativePath = 'budget/budget_history.json';

  Future<List<BudgetSnapshot>> _readAll() async {
    if (!await _storage.exists(_relativePath)) return [];
    final content = await _storage.readString(_relativePath);
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list
        .map((e) => BudgetSnapshot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<BudgetSnapshot> all) async {
    final jsonList = all.map((s) => s.toJson()).toList();
    await _storage.writeString(
      _relativePath,
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
  }

  /// Liste tous les budgets sauvegardés, le plus récent en premier.
  Future<List<BudgetSnapshot>> listAll() async {
    final all = await _readAll();
    return all.reversed.toList();
  }

  Future<BudgetData> loadSnapshot(String id) async {
    final all = await _readAll();
    final snap = all.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Budget introuvable'),
    );
    return snap.data;
  }

  /// Crée un nouveau budget nommé. Retourne son id.
  Future<String> saveNew(BudgetData data, {String? name}) async {
    final all = await _readAll();
    final id = const Uuid().v4();
    all.add(
      BudgetSnapshot(
        id: id,
        name: name,
        savedAt: DateTime.now().toUtc(),
        data: data,
      ),
    );
    await _writeAll(all);
    return id;
  }

  /// Met à jour les données d'un budget existant (conserve son nom).
  Future<void> updateSnapshot(String id, BudgetData data) async {
    final all = await _readAll();
    final idx = all.indexWhere((s) => s.id == id);
    if (idx == -1) {
      await saveNew(data);
      return;
    }
    all[idx] = BudgetSnapshot(
      id: id,
      name: all[idx].name,
      savedAt: DateTime.now().toUtc(),
      data: data,
    );
    await _writeAll(all);
  }

  Future<void> renameSnapshot(String id, String name) async {
    final all = await _readAll();
    final idx = all.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    all[idx] = BudgetSnapshot(
      id: id,
      name: name,
      savedAt: all[idx].savedAt,
      data: all[idx].data,
    );
    await _writeAll(all);
  }

  Future<void> deleteSnapshot(String id) async {
    final all = await _readAll();
    all.removeWhere((s) => s.id == id);
    await _writeAll(all);
  }
}

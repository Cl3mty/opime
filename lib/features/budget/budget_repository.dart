import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'budget_models.dart';

class BudgetRepository {
  final String vaultPath;
  BudgetRepository(this.vaultPath);

  File get _file => File(p.join(vaultPath, 'budget', 'budget_history.json'));

  Future<void> _ensureDir() async {
    final dir = Directory(p.join(vaultPath, 'budget'));
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  Future<List<BudgetSnapshot>> _readAll() async {
    if (!await _file.exists()) return [];
    final content = await _file.readAsString();
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list
        .map((e) => BudgetSnapshot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<BudgetSnapshot> all) async {
    await _ensureDir();
    final jsonList = all.map((s) => s.toJson()).toList();
    await _file.writeAsString(
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

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class BudgetCategoriesRepository {
  final String vaultPath;
  BudgetCategoriesRepository(this.vaultPath);

  static const defaults = [
    'Logement',
    'Nourriture',
    'Abonnements',
    'Transport',
    'Bourse',
    'Épargne',
  ];

  File get _file =>
      File(p.join(vaultPath, 'budget', 'tracking', 'categories.json'));

  Future<List<String>> load() async {
    if (!await _file.exists()) {
      await save(defaults);
      return List.of(defaults);
    }
    final content = await _file.readAsString();
    if (content.trim().isEmpty) return List.of(defaults);
    try {
      return (jsonDecode(content) as List).map((e) => e as String).toList();
    } catch (_) {
      return List.of(defaults);
    }
  }

  Future<void> save(List<String> categories) async {
    final dir = _file.parent;
    if (!await dir.exists()) await dir.create(recursive: true);
    await _file.writeAsString(jsonEncode(categories));
  }

  Future<List<String>> addCategory(String name) async {
    final all = await load();
    if (!all.contains(name)) {
      all.add(name);
      await save(all);
    }
    return all;
  }
}

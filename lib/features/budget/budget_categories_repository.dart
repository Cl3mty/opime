import 'dart:convert';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';

class BudgetCategoriesRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  BudgetCategoriesRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const defaults = [
    'Logement',
    'Nourriture',
    'Abonnements',
    'Transport',
    'Bourse',
    'Épargne',
  ];

  static const _relativePath = 'budget/tracking/categories.json';

  Future<List<String>> load() async {
    if (!await _storage.exists(_relativePath)) {
      await save(defaults);
      return List.of(defaults);
    }
    final content = await _storage.readString(_relativePath);
    if (content.trim().isEmpty) return List.of(defaults);
    try {
      return (jsonDecode(content) as List).map((e) => e as String).toList();
    } catch (_) {
      return List.of(defaults);
    }
  }

  Future<void> save(List<String> categories) async {
    await _storage.writeString(_relativePath, jsonEncode(categories));
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

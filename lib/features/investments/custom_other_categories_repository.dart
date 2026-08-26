import 'dart:convert';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';

/// Types personnalisés ajoutés par l'utilisateur pour un compte "Autres"
/// (`AssetClass.autres`), en plus des enveloppes fixes (Art, Voiture,
/// Montre...) — tapés une fois (ex : "Vins de collection"), puis proposés
/// de nouveau dans le sélecteur de type à chaque nouveau compte "Autres".
/// Même structure que `BudgetCategoriesRepository`, sans notion de scope :
/// une seule liste, globale au vault.
class CustomOtherCategoriesRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  CustomOtherCategoriesRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _relativePath = 'investissements/autres_categories.json';

  Future<List<String>> load() async {
    if (!await _storage.exists(_relativePath)) return [];
    final content = await _storage.readString(_relativePath);
    if (content.trim().isEmpty) return [];
    try {
      return (jsonDecode(content) as List).map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<String> categories) async {
    await _storage.writeString(_relativePath, jsonEncode(categories));
  }

  Future<List<String>> addCategory(String name) async {
    final trimmed = name.trim();
    final all = await load();
    if (trimmed.isNotEmpty && !all.contains(trimmed)) {
      all.add(trimmed);
      await save(all);
    }
    return all;
  }

  /// Si [newName] correspond déjà à une autre catégorie existante,
  /// [oldName] est simplement retirée plutôt que dupliquée — l'appelant est
  /// responsable de reclasser les comptes qui utilisaient [oldName] vers
  /// [newName].
  Future<List<String>> renameCategory(String oldName, String newName) async {
    final trimmed = newName.trim();
    final all = await load();
    final index = all.indexOf(oldName);
    if (index == -1 || trimmed.isEmpty) return all;
    if (trimmed != oldName && all.contains(trimmed)) {
      all.removeAt(index);
    } else {
      all[index] = trimmed;
    }
    await save(all);
    return all;
  }

  Future<List<String>> removeCategory(String name) async {
    final all = await load();
    all.remove(name);
    await save(all);
    return all;
  }
}

import 'dart:convert';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';
import 'budget_recurring_templates_models.dart';

/// Persiste les lignes récurrentes du suivi de budget — un seul fichier
/// plat, `_readAll`/`_writeAll` comme [BudgetRepository]
/// (`budget_repository.dart`), pas un fichier par section comme
/// [BudgetCategoriesRepository] : contrairement aux catégories
/// (Factures/Dépenses uniquement, données par défaut et migration propres
/// à chaque scope), les templates ont la même forme sur les six sections,
/// sans donnée par défaut ni migration — un simple filtre côté client sur
/// [RecurringTemplate.section] suffit et évite six allers-retours disque à
/// chaque chargement.
class BudgetRecurringTemplatesRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  BudgetRecurringTemplatesRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _relativePath = 'budget/tracking/recurring_templates.json';

  Future<List<RecurringTemplate>> _readAll() async {
    if (!await _storage.exists(_relativePath)) return [];
    final content = await _storage.readString(_relativePath);
    if (content.trim().isEmpty) return [];
    try {
      final list = jsonDecode(content) as List;
      return list
          .map((e) => RecurringTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<RecurringTemplate> all) async {
    final jsonList = all.map((t) => t.toJson()).toList();
    await _storage.writeString(
      _relativePath,
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
  }

  Future<List<RecurringTemplate>> load() => _readAll();

  Future<void> add(RecurringTemplate template) async {
    final all = await _readAll();
    all.add(template);
    await _writeAll(all);
  }

  Future<void> remove(String id) async {
    final all = await _readAll();
    all.removeWhere((t) => t.id == id);
    await _writeAll(all);
  }
}

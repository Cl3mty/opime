import 'dart:convert';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';

/// Les catégories de Factures et celles de Dépenses (Suivi des budgets,
/// `budget_tracking_screen.dart`) sont deux listes distinctes — une
/// facture (loyer, abonnements...) et une dépense (courses, loisirs...)
/// n'ont pas vocation à partager le même classement, contrairement à
/// avant (une seule liste commune aux deux colonnes).
enum BudgetCategoryScope { factures, depenses }

class BudgetCategoriesRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  BudgetCategoriesRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  /// Pour l'instant, volontairement restreinte à l'assurance et aux
  /// abonnements — les seules catégories de facture pertinentes tant que
  /// le reste n'a pas été précisé.
  static const facturesDefaults = ['Assurance', 'Abonnements'];

  static const depensesDefaults = [
    'Logement',
    'Nourriture',
    'Abonnements',
    'Transport',
    'Bourse',
    'Épargne',
  ];

  static List<String> defaultsFor(BudgetCategoryScope scope) =>
      scope == BudgetCategoryScope.factures
          ? facturesDefaults
          : depensesDefaults;

  /// Ancien emplacement, une seule liste partagée entre Factures et
  /// Dépenses avant leur séparation — encore lu par [load] pour amorcer
  /// la liste Dépenses à partir des catégories déjà créées par
  /// l'utilisateur, plutôt que de les faire disparaître silencieusement.
  /// Jamais utilisé pour Factures : reprendre cette ancienne liste (pensée
  /// pour les dépenses — Logement, Transport...) la rendrait de nouveau
  /// identique à Dépenses, l'inverse de ce que la séparation apporte —
  /// Factures démarre toujours sur [facturesDefaults].
  static const _legacyPath = 'budget/tracking/categories.json';

  /// Marqueur posé une seule fois par [_resetFacturesOnce] — une version
  /// antérieure de cette fonctionnalité pouvait déjà avoir écrit
  /// `categories_factures.json` en l'amorçant (à tort) depuis la même
  /// source que Dépenses, avant que Factures n'ait ses propres valeurs
  /// par défaut ([facturesDefaults]). Sans ce marqueur, il faudrait
  /// deviner après coup si un contenu Factures identique à celui de
  /// Dépenses est ce résidu ou une vraie coïncidence de l'utilisateur —
  /// fragile, et risquerait d'écraser une personnalisation légitime plus
  /// tard. Le marqueur transforme la correction en un geste ponctuel,
  /// définitif, après quoi les deux listes évoluent librement, y compris
  /// si elles finissent par se recouper par coïncidence.
  static const _facturesResetMarkerPath =
      'budget/tracking/.categories_factures_reset_v1';

  String _relativePathFor(BudgetCategoryScope scope) =>
      'budget/tracking/categories_${scope.name}.json';

  Future<void> _resetFacturesOnce() async {
    if (await _storage.exists(_facturesResetMarkerPath)) return;
    await _storage.writeString(_facturesResetMarkerPath, '');
    await save(BudgetCategoryScope.factures, List.of(facturesDefaults));
  }

  Future<List<String>> load(BudgetCategoryScope scope) async {
    if (scope == BudgetCategoryScope.factures) await _resetFacturesOnce();

    final path = _relativePathFor(scope);
    if (await _storage.exists(path)) {
      final content = await _storage.readString(path);
      if (content.trim().isEmpty) return List.of(defaultsFor(scope));
      try {
        return (jsonDecode(content) as List).map((e) => e as String).toList();
      } catch (_) {
        return List.of(defaultsFor(scope));
      }
    }

    if (scope == BudgetCategoryScope.factures) {
      final seed = List.of(facturesDefaults);
      await save(scope, seed);
      return seed;
    }

    final legacy = await _readLegacy();
    final seed = legacy ?? List.of(defaultsFor(scope));
    await save(scope, seed);
    return seed;
  }

  Future<List<String>?> _readLegacy() async {
    if (!await _storage.exists(_legacyPath)) return null;
    final content = await _storage.readString(_legacyPath);
    if (content.trim().isEmpty) return null;
    try {
      return (jsonDecode(content) as List).map((e) => e as String).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> save(BudgetCategoryScope scope, List<String> categories) async {
    await _storage.writeString(
      _relativePathFor(scope),
      jsonEncode(categories),
    );
  }

  Future<List<String>> addCategory(
    BudgetCategoryScope scope,
    String name,
  ) async {
    final all = await load(scope);
    if (!all.contains(name)) {
      all.add(name);
      await save(scope, all);
    }
    return all;
  }
}

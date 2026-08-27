/// Couche de données pure de l'export PDF du patrimoine : filtre/aplatit
/// l'arbre `PatrimoineCategory` (compte → investissements, voir
/// `real_patrimoine_adapter.dart`'s `buildAllRealCategoriesByAccount`) et la
/// liste brute des `Liability` selon une sélection utilisateur, sans aucune
/// dépendance au package `pdf` ni à Flutter — testable en isolation, voir
/// `patrimoine_pdf_builder.dart` pour la mise en page réelle.
library;

import '../dashboard/patrimoine_models.dart';
import '../liabilities/liabilities_models.dart';

/// Clé d'une ligne actif sélectionnable dans le dialogue d'export : l'id du
/// compte seul pour une ligne "compte" (pas d'investissement propre — voir
/// `real_patrimoine_adapter.dart`'s `_buildAccountLeaf` pour un compte
/// vide), ou 'accountId|investmentId' pour un investissement individuel au
/// sein d'un compte qui en porte plusieurs.
String exportAssetKey(String accountId, [String? investmentId]) =>
    investmentId == null ? accountId : '$accountId|$investmentId';

/// Une ligne du tableau "Actifs" du PDF — un investissement, ou le compte
/// lui-même quand il n'en porte aucun (ex : immobilier). L'identité du
/// compte/établissement porteur n'est plus répétée ici : elle est portée par
/// [PatrimoineExportAccountGroup]/[PatrimoineExportEstablishmentGroup], qui
/// la matérialisent en en-têtes de section plutôt qu'en sous-titre de
/// cellule.
class PatrimoineExportRow {
  final String label;
  final String? subtitle;
  final double? quantite;
  final double valeur;
  final double? pru;
  final double plusValueAbs;

  /// `null` sans coût d'acquisition (ex : un objet reçu en cadeau) — voir
  /// `PatrimoineAccount.plusValuePercent`.
  final double? plusValuePercent;

  const PatrimoineExportRow({
    required this.label,
    this.subtitle,
    this.quantite,
    required this.valeur,
    this.pru,
    required this.plusValueAbs,
    required this.plusValuePercent,
  });
}

/// Les lignes d'un même compte, au sein d'un [PatrimoineExportEstablishmentGroup].
/// [showAccountHeader] est `false` quand le compte ne porte aucun
/// investissement propre (voir [buildAssetExportCategories]) : son unique
/// ligne est alors déjà le compte lui-même, un en-tête répéterait son nom
/// sans rien ajouter.
class PatrimoineExportAccountGroup {
  final String accountName;
  final bool showAccountHeader;
  final List<PatrimoineExportRow> rows;

  const PatrimoineExportAccountGroup({
    required this.accountName,
    required this.showAccountHeader,
    required this.rows,
  });

  double get total => rows.fold(0.0, (sum, r) => sum + r.valeur);
}

/// Les comptes d'un même établissement (banque, courtier...), au sein d'une
/// [PatrimoineExportCategory]. [showEstablishmentHeader] est `false` pour un
/// compte isolé sans établissement distinct (son propre nom tient déjà lieu
/// d'identité — même convention que `category_detail_screen.dart`'s
/// `_buildAccountAccordions`, qui évite le même niveau d'imbrication
/// redondant).
class PatrimoineExportEstablishmentGroup {
  final String establishmentName;
  final bool showEstablishmentHeader;
  final List<PatrimoineExportAccountGroup> accounts;

  const PatrimoineExportEstablishmentGroup({
    required this.establishmentName,
    required this.showEstablishmentHeader,
    required this.accounts,
  });

  double get total => accounts.fold(0.0, (sum, a) => sum + a.total);
}

/// Une catégorie d'actif du PDF, groupée établissement → compte → lignes et
/// déjà filtrée selon la sélection — omise du document si elle ne contient
/// plus aucune ligne (voir [buildAssetExportCategories]).
class PatrimoineExportCategory {
  final String label;
  final bool showsPruColumn;
  final List<PatrimoineExportEstablishmentGroup> establishments;

  const PatrimoineExportCategory({
    required this.label,
    required this.showsPruColumn,
    required this.establishments,
  });

  double get total => establishments.fold(0.0, (sum, e) => sum + e.total);

  /// Toutes les lignes de la catégorie, tous établissements/comptes
  /// confondus — pour décider une fois pour toute la catégorie si la
  /// colonne "Quantité" doit apparaître (voir `patrimoine_pdf_builder.dart`),
  /// plutôt que de la faire varier d'un tableau de compte à l'autre.
  List<PatrimoineExportRow> get allRows => [
    for (final establishment in establishments)
      for (final account in establishment.accounts) ...account.rows,
  ];
}

/// Filtre [categories] selon [selectedKeys] (voir [exportAssetKey]) puis les
/// regroupe par établissement (`bankName ?? name`, même clé que
/// `category_detail_screen.dart`) puis par compte : un compte sans
/// investissement propre devient une seule ligne (le compte lui-même), un
/// compte qui en porte devient une ligne par investissement retenu. Un
/// compte, un établissement ou une catégorie sans aucune ligne retenue est
/// omis du résultat plutôt que d'apparaître vide dans le PDF.
List<PatrimoineExportCategory> buildAssetExportCategories(
  List<PatrimoineCategory> categories,
  Set<String> selectedKeys,
) {
  final result = <PatrimoineExportCategory>[];
  for (final category in categories) {
    final byEstablishment = <String, List<PatrimoineAccount>>{};
    for (final account in category.accounts) {
      final key = account.bankName ?? account.name;
      byEstablishment.putIfAbsent(key, () => []).add(account);
    }

    final establishments = <PatrimoineExportEstablishmentGroup>[];
    for (final entry in byEstablishment.entries) {
      final accountGroups = <PatrimoineExportAccountGroup>[];
      var hasDistinctBank = false;
      for (final account in entry.value) {
        final rows = <PatrimoineExportRow>[];
        if (account.investments.isEmpty) {
          final key = exportAssetKey(account.id!);
          if (selectedKeys.contains(key)) {
            rows.add(
              PatrimoineExportRow(
                label: account.name,
                subtitle: account.subtitle,
                quantite: account.quantite,
                valeur: account.valeur,
                pru: account.pru,
                plusValueAbs: account.plusValueAbs,
                plusValuePercent: account.plusValuePercent,
              ),
            );
          }
        } else {
          for (final investment in account.investments) {
            final key = exportAssetKey(account.id!, investment.id!);
            if (!selectedKeys.contains(key)) continue;
            rows.add(
              PatrimoineExportRow(
                label: investment.name,
                quantite: investment.quantite,
                valeur: investment.valeur,
                pru: investment.pru,
                plusValueAbs: investment.plusValueAbs,
                plusValuePercent: investment.plusValuePercent,
              ),
            );
          }
        }
        if (rows.isEmpty) continue;
        if (account.bankName != null) hasDistinctBank = true;
        accountGroups.add(
          PatrimoineExportAccountGroup(
            accountName: account.name,
            showAccountHeader: account.investments.isNotEmpty,
            rows: rows,
          ),
        );
      }
      if (accountGroups.isEmpty) continue;
      establishments.add(
        PatrimoineExportEstablishmentGroup(
          establishmentName: entry.key,
          showEstablishmentHeader: accountGroups.length > 1 || hasDistinctBank,
          accounts: accountGroups,
        ),
      );
    }
    if (establishments.isEmpty) continue;
    result.add(
      PatrimoineExportCategory(
        label: category.label,
        showsPruColumn: category.showsPruColumn,
        establishments: establishments,
      ),
    );
  }
  return result;
}

/// Une ligne du tableau "Passifs" du PDF — depuis [Liability] brut, qui
/// porte mensualité/taux contrairement à l'adaptation générique
/// `PatrimoineCategory` utilisée côté actifs (voir
/// `real_passifs_adapter.dart`, qui ne les transporte pas).
class LiabilityExportRow {
  final String name;
  final String typeLabel;
  final double capitalRestantDu;
  final double mensualite;
  final double tauxInteret;

  const LiabilityExportRow({
    required this.name,
    required this.typeLabel,
    required this.capitalRestantDu,
    required this.mensualite,
    required this.tauxInteret,
  });
}

/// Filtre [liabilities] selon [selectedIds].
List<LiabilityExportRow> buildLiabilityExportRows(
  List<Liability> liabilities,
  Set<String> selectedIds,
) {
  return [
    for (final liability in liabilities)
      if (selectedIds.contains(liability.id))
        LiabilityExportRow(
          name: liability.name,
          typeLabel: liability.type.label,
          capitalRestantDu: liability.remainingBalance,
          mensualite: liability.mensualite,
          tauxInteret: liability.tauxInteret,
        ),
  ];
}

/// Racine des données d'export — tout ce dont `patrimoine_pdf_builder.dart`
/// a besoin, sans dépendance au package `pdf`.
class PatrimoineExportData {
  final String profileName;
  final DateTime generatedAt;
  final List<PatrimoineExportCategory> assetCategories;
  final List<LiabilityExportRow> liabilities;

  const PatrimoineExportData({
    required this.profileName,
    required this.generatedAt,
    required this.assetCategories,
    required this.liabilities,
  });

  double get totalActifs =>
      assetCategories.fold(0.0, (sum, c) => sum + c.total);

  double get totalPassifs =>
      liabilities.fold(0.0, (sum, l) => sum + l.capitalRestantDu);

  double get patrimoineNet => totalActifs - totalPassifs;
}

/// Point d'entrée unique combinant [buildAssetExportCategories] et
/// [buildLiabilityExportRows] en une seule racine de données.
PatrimoineExportData buildPatrimoineExportData({
  required String profileName,
  required DateTime generatedAt,
  required List<PatrimoineCategory> assetCategories,
  required Set<String> selectedAssetKeys,
  required List<Liability> liabilities,
  required Set<String> selectedLiabilityIds,
}) {
  return PatrimoineExportData(
    profileName: profileName,
    generatedAt: generatedAt,
    assetCategories: buildAssetExportCategories(
      assetCategories,
      selectedAssetKeys,
    ),
    liabilities: buildLiabilityExportRows(liabilities, selectedLiabilityIds),
  );
}

import 'dart:math' as math;
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, Color;
import '../dashboard/patrimoine_models.dart';
import 'liabilities_models.dart';

/// Adapte les passifs réels vers le modèle générique du Dashboard
/// (`dashboard/patrimoine_models.dart`) pour réutiliser telles quelles ses
/// cartes — même principe que
/// `features/investments/real_patrimoine_adapter.dart` côté actifs.
const _categoryMeta = {
  LiabilityType.pretImmobilier: (
    LucideIcons.house,
    Color(0xFFDC2626),
    AllocationTier.croissance,
    'Capital restant dû sur les prêts liés à l\'acquisition de biens '
        'immobiliers.',
  ),
  LiabilityType.creditAutre: (
    LucideIcons.handCoins,
    Color(0xFFF97316),
    AllocationTier.croissance,
    'Crédits à la consommation et prêts personnels en cours.',
  ),
};

List<PatrimoineCategory> buildRealPassifCategories(
  List<Liability> liabilities,
) {
  final byType = <LiabilityType, List<Liability>>{};
  for (final liability in liabilities) {
    byType.putIfAbsent(liability.type, () => []).add(liability);
  }
  return [
    for (final entry in byType.entries) _buildCategory(entry.key, entry.value),
  ];
}

/// Comme [buildRealPassifCategories], mais toujours les 2 types de passifs
/// dans le même ordre que [LiabilityType.values], vides via
/// [emptyPassifCategoryFor] pour celui sans passif — même principe que
/// `buildAllRealCategories` côté actifs.
List<PatrimoineCategory> buildAllRealPassifCategories(
  List<Liability> liabilities,
) {
  final populated = {
    for (final c in buildRealPassifCategories(liabilities)) c.id: c,
  };
  return [
    for (final type in LiabilityType.values)
      populated[type.categoryId] ?? emptyPassifCategoryFor(type.categoryId),
  ];
}

PatrimoineCategory emptyPassifCategoryFor(String categoryId) {
  final type = LiabilityType.values.firstWhere(
    (t) => t.categoryId == categoryId,
  );
  final meta = _categoryMeta[type]!;
  return PatrimoineCategory(
    id: categoryId,
    label: type.label,
    icon: meta.$1,
    color: meta.$2,
    tier: meta.$3,
    description: meta.$4,
    accounts: const [],
  );
}

PatrimoineCategory _buildCategory(
  LiabilityType type,
  List<Liability> liabilities,
) {
  final meta = _categoryMeta[type]!;
  return PatrimoineCategory(
    id: type.categoryId,
    label: type.label,
    icon: meta.$1,
    color: meta.$2,
    tier: meta.$3,
    description: meta.$4,
    accounts: [for (final liability in liabilities) _buildLeaf(liability)],
  );
}

/// Un passif compte comme "PatrimoineAccount" à part entière : [valeur] est
/// le capital restant dû, [plusValueAbs]/[plusValuePercent] le montant déjà
/// remboursé — négatif (donc affiché en rouge) : une baisse de la dette est
/// visuellement traitée comme la baisse de n'importe quelle "valeur", sans
/// distinction de signe métier entre actif et passif.
PatrimoineAccount _buildLeaf(Liability liability) {
  final remaining = liability.remainingBalance;
  final repaid = remaining - liability.montantEmprunte;
  return PatrimoineAccount(
    id: liability.id,
    name: liability.name,
    subtitle: liability.isPaidOff ? 'Soldé' : null,
    valeur: remaining,
    plusValueAbs: repaid,
    plusValuePercent: liability.montantEmprunte == 0
        ? 0
        : repaid / liability.montantEmprunte * 100,
  );
}

/// Grille de dates commune à [liabilities], de la première date de départ
/// de prêt jusqu'à l'échéance la plus tardive — factorisée entre
/// [remainingBalanceHistoryFor] (somme de tous les prêts) et
/// [perLiabilityHistoryOnGrid] (une courbe par prêt, mêmes abscisses) pour
/// qu'elles restent comparables/sommables terme à terme.
List<DateTime> _sharedGrid(List<Liability> liabilities) {
  if (liabilities.isEmpty) return [];

  DateTime? earliestStart;
  DateTime? latestEnd;
  for (final liability in liabilities) {
    if (earliestStart == null || liability.dateDebut.isBefore(earliestStart)) {
      earliestStart = liability.dateDebut;
    }
    final end = DateTime(
      liability.dateDebut.year,
      liability.dateDebut.month +
          liability.nbrEcheances +
          liability.dureeDiffereMois,
      liability.dateDebut.day,
    );
    if (latestEnd == null || end.isAfter(latestEnd)) latestEnd = end;
  }
  final start = DateTime.utc(
    earliestStart!.year,
    earliestStart.month,
    earliestStart.day,
  );
  final end = DateTime.utc(latestEnd!.year, latestEnd.month, latestEnd.day);
  final totalDays = end.difference(start).inDays;
  if (totalDays <= 0) return [];

  final stepDays = math.max(1, (totalDays / 30).ceil());
  return [
    for (var offset = 0; offset <= totalDays; offset += stepDays)
      start.add(Duration(days: offset)),
  ];
}

/// Courbe du capital restant dû cumulé, jour par jour, de la première date
/// de départ de prêt jusqu'à l'échéance la plus tardive — décroissante par
/// construction, réutilisée telle quelle par [NetWorthChart].
List<NetWorthPoint> remainingBalanceHistoryFor(List<Liability> liabilities) {
  final grid = _sharedGrid(liabilities);
  return [
    for (final date in grid) NetWorthPoint(date, _balanceAt(liabilities, date)),
  ];
}

/// Comme [remainingBalanceHistoryFor], mais une courbe par prêt (clé :
/// [Liability.id]) plutôt qu'une somme unique — toutes sur la même grille
/// de dates, pour permettre à l'utilisateur de choisir un/plusieurs/tous
/// les prêts affichés dans le graphique d'évolution d'une catégorie de
/// passifs (voir `dashboard/category_detail_screen.dart`'s
/// `historyByLineId`), en sommant terme à terme les courbes sélectionnées.
Map<String, List<NetWorthPoint>> perLiabilityHistoryOnGrid(
  List<Liability> liabilities,
) {
  final grid = _sharedGrid(liabilities);
  return {
    for (final liability in liabilities)
      liability.id: [
        for (final date in grid)
          NetWorthPoint(date, _balanceAt([liability], date)),
      ],
  };
}

/// Comme [remainingBalanceHistoryFor], mais évalué aux dates de [grid]
/// (voir `real_patrimoine_adapter.dart`'s `evenDateGrid`) plutôt que sur
/// une grille propre aux dates de prêt — pour la carte "Patrimoine net" du
/// Dashboard, où le capital restant dû doit partager les mêmes abscisses,
/// bornées par la période sélectionnée, que le côté actifs.
List<NetWorthPoint> totalBalanceOnGrid(
  List<Liability> liabilities,
  List<DateTime> grid,
) {
  return [
    for (final date in grid) NetWorthPoint(date, _balanceAt(liabilities, date)),
  ];
}

/// Première date de départ de prêt, tous [liabilities] confondus — `null`
/// sans aucun passif. Même rôle que
/// `real_patrimoine_adapter.dart`'s `earliestTransactionDateAcrossAccounts`
/// côté actifs : sert à ancrer la borne "Tout" de la carte "Patrimoine net"
/// du Dashboard sur la donnée la plus ancienne, actifs et passifs confondus.
DateTime? earliestLiabilityStart(List<Liability> liabilities) {
  DateTime? earliest;
  for (final liability in liabilities) {
    if (earliest == null || liability.dateDebut.isBefore(earliest)) {
      earliest = liability.dateDebut;
    }
  }
  if (earliest == null) return null;
  return DateTime.utc(earliest.year, earliest.month, earliest.day);
}

double _balanceAt(List<Liability> liabilities, DateTime date) {
  var total = 0.0;
  for (final liability in liabilities) {
    if (date.isBefore(liability.dateDebut)) {
      total += liability.montantEmprunte;
      continue;
    }
    // Différence en mois calendaires complets, en tenant compte du jour du
    // mois — une simple différence `date.month - dateDebut.month` compte à
    // tort un mois entier écoulé dès que le calendrier change de mois,
    // même quelques jours avant l'anniversaire mensuel du prêt (ex : prêt
    // débuté le 15, date évaluée le 20 janvier suivant : un mois n'est pas
    // encore écoulé) — décalage qui désaligne le graphique du capital
    // restant dû, chaque point étant échantillonné à une date arbitraire
    // plutôt qu'au jour anniversaire exact du prêt.
    var monthsSinceStart =
        (date.year - liability.dateDebut.year) * 12 +
        (date.month - liability.dateDebut.month);
    if (date.day < liability.dateDebut.day) monthsSinceStart -= 1;
    final byMonth = liability.remainingBalanceByMonth;
    if (byMonth.isEmpty) continue;
    final index = (monthsSinceStart - 1).clamp(0, byMonth.length - 1);
    total += monthsSinceStart <= 0 ? liability.montantEmprunte : byMonth[index];
  }
  return total;
}

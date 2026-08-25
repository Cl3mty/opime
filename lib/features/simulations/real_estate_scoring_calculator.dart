import 'package:flutter/material.dart' show Color;

/// Les 5 paliers de qualité utilisés par chacun des 7 critères du scoring
/// bancaire indicatif (voir [RealEstateScoringResult]), du meilleur au pire.
enum ScoreTier { excellent, bon, moyen, mauvais, critique }

extension ScoreTierInfo on ScoreTier {
  String get label => switch (this) {
    ScoreTier.excellent => 'Excellent',
    ScoreTier.bon => 'Bon',
    ScoreTier.moyen => 'Moyen',
    ScoreTier.mauvais => 'Mauvais',
    ScoreTier.critique => 'Critique',
  };

  /// 1 (critique) à 5 (excellent) — sommés sur les 7 critères pour la note
  /// globale (voir [RealEstateScoringResult.totalPoints]).
  int get points => switch (this) {
    ScoreTier.excellent => 5,
    ScoreTier.bon => 4,
    ScoreTier.moyen => 3,
    ScoreTier.mauvais => 2,
    ScoreTier.critique => 1,
  };

  Color get color => switch (this) {
    ScoreTier.excellent => const Color(0xFF16A34A),
    ScoreTier.bon => const Color(0xFF65A30D),
    ScoreTier.moyen => const Color(0xFFF59E0B),
    ScoreTier.mauvais => const Color(0xFFF97316),
    ScoreTier.critique => const Color(0xFFDC2626),
  };
}

/// Critère "Profession" : chaque catégorie correspond directement à un
/// palier (pas de seuil numérique à calculer).
enum ProfessionCategory { dirigeantCadreSuperieur, cadre, salarie, ouvrier, chomeur }

extension ProfessionCategoryInfo on ProfessionCategory {
  String get label => switch (this) {
    ProfessionCategory.dirigeantCadreSuperieur =>
      "Chef d'entreprise à succès / cadre supérieur",
    ProfessionCategory.cadre => 'Cadre',
    ProfessionCategory.salarie => 'Salarié',
    ProfessionCategory.ouvrier => 'Ouvrier',
    ProfessionCategory.chomeur => 'Chômeur',
  };

  ScoreTier get tier => switch (this) {
    ProfessionCategory.dirigeantCadreSuperieur => ScoreTier.excellent,
    ProfessionCategory.cadre => ScoreTier.bon,
    ProfessionCategory.salarie => ScoreTier.moyen,
    ProfessionCategory.ouvrier => ScoreTier.mauvais,
    ProfessionCategory.chomeur => ScoreTier.critique,
  };
}

/// Critère "Historique bancaire" (découverts/incidents de paiement) : la
/// formulation d'origine ne se réduit pas à un seuil numérique unique
/// ("0 dans les 3 dernières années" / "0 dans l'année" / ... / "plusieurs
/// dans les 6 derniers mois"), donc catégories directes comme la profession.
enum BankHistoryStatus { none3Years, none1Year, none6Months, one6Months, several6Months }

extension BankHistoryStatusInfo on BankHistoryStatus {
  String get label => switch (this) {
    BankHistoryStatus.none3Years =>
      'Aucun découvert ni incident depuis 3 ans',
    BankHistoryStatus.none1Year => 'Aucun depuis 1 an',
    BankHistoryStatus.none6Months => 'Aucun depuis 6 mois',
    BankHistoryStatus.one6Months => '1 incident dans les 6 derniers mois',
    BankHistoryStatus.several6Months =>
      'Plusieurs incidents dans les 6 derniers mois',
  };

  ScoreTier get tier => switch (this) {
    BankHistoryStatus.none3Years => ScoreTier.excellent,
    BankHistoryStatus.none1Year => ScoreTier.bon,
    BankHistoryStatus.none6Months => ScoreTier.moyen,
    BankHistoryStatus.one6Months => ScoreTier.mauvais,
    BankHistoryStatus.several6Months => ScoreTier.critique,
  };
}

ScoreTier tierForDebtRatio(double ratioPercent) {
  if (ratioPercent < 20) return ScoreTier.excellent;
  if (ratioPercent < 30) return ScoreTier.bon;
  if (ratioPercent < 35) return ScoreTier.moyen;
  if (ratioPercent < 40) return ScoreTier.mauvais;
  return ScoreTier.critique;
}

ScoreTier tierForResteAVivrePart(double annualPerPart) {
  if (annualPerPart > 20000) return ScoreTier.excellent;
  if (annualPerPart >= 10000) return ScoreTier.bon;
  if (annualPerPart >= 5000) return ScoreTier.moyen;
  if (annualPerPart >= 3000) return ScoreTier.mauvais;
  return ScoreTier.critique;
}

ScoreTier tierForAge(int age) {
  if (age < 25) return ScoreTier.excellent;
  if (age < 35) return ScoreTier.bon;
  if (age < 45) return ScoreTier.moyen;
  if (age <= 60) return ScoreTier.mauvais;
  return ScoreTier.critique;
}

ScoreTier tierForIncomeStabilityMonths(int months) {
  if (months > 36) return ScoreTier.excellent;
  if (months >= 12) return ScoreTier.bon;
  if (months >= 6) return ScoreTier.moyen;
  if (months >= 3) return ScoreTier.mauvais;
  return ScoreTier.critique;
}

/// 0% ou déficit est explicitement "Critique" dans l'énoncé d'origine — la
/// tranche "Mauvais entre 0 et 5%" se lit donc comme "strictement entre 0
/// et 5%", pas "0 à 5% inclus" (qui chevaucherait Critique).
ScoreTier tierForSavingsEffort(double percent) {
  if (percent <= 0) return ScoreTier.critique;
  if (percent < 5) return ScoreTier.mauvais;
  if (percent < 10) return ScoreTier.moyen;
  if (percent < 25) return ScoreTier.bon;
  return ScoreTier.excellent;
}

class ScoreCriterion {
  final String label;
  final String valueLabel;
  final ScoreTier tier;
  const ScoreCriterion({
    required this.label,
    required this.valueLabel,
    required this.tier,
  });
}

class RealEstateScoringResult {
  final double debtRatioPercent;
  final double resteAVivreAnnuelParPart;
  final double savingsEffortPercent;
  final List<ScoreCriterion> criteria;
  final int totalPoints;
  final ScoreTier overallTier;

  const RealEstateScoringResult({
    required this.debtRatioPercent,
    required this.resteAVivreAnnuelParPart,
    required this.savingsEffortPercent,
    required this.criteria,
    required this.totalPoints,
    required this.overallTier,
  });
}

String stabilityDurationLabel(int months) {
  if (months < 12) return '$months mois';
  final years = months / 12;
  final wholeYears = years == years.truncateToDouble();
  return wholeYears
      ? '${years.toInt()} ans'
      : '${years.toStringAsFixed(1)} ans';
}

/// Calcule les 7 critères du scoring bancaire indicatif et une note globale
/// (somme de points 1-5 par critère, /35), à partir des saisies de
/// l'utilisateur. Simulation pédagogique simplifiée — voir le disclaimer
/// affiché dans `RealEstateScoringScreen`, pas un vrai score bancaire.
RealEstateScoringResult computeRealEstateScoring({
  required double revenusMensuels,
  required double chargesMensuellesHorsPret,
  required double mensualitePret,
  required double partsFiscales,
  required int age,
  required ProfessionCategory profession,
  required int ancienneteRevenusMois,
  required BankHistoryStatus historiqueBancaire,
  required double epargneMensuelle,
}) {
  final debtRatio = revenusMensuels > 0
      ? (chargesMensuellesHorsPret + mensualitePret) / revenusMensuels * 100
      : 0.0;
  final resteAVivreAnnuel =
      (revenusMensuels - chargesMensuellesHorsPret - mensualitePret) * 12;
  final resteAVivreParPart = partsFiscales > 0
      ? resteAVivreAnnuel / partsFiscales
      : resteAVivreAnnuel;
  final savingsEffort = revenusMensuels > 0
      ? epargneMensuelle / revenusMensuels * 100
      : 0.0;

  final debtTier = tierForDebtRatio(debtRatio);
  final resteTier = tierForResteAVivrePart(resteAVivreParPart);
  final ageTier = tierForAge(age);
  final professionTier = profession.tier;
  final stabilityTier = tierForIncomeStabilityMonths(ancienneteRevenusMois);
  final historyTier = historiqueBancaire.tier;
  final savingsTier = tierForSavingsEffort(savingsEffort);

  final criteria = [
    ScoreCriterion(
      label: "Taux d'endettement",
      valueLabel: '${debtRatio.toStringAsFixed(1)} %',
      tier: debtTier,
    ),
    ScoreCriterion(
      label: 'Reste à vivre / part',
      valueLabel: '${resteAVivreParPart.round()} € / an',
      tier: resteTier,
    ),
    ScoreCriterion(label: 'Âge', valueLabel: '$age ans', tier: ageTier),
    ScoreCriterion(
      label: 'Profession',
      valueLabel: profession.label,
      tier: professionTier,
    ),
    ScoreCriterion(
      label: 'Pérennité des revenus',
      valueLabel: stabilityDurationLabel(ancienneteRevenusMois),
      tier: stabilityTier,
    ),
    ScoreCriterion(
      label: 'Historique bancaire',
      valueLabel: historiqueBancaire.label,
      tier: historyTier,
    ),
    ScoreCriterion(
      label: "Effort d'épargne",
      valueLabel: '${savingsEffort.toStringAsFixed(1)} %',
      tier: savingsTier,
    ),
  ];

  final totalPoints = criteria.fold(0, (sum, c) => sum + c.tier.points);
  final averagePoints = totalPoints / criteria.length;
  final overallTier = averagePoints >= 4.5
      ? ScoreTier.excellent
      : averagePoints >= 3.5
      ? ScoreTier.bon
      : averagePoints >= 2.5
      ? ScoreTier.moyen
      : averagePoints >= 1.5
      ? ScoreTier.mauvais
      : ScoreTier.critique;

  return RealEstateScoringResult(
    debtRatioPercent: debtRatio,
    resteAVivreAnnuelParPart: resteAVivreParPart,
    savingsEffortPercent: savingsEffort,
    criteria: criteria,
    totalPoints: totalPoints,
    overallTier: overallTier,
  );
}

import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/simulations/simulation_state_repository.dart';
import '../../core/ui/frosted_card.dart';
import '../../l10n/app_localizations.dart';
import 'loan_calculator.dart';
import 'real_estate_scoring_calculator.dart';

// ---------------------------------------------------------------------
// Libellés localisés des enums de `real_estate_scoring_calculator.dart`.
//
// Ces enums exposent aussi un getter `.label` en dur en français (utilisé
// par le calculateur pour construire `ScoreCriterion.label`/`.valueLabel`
// et couvert tel quel par `real_estate_scoring_calculator_test.dart`, qui
// n'a pas accès à un `BuildContext`/`AppLocalizations`) : on ne peut donc
// pas le faire dépendre de la locale sans casser ce test. On duplique donc
// ici, côté écran (qui a le contexte), un mapping enum → texte localisé
// utilisé pour tout l'affichage — le `.label` du calculateur reste une
// donnée interne non affichée.
// ---------------------------------------------------------------------

String _localizedTierLabel(AppLocalizations l10n, ScoreTier tier) =>
    switch (tier) {
      ScoreTier.excellent => l10n.simulations_scoring_tier_excellent,
      ScoreTier.bon => l10n.simulations_scoring_tier_good,
      ScoreTier.moyen => l10n.simulations_scoring_tier_average,
      ScoreTier.mauvais => l10n.simulations_scoring_tier_poor,
      ScoreTier.critique => l10n.simulations_scoring_tier_critical,
    };

String _localizedProfessionLabel(
  AppLocalizations l10n,
  ProfessionCategory profession,
) => switch (profession) {
  ProfessionCategory.dirigeantCadreSuperieur =>
    l10n.simulations_scoring_profession_executive_senior,
  ProfessionCategory.cadre => l10n.simulations_scoring_profession_executive,
  ProfessionCategory.salarie => l10n.simulations_scoring_profession_employee,
  ProfessionCategory.ouvrier => l10n.simulations_scoring_profession_worker,
  ProfessionCategory.chomeur => l10n.simulations_scoring_profession_unemployed,
};

String _localizedBankHistoryLabel(
  AppLocalizations l10n,
  BankHistoryStatus status,
) => switch (status) {
  BankHistoryStatus.none3Years => l10n.simulations_scoring_bank_history_none_3y,
  BankHistoryStatus.none1Year => l10n.simulations_scoring_bank_history_none_1y,
  BankHistoryStatus.none6Months =>
    l10n.simulations_scoring_bank_history_none_6m,
  BankHistoryStatus.one6Months => l10n.simulations_scoring_bank_history_one_6m,
  BankHistoryStatus.several6Months =>
    l10n.simulations_scoring_bank_history_several_6m,
};

/// Équivalent localisé de `stabilityDurationLabel` (calculateur, resté en
/// français pour la raison ci-dessus).
String _localizedStabilityDurationLabel(AppLocalizations l10n, int months) {
  if (months < 12) return l10n.investments_delay_months(months);
  final years = months / 12;
  final wholeYears = years == years.truncateToDouble();
  return wholeYears
      ? l10n.investments_delay_years(years.toInt())
      : l10n.simulations_scoring_duration_years_fractional(
          years.toStringAsFixed(1),
        );
}

/// Onglet "Scoring" de Simulation > Immobilier : estime approximativement
/// la qualité du profil d'un utilisateur pour l'obtention d'un crédit
/// immobilier, à partir de 7 critères bancaires classiques (endettement,
/// reste à vivre, âge, profession, pérennité des revenus, historique
/// bancaire, effort d'épargne) — chacun noté sur 5 paliers (Excellent à
/// Critique). Simulation pédagogique simplifiée, pas un vrai score
/// bancaire (voir `_ScoringDisclaimer`).
class RealEstateScoringScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const RealEstateScoringScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<RealEstateScoringScreen> createState() =>
      _RealEstateScoringScreenState();
}

class _RealEstateScoringScreenState extends State<RealEstateScoringScreen> {
  double _revenusMensuels = 3000;
  double _chargesMensuelles = 500;
  double _mensualitePret = 0;
  double _partsFiscales = 1;
  int _age = 35;
  ProfessionCategory _profession = ProfessionCategory.salarie;
  int _ancienneteMois = 24;
  BankHistoryStatus _historiqueBancaire = BankHistoryStatus.none1Year;
  double _epargneMensuelle = 200;

  late final SimulationStateRepository _stateRepo;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
    widget.amountVisibility.addListener(_onAmountVisibilityChanged);
  }

  void _onAmountVisibilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.amountVisibility.removeListener(_onAmountVisibilityChanged);
    super.dispose();
  }

  /// La mensualité n'est pré-remplie depuis l'onglet Prêt que si elle n'a
  /// jamais été éditée ici (absente du JSON déjà persisté pour Scoring) —
  /// une fois éditée, elle reste indépendante (le scoring peut vouloir
  /// tester un prêt hypothétique différent de celui configuré ailleurs).
  Future<void> _loadState() async {
    final data = await _stateRepo.read('real_estate_scoring');
    var mensualiteDefault = _mensualitePret;
    if (!data.containsKey('mensualitePret')) {
      final loanData = await _stateRepo.read('loan');
      mensualiteDefault =
          _mensualiteFromLoanJson(loanData) ?? mensualiteDefault;
    }
    if (!mounted) return;
    setState(() {
      _revenusMensuels = _readDouble(
        data,
        'revenusMensuels',
        fallback: _revenusMensuels,
      );
      _chargesMensuelles = _readDouble(
        data,
        'chargesMensuelles',
        fallback: _chargesMensuelles,
      );
      _mensualitePret = data.containsKey('mensualitePret')
          ? _readDouble(data, 'mensualitePret', fallback: mensualiteDefault)
          : mensualiteDefault;
      _partsFiscales = _readDouble(
        data,
        'partsFiscales',
        fallback: _partsFiscales,
      );
      _age = _readInt(data, 'age', fallback: _age);
      _profession = _readProfession(data, 'profession', fallback: _profession);
      _ancienneteMois = _readInt(
        data,
        'ancienneteMois',
        fallback: _ancienneteMois,
      );
      _historiqueBancaire = _readHistory(
        data,
        'historiqueBancaire',
        fallback: _historiqueBancaire,
      );
      _epargneMensuelle = _readDouble(
        data,
        'epargneMensuelle',
        fallback: _epargneMensuelle,
      );
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('real_estate_scoring', {
      'revenusMensuels': _revenusMensuels,
      'chargesMensuelles': _chargesMensuelles,
      'mensualitePret': _mensualitePret,
      'partsFiscales': _partsFiscales,
      'age': _age,
      'profession': _profession.name,
      'ancienneteMois': _ancienneteMois,
      'historiqueBancaire': _historiqueBancaire.name,
      'epargneMensuelle': _epargneMensuelle,
    });
  }

  void _update(void Function() change) {
    setState(change);
    _saveState();
  }

  /// Recalcule la mensualité (hors frais de dossier/garantie, qui ne
  /// pèsent pas sur la mensualité elle-même) à partir des paramètres bruts
  /// persistés par l'onglet Prêt — même lecture que
  /// `real_estate_estimation_screen.dart`'s `_LoanParams`, mais recalculée
  /// à la volée plutôt que stockée : cet onglet Prêt persiste des
  /// paramètres, pas son résultat calculé.
  double? _mensualiteFromLoanJson(Map<String, dynamic> loanData) {
    if (loanData.isEmpty) return null;
    final montantProjet = _readDouble(loanData, 'montantEmprunte', fallback: 0);
    final apport = _readDouble(loanData, 'apport', fallback: 0);
    final montantEmprunte = (montantProjet - apport).clamp(0.0, double.infinity);
    if (montantEmprunte <= 0) return null;
    final dureeAnnees = _readInt(
      loanData,
      'dureeAnnees',
      fallback: 20,
    ).clamp(1, 35);
    final result = simulateLoan(
      montantEmprunte: montantEmprunte,
      dureeAnnees: dureeAnnees,
      tauxInteret: _readDouble(loanData, 'tauxInteret', fallback: 3.5),
      assuranceMensuelle: _readDouble(
        loanData,
        'assuranceMensuelle',
        fallback: 20,
      ),
      fraisDossier: 0,
      fraisGarantie: 0,
      type: _readLoanType(loanData, 'type', fallback: LoanType.amortissable),
      differeActif: _readBool(loanData, 'differeActif', fallback: false),
      dureeDiffereMois: _readInt(
        loanData,
        'dureeDiffereMois',
        fallback: 12,
      ).clamp(1, dureeAnnees * 12 - 1),
      typeDiffere: _readDeferType(
        loanData,
        'typeDiffere',
        fallback: DeferType.partielle,
      ),
    );
    return result.mensualite;
  }

  double _readDouble(
    Map<String, dynamic> json,
    String key, {
    required double fallback,
  }) {
    final value = json[key];
    if (value is num) return value.toDouble();
    return fallback;
  }

  int _readInt(Map<String, dynamic> json, String key, {required int fallback}) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.round();
    return fallback;
  }

  bool _readBool(
    Map<String, dynamic> json,
    String key, {
    required bool fallback,
  }) {
    final value = json[key];
    if (value is bool) return value;
    return fallback;
  }

  LoanType _readLoanType(
    Map<String, dynamic> json,
    String key, {
    required LoanType fallback,
  }) {
    final value = json[key];
    if (value is String) {
      for (final t in LoanType.values) {
        if (t.name == value) return t;
      }
    }
    return fallback;
  }

  DeferType _readDeferType(
    Map<String, dynamic> json,
    String key, {
    required DeferType fallback,
  }) {
    final value = json[key];
    if (value is String) {
      for (final t in DeferType.values) {
        if (t.name == value) return t;
      }
    }
    return fallback;
  }

  ProfessionCategory _readProfession(
    Map<String, dynamic> json,
    String key, {
    required ProfessionCategory fallback,
  }) {
    final value = json[key];
    if (value is String) {
      for (final p in ProfessionCategory.values) {
        if (p.name == value) return p;
      }
    }
    return fallback;
  }

  BankHistoryStatus _readHistory(
    Map<String, dynamic> json,
    String key, {
    required BankHistoryStatus fallback,
  }) {
    final value = json[key];
    if (value is String) {
      for (final h in BankHistoryStatus.values) {
        if (h.name == value) return h;
      }
    }
    return fallback;
  }

  Future<void> _resetState() async {
    await _stateRepo.delete('real_estate_scoring');
    if (!mounted) return;
    setState(() {
      _revenusMensuels = 3000;
      _chargesMensuelles = 500;
      _mensualitePret = 0;
      _partsFiscales = 1;
      _age = 35;
      _profession = ProfessionCategory.salarie;
      _ancienneteMois = 24;
      _historiqueBancaire = BankHistoryStatus.none1Year;
      _epargneMensuelle = 200;
    });
    _loadState();
  }

  /// Largeur du plus long libellé parmi [labels], pour dimensionner la
  /// popup d'un `Select` sur son contenu réel (voir les commentaires sur
  /// `popupConstraints` plus bas). Marge ajoutée pour le padding horizontal
  /// et l'icône de coche d'une `SelectItemButton`.
  double _maxOptionWidth(BuildContext context, List<String> labels) {
    final style = DefaultTextStyle.of(context).style;
    var maxWidth = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width > maxWidth) maxWidth = painter.width;
    }
    return maxWidth + 64;
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.amountVisibility.hidden;
    final result = computeRealEstateScoring(
      revenusMensuels: _revenusMensuels,
      chargesMensuellesHorsPret: _chargesMensuelles,
      mensualitePret: _mensualitePret,
      partsFiscales: _partsFiscales,
      age: _age,
      profession: _profession,
      ancienneteRevenusMois: _ancienneteMois,
      historiqueBancaire: _historiqueBancaire,
      epargneMensuelle: _epargneMensuelle,
    );

    return _ScoringSplitCard(
      left: _buildInputsContent(hidden),
      right: _buildResultsContent(result, hidden),
    );
  }

  // ---------------------------------------------------------------------
  // Colonne de gauche : formulaire
  // ---------------------------------------------------------------------

  Widget _buildInputsContent(bool hidden) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(
          l10n.simulations_scoring_income_charges_section_label,
        ).muted().small(),
        const SizedBox(height: 12),
        _NumberField(
          label: l10n.simulations_scoring_household_monthly_income_label,
          suffix: '€',
          value: _revenusMensuels,
          step: 100,
          onChanged: (v) =>
              _update(() => _revenusMensuels = v.clamp(0, double.infinity)),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.simulations_scoring_monthly_expenses_label,
          suffix: '€',
          value: _chargesMensuelles,
          step: 50,
          onChanged: (v) =>
              _update(() => _chargesMensuelles = v.clamp(0, double.infinity)),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.simulations_scoring_mortgage_payment_label,
          suffix: '€',
          value: _mensualitePret,
          step: 50,
          onChanged: (v) =>
              _update(() => _mensualitePret = v.clamp(0, double.infinity)),
        ),
        shadcn.Text(
          l10n.simulations_scoring_prefilled_from_loan_tab,
        ).muted().xSmall(),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.simulations_scoring_tax_shares_label,
          suffix: l10n.simulations_scoring_suffix_shares,
          value: _partsFiscales,
          step: 0.5,
          decimals: 1,
          onChanged: (v) =>
              _update(() => _partsFiscales = v.clamp(0.5, 20)),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.simulations_scoring_monthly_savings_label,
          suffix: '€',
          value: _epargneMensuelle,
          step: 50,
          onChanged: (v) => _update(
            () => _epargneMensuelle = v.clamp(-double.infinity, double.infinity),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        shadcn.Text(l10n.simulations_scoring_profile_section_label).muted().small(),
        const SizedBox(height: 12),
        _NumberField(
          label: l10n.simulations_scoring_age_label,
          suffix: l10n.simulations_loan_suffix_years,
          value: _age.toDouble(),
          step: 1,
          decimals: 0,
          onChanged: (v) => _update(() => _age = v.round().clamp(16, 100)),
        ),
        const SizedBox(height: 16),
        shadcn.Text(l10n.simulations_scoring_profession_label).muted().small(),
        const SizedBox(height: 6),
        Select<ProfessionCategory>(
          value: _profession,
          placeholder: shadcn.Text(l10n.simulations_scoring_profession_label),
          onChanged: (value) {
            if (value != null) _update(() => _profession = value);
          },
          itemBuilder: (context, value) => shadcn.Text(
            _localizedProfessionLabel(l10n, value),
            overflow: TextOverflow.ellipsis,
          ),
          // Par défaut, la popup fait exactement la largeur du bouton
          // déclencheur (`PopoverConstraint.anchorFixedSize`) — bien trop
          // étroit pour des libellés comme "Chef d'entreprise à succès /
          // cadre supérieur" dans la colonne de gauche (360px).
          // `PopoverConstraint.intrinsic` le résoudrait proprement côté
          // shadcn_flutter, mais déclenche une assertion du MouseTracker de
          // Flutter ("!_debugDuringDeviceUpdate") à l'ouverture — measure la
          // largeur du plus long libellé nous-mêmes et la fixe via
          // `flexible`, déjà utilisé sans souci ailleurs dans l'app.
          popupWidthConstraint: PopoverConstraint.flexible,
          popupConstraints: BoxConstraints.tightFor(
            width: _maxOptionWidth(
              context,
              [
                for (final v in ProfessionCategory.values)
                  _localizedProfessionLabel(l10n, v),
              ],
            ),
          ),
          popup: (context) => SelectPopup(
            items: SelectItemList(
              children: [
                for (final value in ProfessionCategory.values)
                  SelectItemButton(
                    value: value,
                    child: shadcn.Text(_localizedProfessionLabel(l10n, value)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.simulations_scoring_income_seniority_label,
          suffix: l10n.simulations_loan_suffix_months,
          value: _ancienneteMois.toDouble(),
          step: 1,
          decimals: 0,
          onChanged: (v) =>
              _update(() => _ancienneteMois = v.round().clamp(0, 600)),
        ),
        const SizedBox(height: 16),
        shadcn.Text(l10n.simulations_scoring_bank_history_label).muted().small(),
        const SizedBox(height: 6),
        Select<BankHistoryStatus>(
          value: _historiqueBancaire,
          placeholder: shadcn.Text(l10n.simulations_scoring_bank_history_label),
          onChanged: (value) {
            if (value != null) _update(() => _historiqueBancaire = value);
          },
          itemBuilder: (context, value) => shadcn.Text(
            _localizedBankHistoryLabel(l10n, value),
            overflow: TextOverflow.ellipsis,
          ),
          // Voir le commentaire équivalent sur le Select Profession
          // ci-dessus : "Plusieurs incidents dans les 6 derniers mois" ne
          // tient pas dans la largeur du bouton déclencheur.
          popupWidthConstraint: PopoverConstraint.flexible,
          popupConstraints: BoxConstraints.tightFor(
            width: _maxOptionWidth(
              context,
              [
                for (final v in BankHistoryStatus.values)
                  _localizedBankHistoryLabel(l10n, v),
              ],
            ),
          ),
          popup: (context) => SelectPopup(
            items: SelectItemList(
              children: [
                for (final value in BankHistoryStatus.values)
                  SelectItemButton(
                    value: value,
                    child: shadcn.Text(_localizedBankHistoryLabel(l10n, value)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlineButton(
          onPressed: _resetState,
          leading: const Icon(LucideIcons.refreshCw),
          child: shadcn.Text(l10n.simulations_loan_reset_parameters),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Colonne de droite : résultats
  // ---------------------------------------------------------------------

  /// Reconstruit, pour chacun des 7 critères de [result] (dans l'ordre fixe
  /// où `computeRealEstateScoring` les construit — voir
  /// `real_estate_scoring_calculator.dart`), un libellé et une valeur
  /// affichée localisés à partir des données brutes déjà connues de l'écran
  /// (état saisi + agrégats de [result]), plutôt que d'utiliser
  /// `ScoreCriterion.label`/`.valueLabel` qui restent en français (voir le
  /// commentaire en tête de fichier sur `_localizedTierLabel` et consorts).
  List<(String label, String value, ScoreTier tier)> _localizedRows(
    AppLocalizations l10n,
    RealEstateScoringResult result,
  ) {
    final tiers = [for (final c in result.criteria) c.tier];
    return [
      (
        l10n.simulations_scoring_debt_ratio_label,
        '${result.debtRatioPercent.toStringAsFixed(1)} %',
        tiers[0],
      ),
      (
        l10n.simulations_scoring_disposable_income_label,
        l10n.simulations_scoring_disposable_income_value(
          result.resteAVivreAnnuelParPart.round(),
        ),
        tiers[1],
      ),
      (
        l10n.simulations_scoring_age_label,
        l10n.investments_delay_years(_age),
        tiers[2],
      ),
      (
        l10n.simulations_scoring_profession_label,
        _localizedProfessionLabel(l10n, _profession),
        tiers[3],
      ),
      (
        l10n.simulations_scoring_income_stability_label,
        _localizedStabilityDurationLabel(l10n, _ancienneteMois),
        tiers[4],
      ),
      (
        l10n.simulations_scoring_bank_history_label,
        _localizedBankHistoryLabel(l10n, _historiqueBancaire),
        tiers[5],
      ),
      (
        l10n.simulations_scoring_savings_effort_label,
        '${result.savingsEffortPercent.toStringAsFixed(1)} %',
        tiers[6],
      ),
    ];
  }

  Widget _buildResultsContent(RealEstateScoringResult result, bool hidden) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _OverallScoreBadge(result: result),
        const SizedBox(height: 20),
        Column(
          children: [
            for (final row in _localizedRows(l10n, result))
              _CriterionRow(label: row.$1, value: row.$2, tier: row.$3),
          ],
        ),
        const SizedBox(height: 20),
        const _ScoringDisclaimer(),
      ],
    );
  }
}

class _OverallScoreBadge extends StatelessWidget {
  final RealEstateScoringResult result;
  const _OverallScoreBadge({required this.result});

  IconData _iconFor(ScoreTier tier) => switch (tier) {
    ScoreTier.excellent || ScoreTier.bon => LucideIcons.circleCheck,
    ScoreTier.moyen => LucideIcons.circleAlert,
    ScoreTier.mauvais || ScoreTier.critique => LucideIcons.triangleAlert,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tier = result.overallTier;
    final color = tier.color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Theme.of(context).radiusMd),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(_iconFor(tier), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(
                  l10n.simulations_scoring_overall_profile_label(
                    _localizedTierLabel(l10n, tier),
                  ),
                ).semiBold(),
                shadcn.Text(
                  l10n.simulations_scoring_total_points(result.totalPoints),
                ).small(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  final String label;
  final String value;
  final ScoreTier tier;
  const _CriterionRow({
    required this.label,
    required this.value,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = tier.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(label).medium().small(),
                const SizedBox(height: 2),
                shadcn.Text(value).muted().xSmall(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color),
            ),
            child: shadcn.Text(
              _localizedTierLabel(l10n, tier),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoringDisclaimer extends StatelessWidget {
  const _ScoringDisclaimer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.mutedForeground;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.border),
        borderRadius: BorderRadius.circular(Theme.of(context).radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: shadcn.Text(
              l10n.simulations_scoring_disclaimer,
            ).muted().small(),
          ),
        ],
      ),
    );
  }
}

class _ScoringSplitCard extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _ScoringSplitCard({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;

          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(padding: const EdgeInsets.all(20), child: left),
                  const Divider(height: 1),
                  Padding(padding: const EdgeInsets.all(20), child: right),
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 360,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(child: left),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(child: right),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Champ numérique (identique en esprit à celui des autres onglets de
// Simulation — duplication volontaire, pas de widget privé partagé entre
// fichiers dans cette partie du code).
// ---------------------------------------------------------------------

class _NumberField extends StatefulWidget {
  final String label;
  final String suffix;
  final double value;
  final double step;
  final int decimals;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.label,
    required this.suffix,
    required this.value,
    required this.step,
    required this.onChanged,
    this.decimals = 0,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textFor(widget.value));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = _textFor(widget.value);
    if (!_focusNode.hasFocus && _controller.text != newText) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _textFor(double value) => widget.decimals == 0
      ? value.round().toString()
      : value.toStringAsFixed(widget.decimals).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(widget.label).muted().small(),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                border: Border.all(color: Colors.transparent),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (text) {
                  final parsed = parseDecimal(text);
                  if (parsed != null) widget.onChanged(parsed);
                },
                onSubmitted: (_) => _controller.text = _textFor(widget.value),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.ghost(
                  icon: const Icon(LucideIcons.chevronUp, size: 14),
                  onPressed: () => widget.onChanged(widget.value + widget.step),
                ),
                IconButton.ghost(
                  icon: const Icon(LucideIcons.chevronDown, size: 14),
                  onPressed: () => widget.onChanged(widget.value - widget.step),
                ),
              ],
            ),
            const SizedBox(width: 4),
            shadcn.Text(widget.suffix).muted(),
          ],
        ),
        const Divider(),
      ],
    );
  }
}

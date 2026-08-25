import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/simulations/simulation_state_repository.dart';
import '../../core/ui/frosted_card.dart';
import 'loan_calculator.dart';
import 'real_estate_scoring_calculator.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text('Revenus & charges').muted().small(),
        const SizedBox(height: 12),
        _NumberField(
          label: 'Revenus mensuels du foyer',
          suffix: '€',
          value: _revenusMensuels,
          step: 100,
          onChanged: (v) =>
              _update(() => _revenusMensuels = v.clamp(0, double.infinity)),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Charges mensuelles (hors prêt immo)',
          suffix: '€',
          value: _chargesMensuelles,
          step: 50,
          onChanged: (v) =>
              _update(() => _chargesMensuelles = v.clamp(0, double.infinity)),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Mensualité du prêt immobilier',
          suffix: '€',
          value: _mensualitePret,
          step: 50,
          onChanged: (v) =>
              _update(() => _mensualitePret = v.clamp(0, double.infinity)),
        ),
        shadcn.Text(
          'Pré-remplie depuis l\'onglet Prêt tant que non modifiée ici.',
        ).muted().xSmall(),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Parts fiscales',
          suffix: 'parts',
          value: _partsFiscales,
          step: 0.5,
          decimals: 1,
          onChanged: (v) =>
              _update(() => _partsFiscales = v.clamp(0.5, 20)),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Épargne mensuelle',
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
        shadcn.Text('Profil').muted().small(),
        const SizedBox(height: 12),
        _NumberField(
          label: 'Âge',
          suffix: 'ans',
          value: _age.toDouble(),
          step: 1,
          decimals: 0,
          onChanged: (v) => _update(() => _age = v.round().clamp(16, 100)),
        ),
        const SizedBox(height: 16),
        shadcn.Text('Profession').muted().small(),
        const SizedBox(height: 6),
        Select<ProfessionCategory>(
          value: _profession,
          placeholder: const shadcn.Text('Profession'),
          onChanged: (value) {
            if (value != null) _update(() => _profession = value);
          },
          itemBuilder: (context, value) => shadcn.Text(
            value.label,
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
              [for (final v in ProfessionCategory.values) v.label],
            ),
          ),
          popup: (context) => SelectPopup(
            items: SelectItemList(
              children: [
                for (final value in ProfessionCategory.values)
                  SelectItemButton(
                    value: value,
                    child: shadcn.Text(value.label),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Ancienneté des revenus actuels',
          suffix: 'mois',
          value: _ancienneteMois.toDouble(),
          step: 1,
          decimals: 0,
          onChanged: (v) =>
              _update(() => _ancienneteMois = v.round().clamp(0, 600)),
        ),
        const SizedBox(height: 16),
        shadcn.Text('Historique bancaire').muted().small(),
        const SizedBox(height: 6),
        Select<BankHistoryStatus>(
          value: _historiqueBancaire,
          placeholder: const shadcn.Text('Historique bancaire'),
          onChanged: (value) {
            if (value != null) _update(() => _historiqueBancaire = value);
          },
          itemBuilder: (context, value) => shadcn.Text(
            value.label,
            overflow: TextOverflow.ellipsis,
          ),
          // Voir le commentaire équivalent sur le Select Profession
          // ci-dessus : "Plusieurs incidents dans les 6 derniers mois" ne
          // tient pas dans la largeur du bouton déclencheur.
          popupWidthConstraint: PopoverConstraint.flexible,
          popupConstraints: BoxConstraints.tightFor(
            width: _maxOptionWidth(
              context,
              [for (final v in BankHistoryStatus.values) v.label],
            ),
          ),
          popup: (context) => SelectPopup(
            items: SelectItemList(
              children: [
                for (final value in BankHistoryStatus.values)
                  SelectItemButton(
                    value: value,
                    child: shadcn.Text(value.label),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlineButton(
          onPressed: _resetState,
          leading: const Icon(LucideIcons.refreshCw),
          child: const shadcn.Text('Réinitialiser les paramètres'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Colonne de droite : résultats
  // ---------------------------------------------------------------------

  Widget _buildResultsContent(RealEstateScoringResult result, bool hidden) {
    return Column(
      children: [
        _OverallScoreBadge(result: result),
        const SizedBox(height: 20),
        Column(
          children: [
            for (final criterion in result.criteria)
              _CriterionRow(criterion: criterion),
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
                shadcn.Text('Profil ${tier.label.toLowerCase()}').semiBold(),
                shadcn.Text('${result.totalPoints} / 35 points').small(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  final ScoreCriterion criterion;
  const _CriterionRow({required this.criterion});

  @override
  Widget build(BuildContext context) {
    final color = criterion.tier.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(criterion.label).medium().small(),
                const SizedBox(height: 2),
                shadcn.Text(criterion.valueLabel).muted().xSmall(),
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
              criterion.tier.label,
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
              "Estimation pédagogique et indicative : la grille de notation "
              "utilisée ici est une simplification courante des critères "
              "bancaires classiques, pas le barème d'un établissement "
              "précis. Le scoring réel d'une banque tient compte de bien "
              "d'autres éléments (garanties, patrimoine, politique interne "
              "du moment...).",
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

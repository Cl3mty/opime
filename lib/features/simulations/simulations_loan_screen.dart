import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/simulations/simulation_state_repository.dart';
import '../../core/ui/toggle_button_style.dart';
import '../../core/ui/frosted_card.dart';
import 'loan_calculator.dart';
import 'loan_chart.dart';

class LoanSimulationScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const LoanSimulationScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<LoanSimulationScreen> createState() => _LoanSimulationScreenState();
}

class _LoanSimulationScreenState extends State<LoanSimulationScreen> {
  double _montantProjet = 100000;
  double _apport = 0;
  int _dureeAnnees = 20;
  double _tauxInteret = 3.5;
  double _assuranceMensuelle = 20;
  double _fraisDossier = 800;
  double _fraisGarantie = 1200;

  LoanType _type = LoanType.amortissable;
  bool _differeActif = false;
  int _dureeDiffereMois = 12;
  DeferType _typeDiffere = DeferType.partielle;
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

  Future<void> _loadState() async {
    final data = await _stateRepo.read('loan');
    if (!mounted || data.isEmpty) return;

    setState(() {
      _montantProjet = _readDouble(
        data,
        'montantEmprunte',
        fallback: _montantProjet,
      );
      _apport = _readDouble(data, 'apport', fallback: _apport);
      _dureeAnnees = _readInt(
        data,
        'dureeAnnees',
        fallback: _dureeAnnees,
      ).clamp(1, 35);
      _tauxInteret = _readDouble(data, 'tauxInteret', fallback: _tauxInteret);
      // Migration depuis l'ancien format (taux d'assurance en % du capital
      // emprunté) vers une mensualité d'assurance en euros.
      if (data.containsKey('tauxAssurance') &&
          !data.containsKey('assuranceMensuelle')) {
        final taux = _readDouble(data, 'tauxAssurance', fallback: 0);
        _assuranceMensuelle = _montantEmprunteDerive * taux / 100 / 12;
      } else {
        _assuranceMensuelle = _readDouble(
          data,
          'assuranceMensuelle',
          fallback: _assuranceMensuelle,
        );
      }
      _fraisDossier = _readDouble(
        data,
        'fraisDossier',
        fallback: _fraisDossier,
      );
      _fraisGarantie = _readDouble(
        data,
        'fraisGarantie',
        fallback: _fraisGarantie,
      );
      _type = _readLoanType(data, 'type', fallback: _type);
      _differeActif = _readBool(data, 'differeActif', fallback: _differeActif);
      _dureeDiffereMois = _readInt(
        data,
        'dureeDiffereMois',
        fallback: _dureeDiffereMois,
      ).clamp(1, _dureeAnnees * 12 - 1);
      _typeDiffere = _readDeferType(
        data,
        'typeDiffere',
        fallback: _typeDiffere,
      );
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('loan', {
      'montantEmprunte': _montantProjet,
      'apport': _apport,
      'dureeAnnees': _dureeAnnees,
      'tauxInteret': _tauxInteret,
      'assuranceMensuelle': _assuranceMensuelle,
      'fraisDossier': _fraisDossier,
      'fraisGarantie': _fraisGarantie,
      'type': _type.name,
      'differeActif': _differeActif,
      'dureeDiffereMois': _dureeDiffereMois,
      'typeDiffere': _typeDiffere.name,
    });
  }

  void _update(void Function() change) {
    setState(change);
    _saveState();
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

  Future<void> _resetState() async {
    await _stateRepo.delete('loan');
    if (!mounted) return;
    setState(() {
      _montantProjet = 100000;
      _apport = 0;
      _dureeAnnees = 20;
      _tauxInteret = 3.5;
      _assuranceMensuelle = 20;
      _fraisDossier = 800;
      _fraisGarantie = 1200;
      _type = LoanType.amortissable;
      _differeActif = false;
      _dureeDiffereMois = 12;
      _typeDiffere = DeferType.partielle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _simulate();
    final hidden = widget.amountVisibility.hidden;

    return _LoanSplitCard(
      left: _buildInputsContent(),
      right: _buildResultsContent(result, hidden),
    );
  }

  /// Montant réellement emprunté, dérivé du coût du projet moins l'apport
  /// (jamais négatif) — même principe que l'onglet Estimation, qui peut
  /// écrire ces deux valeurs ici (clés `montantEmprunte`/`apport` du JSON
  /// persisté) via le bouton "Utiliser le prêt configuré".
  double get _montantEmprunteDerive =>
      (_montantProjet - _apport).clamp(0.0, double.infinity);

  LoanResult _simulate() => simulateLoan(
    montantEmprunte: _montantEmprunteDerive,
    dureeAnnees: _dureeAnnees,
    tauxInteret: _tauxInteret,
    assuranceMensuelle: _assuranceMensuelle,
    fraisDossier: _fraisDossier,
    fraisGarantie: _fraisGarantie,
    type: _type,
    differeActif: _differeActif,
    dureeDiffereMois: _dureeDiffereMois,
    typeDiffere: _typeDiffere,
  );

  // ---------------------------------------------------------------------
  // Colonne de gauche : formulaire
  // ---------------------------------------------------------------------

  Widget _buildInputsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text('Type de crédit').muted().small(),
        const SizedBox(height: 8),
        ButtonGroup(
          children: [
            SelectedButton(
              value: _type == LoanType.amortissable,
              onChanged: (_) => _update(() => _type = LoanType.amortissable),
              selectedStyle: const ButtonStyle.primary(),
              style: toggleUnselectedStyle(context),
              child: const shadcn.Text('Amortissable'),
            ),
            SelectedButton(
              value: _type == LoanType.inFine,
              onChanged: (_) => _update(() => _type = LoanType.inFine),
              selectedStyle: const ButtonStyle.primary(),
              style: toggleUnselectedStyle(context),
              child: const shadcn.Text('In fine'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _NumberField(
          label: 'Montant du projet',
          suffix: '€',
          value: _montantProjet,
          step: 1000,
          onChanged: (v) => _update(() => _montantProjet = v),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Apport',
          suffix: '€',
          value: _apport,
          step: 1000,
          onChanged: (v) => _update(() => _apport = v),
        ),
        const SizedBox(height: 4),
        shadcn.Text(
          'Montant emprunté (dérivé) : ${displayEuros(_montantEmprunteDerive, widget.amountVisibility.hidden)}',
        ).muted().small(),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Durée de remboursement',
          suffix: 'ans',
          value: _dureeAnnees.toDouble(),
          step: 1,
          decimals: 0,
          onChanged: (v) =>
              _update(() => _dureeAnnees = v.round().clamp(1, 35)),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: "Taux d'intérêt",
                suffix: '%',
                value: _tauxInteret,
                step: 0.1,
                decimals: 2,
                onChanged: (v) => _update(() => _tauxInteret = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: "Assurance mensuelle",
                suffix: '€/mois',
                value: _assuranceMensuelle,
                step: 5,
                decimals: 2,
                onChanged: (v) => _update(() => _assuranceMensuelle = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: 'Frais de dossier',
                suffix: '€',
                value: _fraisDossier,
                step: 50,
                decimals: 0,
                onChanged: (v) => _update(() => _fraisDossier = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: 'Frais de garantie',
                suffix: '€',
                value: _fraisGarantie,
                step: 50,
                decimals: 0,
                onChanged: (v) => _update(() => _fraisGarantie = v),
              ),
            ),
          ],
        ),
        if (_type == LoanType.amortissable) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: shadcn.Text(
                  'Différé de remboursement',
                ).semiBold().small(),
              ),
              _SimpleSwitch(
                value: _differeActif,
                onChanged: (v) => _update(() => _differeActif = v),
              ),
            ],
          ),
          if (_differeActif) ...[
            const SizedBox(height: 12),
            ButtonGroup(
              children: [
                SelectedButton(
                  value: _typeDiffere == DeferType.partielle,
                  onChanged: (_) =>
                      _update(() => _typeDiffere = DeferType.partielle),
                  selectedStyle: const ButtonStyle.primary(),
                  style: toggleUnselectedStyle(context),
                  child: const shadcn.Text('Franchise partielle'),
                ),
                SelectedButton(
                  value: _typeDiffere == DeferType.totale,
                  onChanged: (_) =>
                      _update(() => _typeDiffere = DeferType.totale),
                  selectedStyle: const ButtonStyle.primary(),
                  style: toggleUnselectedStyle(context),
                  child: const shadcn.Text('Franchise totale'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            shadcn.Text(
              _typeDiffere == DeferType.partielle
                  ? "Seuls les intérêts sont payés pendant le différé, le capital ne bouge pas."
                  : "Aucun paiement pendant le différé, les intérêts s'ajoutent au capital restant dû.",
            ).muted().small(),
            const SizedBox(height: 12),
            _NumberField(
              label: 'Durée du différé',
              suffix: 'mois',
              value: _dureeDiffereMois.toDouble(),
              step: 1,
              decimals: 0,
              onChanged: (v) => _update(
                () => _dureeDiffereMois = v.round().clamp(
                  1,
                  _dureeAnnees * 12 - 1,
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 12),
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

  Widget _buildResultsContent(LoanResult result, bool hidden) {
    final accent = Theme.of(context).colorScheme.primary;
    final red = const Color(0xFFE07A6B);
    final blue = const Color(0xFF7B8FE8);

    return Column(
      children: [
        shadcn.Text('Mensualités').muted(),
        const SizedBox(height: 8),
        shadcn.Text(
          displayEuros(result.mensualite, hidden),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        shadcn.Text.rich(
          TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: 'Dont assurance '),
              TextSpan(
                text: '${displayEuros(result.assuranceMensuelle, hidden)}/mois',
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ).muted(),
        if (result.mensualiteDifferee != null) ...[
          const SizedBox(height: 2),
          shadcn.Text(
            'Pendant le différé : ${displayEuros(result.mensualiteDifferee!, hidden)}/mois',
          ).muted().small(),
        ],
        if (result.capitalRembourseInFine != null) ...[
          const SizedBox(height: 2),
          shadcn.Text(
            'Capital remboursé en une fois à l\'échéance : ${displayEuros(result.capitalRembourseInFine!, hidden)}',
          ).muted().small(),
        ],
        const SizedBox(height: 20),
        _LoanCostStats(
          items: [
            (
              'Coût total du crédit',
              displayEuros(result.coutTotalCredit, hidden),
            ),
            ('Dont assurance', displayEuros(result.totalAssurance, hidden)),
            (
              'Coût total (frais inclus)',
              displayEuros(result.coutTotalAvecFrais, hidden),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            LegendPill(
              color: red,
              label: 'Capital',
              value: displayEuros(result.montantEmprunte, hidden),
            ),
            LegendPill(
              color: blue,
              label: 'Intérêts',
              value: displayEuros(
                result.coutTotalCredit - result.totalAssurance,
                hidden,
              ),
            ),
            LegendPill(
              color: accent,
              label: 'Assurance',
              value: displayEuros(result.totalAssurance, hidden),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 280,
          child: LoanChart(
            years: result.years,
            red: red,
            blue: blue,
            gold: accent,
            textColor: Theme.of(context).colorScheme.mutedForeground,
            gridColor: Theme.of(context).colorScheme.border,
            cardColor: Theme.of(context).colorScheme.popover,
            hidden: hidden,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        shadcn.Text.rich(
          TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: 'Pour un emprunt de '),
              TextSpan(
                text: displayEuros(result.montantEmprunte, hidden),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' sur '),
              TextSpan(
                text: '$_dureeAnnees ans',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ', votre mensualité s\'élève à '),
              TextSpan(
                text: displayEuros(result.mensualite, hidden),
                style: TextStyle(fontWeight: FontWeight.bold, color: accent),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const _LoanDisclaimer(),
      ],
    );
  }
}

class _LoanSplitCard extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _LoanSplitCard({required this.left, required this.right});

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

class _LoanDisclaimer extends StatelessWidget {
  const _LoanDisclaimer();

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
              "Simulation de prêt indicative: les résultats reposent sur des hypothèses simplifiées "
              "(taux constants, assurance linéaire, frais fixes). Les conditions bancaires réelles, "
              "garanties et clauses contractuelles peuvent modifier le coût total du crédit.",
            ).muted().small(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Interrupteur simple (maison, pour éviter de deviner l'API Switch de shadcn)
// ---------------------------------------------------------------------

class _SimpleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SimpleSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final track = Theme.of(context).colorScheme.border;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 22,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? accent : track,
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Champ numérique (identique en esprit à celui de la page Simulation)
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

/// Ligne de statistiques de coût sous le graphique : côte à côte si la
/// largeur le permet, sinon empilées en colonne pour ne pas écraser des
/// montants qui peuvent être grands (notamment sur mobile).
class _LoanCostStats extends StatelessWidget {
  final List<(String, String)> items;
  const _LoanCostStats({required this.items});

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value) {
      return Column(
        children: [
          shadcn.Text(label).muted().small(),
          const SizedBox(height: 4),
          shadcn.Text(value).large().semiBold(),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 40),
                stat(items[i].$1, items[i].$2),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              stat(items[i].$1, items[i].$2),
            ],
          ],
        );
      },
    );
  }
}

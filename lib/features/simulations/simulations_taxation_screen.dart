import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/simulations/simulation_state_repository.dart';
import '../../core/ui/frosted_card.dart';

class TaxationSimulationScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const TaxationSimulationScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<TaxationSimulationScreen> createState() => _TaxationScreenState();
}

class _TaxationScreenState extends State<TaxationSimulationScreen> {
  int _tabIndex = 0;
  late final SimulationStateRepository _stateRepo;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
  }

  Future<void> _loadState() async {
    final data = await _stateRepo.read('taxation');
    if (!mounted) return;
    setState(() {
      final tabValue = data['tabIndex'];
      if (tabValue is int) {
        _tabIndex = tabValue.clamp(0, 1);
      } else if (tabValue is num) {
        _tabIndex = tabValue.round().clamp(0, 1);
      }
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('taxation', {'tabIndex': _tabIndex});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TabList(
                index: _tabIndex,
                onChanged: (value) {
                  setState(() => _tabIndex = value);
                  _saveState();
                },
                children: const [
                  TabItem(child: shadcn.Text('IR')),
                  TabItem(child: shadcn.Text('IFI')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tabIndex == 0
                ? _IRTab(
                    vaultPath: widget.vaultPath,
                    amountVisibility: widget.amountVisibility,
                  )
                : _IFITab(
                    vaultPath: widget.vaultPath,
                    amountVisibility: widget.amountVisibility,
                  ),
          ),
        ],
      ),
    );
  }
}

class _IFIDisclaimer extends StatelessWidget {
  const _IFIDisclaimer();

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
              "Simulation IFI indicative basée sur un barème 2026 simplifié, hors dispositifs spécifiques "
              "(décote, exonérations particulières, cas de démembrement, plafonnement selon revenus, etc.). "
              "Les règles fiscales évoluent régulièrement : vérifiez toujours avec un professionnel avant décision.",
            ).muted().small(),
          ),
        ],
      ),
    );
  }
}

class _IRDisclaimer extends StatelessWidget {
  const _IRDisclaimer();

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
              "Simulation d'impôt sur le revenu indicative avec quotient familial simplifié. "
              "Elle n'intègre pas toutes les situations réelles (charges déductibles, crédits/réductions d'impôt, "
              "revenus spécifiques, plafonnements et règles particulières). Vérifiez le résultat final avec un expert.",
            ).muted().small(),
          ),
        ],
      ),
    );
  }
}

class _TaxationSplitCard extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _TaxationSplitCard({required this.left, required this.right});

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
                width: 300,
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
// Partagé
// ---------------------------------------------------------------------

class BracketRow {
  final String label;
  final double montant;
  final double montantMax;
  final double impot;
  BracketRow({
    required this.label,
    required this.montant,
    required this.montantMax,
    required this.impot,
  });
}

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

class _LegendPill extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        shadcn.Text(label).small(),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final List<String> values;
  final bool expand;
  const _StatColumn({
    required this.label,
    required this.values,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: expand
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        shadcn.Text(label).muted().small(),
        const SizedBox(height: 4),
        for (final v in values) shadcn.Text(v).medium(),
      ],
    );
    return expand ? Expanded(child: content) : content;
  }
}

/// Ligne de statistiques sous un graphique : côte à côte si la largeur le
/// permet, sinon empilées en colonne pour ne pas écraser des montants qui
/// peuvent être grands (notamment sur mobile).
class _StatRow extends StatelessWidget {
  final List<(String, List<String>)> items;
  const _StatRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            children: [
              for (final item in items)
                _StatColumn(label: item.$1, values: item.$2),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _StatColumn(
                label: items[i].$1,
                values: items[i].$2,
                expand: false,
              ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Onglet IFI
// ---------------------------------------------------------------------

class IFIResult {
  final double tauxMax;
  final double total;
  final List<BracketRow> chartData;
  IFIResult({
    required this.tauxMax,
    required this.total,
    required this.chartData,
  });
}

/// Barème IFI (article 977 CGI) : seuils de patrimoine immobilier net
/// et taux marginaux par tranche.
const ifiLimits = [800000.0, 1300000.0, 2570000.0, 5000000.0, 10000000.0];
const ifiRates = [0.0, 0.5, 0.7, 1.0, 1.25, 1.5];

/// Largeur de chaque tranche, utilisée uniquement pour l'échelle du
/// graphique (la dernière tranche est en réalité non plafonnée).
const ifiMontantMax = [
  800000.0,
  500000.0,
  1270000.0,
  2430000.0,
  5000000.0,
  1200000.0,
];

/// L'IFI n'est dû qu'au-delà de 1 300 000 € de patrimoine net (en-dessous,
/// exonération totale) ; au-delà, le barème s'applique sur la totalité du
/// patrimoine à partir de 800 000 € (pas de décote implémentée ici, voir
/// [_IFIDisclaimer]).
IFIResult computeIFI(double immobilierNet) {
  double c0(double v) => v < 0 ? 0 : v;
  final montants = [
    c0(min(immobilierNet, ifiLimits[0])),
    c0(min(immobilierNet - ifiLimits[0], ifiLimits[1] - ifiLimits[0])),
    c0(min(immobilierNet - ifiLimits[1], ifiLimits[2] - ifiLimits[1])),
    c0(min(immobilierNet - ifiLimits[2], ifiLimits[3] - ifiLimits[2])),
    c0(min(immobilierNet - ifiLimits[3], ifiLimits[4] - ifiLimits[3])),
    c0(immobilierNet - ifiLimits[4]),
  ];

  var maxIndex = 0;
  for (var i = 0; i < montants.length; i++) {
    if (montants[i] > 0) maxIndex = i;
  }
  final exonere = immobilierNet <= 1300000;
  final tauxMax = exonere ? 0.0 : ifiRates[maxIndex];

  final impots = List.generate(
    6,
    (i) => exonere ? 0.0 : montants[i] * ifiRates[i] / 100,
  );
  final total = impots.fold<double>(0, (s, v) => s + v);

  final chartData = List.generate(
    6,
    (i) => BracketRow(
      label: '${ifiRates[i]}%',
      montant: montants[i],
      montantMax: ifiMontantMax[i],
      impot: impots[i],
    ),
  );

  return IFIResult(tauxMax: tauxMax, total: total, chartData: chartData);
}

class _IFITab extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const _IFITab({required this.vaultPath, required this.amountVisibility});

  @override
  State<_IFITab> createState() => _IFITabState();
}

class _IFITabState extends State<_IFITab> {
  double _immobilierNet = 2000000;
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
    final data = await _stateRepo.read('taxation_ifi');
    if (!mounted || data.isEmpty) return;
    setState(() {
      final value = data['immobilierNet'];
      if (value is num) _immobilierNet = value.toDouble();
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('taxation_ifi', {'immobilierNet': _immobilierNet});
  }

  Future<void> _resetState() async {
    await _stateRepo.delete('taxation_ifi');
    if (!mounted) return;
    setState(() {
      _immobilierNet = 2000000;
    });
  }

  IFIResult _compute() => computeIFI(_immobilierNet);

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    final accent = Theme.of(context).colorScheme.primary;
    final violet = const Color(0xFF9B7BE8);
    final red = const Color(0xFFE07A6B);
    final hidden = widget.amountVisibility.hidden;

    return _TaxationSplitCard(
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NumberField(
            label: 'Patrimoine immobilier net',
            suffix: '€',
            value: _immobilierNet,
            step: 50000,
            onChanged: (v) {
              setState(() => _immobilierNet = v);
              _saveState();
            },
          ),
          const SizedBox(height: 8),
          OutlineButton(
            onPressed: _resetState,
            leading: const Icon(LucideIcons.refreshCw),
            child: const shadcn.Text('Réinitialiser les paramètres'),
          ),
        ],
      ),
      right: Column(
        children: [
          shadcn.Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 18),
              children: [
                const TextSpan(
                  text:
                      'Cette année, vous avez un patrimoine immobilier net de ',
                ),
                TextSpan(
                  text: displayEuros(_immobilierNet, hidden),
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text:
                      ', induisant un impôt sur la fortune immobilière total de ',
                ),
                TextSpan(
                  text: displayEuros(result.total, hidden),
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ", soit l'équivalent de "),
                TextSpan(
                  text: '${displayEuros(result.total / 12, hidden)}/mois',
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 320,
            child: _BracketChart(
              data: result.chartData,
              amber: accent,
              violet: violet,
              red: red,
              textColor: Theme.of(context).colorScheme.mutedForeground,
              gridColor: Theme.of(context).colorScheme.border,
              cardColor: Theme.of(context).colorScheme.popover,
              hidden: hidden,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            children: [
              _LegendPill(color: accent, label: 'Montant'),
              _LegendPill(color: violet, label: 'Montant max de la tranche'),
              _LegendPill(color: red, label: 'Impôt'),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _StatRow(
            items: [
              ("Taux maximal d'imposition", ['${result.tauxMax}%']),
              (
                'IFI (total & mensualisé)',
                [
                  displayEuros(result.total, hidden),
                  '${displayEuros(result.total / 12, hidden)}/mois',
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _IFIDisclaimer(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Onglet Impôt sur le revenu
// ---------------------------------------------------------------------

class IRResult {
  final double quotient;
  final double tmi;
  final double total;
  final List<BracketRow> chartData;
  IRResult({
    required this.quotient,
    required this.tmi,
    required this.total,
    required this.chartData,
  });
}

/// Barème de l'impôt sur le revenu par part de quotient familial (revenus
/// 2024, dernier barème connu, non révisé depuis pour l'année suivante).
const irLimits = [11294.0, 28797.0, 82341.0, 177106.0];
const irRates = [0.0, 11.0, 30.0, 41.0, 45.0];

/// Largeur de chaque tranche, utilisée uniquement pour l'échelle du
/// graphique (la dernière tranche est en réalité non plafonnée).
const irMontantMax = [11294.0, 17503.0, 53544.0, 94765.0, 120000.0];

/// Quotient familial simplifié : le revenu net imposable est divisé par le
/// nombre de parts pour obtenir le taux marginal, puis l'impôt par part est
/// multiplié par le nombre de parts pour obtenir l'impôt total du foyer.
IRResult computeIR({required double netImposable, required double nbrParts}) {
  double c0(double v) => v < 0 ? 0 : v;
  final parts = nbrParts < 1 ? 1.0 : nbrParts;
  final quotient = netImposable / parts;

  final montants = [
    c0(min(quotient, irLimits[0])),
    c0(min(quotient - irLimits[0], irLimits[1] - irLimits[0])),
    c0(min(quotient - irLimits[1], irLimits[2] - irLimits[1])),
    c0(min(quotient - irLimits[2], irLimits[3] - irLimits[2])),
    c0(quotient - irLimits[3]),
  ];

  var maxIndex = 0;
  for (var i = 0; i < montants.length; i++) {
    if (montants[i] > 0) maxIndex = i;
  }
  final tmi = irRates[maxIndex];

  final impots = List.generate(5, (i) => montants[i] * irRates[i] / 100);
  final total = impots.fold<double>(0, (s, v) => s + v) * parts;

  final chartData = List.generate(
    5,
    (i) => BracketRow(
      label: '${irRates[i]}%',
      montant: montants[i],
      montantMax: irMontantMax[i],
      impot: impots[i],
    ),
  );

  return IRResult(
    quotient: quotient,
    tmi: tmi,
    total: total,
    chartData: chartData,
  );
}

class _IRTab extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const _IRTab({required this.vaultPath, required this.amountVisibility});

  @override
  State<_IRTab> createState() => _IRTabState();
}

class _IRTabState extends State<_IRTab> {
  double _netImposable = 150000;
  double _nbrParts = 1;
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
    final data = await _stateRepo.read('taxation_ir');
    if (!mounted || data.isEmpty) return;
    setState(() {
      final netImposable = data['netImposable'];
      final nbrParts = data['nbrParts'];
      if (netImposable is num) _netImposable = netImposable.toDouble();
      if (nbrParts is num) {
        _nbrParts = nbrParts.toDouble().clamp(1, double.infinity);
      }
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('taxation_ir', {
      'netImposable': _netImposable,
      'nbrParts': _nbrParts,
    });
  }

  Future<void> _resetState() async {
    await _stateRepo.delete('taxation_ir');
    if (!mounted) return;
    setState(() {
      _netImposable = 150000;
      _nbrParts = 1;
    });
  }

  IRResult _compute() =>
      computeIR(netImposable: _netImposable, nbrParts: _nbrParts);

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    final accent = Theme.of(context).colorScheme.primary;
    final violet = const Color(0xFF9B7BE8);
    final red = const Color(0xFFE07A6B);
    final hidden = widget.amountVisibility.hidden;

    return _TaxationSplitCard(
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NumberField(
            label: 'Revenu net imposable',
            suffix: '€',
            value: _netImposable,
            step: 5000,
            onChanged: (v) {
              setState(() => _netImposable = v);
              _saveState();
            },
          ),
          const SizedBox(height: 16),
          _NumberField(
            label: 'Nombre de parts',
            suffix: '',
            value: _nbrParts,
            step: 0.5,
            decimals: 1,
            onChanged: (v) {
              setState(() => _nbrParts = v < 1 ? 1 : v);
              _saveState();
            },
          ),
          const SizedBox(height: 8),
          OutlineButton(
            onPressed: _resetState,
            leading: const Icon(LucideIcons.refreshCw),
            child: const shadcn.Text('Réinitialiser les paramètres'),
          ),
        ],
      ),
      right: Column(
        children: [
          shadcn.Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 18),
              children: [
                const TextSpan(
                  text: 'Cette année, vous avez un net imposable de ',
                ),
                TextSpan(
                  text: displayEuros(_netImposable, hidden),
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text: ", induisant un impôt sur le revenu total de ",
                ),
                TextSpan(
                  text: displayEuros(result.total, hidden),
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ", soit l'équivalent de "),
                TextSpan(
                  text: '${displayEuros(result.total / 12, hidden)}/mois',
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 320,
            child: _BracketChart(
              data: result.chartData,
              amber: accent,
              violet: violet,
              red: red,
              textColor: Theme.of(context).colorScheme.mutedForeground,
              gridColor: Theme.of(context).colorScheme.border,
              cardColor: Theme.of(context).colorScheme.popover,
              hidden: hidden,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            children: [
              _LegendPill(color: accent, label: 'Montant'),
              _LegendPill(color: violet, label: 'Montant max de la tranche'),
              _LegendPill(color: red, label: 'Impôt'),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _StatRow(
            items: [
              ('Quotient familial', [displayEuros(result.quotient, hidden)]),
              ("Taux marginal d'imposition", ['${result.tmi}%']),
              (
                'Impôt sur le revenu (total & mensualisé)',
                [
                  displayEuros(result.total, hidden),
                  '${displayEuros(result.total / 12, hidden)}/mois',
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _IRDisclaimer(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Graphique en barres groupées (3 barres par tranche)
// ---------------------------------------------------------------------

class _BracketChart extends StatefulWidget {
  final List<BracketRow> data;
  final Color amber;
  final Color violet;
  final Color red;
  final Color textColor;
  final Color gridColor;
  final Color cardColor;
  final bool hidden;

  const _BracketChart({
    required this.data,
    required this.amber,
    required this.violet,
    required this.red,
    required this.textColor,
    required this.gridColor,
    required this.cardColor,
    required this.hidden,
  });

  @override
  State<_BracketChart> createState() => _BracketChartState();
}

class _BracketChartState extends State<_BracketChart> {
  int? _hoveredIndex;

  static const double _leftAxisWidth = 60;
  static const double _bottomAxisHeight = 24;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final chartHeight = height - _bottomAxisHeight;
        final n = widget.data.length;
        final groupSlot = (width - _leftAxisWidth) / n;

        void updateHover(Offset local) {
          final idx = ((local.dx - _leftAxisWidth) / groupSlot).floor().clamp(
            0,
            n - 1,
          );
          if (idx != _hoveredIndex) setState(() => _hoveredIndex = idx);
        }

        final hovered = _hoveredIndex != null
            ? widget.data[_hoveredIndex!]
            : null;

        return MouseRegion(
          onHover: (e) => updateHover(e.localPosition),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: GestureDetector(
            onPanDown: (details) => updateHover(details.localPosition),
            onPanUpdate: (details) => updateHover(details.localPosition),
            onPanEnd: (_) => setState(() => _hoveredIndex = null),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(width, height),
                  painter: _BracketChartPainter(
                    data: widget.data,
                    amber: widget.amber,
                    violet: widget.violet,
                    red: widget.red,
                    textColor: widget.textColor,
                    gridColor: widget.gridColor,
                    hoveredIndex: _hoveredIndex,
                    hidden: widget.hidden,
                  ),
                ),
                if (hovered != null)
                  Positioned(
                    left: (_leftAxisWidth + groupSlot * _hoveredIndex! - 120)
                        .clamp(
                          _leftAxisWidth,
                          max(_leftAxisWidth, width - 260),
                        ),
                    top: (chartHeight / 2 - 90).clamp(
                      0,
                      max(0.0, chartHeight - 180),
                    ),
                    child: _BracketTooltip(
                      title: 'Tranche ${hovered.label}',
                      montant: hovered.montant,
                      montantMax: hovered.montantMax,
                      impot: hovered.impot,
                      amber: widget.amber,
                      violet: widget.violet,
                      red: widget.red,
                      cardColor: widget.cardColor,
                      hidden: widget.hidden,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BracketTooltip extends StatelessWidget {
  final String title;
  final double montant;
  final double montantMax;
  final double impot;
  final Color amber;
  final Color violet;
  final Color red;
  final Color cardColor;
  final bool hidden;

  const _BracketTooltip({
    required this.title,
    required this.montant,
    required this.montantMax,
    required this.impot,
    required this.amber,
    required this.violet,
    required this.red,
    required this.cardColor,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(title).muted(),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 8),
                _row('Montant', montant, amber),
                const SizedBox(height: 6),
                _row('Montant max', montantMax, violet),
                const SizedBox(height: 6),
                _row('Impôt', impot, red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: shadcn.Text(label)),
        shadcn.Text(
          displayEuros(value, hidden),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _BracketChartPainter extends CustomPainter {
  final List<BracketRow> data;
  final Color amber;
  final Color violet;
  final Color red;
  final Color textColor;
  final Color gridColor;
  final int? hoveredIndex;
  final bool hidden;

  _BracketChartPainter({
    required this.data,
    required this.amber,
    required this.violet,
    required this.red,
    required this.textColor,
    required this.gridColor,
    required this.hoveredIndex,
    required this.hidden,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxisWidth = 60.0;
    const bottomAxisHeight = 24.0;
    final chartWidth = size.width - leftAxisWidth;
    final chartHeight = size.height - bottomAxisHeight;
    final n = data.length;
    final groupSlot = chartWidth / n;
    final barWidth = groupSlot * 0.22;
    final barGap = groupSlot * 0.06;

    final maxValue = data
        .map(
          (d) => [
            d.montant,
            d.montantMax,
            d.impot,
          ].reduce((a, b) => a > b ? a : b),
        )
        .reduce((a, b) => a > b ? a : b);
    final axisMax = _niceCeil(maxValue * 1.15);
    const gridLines = 4;
    final step = axisMax / gridLines;

    double yFor(double value) => chartHeight - (value / axisMax) * chartHeight;

    for (var i = 0; i <= gridLines; i++) {
      final v = step * i;
      final y = yFor(v);
      canvas.drawLine(
        Offset(leftAxisWidth, y),
        Offset(size.width, y),
        Paint()
          ..color = gridColor.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: displayEurosCompact(v, hidden),
          style: TextStyle(color: textColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftAxisWidth - tp.width - 8, y - tp.height / 2));
    }

    for (var idx = 0; idx < n; idx++) {
      final row = data[idx];
      final groupStart = leftAxisWidth + groupSlot * idx;
      final isHovered = hoveredIndex == idx;
      final opacity = isHovered ? 1.0 : 0.85;

      final centerX = groupStart + groupSlot / 2;
      final x1 = centerX - (barWidth * 1.5 + barGap);
      final x2 = centerX - barWidth / 2;
      final x3 = centerX + barWidth / 2 + barGap;

      _drawBar(
        canvas,
        x1,
        yFor(row.montant),
        barWidth,
        chartHeight - yFor(row.montant),
        amber.withValues(alpha: opacity),
      );
      _drawBar(
        canvas,
        x2,
        yFor(row.montantMax),
        barWidth,
        chartHeight - yFor(row.montantMax),
        violet.withValues(alpha: opacity),
      );
      _drawBar(
        canvas,
        x3,
        yFor(row.impot),
        barWidth,
        chartHeight - yFor(row.impot),
        red.withValues(alpha: opacity),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: row.label,
          style: TextStyle(color: textColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(centerX - tp.width / 2, chartHeight + 6));
    }
  }

  void _drawBar(
    Canvas canvas,
    double x,
    double top,
    double width,
    double height,
    Color color,
  ) {
    if (height <= 0) return;
    final rrect = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, top, width, height),
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(2),
    );
    canvas.drawRRect(rrect, Paint()..color = color);
  }

  double _niceCeil(double value) {
    if (value <= 0) return 100;
    var magnitude = 1.0;
    while (magnitude * 10 <= value) {
      magnitude *= 10;
    }
    final normalized = value / magnitude;
    double niceNormalized;
    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }
    return niceNormalized * magnitude;
  }

  @override
  bool shouldRepaint(covariant _BracketChartPainter oldDelegate) =>
      oldDelegate.hoveredIndex != hoveredIndex ||
      oldDelegate.data != data ||
      oldDelegate.hidden != hidden;
}

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/simulations/simulation_state_repository.dart';
import '../../core/ui/frosted_card.dart';

class WealthSimulationScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const WealthSimulationScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<WealthSimulationScreen> createState() => _WealthSimulationScreenState();
}

class _WealthSimulationScreenState extends State<WealthSimulationScreen> {
  int _tabIndex = 0;
  late final SimulationStateRepository _stateRepo;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
  }

  Future<void> _loadState() async {
    final data = await _stateRepo.read('wealth');
    if (!mounted) return;
    setState(() {
      _tabIndex = _readInt(data, 'tabIndex', fallback: _tabIndex).clamp(0, 1);
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('wealth', {'tabIndex': _tabIndex});
  }

  int _readInt(Map<String, dynamic> json, String key, {required int fallback}) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.round();
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compactLabels = constraints.maxWidth < 500;
              // Align + scroll horizontal plutôt qu'un simple Row centré :
              // même en version courte, "Intérêts composés" peut forcer les
              // tabs à passer sur deux lignes sur les téléphones les plus
              // étroits (le Row leur donne une largeur non bornée dans
              // laquelle Text s'enroule). Centré quand tout tient, défilable
              // sinon.
              return Align(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: TabList(
                    index: _tabIndex,
                    onChanged: (value) {
                      setState(() => _tabIndex = value);
                      _saveState();
                    },
                    children: [
                      TabItem(
                        child: shadcn.Text(
                          compactLabels
                              ? 'Intérêts composés'
                              : 'Déterministe (Intérêts composés)',
                        ),
                      ),
                      TabItem(
                        child: shadcn.Text(
                          compactLabels
                              ? 'Monte-Carlo'
                              : 'Stochastique (Monte-Carlo)',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tabIndex == 0
                ? _SimpleSimulationTab(
                    vaultPath: widget.vaultPath,
                    amountVisibility: widget.amountVisibility,
                  )
                : _MonteCarloSimulationTab(
                    vaultPath: widget.vaultPath,
                    amountVisibility: widget.amountVisibility,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SimulationSplitCard extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _SimulationSplitCard({required this.left, required this.right});

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

class _WealthSimpleDisclaimer extends StatelessWidget {
  const _WealthSimpleDisclaimer();

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
              "Projection déterministe indicative fondée sur des rendements constants et une fiscalité simplifiée. "
              "Les valeurs « pouvoir d'achat actuel » actualisent le résultat nominal avec le taux d'inflation renseigné "
              "(valeur réelle = valeur nominale ÷ (1 + inflation)^années). "
              "Les marchés, frais, impôts réels et aléas de vie peuvent modifier significativement les résultats.",
            ).muted().small(),
          ),
        ],
      ),
    );
  }
}

class _WealthMonteCarloDisclaimer extends StatelessWidget {
  const _WealthMonteCarloDisclaimer();

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
              "Simulation Monte-Carlo indicative: les distributions retenues et hypothèses de volatilité restent simplifiées. "
              "Les percentiles ne constituent ni une garantie de performance ni une recommandation d'investissement.",
            ).muted().small(),
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// Formatage partagé
// =======================================================================

double gaussianSample(Random rng, double mean, double stddev) {
  final u1 = rng.nextDouble().clamp(1e-9, 1.0);
  final u2 = rng.nextDouble();
  final z0 = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  return mean + z0 * stddev;
}

double monthlyRateFromAnnualPct(double annualPct) {
  final annualGrowthFactor = (1 + annualPct / 100).clamp(0.0, double.infinity);
  if (annualGrowthFactor == 0) return -1;
  return pow(annualGrowthFactor, 1 / 12).toDouble() - 1;
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

// =======================================================================
// Champ numérique et slider partagés par les deux onglets
// =======================================================================

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

class _SplitSlider extends StatelessWidget {
  final String label;
  final String leftLabel;
  final String rightLabel;
  final double value;
  final ValueChanged<double> onChanged;

  const _SplitSlider({
    required this.label,
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final track = Theme.of(context).colorScheme.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(label).muted().small(),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            void updateFromDx(double dx) {
              final fraction = (dx / width).clamp(0.0, 1.0);
              onChanged((fraction * 100).clamp(0, 100));
            }

            return GestureDetector(
              onPanDown: (details) => updateFromDx(details.localPosition.dx),
              onPanUpdate: (details) => updateFromDx(details.localPosition.dx),
              child: SizedBox(
                height: 24,
                width: width,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: track,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      height: 4,
                      width: width * (value / 100),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      left: (width * (value / 100) - 10).clamp(0, width - 20),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            shadcn.Text.rich(
              TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(text: '$leftLabel '),
                  TextSpan(
                    text: '${value.round()} %',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            shadcn.Text.rich(
              TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(text: '$rightLabel '),
                  TextSpan(
                    text: '${(100 - value).round()} %',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendPill extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendPill({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          shadcn.Text(label).small(),
          const SizedBox(width: 6),
          shadcn.Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ).small(),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final bool expand;
  const _StatColumn({
    required this.label,
    required this.value,
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
        shadcn.Text(value).medium(),
      ],
    );
    return expand ? Expanded(child: content) : content;
  }
}

/// Ligne de statistiques sous un graphique : les valeurs restent côte à
/// côte si la largeur le permet, sinon s'empilent en colonne pour ne pas
/// écraser des montants qui peuvent être grands (notamment sur mobile).
class _StatRow extends StatelessWidget {
  final List<(String, String)> items;
  const _StatRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            children: [
              for (final item in items)
                _StatColumn(label: item.$1, value: item.$2),
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
                value: items[i].$2,
                expand: false,
              ),
            ],
          ],
        );
      },
    );
  }
}

// =======================================================================
// ONGLET 1 : Simple (intérêts composés)
// =======================================================================

class _SimpleSimulationTab extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const _SimpleSimulationTab({
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<_SimpleSimulationTab> createState() => _SimpleSimulationTabState();
}

class _SimpleSimulationTabState extends State<_SimpleSimulationTab> {
  double _patrimoineActuel = 100000;
  double _repartitionInitialeBourse = 50;
  double _investissementsMensuels = 500;
  double _repartitionInvestBourse = 50;
  int _nombreAnnees = 20;
  double _rendementBourse = 8;
  double _rendementAutre = 5;
  double _impositionBourse = 18.6;
  double _impositionAutre = 31.4;
  double _tauxRetrait = 4;
  double _tauxInflation = 3;
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
    final data = await _stateRepo.read('wealth_simple');
    if (!mounted || data.isEmpty) return;
    setState(() {
      _patrimoineActuel = _readDouble(
        data,
        'patrimoineActuel',
        fallback: _patrimoineActuel,
      );
      _repartitionInitialeBourse = _readDouble(
        data,
        'repartitionInitialeBourse',
        fallback: _repartitionInitialeBourse,
      ).clamp(0, 100);
      _investissementsMensuels = _readDouble(
        data,
        'investissementsMensuels',
        fallback: _investissementsMensuels,
      );
      _repartitionInvestBourse = _readDouble(
        data,
        'repartitionInvestBourse',
        fallback: _repartitionInvestBourse,
      ).clamp(0, 100);
      _nombreAnnees = _readInt(
        data,
        'nombreAnnees',
        fallback: _nombreAnnees,
      ).clamp(1, 60);
      _rendementBourse = _readDouble(
        data,
        'rendementBourse',
        fallback: _rendementBourse,
      );
      _rendementAutre = _readDouble(
        data,
        'rendementAutre',
        fallback: _rendementAutre,
      );
      _impositionBourse = _readDouble(
        data,
        'impositionBourse',
        fallback: _impositionBourse,
      );
      _impositionAutre = _readDouble(
        data,
        'impositionAutre',
        fallback: _impositionAutre,
      );
      _tauxRetrait = _readDouble(data, 'tauxRetrait', fallback: _tauxRetrait);
      _tauxInflation = _readDouble(
        data,
        'tauxInflation',
        fallback: _tauxInflation,
      );
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('wealth_simple', {
      'patrimoineActuel': _patrimoineActuel,
      'repartitionInitialeBourse': _repartitionInitialeBourse,
      'investissementsMensuels': _investissementsMensuels,
      'repartitionInvestBourse': _repartitionInvestBourse,
      'nombreAnnees': _nombreAnnees,
      'rendementBourse': _rendementBourse,
      'rendementAutre': _rendementAutre,
      'impositionBourse': _impositionBourse,
      'impositionAutre': _impositionAutre,
      'tauxRetrait': _tauxRetrait,
      'tauxInflation': _tauxInflation,
    });
  }

  void _update(void Function() change) {
    setState(change);
    _saveState();
  }

  Future<void> _resetState() async {
    await _stateRepo.delete('wealth_simple');
    if (!mounted) return;
    setState(() {
      _patrimoineActuel = 100000;
      _repartitionInitialeBourse = 50;
      _investissementsMensuels = 500;
      _repartitionInvestBourse = 50;
      _nombreAnnees = 20;
      _rendementBourse = 8;
      _rendementAutre = 5;
      _impositionBourse = 18.6;
      _impositionAutre = 31.4;
      _tauxRetrait = 4;
      _tauxInflation = 3;
    });
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

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    return _SimulationSplitCard(
      left: _buildInputsContent(),
      right: _buildResultsContent(result, widget.amountVisibility.hidden),
    );
  }

  SimulationResult _compute() => computeWealthProjection(
    patrimoineActuel: _patrimoineActuel,
    repartitionInitialeBourse: _repartitionInitialeBourse,
    investissementsMensuels: _investissementsMensuels,
    repartitionInvestBourse: _repartitionInvestBourse,
    nombreAnnees: _nombreAnnees,
    rendementBourse: _rendementBourse,
    rendementAutre: _rendementAutre,
    impositionBourse: _impositionBourse,
    impositionAutre: _impositionAutre,
    tauxRetrait: _tauxRetrait,
    tauxInflation: _tauxInflation,
  );

  Widget _buildInputsContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NumberField(
          label: 'Patrimoine actuel',
          suffix: '€',
          value: _patrimoineActuel,
          step: 1000,
          onChanged: (v) => _update(() => _patrimoineActuel = v),
        ),
        _SplitSlider(
          label: 'Répartition de votre patrimoine initial',
          leftLabel: 'Bourse',
          rightLabel: 'Autre',
          value: _repartitionInitialeBourse,
          onChanged: (v) => _update(() => _repartitionInitialeBourse = v),
        ),
        _NumberField(
          label: 'Investissements mensuels',
          suffix: '€',
          value: _investissementsMensuels,
          step: 50,
          onChanged: (v) => _update(() => _investissementsMensuels = v),
        ),
        _SplitSlider(
          label: 'Répartition des investissements',
          leftLabel: 'Bourse',
          rightLabel: 'Autre',
          value: _repartitionInvestBourse,
          onChanged: (v) => _update(() => _repartitionInvestBourse = v),
        ),
        _NumberField(
          label: "Nombre d'années d'épargne",
          suffix: 'ans',
          value: _nombreAnnees.toDouble(),
          step: 1,
          decimals: 0,
          onChanged: (v) =>
              _update(() => _nombreAnnees = v.round().clamp(1, 60)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: 'Rendement bourse',
                suffix: '%',
                value: _rendementBourse,
                step: 0.5,
                decimals: 1,
                onChanged: (v) => _update(() => _rendementBourse = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: 'Rendement autre',
                suffix: '%',
                value: _rendementAutre,
                step: 0.5,
                decimals: 1,
                onChanged: (v) => _update(() => _rendementAutre = v),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: 'Imposition bourse',
                suffix: '%',
                value: _impositionBourse,
                step: 0.1,
                decimals: 1,
                onChanged: (v) => _update(() => _impositionBourse = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: 'Imposition autre',
                suffix: '%',
                value: _impositionAutre,
                step: 0.1,
                decimals: 1,
                onChanged: (v) => _update(() => _impositionAutre = v),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: 'Taux de retrait',
                suffix: '%',
                value: _tauxRetrait,
                step: 0.5,
                decimals: 1,
                onChanged: (v) => _update(() => _tauxRetrait = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: "Taux d'inflation",
                suffix: '%',
                value: _tauxInflation,
                step: 0.5,
                decimals: 1,
                onChanged: (v) => _update(() => _tauxInflation = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlineButton(
          onPressed: _resetState,
          leading: const Icon(LucideIcons.refreshCw),
          child: const shadcn.Text('Réinitialiser les paramètres'),
        ),
      ],
    );
  }

  Widget _buildResultsContent(SimulationResult result, bool hidden) {
    final accent = Theme.of(context).colorScheme.primary;
    final blue = const Color(0xFF7B8FE8);
    final grey = const Color(0xFF6B7280);

    return Column(
      children: [
        shadcn.Text('Valeur nette dans $_nombreAnnees ans').muted(),
        const SizedBox(height: 8),
        shadcn.Text(
          displayEuros(result.valeurNette, hidden),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        shadcn.Text.rich(
          TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: "soit un revenu passif d'environ "),
              TextSpan(
                text: '${displayEuros(result.revenuMensuel, hidden)} / mois',
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ).muted(),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _LegendPill(
              color: grey,
              label: 'Patrimoine initial',
              value: displayEuros(result.patrimoineInitial, hidden),
            ),
            _LegendPill(
              color: blue,
              label: 'Versements',
              value: displayEuros(result.versements, hidden),
            ),
            _LegendPill(
              color: accent,
              label: 'Intérêts nets',
              value: displayEuros(result.plusValue, hidden),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 320,
          child: _ProjectionChart(
            points: result.points,
            nombreAnnees: _nombreAnnees,
            patrimoineInitial: result.patrimoineInitial,
            blue: blue,
            gold: accent,
            grey: grey,
            textColor: Theme.of(context).colorScheme.mutedForeground,
            gridColor: Theme.of(context).colorScheme.border,
            cardColor: Theme.of(context).colorScheme.popover,
            hidden: hidden,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        _StatRow(
          items: [
            ('Valeur future', displayEuros(result.valeurFuture, hidden)),
            ('Dont plus-value', displayEuros(result.plusValue, hidden)),
            ('Valeur nette', displayEuros(result.valeurNette, hidden)),
            ('Revenu mensuel', displayEuros(result.revenuMensuel, hidden)),
          ],
        ),
        const SizedBox(height: 14),
        _StatRow(
          items: [
            (
              'Valeur nette (pouvoir d\'achat actuel)',
              displayEuros(result.valeurNetteReelle, hidden),
            ),
            (
              'Revenu mensuel (pouvoir d\'achat actuel)',
              displayEuros(result.revenuMensuelReel, hidden),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _WealthSimpleDisclaimer(),
      ],
    );
  }
}

class YearPoint {
  final int year;
  final double principal;
  final double total;
  YearPoint({required this.year, required this.principal, required this.total});
}

class SimulationResult {
  final List<YearPoint> points;
  final double patrimoineInitial;
  final double versements;
  final double valeurFuture;
  final double plusValue;
  final double valeurNette;
  final double revenuMensuel;
  final double valeurNetteReelle;
  final double revenuMensuelReel;

  SimulationResult({
    required this.points,
    required this.patrimoineInitial,
    required this.versements,
    required this.valeurFuture,
    required this.plusValue,
    required this.valeurNette,
    required this.revenuMensuel,
    required this.valeurNetteReelle,
    required this.revenuMensuelReel,
  });
}

/// Projection déterministe à taux constants, avec versements mensuels
/// répartis entre les deux "poches" (bourse / autre) selon leurs proportions
/// respectives, et fiscalité forfaitaire appliquée aux seules plus-values.
///
/// [tauxInflation] sert à convertir la valeur nette et le revenu mensuel
/// nominaux en euros constants (pouvoir d'achat d'aujourd'hui), via
/// l'actualisation standard `valeur réelle = valeur nominale / (1 + inflation)^n`.
SimulationResult computeWealthProjection({
  required double patrimoineActuel,
  required double repartitionInitialeBourse,
  required double investissementsMensuels,
  required double repartitionInvestBourse,
  required int nombreAnnees,
  required double rendementBourse,
  required double rendementAutre,
  required double impositionBourse,
  required double impositionAutre,
  required double tauxRetrait,
  required double tauxInflation,
}) {
  final initialBourse = patrimoineActuel * repartitionInitialeBourse / 100;
  final initialAutre =
      patrimoineActuel * (100 - repartitionInitialeBourse) / 100;
  final investBourseMensuel =
      investissementsMensuels * repartitionInvestBourse / 100;
  final investAutreMensuel =
      investissementsMensuels * (100 - repartitionInvestBourse) / 100;
  final monthlyRateBourse = monthlyRateFromAnnualPct(rendementBourse);
  final monthlyRateAutre = monthlyRateFromAnnualPct(rendementAutre);
  final totalMonths = nombreAnnees * 12;

  var bourse = initialBourse;
  var autre = initialAutre;

  final points = <YearPoint>[
    YearPoint(year: 0, principal: patrimoineActuel, total: patrimoineActuel),
  ];

  for (var month = 1; month <= totalMonths; month++) {
    bourse = bourse * (1 + monthlyRateBourse) + investBourseMensuel;
    autre = autre * (1 + monthlyRateAutre) + investAutreMensuel;
    if (month % 12 == 0) {
      final year = month ~/ 12;
      final principal = patrimoineActuel + investissementsMensuels * month;
      points.add(
        YearPoint(year: year, principal: principal, total: bourse + autre),
      );
    }
  }

  final valeurFuture = bourse + autre;
  final versements = investissementsMensuels * totalMonths;
  final plusValue = valeurFuture - patrimoineActuel - versements;

  final contributionsBourse = initialBourse + investBourseMensuel * totalMonths;
  final contributionsAutre = initialAutre + investAutreMensuel * totalMonths;
  final gainsBourse = (bourse - contributionsBourse).clamp(0, double.infinity);
  final gainsAutre = (autre - contributionsAutre).clamp(0, double.infinity);
  final taxes =
      gainsBourse * impositionBourse / 100 + gainsAutre * impositionAutre / 100;
  final valeurNette = valeurFuture - taxes;
  final revenuMensuel = valeurNette * tauxRetrait / 100 / 12;

  // Actualisation en euros constants : on protège la division contre un
  // taux d'inflation aberrant (<= -100 %) saisi par l'utilisateur.
  final croissancePrix = max(0.0001, 1 + tauxInflation / 100);
  final facteurActualisation = pow(croissancePrix, nombreAnnees).toDouble();
  final valeurNetteReelle = valeurNette / facteurActualisation;
  final revenuMensuelReel = revenuMensuel / facteurActualisation;

  return SimulationResult(
    points: points,
    patrimoineInitial: patrimoineActuel,
    versements: versements,
    valeurFuture: valeurFuture,
    plusValue: plusValue,
    valeurNette: valeurNette,
    revenuMensuel: revenuMensuel,
    valeurNetteReelle: valeurNetteReelle,
    revenuMensuelReel: revenuMensuelReel,
  );
}

class _ProjectionChart extends StatefulWidget {
  final List<YearPoint> points;
  final int nombreAnnees;
  final double patrimoineInitial;
  final Color blue;
  final Color gold;
  final Color grey;
  final Color textColor;
  final Color gridColor;
  final Color cardColor;
  final bool hidden;

  const _ProjectionChart({
    required this.points,
    required this.nombreAnnees,
    required this.patrimoineInitial,
    required this.blue,
    required this.gold,
    required this.grey,
    required this.textColor,
    required this.gridColor,
    required this.cardColor,
    required this.hidden,
  });

  @override
  State<_ProjectionChart> createState() => _ProjectionChartState();
}

class _ProjectionChartState extends State<_ProjectionChart> {
  int? _hoveredYear;

  static const double _leftAxisWidth = 60;
  static const double _bottomAxisHeight = 24;

  void _updateHover(Offset localPosition, double width) {
    final chartWidth = width - _leftAxisWidth;
    final fraction = ((localPosition.dx - _leftAxisWidth) / chartWidth).clamp(
      0.0,
      1.0,
    );
    final year = (fraction * widget.nombreAnnees).round().clamp(
      0,
      widget.nombreAnnees,
    );
    if (year != _hoveredYear) setState(() => _hoveredYear = year);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final chartWidth = width - _leftAxisWidth;
        final chartHeight = height - _bottomAxisHeight;
        double xFor(int year) =>
            _leftAxisWidth + chartWidth * (year / widget.nombreAnnees);

        YearPoint? hoveredPoint;
        if (_hoveredYear != null) hoveredPoint = widget.points[_hoveredYear!];

        return MouseRegion(
          onHover: (event) => _updateHover(event.localPosition, width),
          onExit: (_) => setState(() => _hoveredYear = null),
          child: GestureDetector(
            onPanDown: (details) => _updateHover(details.localPosition, width),
            onPanUpdate: (details) =>
                _updateHover(details.localPosition, width),
            onPanEnd: (_) => setState(() => _hoveredYear = null),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(width, height),
                  painter: _ProjectionChartPainter(
                    points: widget.points,
                    nombreAnnees: widget.nombreAnnees,
                    patrimoineInitial: widget.patrimoineInitial,
                    blue: widget.blue,
                    gold: widget.gold,
                    grey: widget.grey,
                    textColor: widget.textColor,
                    gridColor: widget.gridColor,
                    hoveredYear: _hoveredYear,
                    hidden: widget.hidden,
                  ),
                ),
                if (hoveredPoint != null)
                  Positioned(
                    left: (xFor(_hoveredYear!) - 150).clamp(
                      _leftAxisWidth,
                      max(_leftAxisWidth, width - 300),
                    ),
                    top: (chartHeight / 2 - 90).clamp(
                      0,
                      max(0.0, chartHeight - 180),
                    ),
                    child: _HoverTooltip(
                      year: _hoveredYear!,
                      total: hoveredPoint.total,
                      interet: hoveredPoint.total - hoveredPoint.principal,
                      versements:
                          hoveredPoint.principal - widget.patrimoineInitial,
                      patrimoineInitial: widget.patrimoineInitial,
                      blue: widget.blue,
                      gold: widget.gold,
                      grey: widget.grey,
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

class _HoverTooltip extends StatelessWidget {
  final int year;
  final double total;
  final double interet;
  final double versements;
  final double patrimoineInitial;
  final Color blue;
  final Color gold;
  final Color grey;
  final Color cardColor;
  final bool hidden;

  const _HoverTooltip({
    required this.year,
    required this.total,
    required this.interet,
    required this.versements,
    required this.patrimoineInitial,
    required this.blue,
    required this.gold,
    required this.grey,
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
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(
                  year == 0 ? "Aujourd'hui" : 'Dans $year ans',
                ).muted(),
                const SizedBox(height: 4),
                shadcn.Text(
                  displayEuros(total, hidden),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                _row('Intérêts nets', interet, gold),
                const SizedBox(height: 6),
                _row('Versements', versements, blue),
                const SizedBox(height: 6),
                _row('Patrimoine initial', patrimoineInitial, grey),
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

class _ProjectionChartPainter extends CustomPainter {
  final List<YearPoint> points;
  final int nombreAnnees;
  final double patrimoineInitial;
  final Color blue;
  final Color gold;
  final Color grey;
  final Color textColor;
  final Color gridColor;
  final int? hoveredYear;
  final bool hidden;

  _ProjectionChartPainter({
    required this.points,
    required this.nombreAnnees,
    required this.patrimoineInitial,
    required this.blue,
    required this.gold,
    required this.grey,
    required this.textColor,
    required this.gridColor,
    required this.hoveredYear,
    required this.hidden,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxisWidth = 60.0;
    const bottomAxisHeight = 24.0;
    final chartWidth = size.width - leftAxisWidth;
    final chartHeight = size.height - bottomAxisHeight;

    final maxValue = points.map((p) => p.total).reduce((a, b) => a > b ? a : b);
    final axisMax = _niceCeil(maxValue * 1.15);
    const gridLines = 4;
    final step = axisMax / gridLines;

    double xFor(int year) => leftAxisWidth + chartWidth * (year / nombreAnnees);
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

    final baselineY = yFor(patrimoineInitial);

    final baselineAreaPath = Path()
      ..moveTo(xFor(0), baselineY)
      ..lineTo(xFor(nombreAnnees), baselineY)
      ..lineTo(xFor(nombreAnnees), chartHeight)
      ..lineTo(xFor(0), chartHeight)
      ..close();
    canvas.drawPath(
      baselineAreaPath,
      Paint()..color = grey.withValues(alpha: 0.15),
    );

    final principalBandPath = Path()..moveTo(xFor(0), baselineY);
    for (final p in points) {
      principalBandPath.lineTo(xFor(p.year), yFor(p.principal));
    }
    principalBandPath
      ..lineTo(xFor(nombreAnnees), baselineY)
      ..close();
    canvas.drawPath(
      principalBandPath,
      Paint()..color = blue.withValues(alpha: 0.15),
    );

    final interestPath = Path()..moveTo(xFor(0), yFor(points.first.principal));
    for (final p in points) {
      interestPath.lineTo(xFor(p.year), yFor(p.total));
    }
    for (var i = points.length - 1; i >= 0; i--) {
      interestPath.lineTo(xFor(points[i].year), yFor(points[i].principal));
    }
    interestPath.close();
    canvas.drawPath(
      interestPath,
      Paint()..color = gold.withValues(alpha: 0.18),
    );

    canvas.drawLine(
      Offset(leftAxisWidth, baselineY),
      Offset(size.width, baselineY),
      Paint()
        ..color = grey.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );

    final bluePath = Path()..moveTo(xFor(0), yFor(points.first.principal));
    for (final p in points) {
      bluePath.lineTo(xFor(p.year), yFor(p.principal));
    }
    canvas.drawPath(
      bluePath,
      Paint()
        ..color = blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final goldPath = Path()..moveTo(xFor(0), yFor(points.first.total));
    for (final p in points) {
      goldPath.lineTo(xFor(p.year), yFor(p.total));
    }
    canvas.drawPath(
      goldPath,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (hoveredYear != null) {
      final p = points[hoveredYear!];
      final x = xFor(hoveredYear!);
      _drawDashedLine(canvas, Offset(x, 0), Offset(x, chartHeight), gridColor);
      _drawDot(canvas, Offset(x, yFor(p.total)), gold);
      _drawDot(canvas, Offset(x, yFor(p.principal)), blue);
      _drawDot(canvas, Offset(x, baselineY), grey);
    }

    _drawXLabel(
      canvas,
      "Aujourd'hui",
      xFor(0),
      chartHeight,
      textColor,
      alignLeft: true,
    );
    _drawXLabel(
      canvas,
      '${nombreAnnees ~/ 2} ans',
      xFor(nombreAnnees ~/ 2),
      chartHeight,
      textColor,
    );
    _drawXLabel(
      canvas,
      'dans $nombreAnnees ans',
      xFor(nombreAnnees),
      chartHeight,
      textColor,
      alignLeft: false,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    const dashLength = 4.0;
    const gapLength = 4.0;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final totalLength = (end - start).distance;
    var covered = 0.0;
    final direction = (end - start) / totalLength;
    while (covered < totalLength) {
      final segStart = start + direction * covered;
      final segEnd =
          start + direction * (covered + dashLength).clamp(0, totalLength);
      canvas.drawLine(segStart, segEnd, paint);
      covered += dashLength + gapLength;
    }
  }

  void _drawDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 6, Paint()..color = color);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawXLabel(
    Canvas canvas,
    String text,
    double x,
    double y,
    Color color, {
    bool? alignLeft,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx;
    if (alignLeft == true) {
      dx = x;
    } else if (alignLeft == false) {
      dx = x - tp.width;
    } else {
      dx = x - tp.width / 2;
    }
    tp.paint(canvas, Offset(dx, y + 6));
  }

  @override
  bool shouldRepaint(covariant _ProjectionChartPainter oldDelegate) =>
      oldDelegate.hoveredYear != hoveredYear ||
      oldDelegate.points != points ||
      oldDelegate.hidden != hidden;
}

// =======================================================================
// ONGLET 2 : Personnalisé (Monte-Carlo)
// =======================================================================

class _MonteCarloSimulationTab extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const _MonteCarloSimulationTab({
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<_MonteCarloSimulationTab> createState() =>
      _MonteCarloSimulationTabState();
}

class _MonteCarloSimulationTabState extends State<_MonteCarloSimulationTab> {
  double _patrimoineActuel = 100000;
  double _repartitionInitialeBourse = 50;
  double _investissementsMensuels = 500;
  double _repartitionInvestBourse = 50;
  int _nombreAnnees = 20;
  double _rendementBourse = 8;
  double _ecartTypeBourse = 15;
  double _rendementAutre = 5;
  double _ecartTypeAutre = 4;
  double _impositionBourse = 18.6;
  double _impositionAutre = 31.4;
  double _tauxRetrait = 4;
  int _nombreSimulations = 300;
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
    final data = await _stateRepo.read('wealth_monte_carlo');
    if (!mounted || data.isEmpty) return;
    setState(() {
      _patrimoineActuel = _readDouble(
        data,
        'patrimoineActuel',
        fallback: _patrimoineActuel,
      );
      _repartitionInitialeBourse = _readDouble(
        data,
        'repartitionInitialeBourse',
        fallback: _repartitionInitialeBourse,
      ).clamp(0, 100);
      _investissementsMensuels = _readDouble(
        data,
        'investissementsMensuels',
        fallback: _investissementsMensuels,
      );
      _repartitionInvestBourse = _readDouble(
        data,
        'repartitionInvestBourse',
        fallback: _repartitionInvestBourse,
      ).clamp(0, 100);
      _nombreAnnees = _readInt(
        data,
        'nombreAnnees',
        fallback: _nombreAnnees,
      ).clamp(1, 60);
      _rendementBourse = _readDouble(
        data,
        'rendementBourse',
        fallback: _rendementBourse,
      );
      _ecartTypeBourse = _readDouble(
        data,
        'ecartTypeBourse',
        fallback: _ecartTypeBourse,
      );
      _rendementAutre = _readDouble(
        data,
        'rendementAutre',
        fallback: _rendementAutre,
      );
      _ecartTypeAutre = _readDouble(
        data,
        'ecartTypeAutre',
        fallback: _ecartTypeAutre,
      );
      _impositionBourse = _readDouble(
        data,
        'impositionBourse',
        fallback: _impositionBourse,
      );
      _impositionAutre = _readDouble(
        data,
        'impositionAutre',
        fallback: _impositionAutre,
      );
      _tauxRetrait = _readDouble(data, 'tauxRetrait', fallback: _tauxRetrait);
      _nombreSimulations = _readInt(
        data,
        'nombreSimulations',
        fallback: _nombreSimulations,
      ).clamp(50, 2000);
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('wealth_monte_carlo', {
      'patrimoineActuel': _patrimoineActuel,
      'repartitionInitialeBourse': _repartitionInitialeBourse,
      'investissementsMensuels': _investissementsMensuels,
      'repartitionInvestBourse': _repartitionInvestBourse,
      'nombreAnnees': _nombreAnnees,
      'rendementBourse': _rendementBourse,
      'ecartTypeBourse': _ecartTypeBourse,
      'rendementAutre': _rendementAutre,
      'ecartTypeAutre': _ecartTypeAutre,
      'impositionBourse': _impositionBourse,
      'impositionAutre': _impositionAutre,
      'tauxRetrait': _tauxRetrait,
      'nombreSimulations': _nombreSimulations,
    });
  }

  void _update(void Function() change) {
    setState(change);
    _saveState();
  }

  Future<void> _resetState() async {
    await _stateRepo.delete('wealth_monte_carlo');
    if (!mounted) return;
    setState(() {
      _patrimoineActuel = 100000;
      _repartitionInitialeBourse = 50;
      _investissementsMensuels = 500;
      _repartitionInvestBourse = 50;
      _nombreAnnees = 20;
      _rendementBourse = 8;
      _ecartTypeBourse = 15;
      _rendementAutre = 5;
      _ecartTypeAutre = 4;
      _impositionBourse = 18.6;
      _impositionAutre = 31.4;
      _tauxRetrait = 4;
      _nombreSimulations = 300;
    });
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

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    return _SimulationSplitCard(
      left: _buildInputsContent(),
      right: _buildResultsContent(result, widget.amountVisibility.hidden),
    );
  }

  MCResult _compute() => computeMonteCarloProjection(
    patrimoineActuel: _patrimoineActuel,
    repartitionInitialeBourse: _repartitionInitialeBourse,
    investissementsMensuels: _investissementsMensuels,
    repartitionInvestBourse: _repartitionInvestBourse,
    nombreAnnees: _nombreAnnees,
    rendementBourse: _rendementBourse,
    ecartTypeBourse: _ecartTypeBourse,
    rendementAutre: _rendementAutre,
    ecartTypeAutre: _ecartTypeAutre,
    impositionBourse: _impositionBourse,
    impositionAutre: _impositionAutre,
    tauxRetrait: _tauxRetrait,
    nombreSimulations: _nombreSimulations,
  );

  Widget _buildInputsContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NumberField(
          label: 'Patrimoine actuel',
          suffix: '€',
          value: _patrimoineActuel,
          step: 1000,
          onChanged: (v) => _update(() => _patrimoineActuel = v),
        ),
        _SplitSlider(
          label: 'Répartition de votre patrimoine initial',
          leftLabel: 'Bourse',
          rightLabel: 'Autre',
          value: _repartitionInitialeBourse,
          onChanged: (v) => _update(() => _repartitionInitialeBourse = v),
        ),
        _NumberField(
          label: 'Investissements mensuels',
          suffix: '€',
          value: _investissementsMensuels,
          step: 50,
          onChanged: (v) => _update(() => _investissementsMensuels = v),
        ),
        _SplitSlider(
          label: 'Répartition des investissements',
          leftLabel: 'Bourse',
          rightLabel: 'Autre',
          value: _repartitionInvestBourse,
          onChanged: (v) => _update(() => _repartitionInvestBourse = v),
        ),
        _NumberField(
          label: "Nombre d'années d'épargne",
          suffix: 'ans',
          value: _nombreAnnees.toDouble(),
          step: 1,
          decimals: 0,
          onChanged: (v) =>
              _update(() => _nombreAnnees = v.round().clamp(1, 60)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: 'Rendement moyen bourse',
                suffix: '%',
                value: _rendementBourse,
                step: 0.5,
                decimals: 1,
                onChanged: (v) => _update(() => _rendementBourse = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: 'Écart-type bourse',
                suffix: '%',
                value: _ecartTypeBourse,
                step: 0.5,
                decimals: 1,
                onChanged: (v) => _update(() => _ecartTypeBourse = v),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: 'Rendement moyen autre',
                suffix: '%',
                value: _rendementAutre,
                step: 0.5,
                decimals: 1,
                onChanged: (v) => _update(() => _rendementAutre = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: 'Écart-type autre',
                suffix: '%',
                value: _ecartTypeAutre,
                step: 0.5,
                decimals: 1,
                onChanged: (v) => _update(() => _ecartTypeAutre = v),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: 'Imposition bourse',
                suffix: '%',
                value: _impositionBourse,
                step: 0.1,
                decimals: 1,
                onChanged: (v) => _update(() => _impositionBourse = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: 'Imposition autre',
                suffix: '%',
                value: _impositionAutre,
                step: 0.1,
                decimals: 1,
                onChanged: (v) => _update(() => _impositionAutre = v),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: 'Taux de retrait',
                suffix: '%',
                value: _tauxRetrait,
                step: 0.5,
                decimals: 1,
                onChanged: (v) => _update(() => _tauxRetrait = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: 'Nombre de simulations',
                suffix: '',
                value: _nombreSimulations.toDouble(),
                step: 50,
                decimals: 0,
                onChanged: (v) => _update(
                  () => _nombreSimulations = v.round().clamp(50, 2000),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlineButton(
          onPressed: _resetState,
          leading: const Icon(LucideIcons.refreshCw),
          child: const shadcn.Text('Réinitialiser les paramètres'),
        ),
      ],
    );
  }

  Widget _buildResultsContent(MCResult result, bool hidden) {
    final accent = Theme.of(context).colorScheme.primary;
    final blue = const Color(0xFF7B8FE8);
    final grey = const Color(0xFF6B7280);

    return Column(
      children: [
        shadcn.Text('Valeur nette médiane dans $_nombreAnnees ans').muted(),
        const SizedBox(height: 8),
        shadcn.Text(
          displayEuros(result.valeurNetteMediane, hidden),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        shadcn.Text.rich(
          TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: "soit un revenu passif médian d'environ "),
              TextSpan(
                text:
                    '${displayEuros(result.revenuMensuelMedian, hidden)} / mois',
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ).muted(),
        const SizedBox(height: 4),
        shadcn.Text(
          'Entre ${displayEuros(result.valeurNetteP10, hidden)} et ${displayEuros(result.valeurNetteP90, hidden)} selon les scénarios (10e-90e percentile)',
        ).muted().small(),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _LegendPill(
              color: grey,
              label: 'Patrimoine initial',
              value: displayEuros(result.patrimoineInitial, hidden),
            ),
            _LegendPill(
              color: blue,
              label: 'Versements',
              value: displayEuros(result.versements, hidden),
            ),
            _LegendPill(
              color: accent,
              label: 'Médiane (intérêts nets)',
              value: displayEuros(result.plusValueMediane, hidden),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 320,
          child: _MonteCarloChart(
            points: result.points,
            nombreAnnees: _nombreAnnees,
            patrimoineInitial: result.patrimoineInitial,
            blue: blue,
            gold: accent,
            grey: grey,
            textColor: Theme.of(context).colorScheme.mutedForeground,
            gridColor: Theme.of(context).colorScheme.border,
            cardColor: Theme.of(context).colorScheme.popover,
            hidden: hidden,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        _StatRow(
          items: [
            (
              'Valeur future médiane',
              displayEuros(result.valeurFutureMediane, hidden),
            ),
            (
              'Dont plus-value médiane',
              displayEuros(result.plusValueMediane, hidden),
            ),
            (
              'Valeur nette médiane',
              displayEuros(result.valeurNetteMediane, hidden),
            ),
            (
              'Revenu mensuel médian',
              displayEuros(result.revenuMensuelMedian, hidden),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _WealthMonteCarloDisclaimer(),
      ],
    );
  }
}

class MCYearPoint {
  final int year;
  final double principal;
  final double p10;
  final double p50;
  final double p90;
  MCYearPoint({
    required this.year,
    required this.principal,
    required this.p10,
    required this.p50,
    required this.p90,
  });
}

class MCResult {
  final List<MCYearPoint> points;
  final double patrimoineInitial;
  final double versements;
  final double valeurFutureMediane;
  final double plusValueMediane;
  final double valeurNetteMediane;
  final double revenuMensuelMedian;
  final double valeurNetteP10;
  final double valeurNetteP90;

  MCResult({
    required this.points,
    required this.patrimoineInitial,
    required this.versements,
    required this.valeurFutureMediane,
    required this.plusValueMediane,
    required this.valeurNetteMediane,
    required this.revenuMensuelMedian,
    required this.valeurNetteP10,
    required this.valeurNetteP90,
  });
}

/// Simule [nombreSimulations] trajectoires de patrimoine, en tirant chaque
/// année un rendement annuel gaussien indépendant par poche (bourse / autre)
/// autour de la moyenne et de l'écart-type fournis, converti en taux mensuel
/// composé pour les 12 versements de l'année. Les percentiles (P10/P50/P90)
/// sont ensuite lus par rang sur les trajectoires triées année par année.
///
/// Le générateur aléatoire est initialisé avec une graine fixe par défaut
/// (comme le faisait l'implémentation d'origine) afin que la courbe affichée
/// à l'écran ne bouge que lorsque les paramètres changent, pas à chaque
/// rebuild ; les tests peuvent injecter leur propre [random] pour vérifier
/// le comportement avec d'autres tirages.
MCResult computeMonteCarloProjection({
  required double patrimoineActuel,
  required double repartitionInitialeBourse,
  required double investissementsMensuels,
  required double repartitionInvestBourse,
  required int nombreAnnees,
  required double rendementBourse,
  required double ecartTypeBourse,
  required double rendementAutre,
  required double ecartTypeAutre,
  required double impositionBourse,
  required double impositionAutre,
  required double tauxRetrait,
  required int nombreSimulations,
  Random? random,
}) {
  final rng = random ?? Random(12345);
  final initialBourse = patrimoineActuel * repartitionInitialeBourse / 100;
  final initialAutre =
      patrimoineActuel * (100 - repartitionInitialeBourse) / 100;
  final investBourseMensuel =
      investissementsMensuels * repartitionInvestBourse / 100;
  final investAutreMensuel =
      investissementsMensuels * (100 - repartitionInvestBourse) / 100;
  final totalMonths = nombreAnnees * 12;

  final totalsByYear = List.generate(nombreAnnees + 1, (_) => <double>[]);
  final netValues = <double>[];

  for (var s = 0; s < nombreSimulations; s++) {
    var bourse = initialBourse;
    var autre = initialAutre;
    totalsByYear[0].add(patrimoineActuel);
    for (var year = 1; year <= nombreAnnees; year++) {
      final rBourse = gaussianSample(rng, rendementBourse, ecartTypeBourse);
      final rAutre = gaussianSample(rng, rendementAutre, ecartTypeAutre);
      final monthlyRateBourse = monthlyRateFromAnnualPct(rBourse);
      final monthlyRateAutre = monthlyRateFromAnnualPct(rAutre);
      for (var monthInYear = 0; monthInYear < 12; monthInYear++) {
        bourse = bourse * (1 + monthlyRateBourse) + investBourseMensuel;
        autre = autre * (1 + monthlyRateAutre) + investAutreMensuel;
      }
      totalsByYear[year].add(bourse + autre);
    }
    final contributionsBourse =
        initialBourse + investBourseMensuel * totalMonths;
    final contributionsAutre = initialAutre + investAutreMensuel * totalMonths;
    final gainsBourse = (bourse - contributionsBourse).clamp(
      0,
      double.infinity,
    );
    final gainsAutre = (autre - contributionsAutre).clamp(0, double.infinity);
    final taxes =
        gainsBourse * impositionBourse / 100 +
        gainsAutre * impositionAutre / 100;
    netValues.add((bourse + autre) - taxes);
  }

  double percentile(List<double> sorted, double p) {
    final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
    return sorted[idx];
  }

  final points = <MCYearPoint>[];
  for (var year = 0; year <= nombreAnnees; year++) {
    final sorted = [...totalsByYear[year]]..sort();
    points.add(
      MCYearPoint(
        year: year,
        principal: patrimoineActuel + investissementsMensuels * year * 12,
        p10: percentile(sorted, 0.10),
        p50: percentile(sorted, 0.50),
        p90: percentile(sorted, 0.90),
      ),
    );
  }

  final sortedNet = [...netValues]..sort();
  final valeurNetteMediane = percentile(sortedNet, 0.50);
  final valeurNetteP10 = percentile(sortedNet, 0.10);
  final valeurNetteP90 = percentile(sortedNet, 0.90);
  final versements = investissementsMensuels * totalMonths;
  final valeurFutureMediane = points.last.p50;
  final plusValueMediane = valeurFutureMediane - patrimoineActuel - versements;
  final revenuMensuelMedian = valeurNetteMediane * tauxRetrait / 100 / 12;

  return MCResult(
    points: points,
    patrimoineInitial: patrimoineActuel,
    versements: versements,
    valeurFutureMediane: valeurFutureMediane,
    plusValueMediane: plusValueMediane,
    valeurNetteMediane: valeurNetteMediane,
    revenuMensuelMedian: revenuMensuelMedian,
    valeurNetteP10: valeurNetteP10,
    valeurNetteP90: valeurNetteP90,
  );
}

class _MonteCarloChart extends StatefulWidget {
  final List<MCYearPoint> points;
  final int nombreAnnees;
  final double patrimoineInitial;
  final Color blue;
  final Color gold;
  final Color grey;
  final Color textColor;
  final Color gridColor;
  final Color cardColor;
  final bool hidden;

  const _MonteCarloChart({
    required this.points,
    required this.nombreAnnees,
    required this.patrimoineInitial,
    required this.blue,
    required this.gold,
    required this.grey,
    required this.textColor,
    required this.gridColor,
    required this.cardColor,
    required this.hidden,
  });

  @override
  State<_MonteCarloChart> createState() => _MonteCarloChartState();
}

class _MonteCarloChartState extends State<_MonteCarloChart> {
  int? _hoveredYear;

  static const double _leftAxisWidth = 60;
  static const double _bottomAxisHeight = 24;

  void _updateHover(Offset localPosition, double width) {
    final chartWidth = width - _leftAxisWidth;
    final fraction = ((localPosition.dx - _leftAxisWidth) / chartWidth).clamp(
      0.0,
      1.0,
    );
    final year = (fraction * widget.nombreAnnees).round().clamp(
      0,
      widget.nombreAnnees,
    );
    if (year != _hoveredYear) setState(() => _hoveredYear = year);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final chartWidth = width - _leftAxisWidth;
        final chartHeight = height - _bottomAxisHeight;
        double xFor(int year) =>
            _leftAxisWidth + chartWidth * (year / widget.nombreAnnees);

        MCYearPoint? hoveredPoint;
        if (_hoveredYear != null) hoveredPoint = widget.points[_hoveredYear!];

        return MouseRegion(
          onHover: (event) => _updateHover(event.localPosition, width),
          onExit: (_) => setState(() => _hoveredYear = null),
          child: GestureDetector(
            onPanDown: (details) => _updateHover(details.localPosition, width),
            onPanUpdate: (details) =>
                _updateHover(details.localPosition, width),
            onPanEnd: (_) => setState(() => _hoveredYear = null),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(width, height),
                  painter: _MonteCarloChartPainter(
                    points: widget.points,
                    nombreAnnees: widget.nombreAnnees,
                    patrimoineInitial: widget.patrimoineInitial,
                    blue: widget.blue,
                    gold: widget.gold,
                    grey: widget.grey,
                    textColor: widget.textColor,
                    gridColor: widget.gridColor,
                    hoveredYear: _hoveredYear,
                    hidden: widget.hidden,
                  ),
                ),
                if (hoveredPoint != null)
                  Positioned(
                    left: (xFor(_hoveredYear!) - 150).clamp(
                      _leftAxisWidth,
                      max(_leftAxisWidth, width - 300),
                    ),
                    top: (chartHeight / 2 - 100).clamp(
                      0,
                      max(0.0, chartHeight - 200),
                    ),
                    child: _MCHoverTooltip(
                      year: _hoveredYear!,
                      p10: hoveredPoint.p10,
                      p50: hoveredPoint.p50,
                      p90: hoveredPoint.p90,
                      versements:
                          hoveredPoint.principal - widget.patrimoineInitial,
                      patrimoineInitial: widget.patrimoineInitial,
                      blue: widget.blue,
                      gold: widget.gold,
                      grey: widget.grey,
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

class _MCHoverTooltip extends StatelessWidget {
  final int year;
  final double p10;
  final double p50;
  final double p90;
  final double versements;
  final double patrimoineInitial;
  final Color blue;
  final Color gold;
  final Color grey;
  final Color cardColor;
  final bool hidden;

  const _MCHoverTooltip({
    required this.year,
    required this.p10,
    required this.p50,
    required this.p90,
    required this.versements,
    required this.patrimoineInitial,
    required this.blue,
    required this.gold,
    required this.grey,
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
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(
                  year == 0 ? "Aujourd'hui" : 'Dans $year ans',
                ).muted(),
                const SizedBox(height: 4),
                shadcn.Text(
                  displayEuros(p50, hidden),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                shadcn.Text('Médiane').muted().small(),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                _row('90e percentile', p90, gold),
                const SizedBox(height: 6),
                _row('10e percentile', p10, gold.withValues(alpha: 0.5)),
                const SizedBox(height: 6),
                _row('Versements', versements, blue),
                const SizedBox(height: 6),
                _row('Patrimoine initial', patrimoineInitial, grey),
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

class _MonteCarloChartPainter extends CustomPainter {
  final List<MCYearPoint> points;
  final int nombreAnnees;
  final double patrimoineInitial;
  final Color blue;
  final Color gold;
  final Color grey;
  final Color textColor;
  final Color gridColor;
  final int? hoveredYear;
  final bool hidden;

  _MonteCarloChartPainter({
    required this.points,
    required this.nombreAnnees,
    required this.patrimoineInitial,
    required this.blue,
    required this.gold,
    required this.grey,
    required this.textColor,
    required this.gridColor,
    required this.hoveredYear,
    required this.hidden,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxisWidth = 60.0;
    const bottomAxisHeight = 24.0;
    final chartWidth = size.width - leftAxisWidth;
    final chartHeight = size.height - bottomAxisHeight;

    final maxValue = points.map((p) => p.p90).reduce((a, b) => a > b ? a : b);
    final axisMax = _niceCeil(maxValue * 1.15);
    const gridLines = 4;
    final step = axisMax / gridLines;

    double xFor(int year) => leftAxisWidth + chartWidth * (year / nombreAnnees);
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

    final baselineY = yFor(patrimoineInitial);

    // Aire grise sous "Patrimoine initial".
    final baselineAreaPath = Path()
      ..moveTo(xFor(0), baselineY)
      ..lineTo(xFor(nombreAnnees), baselineY)
      ..lineTo(xFor(nombreAnnees), chartHeight)
      ..lineTo(xFor(0), chartHeight)
      ..close();
    canvas.drawPath(
      baselineAreaPath,
      Paint()..color = grey.withValues(alpha: 0.15),
    );

    // Aire bleue : entre "Patrimoine initial" et "Versements cumulés".
    final principalBandPath = Path()..moveTo(xFor(0), baselineY);
    for (final p in points) {
      principalBandPath.lineTo(xFor(p.year), yFor(p.principal));
    }
    principalBandPath
      ..lineTo(xFor(nombreAnnees), baselineY)
      ..close();
    canvas.drawPath(
      principalBandPath,
      Paint()..color = blue.withValues(alpha: 0.15),
    );

    // Bande d'incertitude p10-p90 (au-dessus des versements cumulés).
    final bandPath = Path()..moveTo(xFor(0), yFor(points.first.p10));
    for (final p in points) {
      bandPath.lineTo(xFor(p.year), yFor(p.p90));
    }
    for (var i = points.length - 1; i >= 0; i--) {
      bandPath.lineTo(xFor(points[i].year), yFor(points[i].p10));
    }
    bandPath.close();
    canvas.drawPath(bandPath, Paint()..color = gold.withValues(alpha: 0.18));

    canvas.drawLine(
      Offset(leftAxisWidth, baselineY),
      Offset(size.width, baselineY),
      Paint()
        ..color = grey.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );

    final bluePath = Path()..moveTo(xFor(0), yFor(points.first.principal));
    for (final p in points) {
      bluePath.lineTo(xFor(p.year), yFor(p.principal));
    }
    canvas.drawPath(
      bluePath,
      Paint()
        ..color = blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Ligne médiane (p50).
    final medianPath = Path()..moveTo(xFor(0), yFor(points.first.p50));
    for (final p in points) {
      medianPath.lineTo(xFor(p.year), yFor(p.p50));
    }
    canvas.drawPath(
      medianPath,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (hoveredYear != null) {
      final p = points[hoveredYear!];
      final x = xFor(hoveredYear!);
      _drawDashedLine(canvas, Offset(x, 0), Offset(x, chartHeight), gridColor);
      _drawDot(canvas, Offset(x, yFor(p.p50)), gold);
      _drawDot(canvas, Offset(x, yFor(p.principal)), blue);
      _drawDot(canvas, Offset(x, baselineY), grey);
    }

    _drawXLabel(
      canvas,
      "Aujourd'hui",
      xFor(0),
      chartHeight,
      textColor,
      alignLeft: true,
    );
    _drawXLabel(
      canvas,
      '${nombreAnnees ~/ 2} ans',
      xFor(nombreAnnees ~/ 2),
      chartHeight,
      textColor,
    );
    _drawXLabel(
      canvas,
      'dans $nombreAnnees ans',
      xFor(nombreAnnees),
      chartHeight,
      textColor,
      alignLeft: false,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    const dashLength = 4.0;
    const gapLength = 4.0;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final totalLength = (end - start).distance;
    var covered = 0.0;
    final direction = (end - start) / totalLength;
    while (covered < totalLength) {
      final segStart = start + direction * covered;
      final segEnd =
          start + direction * (covered + dashLength).clamp(0, totalLength);
      canvas.drawLine(segStart, segEnd, paint);
      covered += dashLength + gapLength;
    }
  }

  void _drawDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 6, Paint()..color = color);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawXLabel(
    Canvas canvas,
    String text,
    double x,
    double y,
    Color color, {
    bool? alignLeft,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx;
    if (alignLeft == true) {
      dx = x;
    } else if (alignLeft == false) {
      dx = x - tp.width;
    } else {
      dx = x - tp.width / 2;
    }
    tp.paint(canvas, Offset(dx, y + 6));
  }

  @override
  bool shouldRepaint(covariant _MonteCarloChartPainter oldDelegate) =>
      oldDelegate.hoveredYear != hoveredYear ||
      oldDelegate.points != points ||
      oldDelegate.hidden != hidden;
}

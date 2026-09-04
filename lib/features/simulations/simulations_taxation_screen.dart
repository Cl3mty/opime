import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/simulations/simulation_state_repository.dart';
import '../../core/ui/frosted_card.dart';
import '../../l10n/app_localizations.dart';
import '../investments/investments_models.dart';
import '../investments/investments_repository.dart';
import 'tax_parameters.dart';

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
        _tabIndex = tabValue.clamp(0, 2);
      } else if (tabValue is num) {
        _tabIndex = tabValue.round().clamp(0, 2);
      }
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('taxation', {'tabIndex': _tabIndex});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                children: [
                  TabItem(child: shadcn.Text(l10n.simulations_taxation_tab_ir)),
                  TabItem(child: shadcn.Text(l10n.simulations_taxation_tab_ifi)),
                  TabItem(child: shadcn.Text(l10n.simulations_taxation_tab_pfu)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (_tabIndex) {
              0 => _IRTab(
                  vaultPath: widget.vaultPath,
                  amountVisibility: widget.amountVisibility,
                ),
              1 => _IFITab(
                  vaultPath: widget.vaultPath,
                  amountVisibility: widget.amountVisibility,
                ),
              _ => _PFUTab(
                  vaultPath: widget.vaultPath,
                  amountVisibility: widget.amountVisibility,
                ),
            },
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
              AppLocalizations.of(context).simulations_taxation_ifi_disclaimer,
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
              AppLocalizations.of(context).simulations_taxation_ir_disclaimer,
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

/// L'IFI n'est dû qu'au-delà de [seuilImposition] de patrimoine net
/// (en-dessous, exonération totale) ; au-delà, le barème s'applique sur la
/// totalité du patrimoine à partir de [limits]`[0]` (pas de décote
/// implémentée ici, voir [_IFIDisclaimer]).
///
/// [limits]/[rates]/[seuilImposition] sont les valeurs codées en dur du
/// barème IFI par défaut ([ifiLimits]/[ifiRates]/`1 300 000`) sauf si
/// l'utilisateur les a personnalisées dans Réglages → Paramètres fiscaux
/// (voir `tax_parameters.dart`) — l'appelant transmet alors les valeurs
/// chargées plutôt que de laisser les paramètres par défaut.
IFIResult computeIFI(
  double immobilierNet, {
  List<double> limits = ifiLimits,
  List<double> rates = ifiRates,
  double seuilImposition = 1300000,
}) {
  double c0(double v) => v < 0 ? 0 : v;
  final montants = [
    c0(min(immobilierNet, limits[0])),
    c0(min(immobilierNet - limits[0], limits[1] - limits[0])),
    c0(min(immobilierNet - limits[1], limits[2] - limits[1])),
    c0(min(immobilierNet - limits[2], limits[3] - limits[2])),
    c0(min(immobilierNet - limits[3], limits[4] - limits[3])),
    c0(immobilierNet - limits[4]),
  ];

  var maxIndex = 0;
  for (var i = 0; i < montants.length; i++) {
    if (montants[i] > 0) maxIndex = i;
  }
  final exonere = immobilierNet <= seuilImposition;
  final tauxMax = exonere ? 0.0 : rates[maxIndex];

  final impots = List.generate(
    6,
    (i) => exonere ? 0.0 : montants[i] * rates[i] / 100,
  );
  final total = impots.fold<double>(0, (s, v) => s + v);

  final chartData = List.generate(
    6,
    (i) => BracketRow(
      label: '${rates[i]}%',
      montant: montants[i],
      montantMax: ifiMontantMax[i],
      impot: impots[i],
    ),
  );

  return IFIResult(tauxMax: tauxMax, total: total, chartData: chartData);
}

// ---------------------------------------------------------------------
// Onglet PFU (Prélèvement Foritaire Unique) — retrait PEA / AV
// ---------------------------------------------------------------------

/// Résultat de la simulation de retrait PFU sur un compte PEA ou
/// Assurance-Vie. Pour l'AV, le comparatif avec le barème progressif est
/// également fourni ([baremeIr], [baremePs], [netAfterBareme]).
class PFUResult {
  /// Montant total du gain latent (valeur actuelle − montant investi).
  final double gain;

  /// Part du gain imposée au PFU (gain proportionnel au retrait, abattement
  /// déduit pour l'AV).
  final double gainImposable;

  /// Composante IR du PFU (12.8 % par défaut).
  final double pfuIr;

  /// Composante prélèvements sociaux du PFU (18.6 % par défaut).
  final double pfuPs;

  /// pfuIr + pfuPs.
  final double pfuTotal;

  /// Montant réellement reçu par l'investisseur après PFU.
  final double netAfterPfu;

  /// Impôt sur le revenu selon le barème progressif (uniquement pour l'AV,
  /// `null` pour le PEA).
  final double? baremeIr;

  /// Prélèvements sociaux selon le barème (uniquement pour l'AV).
  final double? baremePs;

  /// baremeIr + baremePs.
  final double? baremeTotal;

  /// Montant réellement reçu après barème progressif (uniquement pour l'AV).
  final double? netAfterBareme;

  /// Libellé de l'enveloppe affiché dans le résultat.
  final String envelopeLabel;

  /// `true` si le retrait est totalement exonéré (PEA > 5 ans).
  final bool isExempt;

  const PFUResult({
    required this.gain,
    required this.gainImposable,
    required this.pfuIr,
    required this.pfuPs,
    required this.pfuTotal,
    required this.netAfterPfu,
    this.baremeIr,
    this.baremePs,
    this.baremeTotal,
    this.netAfterBareme,
    required this.envelopeLabel,
    required this.isExempt,
  });
}

/// Simule l'impact fiscal d'un retrait sur un PEA ou une Assurance-Vie au
/// Prélèvement Forfaitaire Unique (PFU / flat tax).
///
/// Pour le PEA :
/// - Avant 5 ans → PFU sur les gains (IR + PS)
/// - Après 5 ans → exonération totale
///
/// Pour l'Assurance-Vie :
/// - Abattement de 4 600 € (contrat < 8 ans) ou 9 200 € (≥ 8 ans)
/// - PFU sur le gain dépassant l'abattement
/// - Comparaison avec le barème progressif (IR + PS)
///
/// [investedAmount] et [currentValue] servent à calculer la proportion du
/// gain latent réalisée par le retrait.
PFUResult computePFU({
  required double withdrawalAmount,
  required double investedAmount,
  required double currentValue,
  required DateTime openingDate,
  required AccountEnvelope envelope,
  double pfuIrRate = 12.8,
  double pfuPsRate = 18.6,
  List<double> irLimits = irLimits,
  List<double> irRates = irRates,
  double nbrParts = 1,
  DateTime? referenceDate,
}) {
  final now = referenceDate ?? DateTime.now();
  final gain = max(0.0, currentValue - investedAmount);

  // Proportion du gain latent réalisée par le retrait.
  final gainRetrait = currentValue > 0
      ? gain * (withdrawalAmount / currentValue)
      : 0.0;

  // Ancienneté du compte en années.
  final anciennete = now.difference(openingDate).inDays / 365.25;

  final String envelopeLabel;
  final bool isExempt;
  double gainImposable;
  double pfuIr;
  double pfuPs;
  double? baremeIr;
  double? baremePs;
  double? baremeTotal;
  double? netAfterBareme;

  if (envelope == AccountEnvelope.pea) {
    envelopeLabel = 'PEA';
    // PEA : exonéré après 5 ans.
    if (anciennete >= 5) {
      isExempt = true;
      gainImposable = 0;
      pfuIr = 0;
      pfuPs = 0;
    } else {
      isExempt = false;
      gainImposable = gainRetrait;
      pfuIr = gainImposable * pfuIrRate / 100;
      pfuPs = gainImposable * pfuPsRate / 100;
    }
    // Pas de comparaison barème pour le PEA.
    baremeIr = null;
    baremePs = null;
    baremeTotal = null;
    netAfterBareme = null;
  } else {
    // Assurance-Vie.
    envelopeLabel = 'Assurance Vie';
    isExempt = false;

    // Abattement annuel : 4 600 € (< 8 ans) ou 9 200 € (≥ 8 ans).
    final abattement = anciennete >= 8 ? 9200.0 : 4600.0;
    gainImposable = max(0.0, gainRetrait - abattement);

    // PFU.
    pfuIr = gainImposable * pfuIrRate / 100;
    pfuPs = gainImposable * pfuPsRate / 100;

    // Barème progressif (IR + PS) pour comparaison. Les PS au barème sont
    // identiques au PFU (même taux de PS) ; seule la composante IR diffère
    // (barème progressif vs 12.8 % fixe).
    final irResult = computeIR(
      netImposable: gainImposable,
      nbrParts: nbrParts,
      limits: irLimits,
      rates: irRates,
    );
    final bIr = irResult.total;
    final bPs = gainImposable * pfuPsRate / 100;
    baremeIr = bIr;
    baremePs = bPs;
    baremeTotal = bIr + bPs;
    netAfterBareme = withdrawalAmount - (bIr + bPs);
  }

  final pfuTotal = pfuIr + pfuPs;
  final netAfterPfu = withdrawalAmount - pfuTotal;

  return PFUResult(
    gain: gain,
    gainImposable: gainImposable,
    pfuIr: pfuIr,
    pfuPs: pfuPs,
    pfuTotal: pfuTotal,
    netAfterPfu: netAfterPfu,
    baremeIr: baremeIr,
    baremePs: baremePs,
    baremeTotal: baremeTotal,
    netAfterBareme: netAfterBareme,
    envelopeLabel: envelopeLabel,
    isExempt: isExempt,
  );
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
  TaxParameters _taxParams = TaxParameters.defaults;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
    _loadTaxParams();
    widget.amountVisibility.addListener(_onAmountVisibilityChanged);
  }

  Future<void> _loadTaxParams() async {
    final params = await loadTaxParameters(widget.vaultPath);
    if (!mounted) return;
    setState(() => _taxParams = params);
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

  IFIResult _compute() => computeIFI(
    _immobilierNet,
    limits: _taxParams.ifiLimits,
    rates: _taxParams.ifiRates,
    seuilImposition: _taxParams.ifiSeuilImposition,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            label: l10n.simulations_taxation_field_ifi_net_worth,
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
            child: shadcn.Text(l10n.simulations_taxation_reset_parameters),
          ),
        ],
      ),
      right: Column(
        children: [
          shadcn.Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 18),
              children: [
                TextSpan(
                  text: l10n.simulations_taxation_ifi_summary_prefix,
                ),
                TextSpan(
                  text: displayEuros(_immobilierNet, hidden),
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: l10n.simulations_taxation_ifi_summary_middle,
                ),
                TextSpan(
                  text: displayEuros(result.total, hidden),
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
                TextSpan(text: l10n.simulations_taxation_summary_equivalent_suffix),
                TextSpan(
                  text:
                      '${displayEuros(result.total / 12, hidden)}/${l10n.simulations_loan_per_month_suffix}',
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
              _LegendPill(color: accent, label: l10n.simulations_taxation_legend_amount),
              _LegendPill(
                color: violet,
                label: l10n.simulations_taxation_legend_bracket_max,
              ),
              _LegendPill(color: red, label: l10n.simulations_taxation_legend_tax),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _StatRow(
            items: [
              (
                l10n.simulations_taxation_ifi_stat_max_rate,
                ['${result.tauxMax}%'],
              ),
              (
                l10n.simulations_taxation_ifi_stat_total_monthly,
                [
                  displayEuros(result.total, hidden),
                  '${displayEuros(result.total / 12, hidden)}/${l10n.simulations_loan_per_month_suffix}',
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
// Onglet PFU (retrait PEA / Assurance-Vie)
// ---------------------------------------------------------------------

class _PFUTab extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const _PFUTab({required this.vaultPath, required this.amountVisibility});

  @override
  State<_PFUTab> createState() => _PFUTabState();
}

class _PFUTabState extends State<_PFUTab> {
  // --- Champs du formulaire ---
  AccountEnvelope _envelope = AccountEnvelope.pea;
  bool _isManualMode = true;
  String? _selectedAccountId;
  double _withdrawalAmount = 10000;
  double _investedAmount = 8000;
  double _currentValue = 12000;
  DateTime _openingDate = DateTime.now().subtract(const Duration(days: 365 * 3));

  // --- Données ---
  List<InvestmentAccount> _accounts = [];
  late final SimulationStateRepository _stateRepo;
  TaxParameters _taxParams = TaxParameters.defaults;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
    _loadTaxParams();
    _loadAccounts();
    widget.amountVisibility.addListener(_onAmountVisibilityChanged);
  }

  Future<void> _loadTaxParams() async {
    final params = await loadTaxParameters(widget.vaultPath);
    if (!mounted) return;
    setState(() => _taxParams = params);
  }

  Future<void> _loadAccounts() async {
    final repo = InvestmentsRepository(widget.vaultPath);
    final all = await repo.listAll();
    if (!mounted) return;
    setState(() => _accounts = all);
  }

  void _onAmountVisibilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.amountVisibility.removeListener(_onAmountVisibilityChanged);
    super.dispose();
  }

  /// Comptes éligibles au filtre courant (PEA ou AV).
  List<InvestmentAccount> get _eligibleAccounts => _accounts.where((a) {
    if (_envelope == AccountEnvelope.pea) {
      return a.envelope == AccountEnvelope.pea ||
          a.envelope == AccountEnvelope.peaPme;
    }
    return a.envelope == AccountEnvelope.assuranceVie;
  }).toList();

  Future<void> _loadState() async {
    final data = await _stateRepo.read('taxation_pfu');
    if (!mounted || data.isEmpty) return;
    setState(() {
      final envName = data['envelope'] as String?;
      if (envName != null) {
        _envelope = AccountEnvelope.fromName(envName);
      }
      final isManual = data['isManualMode'];
      if (isManual is bool) _isManualMode = isManual;
      final selectedId = data['selectedAccountId'] as String?;
      if (selectedId != null) _selectedAccountId = selectedId;
      final withdrawal = data['withdrawalAmount'];
      if (withdrawal is num) _withdrawalAmount = withdrawal.toDouble();
      final invested = data['investedAmount'];
      if (invested is num) _investedAmount = invested.toDouble();
      final current = data['currentValue'];
      if (current is num) _currentValue = current.toDouble();
      final opening = data['openingDate'] as String?;
      if (opening != null) {
        _openingDate = DateTime.tryParse(opening) ?? _openingDate;
      }
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('taxation_pfu', {
      'envelope': _envelope.name,
      'isManualMode': _isManualMode,
      'selectedAccountId': _selectedAccountId,
      'withdrawalAmount': _withdrawalAmount,
      'investedAmount': _investedAmount,
      'currentValue': _currentValue,
      'openingDate': _openingDate.toIso8601String(),
    });
  }

  Future<void> _resetState() async {
    await _stateRepo.delete('taxation_pfu');
    if (!mounted) return;
    setState(() {
      _envelope = AccountEnvelope.pea;
      _isManualMode = true;
      _selectedAccountId = null;
      _withdrawalAmount = 10000;
      _investedAmount = 8000;
      _currentValue = 12000;
      _openingDate = DateTime.now().subtract(const Duration(days: 365 * 3));
    });
  }

  /// Pré-remplit les champs depuis un compte sélectionné.
  void _applyAccount(InvestmentAccount account) {
    setState(() {
      _selectedAccountId = account.id;
      _investedAmount = account.totalInvested;
      _currentValue = account.totalMarketValue;
      if (account.openingDate != null) _openingDate = account.openingDate!;
    });
    _saveState();
  }

  PFUResult _compute() => computePFU(
    withdrawalAmount: _withdrawalAmount,
    investedAmount: _investedAmount,
    currentValue: _currentValue,
    openingDate: _openingDate,
    envelope: _envelope,
    pfuIrRate: _taxParams.pfuIrRate,
    pfuPsRate: _taxParams.pfuPsRate,
    irLimits: _taxParams.irLimits,
    irRates: _taxParams.irRates,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = _compute();
    final accent = Theme.of(context).colorScheme.primary;
    final hidden = widget.amountVisibility.hidden;

    return _TaxationSplitCard(
      left: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Sélection de l'enveloppe ---
            shadcn.Text(l10n.simulations_taxation_pfu_field_envelope).muted().small(),
            const SizedBox(height: 6),
            Select<AccountEnvelope>(
              value: _envelope,
              constraints: const BoxConstraints(minWidth: 220),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _envelope = value;
                  _selectedAccountId = null;
                });
                _saveState();
              },
              itemBuilder: (context, value) => shadcn.Text(value.label),
              popup: (context) => SelectPopup(
                items: SelectItemList(
                  children: [
                    SelectItemButton(
                      value: AccountEnvelope.pea,
                      child: shadcn.Text(AccountEnvelope.pea.label),
                    ),
                    SelectItemButton(
                      value: AccountEnvelope.assuranceVie,
                      child: shadcn.Text(AccountEnvelope.assuranceVie.label),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Mode de saisie ---
            shadcn.Text(l10n.simulations_taxation_pfu_field_data_source).muted().small(),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: l10n.simulations_taxation_pfu_mode_manual,
                    selected: _isManualMode,
                    onTap: () {
                      setState(() => _isManualMode = true);
                      _saveState();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PillButton(
                    label: l10n.simulations_taxation_pfu_mode_existing_account,
                    selected: !_isManualMode,
                    onTap: () {
                      setState(() => _isManualMode = false);
                      _saveState();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_isManualMode && _eligibleAccounts.isNotEmpty) ...[
              // --- Sélection de compte ---
              shadcn.Text(l10n.simulations_taxation_pfu_field_choose_account).muted().small(),
              const SizedBox(height: 6),
              Select<String>(
                value: _selectedAccountId,
                constraints: const BoxConstraints(minWidth: 220),
                placeholder: shadcn.Text(
                  l10n.simulations_taxation_pfu_select_account_placeholder,
                ),
                onChanged: (id) {
                  if (id == null) return;
                  final account = _eligibleAccounts.firstWhere(
                    (a) => a.id == id,
                  );
                  _applyAccount(account);
                },
                itemBuilder: (context, id) {
                  final account = _eligibleAccounts.firstWhere(
                    (a) => a.id == id,
                  );
                  return shadcn.Text(
                    account.bankName != null
                        ? '${account.name} (${account.bankName})'
                        : account.name,
                  );
                },
                popup: (context) => SelectPopup(
                  items: SelectItemList(
                    children: [
                      for (final a in _eligibleAccounts)
                        SelectItemButton(
                          value: a.id,
                          child: shadcn.Text(
                            a.bankName != null
                                ? '${a.name} (${a.bankName})'
                                : a.name,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (!_isManualMode && _eligibleAccounts.isEmpty) ...[
              shadcn.Text(
                l10n.simulations_taxation_pfu_no_account_found(_envelope.label),
              ).muted().small(),
              const SizedBox(height: 16),
            ],

            // --- Date d'ouverture (mode manuel) ---
            if (_isManualMode) ...[
              shadcn.Text(l10n.simulations_taxation_pfu_field_opening_date).muted().small(),
              const SizedBox(height: 6),
              _DateField(
                date: _openingDate,
                onChanged: (date) {
                  setState(() => _openingDate = date);
                  _saveState();
                },
              ),
              const SizedBox(height: 16),
            ],

            // --- Montant investi (mode manuel) ---
            if (_isManualMode) ...[
              _NumberField(
                label: l10n.simulations_taxation_field_invested_amount,
                suffix: '€',
                value: _investedAmount,
                step: 1000,
                onChanged: (v) {
                  setState(() => _investedAmount = v);
                  _saveState();
                },
              ),
              const SizedBox(height: 16),
            ],

            // --- Valeur actuelle (mode manuel) ---
            if (_isManualMode) ...[
              _NumberField(
                label: l10n.simulations_taxation_field_current_value,
                suffix: '€',
                value: _currentValue,
                step: 1000,
                onChanged: (v) {
                  setState(() => _currentValue = v);
                  _saveState();
                },
              ),
              const SizedBox(height: 16),
            ],

            // --- Montant du retrait ---
            _NumberField(
              label: l10n.simulations_taxation_field_withdrawal_amount,
              suffix: '€',
              value: _withdrawalAmount,
              step: 1000,
              onChanged: (v) {
                setState(() => _withdrawalAmount = max(0.0, v));
                _saveState();
              },
            ),
            const SizedBox(height: 8),
            OutlineButton(
              onPressed: _resetState,
              leading: const Icon(LucideIcons.refreshCw),
              child: shadcn.Text(l10n.simulations_taxation_reset_parameters),
            ),
          ],
        ),
      ),
      right: Column(
        children: [
          // --- Résumé ---
          shadcn.Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 18),
              children: [
                TextSpan(
                  text: result.isExempt
                      ? l10n.simulations_taxation_pfu_summary_withdrawal_exempt_prefix(
                          result.envelopeLabel,
                        )
                      : l10n.simulations_taxation_pfu_summary_withdrawal_prefix(
                          result.envelopeLabel,
                        ),
                ),
                if (result.isExempt)
                  TextSpan(
                    text: l10n.simulations_taxation_pfu_summary_tax_exempt,
                    style: const TextStyle(
                      color: Color(0xFF66BB6A),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else ...[
                  TextSpan(text: l10n.simulations_taxation_pfu_summary_gain_prefix),
                  TextSpan(
                    text: displayEuros(result.gain, hidden),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: l10n.simulations_taxation_pfu_summary_pfu_tax_prefix),
                  TextSpan(
                    text: displayEuros(result.pfuTotal, hidden),
                    style: TextStyle(
                      color: const Color(0xFFE07A6B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: l10n.simulations_taxation_pfu_summary_net_received_prefix),
                  TextSpan(
                    text: displayEuros(result.netAfterPfu, hidden),
                    style: TextStyle(
                      color: const Color(0xFF66BB6A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (result.isExempt) ...[
            const Icon(
              LucideIcons.shieldCheck,
              size: 48,
              color: Color(0xFF66BB6A),
            ),
            const SizedBox(height: 12),
            shadcn.Text(
              l10n.simulations_taxation_pfu_exempt_message,
            ).muted(),
            const SizedBox(height: 4),
            shadcn.Text(
              l10n.simulations_taxation_pfu_exempt_explanation,
            ).muted().small(),
          ] else ...[
            const Divider(),
            const SizedBox(height: 16),

            // --- Stats PFU ---
            _StatRow(
              items: [
                (
                  l10n.simulations_taxation_pfu_stat_unrealized_gain,
                  [displayEuros(result.gain, hidden)],
                ),
                (
                  l10n.simulations_taxation_pfu_stat_taxable_gain,
                  [displayEuros(result.gainImposable, hidden)],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatRow(
              items: [
                (
                  l10n.simulations_taxation_pfu_stat_ir_rate('${_taxParams.pfuIrRate}'),
                  [displayEuros(result.pfuIr, hidden)],
                ),
                (
                  l10n.simulations_taxation_pfu_stat_ps_rate('${_taxParams.pfuPsRate}'),
                  [displayEuros(result.pfuPs, hidden)],
                ),
                (
                  l10n.simulations_taxation_pfu_stat_total,
                  [displayEuros(result.pfuTotal, hidden)],
                ),
                (
                  l10n.simulations_taxation_pfu_stat_net_received,
                  [displayEuros(result.netAfterPfu, hidden)],
                ),
              ],
            ),

            // --- Comparaison barème (AV uniquement) ---
            if (result.baremeTotal != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              shadcn.Text(l10n.simulations_taxation_pfu_comparison_title)
                  .semiBold(),
              const SizedBox(height: 12),
              _StatRow(
                items: [
                  (
                    l10n.simulations_taxation_pfu_stat_bareme_ir,
                    [displayEuros(result.baremeIr!, hidden)],
                  ),
                  (
                    l10n.simulations_taxation_pfu_stat_bareme_ps,
                    [displayEuros(result.baremePs!, hidden)],
                  ),
                  (
                    l10n.simulations_taxation_pfu_stat_bareme_total,
                    [displayEuros(result.baremeTotal!, hidden)],
                  ),
                  (
                    l10n.simulations_taxation_pfu_stat_net_after_bareme,
                    [displayEuros(result.netAfterBareme!, hidden)],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PFUComparisonBanner(
                pfuTotal: result.pfuTotal,
                baremeTotal: result.baremeTotal!,
              ),
            ],
          ],

          const SizedBox(height: 16),
          const _PFUDisclaimer(),
        ],
      ),
    );
  }
}

/// Petit bouton pilule pour basculer entre deux modes.
class _PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.border,
          ),
        ),
        alignment: Alignment.center,
        child: shadcn.Text(
          label,
          style: TextStyle(
            color: selected ? theme.colorScheme.primary : null,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }
}

/// Champ de date simplifié (saisie du jour/mois/année via text fields).
class _DateField extends StatefulWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DateField({required this.date, required this.onChanged});

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _dayCtrl;
  late final TextEditingController _monthCtrl;
  late final TextEditingController _yearCtrl;

  @override
  void initState() {
    super.initState();
    _dayCtrl = TextEditingController(text: widget.date.day.toString());
    _monthCtrl = TextEditingController(
      text: widget.date.month.toString().padLeft(2, '0'),
    );
    _yearCtrl = TextEditingController(text: widget.date.year.toString());
  }

  @override
  void didUpdateWidget(covariant _DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _dayCtrl.text = widget.date.day.toString();
      _monthCtrl.text = widget.date.month.toString().padLeft(2, '0');
      _yearCtrl.text = widget.date.year.toString();
    }
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _sync() {
    final day = int.tryParse(_dayCtrl.text);
    final month = int.tryParse(_monthCtrl.text);
    final year = int.tryParse(_yearCtrl.text);
    if (day != null && month != null && year != null &&
        month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      widget.onChanged(DateTime(year, month, day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _dayCtrl,
            keyboardType: TextInputType.number,
            placeholder: shadcn.Text(l10n.simulations_taxation_date_day_placeholder),
            textAlign: TextAlign.center,
            onChanged: (_) => _sync(),
          ),
        ),
        const SizedBox(width: 4),
        shadcn.Text('/'),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: _monthCtrl,
            keyboardType: TextInputType.number,
            placeholder: shadcn.Text(l10n.simulations_taxation_date_month_placeholder),
            textAlign: TextAlign.center,
            onChanged: (_) => _sync(),
          ),
        ),
        const SizedBox(width: 4),
        shadcn.Text('/'),
        const SizedBox(width: 4),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _yearCtrl,
            keyboardType: TextInputType.number,
            placeholder: shadcn.Text(l10n.simulations_taxation_date_year_placeholder),
            textAlign: TextAlign.center,
            onChanged: (_) => _sync(),
          ),
        ),
      ],
    );
  }
}

/// Bannière indiquant quel régime est le plus avantageux.
class _PFUComparisonBanner extends StatelessWidget {
  final double pfuTotal;
  final double baremeTotal;

  const _PFUComparisonBanner({
    required this.pfuTotal,
    required this.baremeTotal,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pfuWins = pfuTotal <= baremeTotal;
    final difference = (pfuTotal - baremeTotal).abs();
    final color = pfuWins ? const Color(0xFF66BB6A) : const Color(0xFFE9A23B);
    final icon = pfuWins ? LucideIcons.trendingDown : LucideIcons.trendingUp;
    final label = pfuWins
        ? l10n.simulations_taxation_pfu_wins_label
        : l10n.simulations_taxation_bareme_wins_label;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: shadcn.Text(
              l10n.simulations_taxation_pfu_comparison_savings(
                label,
                displayEuros(difference, false),
              ),
            ).small(),
          ),
        ],
      ),
    );
  }
}

/// Avertissement sur les règles fiscales du PFU.
class _PFUDisclaimer extends StatelessWidget {
  const _PFUDisclaimer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.mutedForeground;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shadcn.Text(l10n.simulations_taxation_pfu_about_title).small().semiBold(),
          const SizedBox(height: 4),
          shadcn.Text(
            l10n.simulations_taxation_pfu_about_body,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 4),
          shadcn.Text(
            l10n.simulations_taxation_pfu_about_rates_note,
            style: TextStyle(fontSize: 12, color: muted),
          ),
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
///
/// [limits]/[rates] sont les valeurs codées en dur du barème IR par défaut
/// ([irLimits]/[irRates]) sauf si l'utilisateur les a personnalisées dans
/// Réglages → Paramètres fiscaux (voir `tax_parameters.dart`).
IRResult computeIR({
  required double netImposable,
  required double nbrParts,
  List<double> limits = irLimits,
  List<double> rates = irRates,
}) {
  double c0(double v) => v < 0 ? 0 : v;
  final parts = nbrParts < 1 ? 1.0 : nbrParts;
  final quotient = netImposable / parts;

  final montants = [
    c0(min(quotient, limits[0])),
    c0(min(quotient - limits[0], limits[1] - limits[0])),
    c0(min(quotient - limits[1], limits[2] - limits[1])),
    c0(min(quotient - limits[2], limits[3] - limits[2])),
    c0(quotient - limits[3]),
  ];

  var maxIndex = 0;
  for (var i = 0; i < montants.length; i++) {
    if (montants[i] > 0) maxIndex = i;
  }
  final tmi = rates[maxIndex];

  final impots = List.generate(5, (i) => montants[i] * rates[i] / 100);
  final total = impots.fold<double>(0, (s, v) => s + v) * parts;

  final chartData = List.generate(
    5,
    (i) => BracketRow(
      label: '${rates[i]}%',
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
  TaxParameters _taxParams = TaxParameters.defaults;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
    _loadTaxParams();
    widget.amountVisibility.addListener(_onAmountVisibilityChanged);
  }

  Future<void> _loadTaxParams() async {
    final params = await loadTaxParameters(widget.vaultPath);
    if (!mounted) return;
    setState(() => _taxParams = params);
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

  IRResult _compute() => computeIR(
    netImposable: _netImposable,
    nbrParts: _nbrParts,
    limits: _taxParams.irLimits,
    rates: _taxParams.irRates,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            label: l10n.simulations_taxation_field_taxable_income,
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
            label: l10n.simulations_taxation_field_parts,
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
            child: shadcn.Text(l10n.simulations_taxation_reset_parameters),
          ),
        ],
      ),
      right: Column(
        children: [
          shadcn.Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 18),
              children: [
                TextSpan(
                  text: l10n.simulations_taxation_ir_summary_prefix,
                ),
                TextSpan(
                  text: displayEuros(_netImposable, hidden),
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: l10n.simulations_taxation_ir_summary_middle,
                ),
                TextSpan(
                  text: displayEuros(result.total, hidden),
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
                TextSpan(text: l10n.simulations_taxation_summary_equivalent_suffix),
                TextSpan(
                  text:
                      '${displayEuros(result.total / 12, hidden)}/${l10n.simulations_loan_per_month_suffix}',
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
              _LegendPill(color: accent, label: l10n.simulations_taxation_legend_amount),
              _LegendPill(
                color: violet,
                label: l10n.simulations_taxation_legend_bracket_max,
              ),
              _LegendPill(color: red, label: l10n.simulations_taxation_legend_tax),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _StatRow(
            items: [
              (
                l10n.simulations_taxation_ir_stat_quotient,
                [displayEuros(result.quotient, hidden)],
              ),
              (
                l10n.simulations_taxation_ir_stat_marginal_rate,
                ['${result.tmi}%'],
              ),
              (
                l10n.simulations_taxation_ir_stat_total_monthly,
                [
                  displayEuros(result.total, hidden),
                  '${displayEuros(result.total / 12, hidden)}/${l10n.simulations_loan_per_month_suffix}',
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
                      title: AppLocalizations.of(
                        context,
                      ).simulations_taxation_bracket_tooltip_title(hovered.label),
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
    final l10n = AppLocalizations.of(context);
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
                _row(l10n.simulations_taxation_legend_amount, montant, amber),
                const SizedBox(height: 6),
                _row(l10n.simulations_taxation_bracket_tooltip_max, montantMax, violet),
                const SizedBox(height: 6),
                _row(l10n.simulations_taxation_legend_tax, impot, red),
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

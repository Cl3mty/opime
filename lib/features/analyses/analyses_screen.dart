import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../dashboard/patrimoine_models.dart' show DashboardPeriod;
import '../dashboard/widgets/net_worth_chart.dart' show PeriodTabs;
import '../investments/investments_models.dart'
    show AssetClass, FundStyle, Investment;
import '../investments/performance_calculator.dart' show PerformanceResult;
import '../investments/real_patrimoine_adapter.dart'
    show
        categoryHistoryOnGrid,
        dailyDateGrid,
        earliestTransactionDateAcrossAccounts,
        investmentsForEffectiveClass;
import '../investments/yahoo_finance_client.dart' show PricePoint;
import 'analyses_calculations.dart';
import 'analyses_data_loader.dart';
import 'analyses_settings_repository.dart';

/// Écran "Analyses" : métriques avancées de portefeuille (répartition
/// gestion active/passive, volatilité, corrélation, ratio rendement/risque,
/// TRI, alpha vs benchmark, endettement, levier) — toutes calculées à
/// partir des données réelles (comptes, transactions, historique de cours),
/// jamais de valeur factice. Voir `analyses_calculations.dart` pour les
/// fonctions de calcul pures et `analyses_data_loader.dart` pour le
/// chargement des données.
class AnalysesScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const AnalysesScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<AnalysesScreen> createState() => _AnalysesScreenState();
}

class _AnalysesScreenState extends State<AnalysesScreen> {
  bool _loading = true;
  bool _loadError = false;
  int _loadGeneration = 0;
  AnalysesSnapshot? _snapshot;
  DashboardPeriod _period = DashboardPeriod.year1;
  final _benchmarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AnalysesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) {
      _loading = true;
      _loadError = false;
      _snapshot = null;
      _load();
    }
  }

  @override
  void dispose() {
    _benchmarkController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      // Même délai borné que `strategy_screen.dart` : un dossier Vault sur
      // un emplacement synchronisé (iCloud Drive...) peut ne jamais
      // répondre — mieux vaut un état d'erreur explicite qu'un spinner
      // infini.
      final snapshot = await loadAnalysesSnapshot(
        widget.vaultPath,
      ).timeout(const Duration(seconds: 15));
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _snapshot = snapshot;
        _benchmarkController.text = snapshot.benchmarkTicker ?? '';
        _loading = false;
        _loadError = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    _load();
  }

  Future<void> _saveBenchmark() async {
    final ticker = _benchmarkController.text.trim().toUpperCase();
    await AnalysesSettingsRepository(
      widget.vaultPath,
    ).save(AnalysesSettings(benchmarkTicker: ticker.isEmpty ? null : ticker));
    // Recharge pour déclencher la synchronisation de l'historique du
    // nouveau benchmark (voir `analyses_data_loader.dart`).
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError) {
      return LoadErrorView(
        message:
            'Impossible de charger les analyses. Vérifiez que le dossier '
            'Vault est accessible.',
        onRetry: _retryLoad,
      );
    }

    final snapshot = _snapshot!;
    final metrics = _computeMetrics(snapshot, _period);

    return AnimatedBuilder(
      animation: widget.amountVisibility,
      builder: (context, _) {
        final hidden = widget.amountVisibility.hidden;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  shadcn.Text('Analyses').x2Large().bold(),
                  PeriodTabs(
                    labels: [for (final p in DashboardPeriod.values) p.label],
                    index: _period.index,
                    onChanged: (i) =>
                        setState(() => _period = DashboardPeriod.values[i]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              shadcn.Text(
                'Sur la période sélectionnée, sauf mention contraire.',
              ).muted().small(),
              const SizedBox(height: 16),
              _FundStyleCard(allocation: metrics.fundStyleAllocation),
              const SizedBox(height: 16),
              _RiskReturnCard(categories: metrics.categories, total: metrics.total),
              const SizedBox(height: 16),
              _CorrelationCard(categories: metrics.categories),
              const SizedBox(height: 16),
              _TriCard(categories: metrics.categories, total: metrics.total),
              const SizedBox(height: 16),
              _AlphaCard(
                controller: _benchmarkController,
                onSave: _saveBenchmark,
                hasHistory: snapshot.benchmarkHistory.isNotEmpty,
                alpha: metrics.alpha,
              ),
              const SizedBox(height: 16),
              _DebtLeverageCard(
                totalAssets: metrics.totalAssets,
                totalLiabilities: metrics.totalLiabilities,
                debtRatioAssets: metrics.debtRatioAssets,
                debtRatioIncome: metrics.debtRatioIncome,
                leverage: metrics.leverage,
                hidden: hidden,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Métriques par catégorie d'actif — regroupe tout ce que
/// [_computeMetrics] calcule une fois pour une classe donnée, réutilisé par
/// plusieurs cartes (Risque/rendement, Corrélation, TRI) sans recalculer la
/// même série de valorisations pour chacune.
class _CategoryMetric {
  final AssetClass assetClass;
  final List<double> returns;
  final double? volatility;
  final double? annualReturn;
  final double? sharpe;
  final PerformanceResult? tri;

  const _CategoryMetric({
    required this.assetClass,
    required this.returns,
    required this.volatility,
    required this.annualReturn,
    required this.sharpe,
    required this.tri,
  });
}

class _TotalMetric {
  final double? volatility;
  final double? annualReturn;
  final double? sharpe;
  final PerformanceResult? tri;

  const _TotalMetric({
    required this.volatility,
    required this.annualReturn,
    required this.sharpe,
    required this.tri,
  });
}

class _AnalysesMetrics {
  final List<_CategoryMetric> categories;
  final _TotalMetric total;
  final Map<FundStyle?, double> fundStyleAllocation;
  final double? alpha;
  final double totalAssets;
  final double totalLiabilities;
  final double? debtRatioAssets;
  final double? debtRatioIncome;
  final double? leverage;

  const _AnalysesMetrics({
    required this.categories,
    required this.total,
    required this.fundStyleAllocation,
    required this.alpha,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.debtRatioAssets,
    required this.debtRatioIncome,
    required this.leverage,
  });
}

DateTime _dateOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// Dernier cours connu à [date] ou avant — même logique que la
/// (privée) `_priceAt` de `real_patrimoine_adapter.dart`, dupliquée ici
/// faute d'export : [history] doit déjà être triée par date croissante,
/// garanti par `PriceHistoryRepository.syncIfNeeded`.
double? _priceOnOrBefore(List<PricePoint> history, DateTime date) {
  PricePoint? best;
  for (final point in history) {
    if (point.date.isAfter(date)) break;
    best = point;
  }
  return best?.close;
}

_AnalysesMetrics _computeMetrics(AnalysesSnapshot snapshot, DashboardPeriod period) {
  final today = _dateOnly(DateTime.now());
  final earliest =
      earliestTransactionDateAcrossAccounts(snapshot.accounts) ?? today;
  final start = period.startFor(today: today, earliest: earliest);
  final grid = dailyDateGrid(start, today);
  final periodDays = today.difference(start).inDays.clamp(1, 1 << 31);

  final categories = <_CategoryMetric>[];
  final allInvestments = <Investment>[];
  List<Investment> actionsEtFondsInvestments = const [];

  for (final assetClass in AssetClass.values) {
    final investments = investmentsForEffectiveClass(
      snapshot.accounts,
      assetClass,
    );
    if (assetClass == AssetClass.actionsEtFonds) {
      actionsEtFondsInvestments = investments;
    }
    if (investments.isEmpty) continue;
    allInvestments.addAll(investments);

    final series = categoryHistoryOnGrid(
      investments,
      snapshot.priceHistories,
      grid,
    ).map((p) => p.value).toList();
    final returns = dailyReturns(series);
    final volatility = annualizedVolatility(returns);
    final annualReturn = annualizeReturn(periodReturn(series), periodDays);
    final sharpe = riskReturnRatio(
      annualReturn: annualReturn,
      volatility: volatility,
    );
    final transactions = [for (final inv in investments) ...inv.transactions];
    final currentValue = investments.fold<double>(
      0,
      (sum, inv) => sum + (inv.marketValue ?? inv.investedAmount),
    );
    final tri = transactions.isEmpty
        ? null
        : calculateTri(
            allTransactions: transactions,
            currentValue: currentValue,
            asOf: today,
          );

    categories.add(
      _CategoryMetric(
        assetClass: assetClass,
        returns: returns,
        volatility: volatility,
        annualReturn: annualReturn,
        sharpe: sharpe,
        tri: tri,
      ),
    );
  }

  final totalSeries = categoryHistoryOnGrid(
    allInvestments,
    snapshot.priceHistories,
    grid,
  ).map((p) => p.value).toList();
  final totalReturns = dailyReturns(totalSeries);
  final totalVolatility = annualizedVolatility(totalReturns);
  final totalAnnualReturn = annualizeReturn(
    periodReturn(totalSeries),
    periodDays,
  );
  final totalSharpe = riskReturnRatio(
    annualReturn: totalAnnualReturn,
    volatility: totalVolatility,
  );
  final allTransactions = [
    for (final inv in allInvestments) ...inv.transactions,
  ];
  final totalCurrentValue = allInvestments.fold<double>(
    0,
    (sum, inv) => sum + (inv.marketValue ?? inv.investedAmount),
  );
  final totalTri = allTransactions.isEmpty
      ? null
      : calculateTri(
          allTransactions: allTransactions,
          currentValue: totalCurrentValue,
          asOf: today,
        );

  // Alpha : la série "Actions & Fonds" et celle du benchmark sont évaluées
  // sur le même [start, today] — condition nécessaire pour que la
  // comparaison des rendements annualisés ait un sens (voir le risque
  // documenté dans `analyses_calculations.dart`).
  final actionsSeries = categoryHistoryOnGrid(
    actionsEtFondsInvestments,
    snapshot.priceHistories,
    grid,
  ).map((p) => p.value).toList();
  final actionsAnnualReturn = annualizeReturn(
    periodReturn(actionsSeries),
    periodDays,
  );
  final benchmarkFirst = _priceOnOrBefore(snapshot.benchmarkHistory, start);
  final benchmarkLast = _priceOnOrBefore(snapshot.benchmarkHistory, today);
  double? benchmarkTotalReturn;
  if (benchmarkFirst != null && benchmarkLast != null && benchmarkFirst > 0) {
    benchmarkTotalReturn = (benchmarkLast - benchmarkFirst) / benchmarkFirst;
  }
  final benchmarkAnnualReturn = annualizeReturn(
    benchmarkTotalReturn,
    periodDays,
  );
  final alpha = simpleAlpha(
    portfolioAnnualReturn: actionsAnnualReturn,
    benchmarkAnnualReturn: benchmarkAnnualReturn,
  );

  final allocation = fundStyleAllocation(
    actionsEtFondsInvestments,
    valueOf: (inv) => inv.marketValue ?? inv.investedAmount,
  );

  // Endettement/levier : instantané d'aujourd'hui, indépendant de la
  // période sélectionnée (voir libellé "Aujourd'hui" dans la carte).
  final totalAssets = allInvestments.fold<double>(
    0,
    (sum, inv) => sum + (inv.marketValue ?? inv.investedAmount),
  );
  final totalLiabilities = snapshot.liabilities.fold<double>(
    0,
    (sum, l) => sum + l.remainingBalance,
  );
  final netWorth = totalAssets - totalLiabilities;
  final monthlyInstallments = snapshot.liabilities.fold<double>(
    0,
    (sum, l) => sum + l.mensualite,
  );

  return _AnalysesMetrics(
    categories: categories,
    total: _TotalMetric(
      volatility: totalVolatility,
      annualReturn: totalAnnualReturn,
      sharpe: totalSharpe,
      tri: totalTri,
    ),
    fundStyleAllocation: allocation,
    alpha: alpha,
    totalAssets: totalAssets,
    totalLiabilities: totalLiabilities,
    debtRatioAssets: debtRatioAssets(
      totalLiabilities: totalLiabilities,
      totalAssets: totalAssets,
    ),
    debtRatioIncome: snapshot.monthlyIncome == null
        ? null
        : debtRatioIncome(
            monthlyInstallments: monthlyInstallments,
            monthlyIncome: snapshot.monthlyIncome!,
          ),
    leverage: leverage(totalAssets: totalAssets, netWorth: netWorth),
  );
}

String _naOr(double? value, String Function(double) format) =>
    value == null ? 'Non calculable' : format(value);

String _percent(double value) => displayPercent(value * 100);

Widget _cardTitle(String title, {String? caption}) => Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    shadcn.Text(title).semiBold().large(),
    if (caption != null) ...[
      const SizedBox(width: 8),
      shadcn.Text(caption).muted().xSmall(),
    ],
  ],
);

class _FundStyleCard extends StatelessWidget {
  final Map<FundStyle?, double> allocation;
  const _FundStyleCard({required this.allocation});

  String _labelFor(FundStyle? style) => style?.label ?? 'Non classé';

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Style de gestion', caption: 'Actions & Fonds · aujourd\'hui'),
            const SizedBox(height: 12),
            if (allocation.isEmpty)
              shadcn.Text(
                'Aucun investissement Actions & Fonds classé pour l\'instant.',
              ).muted().small()
            else
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final entry in allocation.entries)
                    _StatChip(
                      label: _labelFor(entry.key),
                      value: '${entry.value.toStringAsFixed(1)} %',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RiskReturnCard extends StatelessWidget {
  final List<_CategoryMetric> categories;
  final _TotalMetric total;
  const _RiskReturnCard({required this.categories, required this.total});

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Risque et rendement'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: SizedBox()),
                SizedBox(
                  width: 110,
                  child: shadcn.Text('Volatilité').muted().xSmall(),
                ),
                SizedBox(
                  width: 90,
                  child: shadcn.Text('Rend./risque').muted().xSmall(),
                ),
              ],
            ),
            _RiskReturnRow(
              label: 'Patrimoine entier',
              bold: true,
              volatility: total.volatility,
              sharpe: total.sharpe,
            ),
            for (final c in categories)
              _RiskReturnRow(
                label: c.assetClass.label,
                volatility: c.volatility,
                sharpe: c.sharpe,
              ),
          ],
        ),
      ),
    );
  }
}

class _RiskReturnRow extends StatelessWidget {
  final String label;
  final bool bold;
  final double? volatility;
  final double? sharpe;

  const _RiskReturnRow({
    required this.label,
    this.bold = false,
    required this.volatility,
    required this.sharpe,
  });

  @override
  Widget build(BuildContext context) {
    final text = bold
        ? shadcn.Text(label).semiBold()
        : shadcn.Text(label);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: text),
          SizedBox(
            width: 110,
            child: shadcn.Text(
              _naOr(volatility, _percent),
            ).muted().small(),
          ),
          SizedBox(
            width: 90,
            child: shadcn.Text(
              sharpe == null ? '—' : sharpe!.toStringAsFixed(2),
            ).muted().small(),
          ),
        ],
      ),
    );
  }
}

class _CorrelationCard extends StatelessWidget {
  final List<_CategoryMetric> categories;
  const _CorrelationCard({required this.categories});

  @override
  Widget build(BuildContext context) {
    final usable = [
      for (final c in categories)
        if (c.returns.length >= 3) c,
    ];
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Corrélation entre catégories'),
            const SizedBox(height: 12),
            if (usable.length < 2)
              shadcn.Text(
                'Pas assez de catégories avec un historique de cours '
                'suffisant sur cette période pour calculer une corrélation.',
              ).muted().small()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < usable.length; i++)
                    for (var j = i + 1; j < usable.length; j++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: shadcn.Text(
                                '${usable[i].assetClass.label} / '
                                '${usable[j].assetClass.label}',
                              ),
                            ),
                            shadcn.Text(
                              _naOr(
                                pearsonCorrelation(
                                  usable[i].returns,
                                  usable[j].returns,
                                ),
                                (v) => v.toStringAsFixed(2),
                              ),
                            ).muted().small(),
                          ],
                        ),
                      ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TriCard extends StatelessWidget {
  final List<_CategoryMetric> categories;
  final _TotalMetric total;
  const _TriCard({required this.categories, required this.total});

  String _formatTri(PerformanceResult? result) {
    if (result == null) return 'Non calculable';
    final percent = displayPercent(result.rate * 100);
    return result.annualized ? '$percent / an' : '$percent depuis le début';
  }

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('TRI (rendement money-weighted)'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: shadcn.Text('Patrimoine entier').semiBold(),
                  ),
                  shadcn.Text(_formatTri(total.tri)).muted().small(),
                ],
              ),
            ),
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: shadcn.Text(c.assetClass.label)),
                    shadcn.Text(_formatTri(c.tri)).muted().small(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlphaCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;
  final bool hasHistory;
  final double? alpha;

  const _AlphaCard({
    required this.controller,
    required this.onSave,
    required this.hasHistory,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Alpha vs benchmark', caption: 'Actions & Fonds'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    placeholder: const shadcn.Text(
                      'Ticker Yahoo Finance (ex: URTH pour un indice monde)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  onPressed: onSave,
                  child: const shadcn.Text('Enregistrer'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (controller.text.trim().isEmpty)
              shadcn.Text(
                'Renseignez un indice de référence pour calculer l\'alpha.',
              ).muted().small()
            else if (!hasHistory)
              shadcn.Text(
                'Historique du benchmark introuvable ou pas encore '
                'synchronisé — réessayez plus tard.',
              ).muted().small()
            else
              shadcn.Text(_naOr(alpha, _percent)).large().semiBold(),
          ],
        ),
      ),
    );
  }
}

class _DebtLeverageCard extends StatelessWidget {
  final double totalAssets;
  final double totalLiabilities;
  final double? debtRatioAssets;
  final double? debtRatioIncome;
  final double? leverage;
  final bool hidden;

  const _DebtLeverageCard({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.debtRatioAssets,
    required this.debtRatioIncome,
    required this.leverage,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Endettement et levier', caption: 'Aujourd\'hui'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _StatChip(
                  label: 'Actifs totaux',
                  value: displayEuros(totalAssets, hidden),
                ),
                _StatChip(
                  label: 'Passifs totaux',
                  value: displayEuros(totalLiabilities, hidden),
                ),
                _StatChip(
                  label: 'Taux d\'endettement (actifs)',
                  value: _naOr(debtRatioAssets, _percent),
                ),
                _StatChip(
                  label: 'Taux d\'endettement (revenus)',
                  value: debtRatioIncome == null
                      ? 'Renseignez vos revenus du mois dans Budget > Suivi'
                      : _percent(debtRatioIncome!),
                ),
                _StatChip(label: 'Levier', value: _naOr(leverage, (v) => v.toStringAsFixed(2))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          shadcn.Text(label).muted().xSmall(),
          shadcn.Text(value).medium(),
        ],
      ),
    );
  }
}

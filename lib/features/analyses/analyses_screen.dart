import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../dashboard/patrimoine_models.dart' show DashboardPeriod, NetWorthPoint;
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
import 'analyses_calculations.dart';
import 'analyses_data_loader.dart';
import 'analyses_settings_repository.dart';
import 'widgets/benchmark_comparison_chart.dart';
import 'widgets/correlation_matrix.dart';

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
              const SizedBox(height: 24),

              // Performance : ce que le patrimoine a rapporté, en absolu
              // (TRI) puis comparé à un indice (Alpha) — la question la
              // plus immédiate ("qu'est-ce que j'ai gagné ?"), donc en
              // premier.
              const _SectionHeader('Performance'),
              const SizedBox(height: 12),
              _TriCard(categories: metrics.categories, total: metrics.total),
              const SizedBox(height: 16),
              _AlphaCard(
                controller: _benchmarkController,
                onSave: _saveBenchmark,
                snapshot: snapshot,
                period: _period,
                hidden: hidden,
              ),

              // Risque : à quel prix (volatilité, drawdown...) cette
              // performance a été obtenue, puis à quel point les
              // catégories/investissements sont corrélés entre eux — le
              // prolongement naturel de "qu'est-ce que j'ai gagné ?".
              const SizedBox(height: 28),
              const _SectionHeader('Risque'),
              const SizedBox(height: 12),
              _RiskReturnCard(categories: metrics.categories, total: metrics.total),
              const SizedBox(height: 16),
              _CorrelationCard(categories: metrics.categories),

              // Composition : comment le patrimoine est construit — une
              // lecture différente (structure, pas performance), regardée
              // une fois qu'on sait ce que ça a rapporté et à quel risque.
              const SizedBox(height: 28),
              const _SectionHeader('Composition'),
              const SizedBox(height: 12),
              _FundStyleCard(allocation: metrics.fundStyleAllocation),

              // Structure financière : endettement/levier — un instantané
              // d'aujourd'hui, indépendant de la période sélectionnée
              // (voir le libellé "Aujourd'hui" de la carte), d'où sa place
              // à part, en dernier.
              const SizedBox(height: 28),
              const _SectionHeader('Structure financière'),
              const SizedBox(height: 12),
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

/// Étiquette de section ("PERFORMANCE", "RISQUE"...) suivie d'une ligne
/// horizontale — regroupe visuellement les cartes de l'écran Analyses par
/// thème plutôt que de les empiler sans distinction, pour que la page
/// reste lisible malgré le nombre de cartes qu'elle contient.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        shadcn.Text(
          title.toUpperCase(),
        ).xSmall().semiBold().muted(),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: theme.colorScheme.border)),
      ],
    );
  }
}

/// Métriques par catégorie d'actif — regroupe tout ce que
/// [_computeMetrics] calcule une fois pour une classe donnée, réutilisé par
/// plusieurs cartes (Risque/rendement, Corrélation, TRI) sans recalculer la
/// même série de valorisations pour chacune.
class _CategoryMetric implements _RiskReturnMetric {
  final AssetClass assetClass;
  final List<double> returns;
  @override
  final double? volatility;
  final double? annualReturn;
  @override
  final double? sharpe;
  @override
  final double? sortino;
  @override
  final double? maxDrawdown;
  @override
  final double? skew;
  @override
  final double? omega;
  @override
  final double? beta;
  final PerformanceResult? tri;

  /// Rendements journaliers de chaque investissement individuel de cette
  /// catégorie (même grille, même méthode que [returns], voir
  /// [dailyReturns]) — pour la matrice de corrélation "au sein d'une
  /// catégorie" de [_CorrelationCard], en plus de la matrice entre
  /// catégories.
  final List<(String label, List<double> returns)> investmentReturns;

  const _CategoryMetric({
    required this.assetClass,
    required this.returns,
    required this.volatility,
    required this.annualReturn,
    required this.sharpe,
    required this.sortino,
    required this.maxDrawdown,
    required this.skew,
    required this.omega,
    required this.beta,
    required this.tri,
    required this.investmentReturns,
  });
}

class _TotalMetric implements _RiskReturnMetric {
  @override
  final double? volatility;
  final double? annualReturn;
  @override
  final double? sharpe;
  @override
  final double? sortino;
  @override
  final double? maxDrawdown;
  @override
  final double? skew;
  @override
  final double? omega;
  @override
  final double? beta;
  final PerformanceResult? tri;

  const _TotalMetric({
    required this.volatility,
    required this.annualReturn,
    required this.sortino,
    required this.maxDrawdown,
    required this.skew,
    required this.omega,
    required this.beta,
    required this.sharpe,
    required this.tri,
  });
}

class _AnalysesMetrics {
  final List<_CategoryMetric> categories;
  final _TotalMetric total;
  final Map<FundStyle?, double> fundStyleAllocation;
  final double totalAssets;
  final double totalLiabilities;
  final double? debtRatioAssets;
  final double? debtRatioIncome;
  final double? leverage;

  const _AnalysesMetrics({
    required this.categories,
    required this.total,
    required this.fundStyleAllocation,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.debtRatioAssets,
    required this.debtRatioIncome,
    required this.leverage,
  });
}

/// Alpha vs benchmark et les deux courbes de comparaison — calculés à part
/// de [_computeMetrics], sur une période propre à la carte Alpha (voir
/// [_AlphaCard]) plutôt que la période globale de l'écran : comparer sur
/// une fenêtre différente du reste de l'écran doit être possible sans tout
/// recalculer.
class _AlphaMetrics {
  /// Rendement réel du portefeuille "Actions & Fonds" sur la période (MWR,
  /// voir [periodMwr]) — `null` sans transaction ni position de départ.
  final PerformanceResult? portfolioReturn;

  /// Rendement que les mêmes flux (mêmes dates, mêmes montants) auraient
  /// fait investis dans le benchmark à la place (voir
  /// [benchmarkEquivalentMwr]) — `null` sans benchmark exploitable.
  final PerformanceResult? benchmarkReturn;

  /// [portfolioReturn] − [benchmarkReturn] — `null` si l'un des deux ne
  /// l'est pas.
  final double? alpha;

  final List<NetWorthPoint> actionsPoints;
  final List<NetWorthPoint> benchmarkPoints;

  const _AlphaMetrics({
    required this.portfolioReturn,
    required this.benchmarkReturn,
    required this.alpha,
    required this.actionsPoints,
    required this.benchmarkPoints,
  });
}

_AlphaMetrics _computeAlphaMetrics(
  AnalysesSnapshot snapshot,
  DashboardPeriod period,
) {
  final today = _dateOnly(DateTime.now());
  final earliest =
      earliestTransactionDateAcrossAccounts(snapshot.accounts) ?? today;
  final start = period.startFor(today: today, earliest: earliest);
  final grid = dailyDateGrid(start, today);
  final actionsEtFondsInvestments = investmentsForEffectiveClass(
    snapshot.accounts,
    AssetClass.actionsEtFonds,
  );

  // Plutôt que de comparer deux rendements simples sur [start, today] en
  // supposant implicitement un capital investi à 100 % depuis `start` des
  // deux côtés (biaise en faveur/défaveur du portefeuille selon que ses
  // apports sont arrivés tôt ou tard dans la période), on rejoue les
  // mêmes flux réels (même position de départ, mêmes dates et montants
  // d'achat/vente) comme si l'argent était allé dans le benchmark au lieu
  // du portefeuille, puis on compare deux vrais MWR — une comparaison
  // honnête de ce que MON argent, aux dates où il est réellement entré, a
  // rapporté dans l'un ou l'autre.
  final actionsPoints = categoryHistoryOnGrid(
    actionsEtFondsInvestments,
    snapshot.priceHistories,
    grid,
  );
  final valuationAtStart = actionsPoints.isEmpty ? 0.0 : actionsPoints.first.value;
  final actionsFlowsAfterStart = [
    for (final inv in actionsEtFondsInvestments)
      for (final t in inv.transactions)
        if (_dateOnly(t.date).isAfter(start)) t,
  ];
  final actionsCurrentValue = actionsEtFondsInvestments.fold<double>(
    0,
    (sum, inv) => sum + (inv.effectiveMarketValue ?? inv.investedAmount),
  );
  final actionsMwr = periodMwr(
    start: start,
    today: today,
    valuationAtStart: valuationAtStart,
    flowsAfterStart: actionsFlowsAfterStart,
    currentValue: actionsCurrentValue,
  );
  final benchmarkMwr = benchmarkEquivalentMwr(
    start: start,
    today: today,
    valuationAtStart: valuationAtStart,
    flowsAfterStart: actionsFlowsAfterStart,
    benchmarkHistory: snapshot.benchmarkHistory,
  );
  final alpha = (actionsMwr != null && benchmarkMwr != null)
      ? actionsMwr.rate - benchmarkMwr.rate
      : null;
  final benchmarkPoints = benchmarkEquivalentValueSeries(
    grid: grid,
    valuationAtStart: valuationAtStart,
    flowsAfterStart: actionsFlowsAfterStart,
    benchmarkHistory: snapshot.benchmarkHistory,
  );

  return _AlphaMetrics(
    portfolioReturn: actionsMwr,
    benchmarkReturn: benchmarkMwr,
    alpha: alpha,
    actionsPoints: actionsPoints,
    benchmarkPoints: benchmarkPoints,
  );
}

DateTime _dateOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);


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
  // Une seule fois pour toutes les catégories/le total : le bêta de
  // chacun face au même benchmark configuré (voir _AlphaCard) réutilise
  // cette même série de rendements journaliers.
  final benchmarkReturns = benchmarkReturnsOnGrid(
    snapshot.benchmarkHistory,
    grid,
  );

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
    final sortino = sortinoRatio(
      annualReturn: annualReturn,
      downsideDeviation: downsideDeviation(returns),
    );
    final transactions = [for (final inv in investments) ...inv.transactions];
    final currentValue = investments.fold<double>(
      0,
      (sum, inv) => sum + (inv.effectiveMarketValue ?? inv.investedAmount),
    );
    final tri = transactions.isEmpty
        ? null
        : calculateTri(
            allTransactions: transactions,
            currentValue: currentValue,
            asOf: today,
          );
    final investmentReturns = [
      for (final investment in investments)
        (
          investment.label,
          dailyReturns(
            categoryHistoryOnGrid(
              [investment],
              snapshot.priceHistories,
              grid,
            ).map((p) => p.value).toList(),
          ),
        ),
    ];

    categories.add(
      _CategoryMetric(
        assetClass: assetClass,
        returns: returns,
        volatility: volatility,
        annualReturn: annualReturn,
        sharpe: sharpe,
        sortino: sortino,
        maxDrawdown: maxDrawdown(series),
        skew: skewness(returns),
        omega: omegaRatio(returns),
        beta: beta(returns, benchmarkReturns),
        tri: tri,
        investmentReturns: investmentReturns,
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
  final totalSortino = sortinoRatio(
    annualReturn: totalAnnualReturn,
    downsideDeviation: downsideDeviation(totalReturns),
  );
  final allTransactions = [
    for (final inv in allInvestments) ...inv.transactions,
  ];
  final totalCurrentValue = allInvestments.fold<double>(
    0,
    (sum, inv) => sum + (inv.effectiveMarketValue ?? inv.investedAmount),
  );
  final totalTri = allTransactions.isEmpty
      ? null
      : calculateTri(
          allTransactions: allTransactions,
          currentValue: totalCurrentValue,
          asOf: today,
        );

  // Alpha vs benchmark et ses deux courbes de comparaison : calculés à
  // part par [_computeAlphaMetrics], sur la période propre à [_AlphaCard]
  // plutôt que [period] (voir sa documentation).

  final allocation = fundStyleAllocation(
    actionsEtFondsInvestments,
    valueOf: (inv) => inv.effectiveMarketValue ?? inv.investedAmount,
  );

  // Endettement/levier : instantané d'aujourd'hui, indépendant de la
  // période sélectionnée (voir libellé "Aujourd'hui" dans la carte).
  final totalAssets = allInvestments.fold<double>(
    0,
    (sum, inv) => sum + (inv.effectiveMarketValue ?? inv.investedAmount),
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
      sortino: totalSortino,
      maxDrawdown: maxDrawdown(totalSeries),
      skew: skewness(totalReturns),
      omega: omegaRatio(totalReturns),
      beta: beta(totalReturns, benchmarkReturns),
      tri: totalTri,
    ),
    fundStyleAllocation: allocation,
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

/// Largeurs de colonnes partagées entre l'en-tête et chaque
/// [_RiskReturnRow] — un ratio (Sharpe, Sortino, Skew, Omega, Bêta) n'a
/// pas d'unité, contrairement à la volatilité et au max drawdown (%),
/// d'où le formatage différent par colonne mais la même largeur partout.
const _riskReturnLabelWidth = 160.0;
const _riskReturnColumnWidth = 84.0;

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
            const SizedBox(height: 4),
            shadcn.Text(
              'Bêta face au benchmark configuré dans la carte Alpha vs '
              'benchmark, si renseigné.',
            ).muted().xSmall(),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: _riskReturnLabelWidth),
                      // Du plus courant/lisible au plus pointu — Skew et
                      // Omega sont les moins familiers, en dernier.
                      for (final header in const [
                        'Volatilité',
                        'Max drawdown',
                        'Sharpe',
                        'Sortino',
                        'Bêta',
                        'Omega',
                        'Skew',
                      ])
                        SizedBox(
                          width: _riskReturnColumnWidth,
                          child: shadcn.Text(header).muted().xSmall(),
                        ),
                    ],
                  ),
                  _RiskReturnRow(
                    label: 'Patrimoine entier',
                    bold: true,
                    metric: total,
                  ),
                  for (final c in categories)
                    _RiskReturnRow(label: c.assetClass.label, metric: c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Champs communs à [_CategoryMetric] et [_TotalMetric] affichés par
/// [_RiskReturnRow] — évite de dupliquer la même liste de paramètres pour
/// les deux types plutôt que d'unifier derrière cette petite interface.
abstract class _RiskReturnMetric {
  double? get volatility;
  double? get sharpe;
  double? get sortino;
  double? get maxDrawdown;
  double? get skew;
  double? get omega;
  double? get beta;
}

class _RiskReturnRow extends StatelessWidget {
  final String label;
  final bool bold;
  final _RiskReturnMetric metric;

  const _RiskReturnRow({
    required this.label,
    this.bold = false,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final text = bold ? shadcn.Text(label).semiBold() : shadcn.Text(label);
    Widget ratio(double? value) => shadcn.Text(
      value == null ? '—' : value.toStringAsFixed(2),
    ).muted().small();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: _riskReturnLabelWidth, child: text),
          SizedBox(
            width: _riskReturnColumnWidth,
            child: shadcn.Text(
              _naOr(metric.volatility, _percent),
            ).muted().small(),
          ),
          SizedBox(
            width: _riskReturnColumnWidth,
            child: shadcn.Text(
              _naOr(metric.maxDrawdown, _percent),
            ).muted().small(),
          ),
          SizedBox(width: _riskReturnColumnWidth, child: ratio(metric.sharpe)),
          SizedBox(
            width: _riskReturnColumnWidth,
            child: ratio(metric.sortino),
          ),
          SizedBox(width: _riskReturnColumnWidth, child: ratio(metric.beta)),
          SizedBox(width: _riskReturnColumnWidth, child: ratio(metric.omega)),
          SizedBox(width: _riskReturnColumnWidth, child: ratio(metric.skew)),
        ],
      ),
    );
  }
}

class _CorrelationCard extends StatefulWidget {
  final List<_CategoryMetric> categories;
  const _CorrelationCard({required this.categories});

  @override
  State<_CorrelationCard> createState() => _CorrelationCardState();
}

class _CorrelationCardState extends State<_CorrelationCard> {
  /// `null` : matrice entre catégories (vue par défaut). Sinon : matrice
  /// entre les investissements individuels de cette catégorie — voir
  /// [CorrelationMatrix.onSelectLabel], qui bascule ici en cliquant un
  /// en-tête de ligne de la matrice entre catégories.
  AssetClass? _drilledInto;

  List<List<double?>> _matrixFor(List<List<double>> series) => [
    for (var i = 0; i < series.length; i++)
      [
        for (var j = 0; j < series.length; j++)
          i == j ? 1.0 : pearsonCorrelation(series[i], series[j]),
      ],
  ];

  @override
  Widget build(BuildContext context) {
    final usableCategories = [
      for (final c in widget.categories)
        if (c.returns.length >= 3) c,
    ];

    _CategoryMetric? selected;
    for (final c in usableCategories) {
      if (c.assetClass == _drilledInto) selected = c;
    }

    late final String title;
    late final Widget content;
    if (selected != null) {
      final usableInvestments = [
        for (final entry in selected.investmentReturns)
          if (entry.$2.length >= 3) entry,
      ];
      title = 'Corrélation — ${selected.assetClass.label}';
      content = usableInvestments.length < 2
          ? shadcn.Text(
              'Pas assez d\'investissements avec un historique de cours '
              'suffisant dans cette catégorie sur cette période pour '
              'calculer une corrélation.',
            ).muted().small()
          : CorrelationMatrix(
              labels: [for (final entry in usableInvestments) entry.$1],
              matrix: _matrixFor([
                for (final entry in usableInvestments) entry.$2,
              ]),
            );
    } else {
      title = 'Corrélation entre catégories';
      content = usableCategories.length < 2
          ? shadcn.Text(
              'Pas assez de catégories avec un historique de cours '
              'suffisant sur cette période pour calculer une corrélation.',
            ).muted().small()
          : CorrelationMatrix(
              labels: [
                for (final c in usableCategories) c.assetClass.label,
              ],
              matrix: _matrixFor([
                for (final c in usableCategories) c.returns,
              ]),
              onSelectLabel: (i) => setState(
                () => _drilledInto = usableCategories[i].assetClass,
              ),
            );
    }

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selected != null)
                  IconButton.ghost(
                    icon: const Icon(LucideIcons.arrowLeft, size: 16),
                    onPressed: () => setState(() => _drilledInto = null),
                  ),
                _cardTitle(title),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }
}

/// "X % / an" (période ≥ 1 an, voir [PerformanceResult.annualized]) ou
/// "X % depuis le début" (période plus courte, taux cumulé non annualisé)
/// — même libellé pour tout MWR/TWR affiché sur cet écran (TRI, ainsi que
/// le portefeuille/benchmark de la carte Alpha), pour rester cohérent
/// plutôt que d'avoir un format différent par carte.
String _formatPerformanceResult(PerformanceResult? result) {
  if (result == null) return 'Non calculable';
  final percent = displayPercent(result.rate * 100);
  return result.annualized ? '$percent / an' : '$percent depuis le début';
}

class _TriCard extends StatelessWidget {
  final List<_CategoryMetric> categories;
  final _TotalMetric total;
  const _TriCard({required this.categories, required this.total});

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
                  shadcn.Text(_formatPerformanceResult(total.tri)).muted().small(),
                ],
              ),
            ),
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: shadcn.Text(c.assetClass.label)),
                    shadcn.Text(_formatPerformanceResult(c.tri)).muted().small(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Indices de référence courants proposés en raccourci, en plus de la
/// saisie libre d'un ticker Yahoo Finance quelconque — les tickers
/// d'indice bruts (`^...`) sont utilisés quand Yahoo Finance les expose
/// directement (S&P 500, CAC 40, Nikkei, DAX, Dow Jones, Russell 2000) ;
/// MSCI World/ACWI n'ont pas de ticker d'indice Yahoo, donc leur ETF
/// répliquant le plus liquide sert de proxy (URTH/ACWI, iShares) — même
/// logique que l'exemple déjà donné dans le champ de saisie.
const _benchmarkPresets = [
  (label: 'S&P 500', ticker: '^GSPC'),
  (label: 'Nasdaq 100', ticker: '^NDX'),
  (label: 'MSCI World', ticker: 'URTH'),
  (label: 'MSCI ACWI', ticker: 'ACWI'),
  (label: 'CAC 40', ticker: '^FCHI'),
  (label: 'Nikkei 225', ticker: '^N225'),
  (label: 'DAX', ticker: '^GDAXI'),
  (label: 'Dow Jones', ticker: '^DJI'),
  (label: 'Russell 2000', ticker: '^RUT'),
];

class _AlphaCard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSave;
  final AnalysesSnapshot snapshot;
  final DashboardPeriod period;
  final bool hidden;

  const _AlphaCard({
    required this.controller,
    required this.onSave,
    required this.snapshot,
    required this.period,
    required this.hidden,
  });

  @override
  State<_AlphaCard> createState() => _AlphaCardState();
}

class _AlphaCardState extends State<_AlphaCard> {
  void _openBenchmarkPresetsMenu(BuildContext anchorContext) {
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: DropdownMenu(
          children: [
            for (final preset in _benchmarkPresets)
              MenuButton(
                trailing: shadcn.Text(preset.ticker).muted().xSmall(),
                child: shadcn.Text(preset.label),
                // Contrairement à la saisie libre (qui attend un clic sur
                // "Enregistrer" pour ne pas resynchroniser à chaque
                // frappe), choisir un préréglage est un choix complet et
                // déjà validé : enregistrer tout de suite évite l'étape
                // supplémentaire, sinon inutile ici.
                onPressed: (_) {
                  setState(() => widget.controller.text = preset.ticker);
                  widget.onSave();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticker = widget.controller.text.trim();
    final hasHistory = widget.snapshot.benchmarkHistory.isNotEmpty;
    final metrics = _computeAlphaMetrics(widget.snapshot, widget.period);
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _cardTitle('Alpha vs benchmark', caption: 'Actions & Fonds'),
                const SizedBox(width: 6),
                Tooltip(
                  tooltip: (context) => const TooltipContainer(
                    child: SizedBox(
                      width: 280,
                      child: shadcn.Text(
                        'Le portefeuille réel est comparé à ce que les '
                        'mêmes versements (mêmes dates, mêmes montants) '
                        'auraient donné investis dans le benchmark à la '
                        'place, plutôt qu\'un indice supposé investi à '
                        '100 % dès le début de la période — un apport '
                        'récent n\'est jamais jugé comme s\'il avait '
                        'fructifié depuis toujours. Alpha = rendement '
                        'réel du portefeuille − rendement que ces mêmes '
                        'flux auraient fait dans le benchmark (deux MWR).',
                      ),
                    ),
                  ),
                  child: Icon(
                    LucideIcons.info,
                    size: 15,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    placeholder: const shadcn.Text(
                      'Ticker Yahoo Finance (ex: URTH pour un indice monde)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) => OutlineButton(
                    onPressed: () => _openBenchmarkPresetsMenu(context),
                    trailing: const Icon(LucideIcons.chevronDown, size: 14),
                    child: const shadcn.Text('Indices courants'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  onPressed: widget.onSave,
                  child: const shadcn.Text('Enregistrer'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (ticker.isEmpty)
              shadcn.Text(
                'Renseignez un indice de référence pour calculer l\'alpha.',
              ).muted().small()
            else if (!hasHistory)
              shadcn.Text(
                'Historique du benchmark introuvable ou pas encore '
                'synchronisé — réessayez plus tard.',
              ).muted().small()
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'Portefeuille',
                      value: _formatPerformanceResult(metrics.portfolioReturn),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      label: ticker,
                      value: _formatPerformanceResult(metrics.benchmarkReturn),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      label: 'Alpha',
                      value: _naOr(metrics.alpha, _percent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                // Plus haut que les autres graphiques de l'écran
                // (généralement ~180) : un gros apport récent peut
                // dominer l'échelle verticale au point d'écraser
                // visuellement tout ce qui le précède — plus de hauteur
                // laisse un peu plus de place pour distinguer les deux
                // courbes avant ce genre de saut.
                height: 320,
                child: BenchmarkComparisonChart(
                  portfolioPoints: metrics.actionsPoints,
                  benchmarkPoints: metrics.benchmarkPoints,
                  benchmarkTicker: ticker,
                  hidden: widget.hidden,
                  portfolioColor: theme.colorScheme.primary,
                  benchmarkColor: theme.colorScheme.mutedForeground,
                  gridColor: theme.colorScheme.border,
                  textColor: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
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

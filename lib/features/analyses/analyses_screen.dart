import 'package:countries_world_map/countries_world_map.dart' show SimpleMap;
import 'package:countries_world_map/data/maps/world_map.dart' show SMapWorld;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../../l10n/app_localizations.dart';
import '../dashboard/patrimoine_models.dart'
    show DashboardPeriod, NetWorthPoint;
import '../dashboard/widgets/allocation_blocks_view.dart' show AllocationSlice;
import '../dashboard/widgets/allocation_donut_view.dart'
    show AllocationDonutView;
import '../dashboard/widgets/net_worth_chart.dart' show PeriodTabs;
import '../investments/investments_models.dart'
    show AssetClass, FundStyle, Investment, Sector, kInvestmentCountries;
import '../investments/performance_calculator.dart' show PerformanceResult;
import '../investments/sector_style.dart' show sectorColor;
import '../investments/real_patrimoine_adapter.dart'
    show
        buildAllRealCategories,
        categoryHistoryOnGrid,
        dailyDateGrid,
        earliestTransactionDateAcrossAccounts,
        investmentsForEffectiveClass;
import 'analyses_calculations.dart';
import 'analyses_data_loader.dart';
import 'analyses_settings_repository.dart';
import 'widgets/benchmark_comparison_chart.dart';
import 'widgets/correlation_matrix.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Ratio largeur/hauteur de [SMapWorld.instructions] (2000×857) — nécessaire
/// pour donner à [SimpleMap] une hauteur cohérente avec sa largeur
/// disponible via [AspectRatio], puisqu'il ne se dimensionne pas tout seul
/// dans des contraintes de hauteur non bornées (voir _GeographicDiversificationCard).
const _worldMapAspectRatio = 2000 / 857;

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

  /// Onglet actif (Performance/Risque/Composition/Structure financière) —
  /// voir [build]. Non persisté (pur état d'affichage, contrairement à
  /// [_period]/au ticker du benchmark qui restent significatifs d'une
  /// session à l'autre) : l'écran rouvre toujours sur "Performance".
  int _tabIndex = 0;

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
        message: AppLocalizations.of(context).analyses_load_error,
        onRetry: _retryLoad,
      );
    }

    final snapshot = _snapshot!;
    final metrics = _computeMetrics(snapshot, _period, widget.vaultPath);

    return AnimatedBuilder(
      animation: widget.amountVisibility,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final hidden = widget.amountVisibility.hidden;
        // Période et benchmark ne concernent que Performance/Risque — les
        // masquer sur Composition/Structure financière (des instantanés
        // d'aujourd'hui, indépendants de la période, voir _DebtLeverageCard)
        // évite d'afficher un sélecteur qui n'aurait aucun effet visible.
        final periodRelevant = _tabIndex == 0 || _tabIndex == 1;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  shadcn.Text(l10n.analyses_title).x2Large().bold(),
                  if (periodRelevant)
                    PeriodTabs(
                      labels: [for (final p in DashboardPeriod.values) p.label],
                      index: _period.index,
                      onChanged: (i) =>
                          setState(() => _period = DashboardPeriod.values[i]),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TabList(
                index: _tabIndex,
                onChanged: (value) => setState(() => _tabIndex = value),
                children: [
                  TabItem(child: shadcn.Text(l10n.analyses_tab_performance)),
                  TabItem(child: shadcn.Text(l10n.analyses_tab_risk)),
                  TabItem(child: shadcn.Text(l10n.analyses_tab_composition)),
                  TabItem(
                    child: shadcn.Text(l10n.analyses_tab_financial_structure),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Performance : ce que le patrimoine a rapporté comparé à un
              // indice (Alpha) puis en absolu (TRI) — la question la plus
              // immédiate ("qu'est-ce que j'ai gagné ?"), donc premier onglet.
              if (_tabIndex == 0) ...[
                _UnrealizedGainCard(
                  plusValueAbs: metrics.globalUnrealizedGain,
                  plusValuePercent: metrics.globalUnrealizedGainPercent,
                  hidden: hidden,
                ),
                const SizedBox(height: 16),
                _AlphaCard(
                  controller: _benchmarkController,
                  onSave: _saveBenchmark,
                  snapshot: snapshot,
                  period: _period,
                  hidden: hidden,
                ),
                const SizedBox(height: 16),
                _TriCard(categories: metrics.categories, total: metrics.total),
              ]
              // Risque : à quel prix (volatilité, drawdown...) cette
              // performance a été obtenue, puis à quel point les
              // catégories/investissements sont corrélés entre eux — le
              // prolongement naturel de "qu'est-ce que j'ai gagné ?".
              else if (_tabIndex == 1) ...[
                _RiskReturnCard(
                  categories: metrics.categories,
                  total: metrics.total,
                ),
                const SizedBox(height: 16),
                _CorrelationCard(categories: metrics.categories),
              ]
              // Composition : comment le patrimoine est construit — une
              // lecture différente (structure, pas performance), regardée
              // une fois qu'on sait ce que ça a rapporté et à quel risque.
              else if (_tabIndex == 2) ...[
                _FundStyleCard(allocation: metrics.fundStyleAllocation),
                const SizedBox(height: 16),
                _SectorDiversificationCard(
                  allocation: metrics.sectorAllocation,
                  totalValue: metrics.actionsEtFondsTotalValue,
                  hidden: hidden,
                  investments: metrics.actionsEtFondsInvestments,
                ),
                const SizedBox(height: 16),
                _GeographicDiversificationCard(
                  allocation: metrics.countryAllocation,
                  hidden: hidden,
                  investments: metrics.actionsEtFondsInvestments,
                ),
              ]
              // Structure financière : endettement/levier — un instantané
              // d'aujourd'hui, indépendant de la période sélectionnée (voir
              // le libellé "Aujourd'hui" de la carte), d'où sa place à part,
              // dernier onglet.
              else
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
  final Map<Sector?, double> sectorAllocation;
  final Map<String?, double> countryAllocation;

  /// Investissements Actions & Fonds classables (même périmètre que
  /// [sectorAllocation]/[countryAllocation]) — exposés en plus des
  /// pourcentages agrégés pour que [_SectorDiversificationCard]/
  /// [_GeographicDiversificationCard] puissent lister, au survol/clic d'un
  /// secteur ou d'un pays, les investissements qui le composent.
  final List<Investment> actionsEtFondsInvestments;

  /// Valeur totale (aujourd'hui) des investissements Actions & Fonds
  /// classables — même périmètre que [sectorAllocation]/[countryAllocation]
  /// (exclut les lignes à valeur nulle ou négative), affichée au centre du
  /// donut sectoriel.
  final double actionsEtFondsTotalValue;
  final double totalAssets;
  final double totalLiabilities;
  final double? debtRatioAssets;
  final double? debtRatioIncome;
  final double? leverage;

  /// Plus-value latente globale (aujourd'hui, indépendante de [period]) —
  /// même périmètre que la carte Allocation du Dashboard
  /// ([PatrimoineCategory.plusValueAbsPatrimoine]/[montantPatrimoine],
  /// ignore les lignes exclues du patrimoine). Affichée auparavant sur la
  /// carte "Patrimoine" du Dashboard (`real_patrimoine_card.dart`),
  /// déplacée ici pour garder cette carte à sa présentation d'origine.
  final double globalUnrealizedGain;
  final double? globalUnrealizedGainPercent;

  const _AnalysesMetrics({
    required this.categories,
    required this.total,
    required this.fundStyleAllocation,
    required this.sectorAllocation,
    required this.countryAllocation,
    required this.actionsEtFondsInvestments,
    required this.actionsEtFondsTotalValue,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.debtRatioAssets,
    required this.debtRatioIncome,
    required this.leverage,
    required this.globalUnrealizedGain,
    required this.globalUnrealizedGainPercent,
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
  final valuationAtStart = actionsPoints.isEmpty
      ? 0.0
      : actionsPoints.first.value;
  final actionsFlowsAfterStart = [
    for (final inv in actionsEtFondsInvestments)
      for (final t in inv.transactions)
        if (_dateOnly(t.date).isAfter(start)) t,
  ];
  final actionsCurrentValue = actionsEtFondsInvestments.fold<double>(
    0,
    (sum, inv) => sum + inv.displayValue,
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

_AnalysesMetrics _computeMetrics(
  AnalysesSnapshot snapshot,
  DashboardPeriod period,
  String vaultPath,
) {
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
    // Un investissement exclu du patrimoine global (voir
    // Investment.excludedFromPatrimoine) continue de compter dans les
    // métriques d'Analyses — seuls les agrégats globaux du Dashboard
    // l'ignorent (voir `real_patrimoine_adapter.dart`'s
    // `investmentsForEffectiveClass`).
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
      (sum, inv) => sum + inv.displayValue,
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
    (sum, inv) => sum + inv.displayValue,
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
    valueOf: (inv) => inv.displayValue,
  );
  final sectorAlloc = sectorAllocation(
    actionsEtFondsInvestments,
    valueOf: (inv) => inv.displayValue,
  );
  final countryAlloc = countryAllocation(
    actionsEtFondsInvestments,
    valueOf: (inv) => inv.displayValue,
  );
  final actionsEtFondsTotalValue = actionsEtFondsInvestments
      .where((inv) => inv.displayValue > 0)
      .fold<double>(0, (sum, inv) => sum + inv.displayValue);

  // Endettement/levier : instantané d'aujourd'hui, indépendant de la
  // période sélectionnée (voir libellé "Aujourd'hui" dans la carte).
  final totalAssets = allInvestments.fold<double>(
    0,
    (sum, inv) => sum + inv.displayValue,
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

  // Même périmètre que la carte Allocation du Dashboard ("mon patrimoine
  // total") : ignore les lignes exclues du patrimoine, voir
  // [PatrimoineCategory.montantPatrimoine]/[plusValueAbsPatrimoine].
  final realCategories = buildAllRealCategories(
    snapshot.accounts,
    snapshot.priceHistories,
    vaultPath,
  );
  final globalUnrealizedGain = realCategories.fold<double>(
    0,
    (sum, c) => sum + c.plusValueAbsPatrimoine,
  );
  final globalCoutAcquisition =
      realCategories.fold<double>(0, (sum, c) => sum + c.montantPatrimoine) -
      globalUnrealizedGain;
  final globalUnrealizedGainPercent = globalCoutAcquisition == 0
      ? null
      : globalUnrealizedGain / globalCoutAcquisition * 100;

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
    sectorAllocation: sectorAlloc,
    countryAllocation: countryAlloc,
    actionsEtFondsInvestments: actionsEtFondsInvestments,
    actionsEtFondsTotalValue: actionsEtFondsTotalValue,
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
    globalUnrealizedGain: globalUnrealizedGain,
    globalUnrealizedGainPercent: globalUnrealizedGainPercent,
  );
}

// `notCalculableLabel` est passé explicitement (plutôt qu'un `BuildContext`)
// car cette fonction est utilisée dans des contextes où récupérer
// `AppLocalizations.of(context)` à chaque appel serait redondant — les
// appelants la calculent déjà une fois pour tout leur `build`.
String _naOr(
  double? value,
  String Function(double) format,
  String notCalculableLabel,
) => value == null ? notCalculableLabel : format(value);

String _percent(double value) => displayPercent(value * 100);

Widget _cardTitle(
  BuildContext context,
  String title, {
  String? caption,
  String? tooltip,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    shadcn.Text(title).semiBold().large(),
    if (tooltip != null) ...[
      const SizedBox(width: 6),
      Tooltip(
        tooltip: (context) => TooltipContainer(
          child: SizedBox(width: 260, child: shadcn.Text(tooltip)),
        ),
        child: Icon(
          LucideIcons.info,
          size: 15,
          color: Theme.of(context).colorScheme.mutedForeground,
        ),
      ),
    ],
    if (caption != null) ...[
      const SizedBox(width: 8),
      shadcn.Text(caption).muted().xSmall(),
    ],
  ],
);

class _FundStyleCard extends StatelessWidget {
  final Map<FundStyle?, double> allocation;
  const _FundStyleCard({required this.allocation});

  String _labelFor(FundStyle? style, AppLocalizations l10n) =>
      style?.label ?? l10n.analyses_unclassified;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              context,
              l10n.analyses_fund_style_title,
              caption: l10n.analyses_scope_caption,
              tooltip: l10n.analyses_fund_style_tooltip,
            ),
            const SizedBox(height: 12),
            if (allocation.isEmpty)
              shadcn.Text(
                l10n.analyses_no_classified_investments,
              ).muted().small()
            else
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final entry in allocation.entries)
                    _StatChip(
                      label: _labelFor(entry.key, l10n),
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

/// Identifiant de la part/du pays "Non classé" (clé `null` des `Map`
/// d'allocation) — partagé par [_SectorDiversificationCard] et
/// [_GeographicDiversificationCard] pour repérer la sélection courante
/// (survol/clic) dans un `Map<Sector?/String?, double>` dont la clé `null`
/// ne peut pas servir directement d'identifiant de widget/état.
const _unclassifiedSelectionId = 'non-classe';

/// Investissements (avec leur contribution en €) qui composent le secteur
/// [key] sélectionné dans [_SectorDiversificationCard] — même logique de
/// ventilation qu'`analyses_calculations.dart`'s `sectorAllocation`
/// (répartition pondérée via [Investment.sectorBreakdown] si renseignée,
/// sinon [Investment.sector] unique) plutôt qu'une simple égalité, pour
/// qu'un ETF multi-secteurs apparaisse dans chaque secteur qu'il couvre
/// avec sa part réelle, pas sa valeur totale. Ignore toute position à
/// valeur actuelle nulle (position soldée) — cohérent avec le camembert,
/// qui les ignore déjà.
List<(Investment, double)> _sectorMatches(
  List<Investment> investments,
  Sector? key,
) {
  final result = <(Investment, double)>[];
  for (final inv in investments) {
    if (inv.displayValue <= 0) continue;
    if (inv.sectorBreakdown.isNotEmpty) {
      if (key == null) {
        final covered = inv.sectorBreakdown.fold(
          0.0,
          (sum, w) => sum + w.percent,
        );
        final remainder =
            inv.displayValue * (100 - covered).clamp(0, 100) / 100;
        if (remainder > 0) result.add((inv, remainder));
      } else {
        final matchedPercent = inv.sectorBreakdown
            .where((w) => w.sector == key)
            .fold(0.0, (sum, w) => sum + w.percent);
        if (matchedPercent > 0) {
          result.add((inv, inv.displayValue * matchedPercent / 100));
        }
      }
    } else if (inv.sector == key) {
      result.add((inv, inv.displayValue));
    }
  }
  return result;
}

/// Même principe que [_sectorMatches], pour la diversification
/// géographique — voir [_GeographicDiversificationCard].
List<(Investment, double)> _countryMatches(
  List<Investment> investments,
  String? key,
) {
  final result = <(Investment, double)>[];
  for (final inv in investments) {
    if (inv.displayValue <= 0) continue;
    if (inv.countryBreakdown.isNotEmpty) {
      if (key == null) {
        final covered = inv.countryBreakdown.fold(
          0.0,
          (sum, w) => sum + w.percent,
        );
        final remainder =
            inv.displayValue * (100 - covered).clamp(0, 100) / 100;
        if (remainder > 0) result.add((inv, remainder));
      } else {
        final matchedPercent = inv.countryBreakdown
            .where((w) => w.countryCode == key)
            .fold(0.0, (sum, w) => sum + w.percent);
        if (matchedPercent > 0) {
          result.add((inv, inv.displayValue * matchedPercent / 100));
        }
      }
    } else if (inv.countryCode == key) {
      result.add((inv, inv.displayValue));
    }
  }
  return result;
}

/// Carte "Diversification sectorielle" : un donut (avec sa légende
/// intégrée, voir [AllocationDonutView]) de la répartition de la valeur
/// des investissements Actions & Fonds par [Sector] — même source
/// ([sectorAllocation]) et même périmètre que [_FundStyleCard], juste une
/// classification différente. Survoler ou cliquer une part (anneau ou
/// légende) affiche la liste des investissements qui la composent — le
/// survol prévisualise, le clic épingle la sélection pour qu'elle reste
/// visible une fois la souris repartie.
class _SectorDiversificationCard extends StatefulWidget {
  final Map<Sector?, double> allocation;
  final double totalValue;
  final bool hidden;
  final List<Investment> investments;

  const _SectorDiversificationCard({
    required this.allocation,
    required this.totalValue,
    required this.hidden,
    required this.investments,
  });

  @override
  State<_SectorDiversificationCard> createState() =>
      _SectorDiversificationCardState();
}

class _SectorDiversificationCardState
    extends State<_SectorDiversificationCard> {
  String? _hoveredId;
  String? _pinnedId;

  String _labelFor(Sector? sector, AppLocalizations l10n) =>
      sector?.label ?? l10n.analyses_unclassified;

  String _idFor(Sector? sector) => sector?.name ?? _unclassifiedSelectionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sorted = widget.allocation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final selectedId = _hoveredId ?? _pinnedId;
    final selectedEntry = selectedId == null
        ? null
        : sorted.where((e) => _idFor(e.key) == selectedId).firstOrNull;
    final matching = selectedEntry == null
        ? const <(Investment, double)>[]
        : _sectorMatches(widget.investments, selectedEntry.key);

    // Les trois colonnes de la carte : l'anneau à gauche, la liste des
    // secteurs (légende avec pastille de couleur) au centre, et le détail
    // des investissements de la part survolée/cliquée à droite.
    final chart = _SectorDonut(
      allocation: widget.allocation,
      totalValue: widget.totalValue,
      hidden: widget.hidden,
      onHoveredIdChanged: (id) => setState(() => _hoveredId = id),
      onSliceTap: (id) =>
          setState(() => _pinnedId = _pinnedId == id ? null : id),
    );
    final list = _SectorList(
      entries: sorted,
      selectedId: selectedId,
      onHoveredIdChanged: (id) => setState(() => _hoveredId = id),
      onTap: (id) => setState(() => _pinnedId = _pinnedId == id ? null : id),
    );
    final detail = _SelectionDetailColumn(
      title: selectedEntry?.key == null
          ? null
          : _labelFor(selectedEntry!.key, l10n),
      entries: matching,
      hidden: widget.hidden,
      dropHint: l10n.analyses_sector_drop_hint,
    );

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              context,
              l10n.analyses_sector_diversification_title,
              caption: l10n.analyses_scope_caption,
              tooltip: l10n.analyses_sector_diversification_tooltip,
            ),
            const SizedBox(height: 12),
            if (widget.allocation.isEmpty)
              shadcn.Text(
                l10n.analyses_no_classified_investments,
              ).muted().small()
            else
              _ThreeColumnLayout(chart: chart, list: list, detail: detail),
          ],
        ),
      ),
    );
  }
}

/// Carte "Diversification géographique" : une carte du monde colorée par
/// pays (plus le pays pèse dans le portefeuille Actions & Fonds, plus sa
/// couleur est intense) accompagnée de la liste des pays avec leur
/// pourcentage — même source ([countryAllocation]) et même périmètre que
/// [_FundStyleCard]/[_SectorDiversificationCard]. Survoler ou cliquer un
/// pays (sur la carte ou dans la liste) affiche les investissements qui le
/// composent — même interaction survol/clic que la carte sectorielle.
class _GeographicDiversificationCard extends StatefulWidget {
  final Map<String?, double> allocation;
  final bool hidden;
  final List<Investment> investments;

  const _GeographicDiversificationCard({
    required this.allocation,
    required this.hidden,
    required this.investments,
  });

  @override
  State<_GeographicDiversificationCard> createState() =>
      _GeographicDiversificationCardState();
}

class _GeographicDiversificationCardState
    extends State<_GeographicDiversificationCard> {
  String? _hoveredId;
  String? _pinnedId;

  String _idFor(String? code) => code ?? _unclassifiedSelectionId;

  String _labelFor(String? code, AppLocalizations l10n) => code == null
      ? l10n.analyses_unclassified
      : (kInvestmentCountries[code] ?? code);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sorted = widget.allocation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxPercent = sorted.isEmpty
        ? 0.0
        : sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final selectedId = _hoveredId ?? _pinnedId;
    final selectedEntry = selectedId == null
        ? null
        : sorted.where((e) => _idFor(e.key) == selectedId).firstOrNull;
    final matching = selectedEntry == null
        ? const <(Investment, double)>[]
        : _countryMatches(widget.investments, selectedEntry.key);

    // `SimpleMap.colors` n'accepte qu'une entrée par pays effectivement
    // détenu (`entry.key != null`) — les pays absents gardent `defaultColor`.
    // Intensité proportionnelle au poids dans le portefeuille plutôt qu'une
    // couleur binaire "détenu/non détenu", pour distinguer d'un coup d'œil
    // une position dominante d'une position marginale.
    final mapColors = <String, Color>{
      for (final entry in sorted)
        if (entry.key != null)
          entry.key!.toLowerCase(): Color.lerp(
            theme.colorScheme.primary.withValues(alpha: 0.25),
            theme.colorScheme.primary,
            maxPercent == 0 ? 0 : (entry.value / maxPercent).clamp(0.0, 1.0),
          )!,
    };

    // Un pays survolé/cliqué sur la carte qui n'est pas effectivement
    // détenu (`allocation` ne le contient pas) ne doit rien changer — sinon
    // survoler des pays sans position ferait clignoter la sélection en
    // vain en parcourant la carte.
    void handleMapHover(String id, bool isHovering) {
      final code = id.toUpperCase();
      if (!isHovering) {
        setState(() => _hoveredId = null);
        return;
      }
      if (!widget.allocation.containsKey(code)) return;
      setState(() => _hoveredId = code);
    }

    void handleMapTap(String id) {
      final code = id.toUpperCase();
      if (!widget.allocation.containsKey(code)) return;
      setState(() => _pinnedId = _pinnedId == code ? null : code);
    }

    // Les trois colonnes de la carte : le planisphère à gauche, la liste
    // des pays au centre, et le détail des investissements du pays
    // survolé/cliqué à droite.
    final chart = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: _worldMapAspectRatio,
        child: SimpleMap(
          instructions: SMapWorld.instructions,
          defaultColor: theme.colorScheme.muted,
          colors: mapColors,
          onHover: (id, name, isHovering) => handleMapHover(id, isHovering),
          callback: (id, name, tapDetails) => handleMapTap(id),
        ),
      ),
    );
    final list = _CountryList(
      entries: sorted,
      selectedId: selectedId,
      onHoveredIdChanged: (id) => setState(() => _hoveredId = id),
      onTap: (id) => setState(() => _pinnedId = _pinnedId == id ? null : id),
    );
    final detail = _SelectionDetailColumn(
      title: selectedEntry?.key == null
          ? null
          : _labelFor(selectedEntry!.key, l10n),
      entries: matching,
      hidden: widget.hidden,
      dropHint: l10n.analyses_country_drop_hint,
    );

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              context,
              l10n.analyses_geo_diversification_title,
              caption: l10n.analyses_scope_caption,
              tooltip: l10n.analyses_geo_diversification_tooltip,
            ),
            const SizedBox(height: 12),
            if (widget.allocation.isEmpty)
              shadcn.Text(
                l10n.analyses_no_classified_investments,
              ).muted().small()
            else
              _ThreeColumnLayout(chart: chart, list: list, detail: detail),
          ],
        ),
      ),
    );
  }
}

/// Liste "pays · pourcentage" de [_GeographicDiversificationCard] — même
/// présentation (et maintenant le même survol/clic, voir [selectedId]) que
/// la légende intégrée d'[AllocationDonutView], puisque [SimpleMap] n'en
/// fournit pas.
class _CountryList extends StatelessWidget {
  final List<MapEntry<String?, double>> entries;
  final String? selectedId;
  final ValueChanged<String?> onHoveredIdChanged;
  final ValueChanged<String> onTap;

  const _CountryList({
    required this.entries,
    required this.selectedId,
    required this.onHoveredIdChanged,
    required this.onTap,
  });

  String _idFor(String? code) => code ?? _unclassifiedSelectionId;

  String _labelFor(String? code, AppLocalizations l10n) => code == null
      ? l10n.analyses_unclassified
      : (kInvestmentCountries[code] ?? code);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onHoveredIdChanged(_idFor(entry.key)),
              onExit: (_) => onHoveredIdChanged(null),
              child: GestureDetector(
                onTap: () => onTap(_idFor(entry.key)),
                child: AnimatedOpacity(
                  duration: Duration.zero,
                  opacity: selectedId != null && selectedId != _idFor(entry.key)
                      ? 0.35
                      : 1.0,
                  child: Row(
                    children: [
                      Flexible(
                        child: shadcn.Text(
                          _labelFor(entry.key, l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ).small(),
                      ),
                      const SizedBox(width: 6),
                      shadcn.Text(
                        entry.value < 1
                            ? '${entry.value.toStringAsFixed(2)} %'
                            : '${entry.value.toStringAsFixed(0)} %',
                      ).muted().xSmall(),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Mise en page responsive à trois colonnes (tableau, liste, détail)
/// utilisée par [_SectorDiversificationCard] et
/// [_GeographicDiversificationCard]. Sous une largeur seuil, les trois
/// colonnes sont empilées verticalement.
class _ThreeColumnLayout extends StatelessWidget {
  final Widget chart;
  final Widget list;
  final Widget detail;

  /// Seuil en dessous duquel les trois colonnes passent en empilement
  /// vertical — en dessous, l'affichage horizontal est illisible.
  static const double _stackThreshold = 700;

  const _ThreeColumnLayout({
    required this.chart,
    required this.list,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _stackThreshold) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: chart),
              const SizedBox(height: 16),
              list,
              const SizedBox(height: 16),
              detail,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: chart),
            const SizedBox(width: 16),
            Expanded(child: list),
            const SizedBox(width: 16),
            Expanded(child: detail),
          ],
        );
      },
    );
  }
}

/// Anneau donut de la diversification sectorielle, réduit à l'anneau seul
/// (sans légende intégrée — la liste des secteurs est dans la colonne
/// centrale [_SectorList]). Étend [AllocationDonutView] avec
/// `showLegend: false`.
class _SectorDonut extends StatelessWidget {
  final Map<Sector?, double> allocation;
  final double totalValue;
  final bool hidden;
  final ValueChanged<String?> onHoveredIdChanged;
  final ValueChanged<String> onSliceTap;

  const _SectorDonut({
    required this.allocation,
    required this.totalValue,
    required this.hidden,
    required this.onHoveredIdChanged,
    required this.onSliceTap,
  });

  String _idFor(Sector? sector) => sector?.name ?? _unclassifiedSelectionId;

  @override
  Widget build(BuildContext context) {
    final sorted = allocation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return AllocationDonutView(
      slices: [
        for (final entry in sorted)
          AllocationSlice(
            id: _idFor(entry.key),
            label:
                entry.key?.label ??
                AppLocalizations.of(context).analyses_unclassified,
            color: sectorColor(entry.key),
            percent: entry.value,
          ),
      ],
      total: totalValue,
      hidden: hidden,
      showLegend: false,
      onHoveredIdChanged: onHoveredIdChanged,
      onSliceTap: onSliceTap,
    );
  }
}

/// Liste « pastille de couleur · secteur · pourcentage » de la colonne
/// centrale de [_SectorDiversificationCard] — même structure que la légende
/// intégrée d'[AllocationDonutView] ([_Legend]), mais widget indépendant
/// avec survol/clic propres pour piloter la colonne de détail.
class _SectorList extends StatelessWidget {
  final List<MapEntry<Sector?, double>> entries;
  final String? selectedId;
  final ValueChanged<String?> onHoveredIdChanged;
  final ValueChanged<String> onTap;

  const _SectorList({
    required this.entries,
    required this.selectedId,
    required this.onHoveredIdChanged,
    required this.onTap,
  });

  String _idFor(Sector? sector) => sector?.name ?? _unclassifiedSelectionId;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onHoveredIdChanged(_idFor(entry.key)),
              onExit: (_) => onHoveredIdChanged(null),
              child: GestureDetector(
                onTap: () => onTap(_idFor(entry.key)),
                child: AnimatedOpacity(
                  duration: Duration.zero,
                  opacity: selectedId != null && selectedId != _idFor(entry.key)
                      ? 0.35
                      : 1.0,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: sectorColor(entry.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: shadcn.Text(
                          entry.key?.label ??
                              AppLocalizations.of(
                                context,
                              ).analyses_unclassified,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ).small(),
                      ),
                      const SizedBox(width: 6),
                      shadcn.Text(
                        entry.value < 1
                            ? '${entry.value.toStringAsFixed(2)} %'
                            : '${entry.value.toStringAsFixed(0)} %',
                      ).muted().xSmall(),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Colonne de droite des cartes de diversification (sous l'en-tête) :
/// affiche la liste des investissements correspondant à la sélection
/// (survol ou clic) ou un texte indicatif ("Survole ou clique ...") quand
/// rien n'est sélectionné. Réutilisée par la carte sectorielle et la
/// carte géographique pour éviter de dupliquer la présentation.
class _SelectionDetailColumn extends StatelessWidget {
  final String? title;
  final List<(Investment, double)> entries;
  final bool hidden;

  /// Texte indicatif affiché quand aucune sélection n'est active.
  final String dropHint;

  const _SelectionDetailColumn({
    this.title,
    required this.entries,
    required this.hidden,
    required this.dropHint,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => b.$2.compareTo(a.$2));
    if (title == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.muted.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: shadcn.Text(dropHint).muted().xSmall(),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shadcn.Text('$title (${sorted.length})').semiBold().small(),
          const SizedBox(height: 6),
          if (sorted.isEmpty)
            shadcn.Text(
              AppLocalizations.of(context).analyses_no_investments,
            ).muted().xSmall()
          else
            for (final (inv, contribution) in sorted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Flexible(
                      child: shadcn.Text(
                        inv.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ).small(),
                    ),
                    const SizedBox(width: 6),
                    shadcn.Text(
                      displayEuros(contribution, hidden),
                    ).muted().xSmall(),
                  ],
                ),
              ),
        ],
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
    final l10n = AppLocalizations.of(context);
    // En-têtes de colonne et leur explication au survol — construits ici
    // (plutôt qu'une `const Map` au niveau fichier comme auparavant) car ils
    // dépendent désormais de `l10n`, qui n'est disponible que dans un
    // `build`. Du plus courant/lisible au plus pointu — Skew et Omega sont
    // les moins familiers, en dernier.
    final riskReturnMetrics = [
      (
        header: l10n.analyses_risk_metric_volatility,
        tooltip: l10n.analyses_risk_metric_volatility_desc,
      ),
      (
        header: l10n.analyses_risk_metric_max_drawdown,
        tooltip: l10n.analyses_risk_metric_max_drawdown_desc,
      ),
      (
        header: l10n.analyses_risk_metric_sharpe,
        tooltip: l10n.analyses_risk_metric_sharpe_desc,
      ),
      (
        header: l10n.analyses_risk_metric_sortino,
        tooltip: l10n.analyses_risk_metric_sortino_desc,
      ),
      (
        header: l10n.analyses_risk_metric_beta,
        tooltip: l10n.analyses_risk_metric_beta_desc,
      ),
      (
        header: l10n.analyses_risk_metric_omega,
        tooltip: l10n.analyses_risk_metric_omega_desc,
      ),
      (
        header: l10n.analyses_risk_metric_skew,
        tooltip: l10n.analyses_risk_metric_skew_desc,
      ),
    ];
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(context, l10n.analyses_risk_return_title),
            const SizedBox(height: 4),
            shadcn.Text(l10n.analyses_risk_return_subtitle).muted().xSmall(),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: _riskReturnLabelWidth),
                      for (final metric in riskReturnMetrics)
                        SizedBox(
                          width: _riskReturnColumnWidth,
                          child: Tooltip(
                            tooltip: (context) => TooltipContainer(
                              child: SizedBox(
                                width: 260,
                                child: shadcn.Text(metric.tooltip),
                              ),
                            ),
                            child: shadcn.Text(metric.header).muted().xSmall(),
                          ),
                        ),
                    ],
                  ),
                  _RiskReturnRow(
                    label: l10n.analyses_whole_portfolio,
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
    final notCalculableLabel = AppLocalizations.of(
      context,
    ).analyses_not_calculable;
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
              _naOr(metric.volatility, _percent, notCalculableLabel),
            ).muted().small(),
          ),
          SizedBox(
            width: _riskReturnColumnWidth,
            child: shadcn.Text(
              _naOr(metric.maxDrawdown, _percent, notCalculableLabel),
            ).muted().small(),
          ),
          SizedBox(width: _riskReturnColumnWidth, child: ratio(metric.sharpe)),
          SizedBox(width: _riskReturnColumnWidth, child: ratio(metric.sortino)),
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
    final l10n = AppLocalizations.of(context);
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
    double? avgCorrelation;
    late final String avgCorrelationLabel;
    if (selected != null) {
      final usableInvestments = [
        for (final entry in selected.investmentReturns)
          if (entry.$2.length >= 3) entry,
      ];
      title = l10n.analyses_correlation_title_category(
        selected.assetClass.label,
      );
      avgCorrelationLabel = l10n.analyses_avg_correlation_within_category;
      if (usableInvestments.length < 2) {
        content = shadcn.Text(
          l10n.analyses_correlation_not_enough_investments,
        ).muted().small();
      } else {
        final series = [for (final entry in usableInvestments) entry.$2];
        avgCorrelation = averageCorrelation(series);
        content = CorrelationMatrix(
          labels: [for (final entry in usableInvestments) entry.$1],
          matrix: _matrixFor(series),
        );
      }
    } else {
      title = l10n.analyses_correlation_between_categories_title;
      avgCorrelationLabel = l10n.analyses_avg_correlation_between_categories;
      if (usableCategories.length < 2) {
        content = shadcn.Text(
          l10n.analyses_correlation_not_enough_categories,
        ).muted().small();
      } else {
        final series = [for (final c in usableCategories) c.returns];
        avgCorrelation = averageCorrelation(series);
        content = CorrelationMatrix(
          labels: [for (final c in usableCategories) c.assetClass.label],
          matrix: _matrixFor(series),
          onSelectLabel: (i) =>
              setState(() => _drilledInto = usableCategories[i].assetClass),
        );
      }
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
                _cardTitle(
                  context,
                  title,
                  tooltip: l10n.analyses_correlation_tooltip,
                ),
              ],
            ),
            if (avgCorrelation != null) ...[
              const SizedBox(height: 8),
              _StatChip(
                label: avgCorrelationLabel,
                value: avgCorrelation.toStringAsFixed(2),
              ),
            ],
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
String _formatPerformanceResult(
  PerformanceResult? result,
  AppLocalizations l10n,
) {
  if (result == null) return l10n.analyses_not_calculable;
  final percent = displayPercent(result.rate * 100);
  return result.annualized
      ? l10n.analyses_performance_per_year(percent)
      : l10n.analyses_performance_since_start(percent);
}

class _TriCard extends StatelessWidget {
  final List<_CategoryMetric> categories;
  final _TotalMetric total;
  const _TriCard({required this.categories, required this.total});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              context,
              l10n.analyses_tri_title,
              tooltip: l10n.analyses_tri_tooltip,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: shadcn.Text(
                      l10n.analyses_whole_portfolio,
                    ).semiBold(),
                  ),
                  shadcn.Text(
                    _formatPerformanceResult(total.tri, l10n),
                  ).muted().small(),
                ],
              ),
            ),
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: shadcn.Text(c.assetClass.label)),
                    shadcn.Text(
                      _formatPerformanceResult(c.tri, l10n),
                    ).muted().small(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Plus-value latente globale (aujourd'hui, indépendante de la période
/// sélectionnée — voir [_AnalysesMetrics.globalUnrealizedGain]) : ce que la
/// vente immédiate de tout le patrimoine rapporterait au-delà du coût
/// d'acquisition. Affichée auparavant sur la carte "Patrimoine" du
/// Dashboard (`real_patrimoine_card.dart`), déplacée ici pour garder cette
/// carte à sa présentation d'origine, plus sobre.
class _UnrealizedGainCard extends StatelessWidget {
  final double plusValueAbs;
  final double? plusValuePercent;
  final bool hidden;

  const _UnrealizedGainCard({
    required this.plusValueAbs,
    required this.plusValuePercent,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = plusValueAbs >= 0 ? _green : _red;
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _cardTitle(
              context,
              l10n.analyses_unrealized_gain_title,
              caption: l10n.analyses_today,
              tooltip: l10n.analyses_unrealized_gain_tooltip,
            ),
            const Spacer(),
            shadcn.Text(
              plusValuePercent == null
                  ? displaySignedEuros(plusValueAbs, hidden)
                  : '${displaySignedEuros(plusValueAbs, hidden)} '
                        '(${displayPercent(plusValuePercent!)})',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ).medium(),
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
    final l10n = AppLocalizations.of(context);
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
            _cardTitle(
              context,
              l10n.analyses_alpha_title,
              caption: l10n.analyses_stocks_funds_label,
              tooltip: l10n.analyses_alpha_tooltip,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    placeholder: shadcn.Text(
                      l10n.analyses_alpha_ticker_placeholder,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) => OutlineButton(
                    onPressed: () => _openBenchmarkPresetsMenu(context),
                    trailing: const Icon(LucideIcons.chevronDown, size: 14),
                    child: shadcn.Text(l10n.analyses_alpha_common_indices),
                  ),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  onPressed: widget.onSave,
                  child: shadcn.Text(l10n.common_save),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (ticker.isEmpty)
              shadcn.Text(l10n.analyses_alpha_no_ticker).muted().small()
            else if (!hasHistory)
              shadcn.Text(l10n.analyses_alpha_no_history).muted().small()
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: l10n.analyses_portfolio_label,
                      value: _formatPerformanceResult(
                        metrics.portfolioReturn,
                        l10n,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      label: ticker,
                      value: _formatPerformanceResult(
                        metrics.benchmarkReturn,
                        l10n,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      label: l10n.analyses_alpha_label,
                      value: _naOr(
                        metrics.alpha,
                        _percent,
                        l10n.analyses_not_calculable,
                      ),
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
    final l10n = AppLocalizations.of(context);
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              context,
              l10n.analyses_debt_leverage_title,
              caption: l10n.analyses_today,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _StatChip(
                  label: l10n.analyses_total_assets_label,
                  value: displayEuros(totalAssets, hidden),
                ),
                _StatChip(
                  label: l10n.analyses_total_liabilities_label,
                  value: displayEuros(totalLiabilities, hidden),
                ),
                _StatChip(
                  label: l10n.analyses_debt_ratio_assets_label,
                  value: _naOr(
                    debtRatioAssets,
                    _percent,
                    l10n.analyses_not_calculable,
                  ),
                  tooltip: l10n.analyses_debt_ratio_assets_tooltip,
                ),
                _StatChip(
                  label: l10n.analyses_debt_ratio_income_label,
                  value: debtRatioIncome == null
                      ? l10n.analyses_debt_ratio_income_missing
                      : _percent(debtRatioIncome!),
                  tooltip: l10n.analyses_debt_ratio_income_tooltip,
                ),
                _StatChip(
                  label: l10n.analyses_leverage_label,
                  value: _naOr(
                    leverage,
                    (v) => v.toStringAsFixed(2),
                    l10n.analyses_not_calculable,
                  ),
                  tooltip: l10n.analyses_leverage_tooltip,
                ),
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

  /// Bulle d'explication au survol du libellé, quand il n'est pas
  /// auto-explicite (ex : "Levier", "Taux d'endettement (actifs)") — même
  /// motif que les en-têtes de colonne de [_RiskReturnCard]. `null`
  /// (défaut) laisse le libellé nu, comme aujourd'hui.
  final String? tooltip;

  const _StatChip({required this.label, required this.value, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelText = shadcn.Text(label).muted().xSmall();
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
          tooltip == null
              ? labelText
              : Tooltip(
                  tooltip: (context) => TooltipContainer(
                    child: SizedBox(width: 240, child: shadcn.Text(tooltip!)),
                  ),
                  child: labelText,
                ),
          shadcn.Text(value).medium(),
        ],
      ),
    );
  }
}

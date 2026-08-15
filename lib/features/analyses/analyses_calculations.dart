import 'dart:math' as math;
import '../investments/investments_models.dart' show FundStyle, Investment, Transaction;
import '../investments/performance_calculator.dart'
    show PerformanceResult, calculateMwr;

/// TRI (XIRR) : délègue directement à [calculateMwr] (déjà éprouvé — Newton-
/// Raphson avec repli par bissection, voir `performance_calculator.dart`)
/// plutôt que de réimplémenter le calcul. [Transaction.amount] est toujours
/// déjà en euros (conversion de change déjà appliquée), donc concaténer les
/// transactions de plusieurs investissements/catégories dans
/// [allTransactions] est valide sans conversion supplémentaire.
PerformanceResult calculateTri({
  required List<Transaction> allTransactions,
  required double currentValue,
  required DateTime asOf,
}) => calculateMwr(
  transactions: allTransactions,
  currentValue: currentValue,
  asOf: asOf,
);

/// Rendements simples jour à jour (`v[i]/v[i-1] - 1`) à partir d'une série
/// de valorisations déjà sur une grille régulière (voir `dailyDateGrid` dans
/// `real_patrimoine_adapter.dart`). Un pas où la valorisation de départ est
/// nulle (pas encore d'exposition à la catégorie) est ignoré plutôt que de
/// produire un rendement infini/NaN.
List<double> dailyReturns(List<double> values) {
  final returns = <double>[];
  for (var i = 1; i < values.length; i++) {
    final previous = values[i - 1];
    if (previous == 0) continue;
    returns.add(values[i] / previous - 1);
  }
  return returns;
}

/// Rendement simple sur toute la période couverte par [series] (première à
/// dernière valeur) — `null` si moins de 2 points, ou si la première
/// valorisation est négative ou nulle (base non positive, même garde que
/// `changePercentFor` dans `patrimoine_chart_widgets.dart`).
double? periodReturn(List<double> series) {
  if (series.length < 2) return null;
  final first = series.first;
  if (first <= 0) return null;
  return (series.last - first) / first;
}

/// Annualise [totalReturn] sur [periodDays] jours — même convention que
/// `performance_calculator.dart`'s `_minAnnualizationDays` : en dessous
/// d'un an, retourne le rendement cumulé tel quel (l'annualiser
/// amplifierait de façon disproportionnée un gain/perte pourtant modeste
/// sur quelques jours) ; au-delà, extrapole à un an. `null` si
/// [totalReturn] est `null`.
double? annualizeReturn(double? totalReturn, int periodDays) {
  if (totalReturn == null) return null;
  if (periodDays < 365) return totalReturn;
  return math.pow(1 + totalReturn, 365 / periodDays) - 1.0;
}

/// Volatilité annualisée : écart-type (population, pas échantillon — la
/// série disponible est un historique complet et fini, pas un échantillon
/// tiré d'une distribution plus large) des rendements journaliers, mis à
/// l'échelle annuelle par `sqrt(tradingDaysPerYear)`. `null` en dessous de 3
/// valorisations utilisables (moins de 2 rendements), seuil sous lequel un
/// écart-type n'a pas de sens statistique.
double? annualizedVolatility(
  List<double> returns, {
  int tradingDaysPerYear = 365,
}) {
  if (returns.length < 2) return null;
  final mean = returns.reduce((a, b) => a + b) / returns.length;
  final variance =
      returns.map((r) => (r - mean) * (r - mean)).reduce((a, b) => a + b) /
      returns.length;
  return math.sqrt(variance) * math.sqrt(tradingDaysPerYear.toDouble());
}

/// Corrélation de Pearson entre deux séries de rendements déjà alignées
/// index à index par l'appelant (mêmes dates, voir `dailyDateGrid`). `null`
/// en dessous de 3 points communs, ou si l'une des deux séries a un
/// écart-type nul — une catégorie totalement plate sur la période a une
/// corrélation mathématiquement indéfinie, pas nulle : cette distinction est
/// volontaire, `0` impliquerait à tort "aucune relation" plutôt que "pas
/// assez de mouvement pour la mesurer".
double? pearsonCorrelation(List<double> a, List<double> b) {
  final n = math.min(a.length, b.length);
  if (n < 3) return null;
  final meanA = a.take(n).reduce((x, y) => x + y) / n;
  final meanB = b.take(n).reduce((x, y) => x + y) / n;
  var covariance = 0.0;
  var varianceA = 0.0;
  var varianceB = 0.0;
  for (var i = 0; i < n; i++) {
    final da = a[i] - meanA;
    final db = b[i] - meanB;
    covariance += da * db;
    varianceA += da * da;
    varianceB += db * db;
  }
  if (varianceA == 0 || varianceB == 0) return null;
  return covariance / math.sqrt(varianceA * varianceB);
}

/// Ratio rendement/risque type Sharpe, **sans taux sans risque soustrait**
/// (rendement annualisé brut / volatilité annualisée) : l'app n'a aucune
/// source fiable de taux sans risque (pas d'API macro), et en coder un en
/// dur (ex : taux OAT 10 ans figé) serait trompeur et vite périmé. `null` si
/// l'un des deux termes est `null`, ou si la volatilité est nulle (division
/// par zéro).
double? riskReturnRatio({
  required double? annualReturn,
  required double? volatility,
}) {
  if (annualReturn == null || volatility == null || volatility == 0) {
    return null;
  }
  return annualReturn / volatility;
}

/// Alpha vs benchmark = rendement excédentaire simple (différence des
/// rendements annualisés du portefeuille/de la catégorie et du benchmark
/// sur la MÊME période calendaire) — **pas** une régression bêta/alpha à la
/// Jensen : un OLS a besoin d'un échantillon de rendements dense et peu
/// bruité pour être stable, alors qu'un patrimoine réel a des séries
/// courtes et irrégulières (peu de flux réels) — la version simple est plus
/// robuste et plus lisible, sans fausse précision. `null` si l'un des deux
/// rendements est `null`.
double? simpleAlpha({
  required double? portfolioAnnualReturn,
  required double? benchmarkAnnualReturn,
}) {
  if (portfolioAnnualReturn == null || benchmarkAnnualReturn == null) {
    return null;
  }
  return portfolioAnnualReturn - benchmarkAnnualReturn;
}

/// Taux d'endettement (actifs) = dette totale / actifs totaux. `null` si
/// [totalAssets] est nul (non calculable, plutôt que 0/0 ou une division
/// par zéro silencieuse) — toujours calculable sinon, y compris à 0 si
/// aucun passif.
double? debtRatioAssets({
  required double totalLiabilities,
  required double totalAssets,
}) {
  if (totalAssets == 0) return null;
  return totalLiabilities / totalAssets;
}

/// Taux d'endettement (revenus) = mensualités de crédit / revenus mensuels.
/// `null` si [monthlyIncome] est nul — l'appelant doit déjà avoir vérifié
/// que des revenus du mois sont renseignés (voir
/// `BudgetTrackingMonth.totalRevenuesRealite`) avant d'appeler.
double? debtRatioIncome({
  required double monthlyInstallments,
  required double monthlyIncome,
}) {
  if (monthlyIncome == 0) return null;
  return monthlyInstallments / monthlyIncome;
}

/// Levier = actifs totaux / patrimoine net. `null` si [netWorth] est nul ou
/// négatif — un patrimoine net négatif ou nul rend le ratio non
/// interprétable comme un "levier" classique (l'endettement dépasse ou
/// égale les actifs) : retourner une valeur brute serait trompeur.
double? leverage({required double totalAssets, required double netWorth}) {
  if (netWorth <= 0) return null;
  return totalAssets / netWorth;
}

/// Répartition de la valeur des investissements `actionsEtFonds` (seule
/// classe où [FundStyle] a un sens) par style de gestion, en pourcentage de
/// la valeur totale — la clé `null` regroupe les investissements non
/// classés. Les pourcentages somment à 100 par construction. Un
/// investissement sans valorisation connue ([valueOf] ≤ 0) est ignoré : il
/// ne contribue à aucun style ni au total.
Map<FundStyle?, double> fundStyleAllocation(
  List<Investment> equityInvestments, {
  required double Function(Investment) valueOf,
}) {
  final totalsByStyle = <FundStyle?, double>{};
  var total = 0.0;
  for (final investment in equityInvestments) {
    final value = valueOf(investment);
    if (value <= 0) continue;
    totalsByStyle[investment.fundStyle] =
        (totalsByStyle[investment.fundStyle] ?? 0) + value;
    total += value;
  }
  if (total == 0) return {};
  return {
    for (final entry in totalsByStyle.entries) entry.key: entry.value / total * 100,
  };
}

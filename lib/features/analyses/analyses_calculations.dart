import 'dart:math' as math;
import '../dashboard/patrimoine_models.dart' show NetWorthPoint;
import '../investments/investments_models.dart'
    show FundStyle, Investment, Sector, Transaction;
import '../investments/performance_calculator.dart'
    show PerformanceResult, calculateMwr;
import '../investments/real_patrimoine_adapter.dart' show priceAt;
import '../investments/yahoo_finance_client.dart' show PricePoint;

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

/// Perte maximale (drawdown) : le pire creux, en %, entre un plus haut et
/// le point le plus bas qui l'a suivi, sur toute la série de valorisations
/// — pas seulement premier vs dernier point ([periodReturn]), qui raterait
/// une chute intermédiaire suivie d'une reprise. Valeur négative ou nulle
/// (`0` : jamais redescendu sous un plus haut précédent) ; `null` en
/// dessous de 2 points.
double? maxDrawdown(List<double> series) {
  if (series.length < 2) return null;
  var peak = series.first;
  var worst = 0.0;
  for (final value in series) {
    if (value > peak) peak = value;
    if (peak <= 0) continue;
    final drawdown = (value - peak) / peak;
    if (drawdown < worst) worst = drawdown;
  }
  return worst;
}

/// Écart-type annualisé des seuls rendements en dessous de [target]
/// (0 par défaut) — les rendements positifs comptent pour zéro plutôt que
/// d'atténuer la mesure : contrairement à [annualizedVolatility], qui
/// pénalise à égalité une hausse et une baisse, ceci ne mesure que le
/// risque de perte réellement redouté (base de [sortinoRatio]). Même
/// convention de mise à l'échelle et le même seuil minimal de points que
/// [annualizedVolatility].
double? downsideDeviation(
  List<double> returns, {
  double target = 0,
  int tradingDaysPerYear = 365,
}) {
  if (returns.length < 2) return null;
  final sumSquaredShortfall = returns.fold<double>(
    0,
    (sum, r) => sum + (r < target ? (r - target) * (r - target) : 0),
  );
  return math.sqrt(sumSquaredShortfall / returns.length) *
      math.sqrt(tradingDaysPerYear.toDouble());
}

/// Ratio de Sortino : comme [riskReturnRatio] (Sharpe sans taux sans
/// risque), mais rapporté au risque de perte seul ([downsideDeviation])
/// plutôt qu'à la volatilité totale — un investissement volatil à la
/// hausse mais stable à la baisse y ressort mieux qu'au Sharpe, qui le
/// pénaliserait pour une volatilité qui n'est pourtant jamais allée dans
/// le mauvais sens.
double? sortinoRatio({
  required double? annualReturn,
  required double? downsideDeviation,
}) => riskReturnRatio(annualReturn: annualReturn, volatility: downsideDeviation);

/// Asymétrie (skewness) de la distribution des rendements journaliers —
/// troisième moment standardisé. Positive : les surprises à la hausse sont
/// plus extrêmes que les baisses (queue étalée à droite) ; négative :
/// l'inverse, des baisses ponctuelles plus violentes que les hausses,
/// souvent perçu comme le risque le plus redouté même à volatilité totale
/// égale. `null` en dessous de 3 points, ou si l'écart-type est nul (série
/// plate, asymétrie indéfinie).
double? skewness(List<double> returns) {
  if (returns.length < 3) return null;
  final n = returns.length;
  final mean = returns.reduce((a, b) => a + b) / n;
  final variance =
      returns.map((r) => (r - mean) * (r - mean)).reduce((a, b) => a + b) / n;
  final std = math.sqrt(variance);
  if (std == 0) return null;
  final thirdMoment =
      returns.map((r) => math.pow(r - mean, 3)).reduce((a, b) => a + b) / n;
  return thirdMoment / math.pow(std, 3);
}

/// Ratio Omega à [threshold] (0 par défaut) : somme des gains journaliers
/// au-dessus du seuil, divisée par la somme des pertes en dessous —
/// contrairement à Sharpe/Sortino (qui ne regardent que moyenne et
/// écart-type, en supposant implicitement une distribution symétrique),
/// utilise toute la distribution des rendements telle quelle. > 1 : les
/// gains l'emportent sur les pertes. `null` en dessous de 2 points, ou
/// sans aucune perte sous le seuil (ratio non borné, pas de division par
/// zéro plutôt qu'un "infini" trompeur).
double? omegaRatio(List<double> returns, {double threshold = 0}) {
  if (returns.length < 2) return null;
  var gains = 0.0;
  var losses = 0.0;
  for (final r in returns) {
    if (r > threshold) {
      gains += r - threshold;
    } else if (r < threshold) {
      losses += threshold - r;
    }
  }
  if (losses == 0) return null;
  return gains / losses;
}

/// Bêta face à un indice de référence : covariance des rendements avec le
/// benchmark, divisée par la variance du benchmark — la sensibilité du
/// portefeuille/de la catégorie aux mouvements du benchmark (1 : bouge
/// comme lui, > 1 : amplifie ses mouvements, < 1 : les amortit, négatif :
/// évolue à l'inverse). [returns] et [benchmarkReturns] doivent déjà être
/// alignés jour à jour par l'appelant (même grille de dates, voir
/// `dailyDateGrid` dans `real_patrimoine_adapter.dart`) — comme
/// [pearsonCorrelation], dont le calcul de covariance est ici repris.
/// `null` en dessous de 3 points communs, ou si le benchmark n'a montré
/// aucune variation (variance nulle, bêta indéfini).
double? beta(List<double> returns, List<double> benchmarkReturns) {
  final n = math.min(returns.length, benchmarkReturns.length);
  if (n < 3) return null;
  final mean = returns.take(n).reduce((a, b) => a + b) / n;
  final benchmarkMean = benchmarkReturns.take(n).reduce((a, b) => a + b) / n;
  var covariance = 0.0;
  var benchmarkVariance = 0.0;
  for (var i = 0; i < n; i++) {
    final d = returns[i] - mean;
    final db = benchmarkReturns[i] - benchmarkMean;
    covariance += d * db;
    benchmarkVariance += db * db;
  }
  if (benchmarkVariance == 0) return null;
  return covariance / benchmarkVariance;
}

/// Rendements journaliers du benchmark sur [grid] — même méthode que
/// [dailyReturns], à partir de son historique de cours échantillonné jour
/// par jour (voir [priceAt], qui prolonge le plus ancien cours connu vers
/// le passé plutôt que d'échouer sur une date antérieure au premier point
/// connu). Liste vide sans historique de benchmark exploitable — [beta]
/// renverra alors `null` faute de points communs.
List<double> benchmarkReturnsOnGrid(
  List<PricePoint> benchmarkHistory,
  List<DateTime> grid,
) {
  if (benchmarkHistory.isEmpty) return [];
  final series = [for (final date in grid) priceAt(benchmarkHistory, date)!];
  return dailyReturns(series);
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

/// Corrélation moyenne d'un groupe d'actifs (catégories, ou investissements
/// au sein d'une catégorie) — moyenne des corrélations de paires distinctes
/// (la diagonale, toujours 1, et chaque paire en double par symétrie de la
/// matrice, sont exclues), ignorant les paires sans corrélation calculable
/// (voir [pearsonCorrelation]). Un résumé à un seul chiffre de la
/// diversification du groupe : proche de 0 (ou négatif) = bien diversifié,
/// proche de 1 = les actifs bougent quasiment tous ensemble, ce qui réduit
/// l'effet de diversification malgré leur nombre. `null` sans aucune paire
/// calculable (moins de 2 actifs, ou toutes les paires indéfinies).
double? averageCorrelation(List<List<double>> series) {
  var sum = 0.0;
  var count = 0;
  for (var i = 0; i < series.length; i++) {
    for (var j = i + 1; j < series.length; j++) {
      final correlation = pearsonCorrelation(series[i], series[j]);
      if (correlation == null) continue;
      sum += correlation;
      count++;
    }
  }
  return count == 0 ? null : sum / count;
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

/// MWR sur [start, today] : la valeur de la catégorie en tout début de
/// période ([valuationAtStart]) traitée comme un premier flux, suivie des
/// flux réels survenus depuis ([flowsAfterStart]) — même modèle que le
/// rendement money-weighted "période courte" de [calculateMwr], amorcé par
/// une valeur de départ plutôt que par zéro (même principe que
/// `real_patrimoine_adapter.dart`'s `_positionReturnForPeriod`, à l'échelle
/// d'une catégorie entière plutôt que d'une position). `null` sans aucun
/// flux (ni valeur de départ, ni transaction dans la période).
PerformanceResult? periodMwr({
  required DateTime start,
  required DateTime today,
  required double valuationAtStart,
  required List<Transaction> flowsAfterStart,
  required double currentValue,
}) {
  final flows = <Transaction>[
    if (valuationAtStart > 0)
      Transaction(
        date: start,
        isBuy: true,
        quantity: 1,
        unitPrice: valuationAtStart,
      ),
    ...flowsAfterStart,
  ];
  if (flows.isEmpty) return null;
  return calculateMwr(
    transactions: flows,
    currentValue: currentValue,
    asOf: today,
  );
}

/// Le MWR qu'aurait produit [benchmarkHistory] si les MÊMES flux
/// ([valuationAtStart] + [flowsAfterStart], mêmes dates et montants) avaient
/// été investis dans le benchmark au lieu du portefeuille réel — chaque
/// montant est converti en "parts" notionnelles du benchmark au cours du
/// jour (voir [priceAt], qui prolonge le plus ancien cours connu vers le
/// passé plutôt que d'échouer), pour comparer un vrai MWR à un MWR
/// équivalent plutôt que deux rendements simples qui supposeraient, à tort,
/// un capital investi à 100 % dès [start] des deux côtés (voir
/// `analyses_screen.dart`'s calcul d'alpha, seul appelant). `null` sans
/// historique de benchmark exploitable aux deux bornes de la période.
PerformanceResult? benchmarkEquivalentMwr({
  required DateTime start,
  required DateTime today,
  required double valuationAtStart,
  required List<Transaction> flowsAfterStart,
  required List<PricePoint> benchmarkHistory,
}) {
  if (benchmarkHistory.isEmpty) return null;
  final benchmarkAtStart = priceAt(benchmarkHistory, start);
  final benchmarkToday = priceAt(benchmarkHistory, today);
  if (benchmarkAtStart == null ||
      benchmarkAtStart <= 0 ||
      benchmarkToday == null) {
    return null;
  }
  var netShares = 0.0;
  final synthetic = <Transaction>[];
  if (valuationAtStart > 0) {
    final shares = valuationAtStart / benchmarkAtStart;
    netShares += shares;
    synthetic.add(
      Transaction(
        date: start,
        isBuy: true,
        quantity: shares,
        unitPrice: benchmarkAtStart,
      ),
    );
  }
  for (final t in flowsAfterStart) {
    final price = priceAt(benchmarkHistory, t.date) ?? benchmarkAtStart;
    if (price <= 0) continue;
    final shares = t.amount / price;
    netShares += t.isBuy ? shares : -shares;
    synthetic.add(
      Transaction(date: t.date, isBuy: t.isBuy, quantity: shares, unitPrice: price),
    );
  }
  if (synthetic.isEmpty) return null;
  return calculateMwr(
    transactions: synthetic,
    currentValue: netShares * benchmarkToday,
    asOf: today,
  );
}

/// La contrepartie de [benchmarkEquivalentMwr] sous forme de courbe plutôt
/// que d'un seul chiffre final : la valeur, à CHAQUE date de [grid], de ce
/// que les mêmes flux réels ([valuationAtStart] + [flowsAfterStart])
/// auraient donné investis dans le benchmark au lieu du portefeuille réel
/// — pour tracer la comparaison visuelle à côté de la vraie courbe de
/// valorisation ([categoryHistoryOnGrid] dans `real_patrimoine_adapter.
/// dart`). `grid.first` doit être la même date que le `start` de
/// [benchmarkEquivalentMwr] : les deux courbes partent alors du même point
/// ([valuationAtStart]), par construction, et ne divergent qu'ensuite —
/// exactement ce que l'alpha mesure. Liste vide sans historique de
/// benchmark exploitable au premier point.
List<NetWorthPoint> benchmarkEquivalentValueSeries({
  required List<DateTime> grid,
  required double valuationAtStart,
  required List<Transaction> flowsAfterStart,
  required List<PricePoint> benchmarkHistory,
}) {
  if (grid.isEmpty || benchmarkHistory.isEmpty) return [];
  final start = grid.first;
  final benchmarkAtStart = priceAt(benchmarkHistory, start);
  if (benchmarkAtStart == null || benchmarkAtStart <= 0) return [];

  // Parts notionnelles acquises à chaque flux (position de départ
  // comprise), à cumuler jusqu'à chaque date de [grid] — même conversion
  // "montant réel ÷ cours du benchmark au jour du flux" que
  // [benchmarkEquivalentMwr].
  final shareEvents = <(DateTime date, double shares)>[
    if (valuationAtStart > 0) (start, valuationAtStart / benchmarkAtStart),
  ];
  for (final t in flowsAfterStart) {
    final price = priceAt(benchmarkHistory, t.date) ?? benchmarkAtStart;
    if (price <= 0) continue;
    final shares = t.amount / price;
    shareEvents.add((t.date, t.isBuy ? shares : -shares));
  }

  return [
    for (final date in grid)
      NetWorthPoint(date, _sharesValueAt(date, shareEvents, benchmarkHistory, benchmarkAtStart)),
  ];
}

double _sharesValueAt(
  DateTime date,
  List<(DateTime date, double shares)> shareEvents,
  List<PricePoint> benchmarkHistory,
  double benchmarkAtStart,
) {
  var netShares = 0.0;
  for (final event in shareEvents) {
    if (!event.$1.isAfter(date)) netShares += event.$2;
  }
  final price = priceAt(benchmarkHistory, date) ?? benchmarkAtStart;
  return netShares * price;
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

/// Répartition de la valeur des investissements `actionsEtFonds` par
/// secteur d'activité — même principe que [fundStyleAllocation] (clé
/// `null` = non classé, pourcentages sommant à 100, un investissement sans
/// valorisation connue est ignoré).
///
/// Un investissement dont [Investment.sectorBreakdown] est renseigné (ETF
/// multi-secteurs) ventile sa valeur sur chacune des entrées de la
/// répartition (`value * entry.percent / 100`) plutôt que de compter en
/// bloc pour un seul secteur ; la part non couverte par la répartition
/// (`100 - somme des percent`, plancher à 0) tombe dans le seau "non
/// classé", comme un investissement sans [Investment.sector] du tout.
Map<Sector?, double> sectorAllocation(
  List<Investment> equityInvestments, {
  required double Function(Investment) valueOf,
}) {
  final totalsBySector = <Sector?, double>{};
  var total = 0.0;
  for (final investment in equityInvestments) {
    final value = valueOf(investment);
    if (value <= 0) continue;
    if (investment.sectorBreakdown.isNotEmpty) {
      var coveredPercent = 0.0;
      for (final weight in investment.sectorBreakdown) {
        final share = value * weight.percent / 100;
        totalsBySector[weight.sector] = (totalsBySector[weight.sector] ?? 0) + share;
        coveredPercent += weight.percent;
      }
      final remainder = value * (100 - coveredPercent).clamp(0, 100) / 100;
      if (remainder > 0) {
        totalsBySector[null] = (totalsBySector[null] ?? 0) + remainder;
      }
    } else {
      totalsBySector[investment.sector] =
          (totalsBySector[investment.sector] ?? 0) + value;
    }
    total += value;
  }
  if (total == 0) return {};
  return {
    for (final entry in totalsBySector.entries)
      entry.key: entry.value / total * 100,
  };
}

/// Répartition de la valeur des investissements `actionsEtFonds` par pays
/// (code ISO 3166-1 alpha-2) — même principe que [fundStyleAllocation] (clé
/// `null` = non classé, pourcentages sommant à 100, un investissement sans
/// valorisation connue est ignoré).
///
/// Même ventilation pondérée que [sectorAllocation] quand
/// [Investment.countryBreakdown] est renseigné (ETF multi-pays) — voir sa
/// doc pour le détail du calcul et du reliquat "non classé".
Map<String?, double> countryAllocation(
  List<Investment> equityInvestments, {
  required double Function(Investment) valueOf,
}) {
  final totalsByCountry = <String?, double>{};
  var total = 0.0;
  for (final investment in equityInvestments) {
    final value = valueOf(investment);
    if (value <= 0) continue;
    if (investment.countryBreakdown.isNotEmpty) {
      var coveredPercent = 0.0;
      for (final weight in investment.countryBreakdown) {
        final share = value * weight.percent / 100;
        totalsByCountry[weight.countryCode] =
            (totalsByCountry[weight.countryCode] ?? 0) + share;
        coveredPercent += weight.percent;
      }
      final remainder = value * (100 - coveredPercent).clamp(0, 100) / 100;
      if (remainder > 0) {
        totalsByCountry[null] = (totalsByCountry[null] ?? 0) + remainder;
      }
    } else {
      totalsByCountry[investment.countryCode] =
          (totalsByCountry[investment.countryCode] ?? 0) + value;
    }
    total += value;
  }
  if (total == 0) return {};
  return {
    for (final entry in totalsByCountry.entries)
      entry.key: entry.value / total * 100,
  };
}

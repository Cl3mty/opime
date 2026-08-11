import 'dart:math' as math;
import 'investments_models.dart';
import 'yahoo_finance_client.dart';

/// En dessous d'un an de détention, annualiser un rendement (l'élever à la
/// puissance `365 / joursDétenus`) amplifie de façon disproportionnée un
/// gain ou une perte pourtant modeste — quelques points de pourcentage sur
/// quelques jours donnent des taux "annuels" absurdes (des milliers de
/// pourcents). En dessous de ce seuil, [calculateMwr]/[calculateTwr]
/// retournent donc le rendement cumulé sur la période réellement écoulée
/// (non annualisé) plutôt que de l'extrapoler sur un an — voir
/// [PerformanceResult.annualized].
const _minAnnualizationDays = 365;

/// Résultat d'un calcul de performance : [rate] est soit un taux annualisé
/// ([annualized] `true`, période de détention ≥ 1 an), soit le rendement
/// cumulé brut sur la période réellement écoulée ([annualized] `false`,
/// période plus courte) — l'UI doit adapter son libellé ("X % / an" vs.
/// "X % depuis le début") en fonction de ce indicateur.
typedef PerformanceResult = ({double rate, bool annualized});

/// Rendement Money-Weighted (MWR / XIRR) : le taux annualisé qui annule la
/// valeur actuelle nette de tous les flux de trésorerie (achats = flux
/// sortants, ventes = flux entrants, valorisation actuelle = flux entrant
/// final) — reflète le rendement réellement perçu, compte tenu du montant
/// et du moment de chaque apport. Résolu par Newton-Raphson avec repli par
/// bissection s'il ne converge pas (méthode standard pour l'XIRR).
PerformanceResult calculateMwr({
  required List<Transaction> transactions,
  required double currentValue,
  required DateTime asOf,
}) {
  if (transactions.isEmpty) return (rate: 0, annualized: false);
  final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
  final t0 = sorted.first.date;

  if (asOf.difference(t0).inDays < _minAnnualizationDays) {
    final netInvested = sorted.fold<double>(
      0,
      (sum, t) => sum + (t.isBuy ? t.amount : -t.amount),
    );
    if (netInvested == 0) return (rate: 0, annualized: false);
    return (
      rate: (currentValue - netInvested) / netInvested,
      annualized: false,
    );
  }

  final flows = <(double amount, double years)>[
    for (final t in sorted)
      (t.isBuy ? -t.amount : t.amount, t.date.difference(t0).inDays / 365.0),
    (currentValue, asOf.difference(t0).inDays / 365.0),
  ];

  double npv(double r) {
    var sum = 0.0;
    for (final (amount, years) in flows) {
      sum += amount / math.pow(1 + r, years);
    }
    return sum;
  }

  double npvDerivative(double r) {
    var sum = 0.0;
    for (final (amount, years) in flows) {
      if (years == 0) continue;
      sum += -years * amount / math.pow(1 + r, years + 1);
    }
    return sum;
  }

  var r = 0.1;
  for (var i = 0; i < 100; i++) {
    final derivative = npvDerivative(r);
    if (derivative.abs() < 1e-12) break;
    final nextR = (r - npv(r) / derivative).clamp(-0.999999, 100.0);
    if ((nextR - r).abs() < 1e-8) return (rate: nextR, annualized: true);
    r = nextR;
  }
  if (npv(r).abs() < 1e-4) return (rate: r, annualized: true);

  // Newton-Raphson n'a pas convergé (cas rares avec des flux atypiques) :
  // repli par bissection, en supposant que le signe de la NPV change entre
  // -99,9 % et +1000 % de rendement (vrai pour des flux réalistes).
  var lower = -0.999;
  var upper = 10.0;
  var lowerValue = npv(lower);
  if (lowerValue.sign == npv(upper).sign) return (rate: 0, annualized: true);
  for (var i = 0; i < 200; i++) {
    final mid = (lower + upper) / 2;
    final midValue = npv(mid);
    if (midValue.abs() < 1e-6) return (rate: mid, annualized: true);
    if (midValue.sign == lowerValue.sign) {
      lower = mid;
      lowerValue = midValue;
    } else {
      upper = mid;
    }
  }
  return (rate: (lower + upper) / 2, annualized: true);
}

/// Rendement Time-Weighted (TWR) : neutralise l'effet des apports/retraits
/// en découpant la période en sous-périodes à chaque transaction, valorisée
/// via l'historique de cours, et en chaînant géométriquement les
/// rendements de chaque sous-période — reflète la performance de l'actif
/// lui-même, indépendamment du moment où l'utilisateur a investi. Retourne
/// `null` si l'historique de cours ne couvre pas le début de la période
/// (pas assez de données pour un calcul fiable).
PerformanceResult? calculateTwr({
  required List<Transaction> transactions,
  required List<PricePoint> priceHistory,
  required double currentValue,
  required DateTime asOf,
}) {
  if (transactions.isEmpty || priceHistory.isEmpty) return null;

  final byDate = <DateTime, List<Transaction>>{};
  for (final t in transactions) {
    final day = DateTime.utc(t.date.year, t.date.month, t.date.day);
    byDate.putIfAbsent(day, () => []).add(t);
  }
  final dates = byDate.keys.toList()..sort();

  final sortedPrices = [...priceHistory]
    ..sort((a, b) => a.date.compareTo(b.date));
  if (sortedPrices.first.date.isAfter(dates.first)) return null;

  double priceAt(DateTime date) {
    PricePoint? best;
    for (final point in sortedPrices) {
      if (point.date.isAfter(date)) break;
      best = point;
    }
    return (best ?? sortedPrices.first).close;
  }

  var quantity = 0.0;
  var chainedReturn = 1.0;
  double? valueAfterPreviousFlow;

  for (final date in dates) {
    final valueBeforeFlow = quantity * priceAt(date);
    if (valueAfterPreviousFlow != null && valueAfterPreviousFlow > 0) {
      chainedReturn *= valueBeforeFlow / valueAfterPreviousFlow;
    }
    var netFlow = 0.0;
    for (final t in byDate[date]!) {
      quantity += t.isBuy ? t.quantity : -t.quantity;
      netFlow += t.isBuy ? t.amount : -t.amount;
    }
    valueAfterPreviousFlow = valueBeforeFlow + netFlow;
  }

  // Dernière sous-période, de la dernière transaction à aujourd'hui —
  // valorisée avec le montant réel affiché à l'écran plutôt qu'un
  // recalcul via le cours, pour rester cohérent.
  if (valueAfterPreviousFlow != null && valueAfterPreviousFlow > 0) {
    chainedReturn *= currentValue / valueAfterPreviousFlow;
  }

  final totalReturn = chainedReturn - 1;
  final totalDays = asOf.difference(dates.first).inDays;
  if (totalDays < _minAnnualizationDays) {
    return (rate: totalReturn, annualized: false);
  }
  return (
    rate: math.pow(1 + totalReturn, 365 / totalDays) - 1.0,
    annualized: true,
  );
}

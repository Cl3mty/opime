import 'dart:math' as math;

import '../dashboard/patrimoine_models.dart' show NetWorthPoint;

/// Durée moyenne d'un mois grégorien, en jours — sert à convertir un nombre
/// de jours écoulés en nombre de mois (continu, pas arrondi) pour la
/// capitalisation des versements mensuels ci-dessous.
const _daysPerMonth = 30.436875;

/// Projette la valeur nette actuelle d'un projet jusqu'à son échéance : la
/// valeur de départ capitalise en croissance composée annuelle au taux
/// [rendementAttenduPercent] (`Project.rendementAttendu`), à laquelle
/// s'ajoute la valeur future des versements mensuels réguliers
/// [apportMensuelEur] (`Project.apportMensuel`, `0` par défaut — dans ce
/// cas la trajectoire ne dépend que de la valeur de départ, comme avant
/// l'introduction du champ). Le taux mensuel utilisé pour les versements
/// est le taux équivalent au taux annuel composé (pas une simple division
/// par 12), pour rester cohérent avec la capitalisation de la valeur de
/// départ. Un point par année entre [today] et [echeance] (toujours au
/// moins 2 points, y compris sur moins d'un an, pour rester traçable par
/// [NetWorthChart]).
List<NetWorthPoint> computeProjectTrajectory({
  required double currentValue,
  required double rendementAttenduPercent,
  required DateTime today,
  required DateTime echeance,
  double apportMensuelEur = 0,
}) {
  if (!echeance.isAfter(today)) {
    return [
      NetWorthPoint(today, currentValue),
      NetWorthPoint(echeance, currentValue),
    ];
  }
  final totalDays = echeance.difference(today).inDays;
  final years = (totalDays / 365).ceil().clamp(1, 100);
  final rate = rendementAttenduPercent / 100;
  // Taux mensuel équivalent au taux annuel composé (et non rate / 12, une
  // approximation "linéaire" moins exacte) : (1+rate)^(1/12) - 1.
  final monthlyRate = math.pow(1 + rate, 1 / 12) - 1;
  return [
    for (var i = 0; i <= years; i++)
      NetWorthPoint(
        i == years
            ? echeance
            : today.add(Duration(days: (totalDays * i / years).round())),
        _projectedValue(
          currentValue: currentValue,
          apportMensuelEur: apportMensuelEur,
          rate: rate,
          monthlyRate: monthlyRate,
          days: totalDays * i / years,
        ),
      ),
  ];
}

/// Valeur projetée après [days] jours : capitalisation composée de
/// [currentValue] + valeur future des versements mensuels [apportMensuelEur]
/// (formule des annuités, mois traité comme une variable continue —
/// `days / 30.44` — pour rester cohérent avec la capitalisation continue de
/// la valeur de départ plutôt que de sauter par paliers mensuels discrets).
double _projectedValue({
  required double currentValue,
  required double apportMensuelEur,
  required double rate,
  required num monthlyRate,
  required double days,
}) {
  final principal = currentValue * math.pow(1 + rate, days / 365);
  if (apportMensuelEur == 0) return principal;
  final months = days / _daysPerMonth;
  final contributions = monthlyRate == 0
      ? apportMensuelEur * months
      : apportMensuelEur *
            ((math.pow(1 + monthlyRate, months) - 1) / monthlyRate);
  return principal + contributions;
}

/// `true`/`false` si la trajectoire projetée (à [rendementAttenduPercent] et
/// [apportMensuelEur] constants, voir [computeProjectTrajectory]) atteint ou
/// dépasse [montantCible] à l'échéance — pour le badge "En bonne voie"/"En
/// retard" des cartes de projet. `null` sans montant cible (rien à
/// comparer, voir `Project.montantCible`).
bool? isProjectOnTrack({
  required double currentValue,
  required double rendementAttenduPercent,
  required double? montantCible,
  required DateTime today,
  required DateTime echeance,
  double apportMensuelEur = 0,
}) {
  if (montantCible == null) return null;
  final trajectory = computeProjectTrajectory(
    currentValue: currentValue,
    rendementAttenduPercent: rendementAttenduPercent,
    today: today,
    echeance: echeance,
    apportMensuelEur: apportMensuelEur,
  );
  return trajectory.last.value >= montantCible;
}

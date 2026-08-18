import 'dart:math' as math;

import '../dashboard/patrimoine_models.dart' show NetWorthPoint;

/// Projette la valeur nette actuelle d'un projet jusqu'à son échéance, en
/// appliquant une croissance composée annuelle au taux
/// [rendementAttenduPercent] (le champ `Project.rendementAttendu` déjà
/// saisi par l'utilisateur) — une estimation volontairement simple : le
/// modèle n'a pas aujourd'hui de champ de versement récurrent à intégrer,
/// seule la valeur de départ capitalise. Un point par année entre
/// [today] et [echeance] (toujours au moins 2 points, y compris sur moins
/// d'un an, pour rester traçable par [NetWorthChart]).
List<NetWorthPoint> computeProjectTrajectory({
  required double currentValue,
  required double rendementAttenduPercent,
  required DateTime today,
  required DateTime echeance,
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
  return [
    for (var i = 0; i <= years; i++)
      NetWorthPoint(
        i == years
            ? echeance
            : today.add(Duration(days: (totalDays * i / years).round())),
        currentValue * math.pow(1 + rate, totalDays * i / years / 365),
      ),
  ];
}

/// `true`/`false` si la trajectoire projetée (à [rendementAttenduPercent]
/// constant, voir [computeProjectTrajectory]) atteint ou dépasse
/// [montantCible] à l'échéance — pour le badge "En bonne voie"/"En retard"
/// des cartes de projet. `null` sans montant cible (rien à comparer, voir
/// `Project.montantCible`).
bool? isProjectOnTrack({
  required double currentValue,
  required double rendementAttenduPercent,
  required double? montantCible,
  required DateTime today,
  required DateTime echeance,
}) {
  if (montantCible == null) return null;
  final trajectory = computeProjectTrajectory(
    currentValue: currentValue,
    rendementAttenduPercent: rendementAttenduPercent,
    today: today,
    echeance: echeance,
  );
  return trajectory.last.value >= montantCible;
}

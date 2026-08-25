import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Détermine quelle part d'un anneau (donut) — un cercle de rayon [radius]
/// avec un trait d'épaisseur [strokeWidth] *centré* dessus, comme dessiné
/// par un `CustomPainter` avec `Paint()..strokeWidth = strokeWidth` sur un
/// `Rect.fromCircle(center: center, radius: radius)` — contient [point].
/// [values] donne le poids relatif de chaque part, dans l'ordre où elles
/// sont dessinées (départ à 12 h, balayage dans le sens horaire — même
/// convention que `Canvas.drawArc` avec un angle de départ de `-pi/2`).
/// Renvoie son index dans [values], ou `null` si [point] tombe dans le
/// trou central, en dehors de l'anneau, ou si [values] est vide/toutes
/// nulles.
///
/// Partagé entre `AllocationDonutView` (carte Allocation du Dashboard) et
/// `_DistributionCard` (Répartition du Suivi budgétaire) — la version
/// dupliquée dans chacun avait un bug commun : la bande de détection au
/// survol testait `[radius - strokeWidth, radius]`, alors que le trait
/// dessiné (centré sur [radius]) s'étend en réalité de
/// `[radius - strokeWidth / 2, radius + strokeWidth / 2]`. La moitié
/// extérieure du trait n'était donc jamais détectée — or c'est justement
/// là qu'une part fine (faible balayage angulaire) concentre le plus de
/// pixels, l'arc s'élargissant avec le rayon : le survol semblait
/// fonctionner pour les grandes parts et pas pour les petites.
int? hitTestDonutSlice({
  required Offset point,
  required Offset center,
  required double radius,
  required double strokeWidth,
  required List<double> values,
}) {
  final innerRadius = radius - strokeWidth / 2;
  final outerRadius = radius + strokeWidth / 2;
  final distance = (point - center).distance;
  if (distance < innerRadius || distance > outerRadius) return null;

  var angle = math.atan2(point.dy - center.dy, point.dx - center.dx) + math.pi / 2;
  if (angle < 0) angle += 2 * math.pi;

  final total = values.fold<double>(0, (sum, v) => sum + v);
  if (total <= 0) return null;

  // Position équivalente le long du cercle, en une seule division plutôt
  // qu'en accumulant un balayage angulaire part par part (chaque addition
  // flottante dérive légèrement l'erreur cumulée, non négligeable pour une
  // petite part en fin de liste) — et le dernier indice sert toujours de
  // filet de sécurité, pour qu'un léger dépassement d'arrondi en bout de
  // cercle retombe sur la dernière part plutôt que sur aucune.
  final target = angle / (2 * math.pi) * total;
  var cumulative = 0.0;
  for (var i = 0; i < values.length; i++) {
    cumulative += values[i];
    if (target < cumulative || i == values.length - 1) return i;
  }
  return null;
}

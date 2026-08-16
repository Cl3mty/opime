import 'dart:math';

/// Rayon moyen de la Terre en kilomètres, utilisé pour la formule de
/// haversine — précision largement suffisante pour filtrer des ventes DVF
/// par distance (pas un usage géodésique de précision).
const _earthRadiusKm = 6371.0;

/// Distance orthodromique (à vol d'oiseau) entre deux points WGS84, en
/// kilomètres — sert à restreindre les ventes DVF comparables à un rayon
/// autour d'une adresse cible (voir `price_estimator.dart`).
double haversineKm({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return _earthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * pi / 180;

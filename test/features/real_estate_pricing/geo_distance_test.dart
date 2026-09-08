import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/geo_distance.dart';

void main() {
  test('distance connue Paris - Marseille (~660 km)', () {
    final km = haversineKm(
      lat1: 48.8566,
      lon1: 2.3522,
      lat2: 43.2965,
      lon2: 5.3698,
    );
    expect(km, closeTo(660, 15));
  });

  test('distance nulle pour le même point', () {
    final km = haversineKm(lat1: 45.0, lon1: 1.0, lat2: 45.0, lon2: 1.0);
    expect(km, closeTo(0, 0.001));
  });
}

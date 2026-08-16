import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/commune_boundaries_client.dart';

void main() {
  group('CommuneBoundariesClient.parseGeoJson', () {
    test('décode un Polygon simple', () {
      const body = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"code": "01001", "nom": "L'Abergement-Clémenciat"},
            "geometry": {
              "type": "Polygon",
              "coordinates": [[[4.90, 46.15], [4.91, 46.16], [4.92, 46.15], [4.90, 46.15]]]
            }
          }
        ]
      }
      ''';

      final result = CommuneBoundariesClient.parseGeoJson(body);

      expect(result, hasLength(1));
      final commune = result!.single;
      expect(commune.code, '01001');
      expect(commune.name, "L'Abergement-Clémenciat");
      expect(commune.polygons, hasLength(1));
      // GeoJSON [lon, lat] -> LatLng(lat, lon)
      expect(commune.polygons.single.first.latitude, 46.15);
      expect(commune.polygons.single.first.longitude, 4.90);
    });

    test('décode un MultiPolygon', () {
      const body = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"code": "17300", "nom": "Rochefort"},
            "geometry": {
              "type": "MultiPolygon",
              "coordinates": [
                [[[-0.9, 45.9], [-0.8, 46.0], [-0.7, 45.9], [-0.9, 45.9]]],
                [[[-1.1, 46.1], [-1.0, 46.2], [-0.9, 46.1], [-1.1, 46.1]]]
              ]
            }
          }
        ]
      }
      ''';

      final result = CommuneBoundariesClient.parseGeoJson(body);

      expect(result, hasLength(1));
      expect(result!.single.polygons, hasLength(2));
    });

    test('feature sans code/nom/géométrie est ignorée', () {
      const body = '''
      {
        "type": "FeatureCollection",
        "features": [
          {"type": "Feature", "properties": {}, "geometry": null}
        ]
      }
      ''';

      final result = CommuneBoundariesClient.parseGeoJson(body);
      expect(result, isEmpty);
    });

    test('JSON illisible : null', () {
      expect(CommuneBoundariesClient.parseGeoJson('pas du json'), isNull);
    });
  });

  group('kDepartmentSlugs', () {
    test('couvre les 101 départements', () {
      expect(kDepartmentSlugs, hasLength(101));
    });

    test('gère la Corse et les DOM', () {
      expect(kDepartmentSlugs['2A'], 'corse-du-sud');
      expect(kDepartmentSlugs['2B'], 'haute-corse');
      expect(kDepartmentSlugs['971'], 'guadeloupe');
      expect(kDepartmentSlugs['976'], 'mayotte');
    });
  });
}

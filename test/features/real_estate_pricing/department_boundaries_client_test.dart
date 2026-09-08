import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/department_boundaries_client.dart';

void main() {
  group('DepartmentBoundariesClient.parseGeoJson', () {
    test('décode un Polygon simple', () {
      const body = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"code": "01", "nom": "Ain"},
            "geometry": {
              "type": "Polygon",
              "coordinates": [[[4.78, 46.17], [4.79, 46.18], [4.80, 46.17], [4.78, 46.17]]]
            }
          }
        ]
      }
      ''';

      final result = DepartmentBoundariesClient.parseGeoJson(body);

      expect(result, hasLength(1));
      final ain = result!.single;
      expect(ain.code, '01');
      expect(ain.name, 'Ain');
      expect(ain.polygons, hasLength(1));
      expect(ain.polygons.single, hasLength(4));
      // GeoJSON [lon, lat] -> LatLng(lat, lon)
      expect(ain.polygons.single.first.latitude, 46.17);
      expect(ain.polygons.single.first.longitude, 4.78);
    });

    test('décode un MultiPolygon (département avec îles)', () {
      const body = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"code": "83", "nom": "Var"},
            "geometry": {
              "type": "MultiPolygon",
              "coordinates": [
                [[[6.0, 43.0], [6.1, 43.1], [6.2, 43.0], [6.0, 43.0]]],
                [[[6.5, 43.5], [6.6, 43.6], [6.7, 43.5], [6.5, 43.5]]]
              ]
            }
          }
        ]
      }
      ''';

      final result = DepartmentBoundariesClient.parseGeoJson(body);

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

      final result = DepartmentBoundariesClient.parseGeoJson(body);
      expect(result, isEmpty);
    });

    test('JSON illisible : null', () {
      expect(DepartmentBoundariesClient.parseGeoJson('pas du json'), isNull);
    });
  });
}

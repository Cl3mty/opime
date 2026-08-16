import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/ban_client.dart';

void main() {
  group('BanClient.parseFeatureCollection', () {
    test('décode une réponse valide', () {
      const body = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [2.301, 48.855]},
            "properties": {
              "label": "8 Boulevard du Port 80000 Amiens",
              "score": 0.97,
              "housenumber": "8",
              "street": "Boulevard du Port",
              "postcode": "80000",
              "city": "Amiens",
              "citycode": "80021",
              "type": "housenumber"
            }
          }
        ]
      }
      ''';

      final result = BanClient.parseFeatureCollection(body);

      expect(result, hasLength(1));
      expect(result!.single.label, '8 Boulevard du Port 80000 Amiens');
      expect(result.single.cityCode, '80021');
      expect(result.single.lat, 48.855);
      expect(result.single.lon, 2.301);
      expect(result.single.score, 0.97);
    });

    test('liste vide sans résultat', () {
      const body = '{"type": "FeatureCollection", "features": []}';
      expect(BanClient.parseFeatureCollection(body), isEmpty);
    });

    test('feature malformée ignorée, les autres conservées', () {
      const body = '''
      {
        "type": "FeatureCollection",
        "features": [
          {"type": "Feature", "geometry": {}, "properties": {}},
          {
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [1.0, 45.0]},
            "properties": {
              "label": "Rue Valide",
              "postcode": "12345",
              "city": "Ville",
              "citycode": "12345",
              "type": "street"
            }
          }
        ]
      }
      ''';

      final result = BanClient.parseFeatureCollection(body);

      expect(result, hasLength(1));
      expect(result!.single.label, 'Rue Valide');
    });

    test('JSON illisible : null', () {
      expect(BanClient.parseFeatureCollection('pas du json'), isNull);
    });

    test('sans clé "features" : null', () {
      expect(BanClient.parseFeatureCollection('{"type": "FeatureCollection"}'), isNull);
    });
  });
}

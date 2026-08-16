import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/geo_dvf_client.dart';
import 'package:opime/features/real_estate_pricing/price_estimator.dart';
import 'package:opime/features/real_estate_pricing/real_estate_heatmap_data.dart';
import 'package:opime/features/real_estate_pricing/rent_price_client.dart';

void main() {
  DvfSale sale({
    String nature = 'Vente',
    double price = 300000,
    double surface = 100,
    String? type = 'Maison',
    String codeCommune = '80021',
  }) => DvfSale(
    natureMutation: nature,
    valeurFonciere: price,
    typeLocal: type,
    surfaceReelleBati: surface,
    longitude: 0,
    latitude: 0,
    dateMutation: DateTime(2024, 1, 1),
    codeCommune: codeCommune,
  );

  group('aggregateDepartmentSalePrice', () {
    test('médiane des ventes exploitables du type demandé', () {
      final sales = [
        for (final price in [200000.0, 300000.0, 400000.0])
          sale(price: price, surface: 100, type: 'Maison'),
        sale(price: 900000, surface: 100, type: 'Appartement'), // filtré (mauvais type)
        sale(nature: 'Échange', price: 1, surface: 1, type: 'Maison'), // filtré (pas une vente)
      ];

      final result = aggregateDepartmentSalePrice(sales, PropertyTypeFilter.maison);

      // prix/m² : 2000, 3000, 4000 -> médiane 3000
      expect(result, 3000);
    });

    test('null sans vente exploitable', () {
      expect(aggregateDepartmentSalePrice(const [], PropertyTypeFilter.maison), isNull);
    });
  });

  group('aggregateCommuneSalePrices', () {
    test('médiane par commune, ignorant les ventes non exploitables', () {
      final sales = [
        for (final price in [200000.0, 300000.0, 400000.0])
          sale(price: price, surface: 100, type: 'Maison', codeCommune: '80021'),
        sale(price: 900000, surface: 100, type: 'Maison', codeCommune: '80174'),
        sale(price: 1000000, surface: 100, type: 'Appartement', codeCommune: '80021'), // filtré (type)
        sale(nature: 'Échange', price: 1, surface: 1, codeCommune: '80021'), // filtré (nature)
      ];

      final result = aggregateCommuneSalePrices(sales, PropertyTypeFilter.maison);

      expect(result['80021'], 3000); // médiane de 2000/3000/4000
      expect(result['80174'], 9000);
      expect(result, hasLength(2));
    });

    test('liste vide donne un résultat vide', () {
      expect(aggregateCommuneSalePrices(const [], PropertyTypeFilter.maison), isEmpty);
    });
  });

  group('aggregateGridSalePrices', () {
    DvfSale saleAt({
      required double lat,
      required double lon,
      double price = 300000,
      double surface = 100,
    }) => DvfSale(
      natureMutation: 'Vente',
      valeurFonciere: price,
      typeLocal: 'Maison',
      surfaceReelleBati: surface,
      longitude: lon,
      latitude: lat,
      dateMutation: DateTime(2024, 1, 1),
      codeCommune: '75056',
    );

    test('regroupe les ventes proches dans la même cellule', () {
      final sales = [
        saleAt(lat: 48.8566, lon: 2.3522, price: 300000, surface: 100), // 3000/m²
        saleAt(lat: 48.8567, lon: 2.3523, price: 400000, surface: 100), // 4000/m²
        saleAt(lat: 45.0, lon: -1.0, price: 100000, surface: 100), // très loin -> autre cellule
      ];

      final result = aggregateGridSalePrices(
        sales,
        PropertyTypeFilter.maison,
        cellSizeMeters: 200,
        referenceLatitude: 48.8566,
      );

      expect(result, hasLength(2));
      final parisCell = result.values.firstWhere((c) => c.sampleSize == 2);
      expect(parisCell.medianPricePerSqm, 3500); // (3000+4000)/2
      // Les deux ventes regroupées tombent bien dans le rectangle de leur
      // cellule.
      expect(parisCell.south, lessThanOrEqualTo(48.8566));
      expect(parisCell.north, greaterThanOrEqualTo(48.8567));
      expect(parisCell.west, lessThanOrEqualTo(2.3522));
      expect(parisCell.east, greaterThanOrEqualTo(2.3523));
    });

    test('des ventes suffisamment éloignées tombent dans des cellules distinctes', () {
      final sales = [
        saleAt(lat: 48.8566, lon: 2.3522),
        saleAt(lat: 48.9000, lon: 2.4000), // ~5 km plus loin
      ];

      final result = aggregateGridSalePrices(
        sales,
        PropertyTypeFilter.maison,
        cellSizeMeters: 150,
        referenceLatitude: 48.8566,
      );

      expect(result, hasLength(2));
    });

    test('liste vide donne un résultat vide', () {
      expect(
        aggregateGridSalePrices(
          const [],
          PropertyTypeFilter.maison,
          cellSizeMeters: 150,
          referenceLatitude: 48.8566,
        ),
        isEmpty,
      );
    });
  });

  group('aggregateDepartmentRents', () {
    RentEstimate rent(String commune, String dept, double value) => RentEstimate(
      communeCode: commune,
      departmentCode: dept,
      loyerPredM2: value,
      lowerBound: value - 1,
      upperBound: value + 1,
      predictionType: 'commune',
      sampleSize: 50,
    );

    test('moyenne par département à partir de la table nationale', () {
      final table = {
        '80021': rent('80021', '80', 10),
        '80174': rent('80174', '80', 12),
        '75056': rent('75056', '75', 25),
      };

      final result = aggregateDepartmentRents(table);

      expect(result['80'], 11); // (10+12)/2
      expect(result['75'], 25);
    });

    test('table vide donne un résultat vide', () {
      expect(aggregateDepartmentRents(const {}), isEmpty);
    });
  });

  group('heatmapColorFor', () {
    test('à la borne basse : vert pur', () {
      final color = heatmapColorFor(1000, greenAt: 1000, redAt: 8000);
      expect(color, const Color(0xFF22C55E));
    });

    test('à la borne haute : rouge pur', () {
      final color = heatmapColorFor(8000, greenAt: 1000, redAt: 8000);
      expect(color, const Color(0xFFEF4444));
    });

    test('au milieu : jaune pur', () {
      final color = heatmapColorFor(4500, greenAt: 1000, redAt: 8000);
      expect(color, const Color(0xFFEAB308));
    });

    test('valeurs hors bornes sont bornées (clamp), pas extrapolées', () {
      final belowGreen = heatmapColorFor(-500, greenAt: 1000, redAt: 8000);
      final aboveRed = heatmapColorFor(50000, greenAt: 1000, redAt: 8000);
      expect(belowGreen, const Color(0xFF22C55E));
      expect(aboveRed, const Color(0xFFEF4444));
    });
  });
}

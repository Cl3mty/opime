import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/geo_dvf_client.dart';
import 'package:opime/features/real_estate_pricing/price_estimator.dart';

void main() {
  const targetLat = 48.85;
  const targetLon = 2.35;

  DvfSale sale({
    String natureMutation = 'Vente',
    required double valeurFonciere,
    String? typeLocal = 'Maison',
    required double surfaceReelleBati,
    double lat = targetLat,
    double lon = targetLon,
    DateTime? date,
    String codeCommune = '75056',
  }) => DvfSale(
    natureMutation: natureMutation,
    valeurFonciere: valeurFonciere,
    typeLocal: typeLocal,
    surfaceReelleBati: surfaceReelleBati,
    longitude: lon,
    latitude: lat,
    dateMutation: date ?? DateTime(2024, 6, 1),
    codeCommune: codeCommune,
  );

  test('null quand aucune vente exploitable', () {
    final result = estimatePricePerSqm(
      targetLat: targetLat,
      targetLon: targetLon,
      propertyType: PropertyTypeFilter.any,
      sales: const [],
    );
    expect(result, isNull);
  });

  test('médiane calculée sur le prix/m² des ventes comparables (nombre impair)', () {
    final sales = [
      for (final price in [100000, 200000, 300000, 400000, 500000])
        sale(valeurFonciere: price.toDouble(), surfaceReelleBati: 100),
    ];
    final result = estimatePricePerSqm(
      targetLat: targetLat,
      targetLon: targetLon,
      propertyType: PropertyTypeFilter.maison,
      sales: sales,
    );
    // prix/m² : 1000, 2000, 3000, 4000, 5000 → médiane 3000
    expect(result!.medianPricePerSqm, 3000);
    expect(result.sampleSize, 5);
  });

  test('exclut les mutations qui ne sont pas des ventes', () {
    final sales = [
      for (var i = 0; i < 5; i++) sale(valeurFonciere: 300000, surfaceReelleBati: 100),
      sale(natureMutation: 'Échange', valeurFonciere: 100000000, surfaceReelleBati: 1),
    ];
    final result = estimatePricePerSqm(
      targetLat: targetLat,
      targetLon: targetLon,
      propertyType: PropertyTypeFilter.maison,
      sales: sales,
    );
    expect(result!.sampleSize, 5);
    expect(result.medianPricePerSqm, 3000);
  });

  test('filtre par type de bien', () {
    final sales = [
      for (var i = 0; i < 5; i++) sale(valeurFonciere: 300000, surfaceReelleBati: 100, typeLocal: 'Maison'),
      for (var i = 0; i < 3; i++) sale(valeurFonciere: 900000, surfaceReelleBati: 100, typeLocal: 'Appartement'),
    ];
    final result = estimatePricePerSqm(
      targetLat: targetLat,
      targetLon: targetLon,
      propertyType: PropertyTypeFilter.maison,
      sales: sales,
    );
    expect(result!.sampleSize, 5);
    expect(result.medianPricePerSqm, 3000);
  });

  test('élargit le rayon jusqu\'à atteindre le seuil minimal de comparables', () {
    // 5 ventes exactement à la cible (distance 0) : le plus petit rayon
    // (0.1 km) suffit déjà.
    final near = [
      for (var i = 0; i < 5; i++) sale(valeurFonciere: 300000, surfaceReelleBati: 100),
    ];
    // 2 ventes très éloignées (~500 km, hors de tous les rayons testés) qui
    // ne doivent jamais entrer dans l'échantillon retenu.
    final far = [
      sale(valeurFonciere: 100000000, surfaceReelleBati: 1, lat: 43.3, lon: 5.4),
      sale(valeurFonciere: 100000000, surfaceReelleBati: 1, lat: 43.3, lon: 5.4),
    ];

    final result = estimatePricePerSqm(
      targetLat: targetLat,
      targetLon: targetLon,
      propertyType: PropertyTypeFilter.maison,
      sales: [...near, ...far],
    );

    expect(result!.sampleSize, 5);
    expect(result.radiusKmUsed, 0.1);
    expect(result.medianPricePerSqm, 3000);
  });

  test('repli sur l\'ensemble fourni si aucun rayon n\'atteint le seuil minimal', () {
    // Seulement 3 ventes exploitables au total (< kDvfMinSampleSize),
    // dispersées à des distances différentes.
    final sales = [
      sale(valeurFonciere: 100000, surfaceReelleBati: 100),
      sale(valeurFonciere: 200000, surfaceReelleBati: 100, lat: 48.9, lon: 2.4),
      sale(valeurFonciere: 300000, surfaceReelleBati: 100, lat: 49.0, lon: 2.5),
    ];

    final result = estimatePricePerSqm(
      targetLat: targetLat,
      targetLon: targetLon,
      propertyType: PropertyTypeFilter.maison,
      sales: sales,
    );

    expect(result!.sampleSize, 3);
    expect(result.radiusKmUsed, isNull);
    expect(result.medianPricePerSqm, 2000);
  });

  test('yearsUsed et bornes de dates reflètent les ventes retenues', () {
    final sales = [
      sale(valeurFonciere: 100000, surfaceReelleBati: 100, date: DateTime(2023, 1, 1)),
      sale(valeurFonciere: 200000, surfaceReelleBati: 100, date: DateTime(2024, 6, 15)),
      sale(valeurFonciere: 300000, surfaceReelleBati: 100, date: DateTime(2022, 12, 31)),
    ];
    final result = estimatePricePerSqm(
      targetLat: targetLat,
      targetLon: targetLon,
      propertyType: PropertyTypeFilter.maison,
      sales: sales,
    );
    expect(result!.yearsUsed, [2022, 2023, 2024]);
    expect(result.oldestSaleDate, DateTime(2022, 12, 31));
    expect(result.newestSaleDate, DateTime(2024, 6, 15));
  });
}

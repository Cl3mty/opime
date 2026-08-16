import 'geo_distance.dart';
import 'geo_dvf_client.dart';

/// Filtre de type de bien appliqué avant l'estimation — `any` n'exclut
/// aucun `type_local` (utile pour un terrain ou un bien mixte), `maison`/
/// `appartement` filtrent sur la valeur exacte du champ `type_local` des
/// fichiers geo-dvf ("Maison"/"Appartement").
enum PropertyTypeFilter { maison, appartement, any }

/// Rayons de recherche successifs (km) autour de l'adresse cible — le plus
/// petit rayon atteignant [kDvfMinSampleSize] comparables est retenu ; si
/// aucun n'y arrive, on retombe sur l'ensemble de la/des commune(s)
/// récupérée(s) (aucun filtre de distance). Démarre à 100 m : en zone dense,
/// ça suffit déjà à atteindre le seuil minimal ; en zone peu dense,
/// l'élargissement progressif prend le relais jusqu'à la commune entière.
const kDvfRadiusStepsKm = [0.1, 0.25, 0.5, 1.0, 2.0, 5.0];

/// Nombre minimal de ventes comparables pour qu'un rayon soit jugé
/// suffisant — en dessous, on élargit (voir [kDvfRadiusStepsKm]) plutôt que
/// de fonder une médiane sur trop peu de points.
const kDvfMinSampleSize = 5;

/// Résultat d'une estimation de prix au m² — porte aussi les métadonnées de
/// transparence (taille d'échantillon, rayon retenu, période couverte) pour
/// que l'UI puisse afficher un niveau de confiance plutôt qu'un chiffre nu.
class PriceEstimate {
  final double medianPricePerSqm;
  final int sampleSize;

  /// `null` quand aucun rayon de [kDvfRadiusStepsKm] n'a atteint
  /// [kDvfMinSampleSize] : l'estimation retombe alors sur l'ensemble des
  /// ventes fournies (commune entière), sans filtre de distance.
  final double? radiusKmUsed;
  final DateTime oldestSaleDate;
  final DateTime newestSaleDate;
  final List<int> yearsUsed;

  const PriceEstimate({
    required this.medianPricePerSqm,
    required this.sampleSize,
    required this.radiusKmUsed,
    required this.oldestSaleDate,
    required this.newestSaleDate,
    required this.yearsUsed,
  });
}

/// Estime le prix au m² à [targetLat]/[targetLon] à partir de [sales] (voir
/// `geo_dvf_client.dart`/`real_estate_price_service.dart` pour leur
/// récupération) : filtre aux ventes exploitables (mutation de type
/// "Vente", prix et surface positifs, type de bien correspondant à
/// [propertyType]), élargit progressivement le rayon de recherche jusqu'à
/// [kDvfMinSampleSize] comparables ou repli sur l'ensemble des ventes
/// fournies, puis prend la médiane du prix/m² (pas la moyenne, plus robuste
/// aux valeurs extrêmes dans un petit échantillon). `null` seulement si
/// aucune vente exploitable n'existe dans [sales].
PriceEstimate? estimatePricePerSqm({
  required double targetLat,
  required double targetLon,
  required PropertyTypeFilter propertyType,
  required List<DvfSale> sales,
}) {
  final usable = [
    for (final sale in sales)
      if (sale.natureMutation == 'Vente' &&
          sale.valeurFonciere > 0 &&
          sale.surfaceReelleBati > 0 &&
          matchesPropertyType(sale.typeLocal, propertyType))
        sale,
  ];
  if (usable.isEmpty) return null;

  List<DvfSale>? withinRadius;
  double? radiusUsed;
  for (final radiusKm in kDvfRadiusStepsKm) {
    final candidates = [
      for (final sale in usable)
        if (haversineKm(
              lat1: targetLat,
              lon1: targetLon,
              lat2: sale.latitude,
              lon2: sale.longitude,
            ) <=
            radiusKm)
          sale,
    ];
    if (candidates.length >= kDvfMinSampleSize) {
      withinRadius = candidates;
      radiusUsed = radiusKm;
      break;
    }
  }
  final comparables = withinRadius ?? usable;

  final pricesPerSqm = [for (final sale in comparables) sale.pricePerSqm]
    ..sort();
  final median = medianOf(pricesPerSqm);

  final dates = [for (final sale in comparables) sale.dateMutation];
  dates.sort();
  final years = {for (final sale in comparables) sale.dateMutation.year}.toList()
    ..sort();

  return PriceEstimate(
    medianPricePerSqm: median,
    sampleSize: comparables.length,
    radiusKmUsed: withinRadius == null ? null : radiusUsed,
    oldestSaleDate: dates.first,
    newestSaleDate: dates.last,
    yearsUsed: years,
  );
}

/// `true` si [typeLocal] (champ `type_local` d'un [DvfSale]) correspond à
/// [filter] — partagé avec `real_estate_heatmap_data.dart` (agrégation par
/// département) pour que les deux pipelines de prix appliquent exactement
/// le même critère de comparabilité.
bool matchesPropertyType(String? typeLocal, PropertyTypeFilter filter) {
  if (filter == PropertyTypeFilter.any) return true;
  final expected = switch (filter) {
    PropertyTypeFilter.maison => 'Maison',
    PropertyTypeFilter.appartement => 'Appartement',
    PropertyTypeFilter.any => null,
  };
  return typeLocal == expected;
}

/// Médiane d'une liste déjà triée — partagée avec
/// `real_estate_heatmap_data.dart`.
double medianOf(List<double> sortedValues) {
  final n = sortedValues.length;
  if (n.isOdd) return sortedValues[n ~/ 2];
  return (sortedValues[n ~/ 2 - 1] + sortedValues[n ~/ 2]) / 2;
}

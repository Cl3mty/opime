import 'dart:math' show cos, pi;
import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart' show LatLng;

import 'geo_dvf_client.dart' show DvfSale;
import 'price_estimator.dart' show PropertyTypeFilter, matchesPropertyType, medianOf;
import 'rent_price_client.dart' show RentEstimate;

/// Mètres par degré de latitude — quasi constant sur Terre, utilisé pour
/// convertir une taille de cellule en mètres ([aggregateGridSalePrices]) en
/// un pas en degrés.
const _metersPerDegreeLatitude = 111320.0;

/// Médiane du prix/m² d'un département entier — même critère de
/// comparabilité que [estimatePricePerSqm] (`price_estimator.dart`), mais
/// sans filtre de distance : [sales] est déjà tout un département (voir
/// `GeoDvfClient.fetchDepartment`), pas un rayon autour d'une adresse.
/// `null` si aucune vente exploitable.
double? aggregateDepartmentSalePrice(
  List<DvfSale> sales,
  PropertyTypeFilter propertyType,
) {
  final usable = [
    for (final sale in sales)
      if (sale.natureMutation == 'Vente' &&
          sale.valeurFonciere > 0 &&
          sale.surfaceReelleBati > 0 &&
          matchesPropertyType(sale.typeLocal, propertyType))
        sale,
  ];
  if (usable.isEmpty) return null;
  final prices = [for (final sale in usable) sale.pricePerSqm]..sort();
  return medianOf(prices);
}

/// Médiane du prix/m² par commune, à partir des ventes d'un département
/// entier déjà récupéré (voir `GeoDvfClient.fetchDepartment` et
/// `DvfDepartmentCacheRepository`) — même critère de comparabilité que
/// [aggregateDepartmentSalePrice], mais un groupe par [DvfSale.codeCommune]
/// plutôt qu'un groupe unique pour tout le département. Utilisé par le
/// palier "Commune" de la carte de chaleur (zoom intermédiaire) : aucun
/// appel réseau supplémentaire, les ventes sont déjà en mémoire/en cache.
Map<String, double> aggregateCommuneSalePrices(
  List<DvfSale> sales,
  PropertyTypeFilter propertyType,
) {
  final usable = [
    for (final sale in sales)
      if (sale.natureMutation == 'Vente' &&
          sale.valeurFonciere > 0 &&
          sale.surfaceReelleBati > 0 &&
          matchesPropertyType(sale.typeLocal, propertyType))
        sale,
  ];
  final byCommune = <String, List<double>>{};
  for (final sale in usable) {
    byCommune.putIfAbsent(sale.codeCommune, () => []).add(sale.pricePerSqm);
  }
  return {
    for (final entry in byCommune.entries)
      entry.key: medianOf(entry.value..sort()),
  };
}

/// Une cellule de la grille fine ([aggregateGridSalePrices]) — son
/// rectangle exact ([south]/[north]/[west]/[east]), pas seulement un point,
/// pour qu'elle puisse être dessinée comme une zone encadrée (le "quartier"
/// qu'elle résume) plutôt qu'un simple marqueur ponctuel.
class GridCell {
  final double south;
  final double north;
  final double west;
  final double east;
  final double medianPricePerSqm;
  final int sampleSize;

  const GridCell({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
    required this.medianPricePerSqm,
    required this.sampleSize,
  });

  /// Les quatre coins du rectangle, dans l'ordre pour un tracé de polygone
  /// (sens horaire ou anti-horaire, peu importe pour un remplissage plein).
  List<LatLng> get corners => [
    LatLng(south, west),
    LatLng(south, east),
    LatLng(north, east),
    LatLng(north, west),
  ];

  LatLng get center => LatLng((south + north) / 2, (west + east) / 2);
}

/// Regroupe les ventes d'un ou plusieurs départements déjà récupérés en
/// cellules carrées d'environ [cellSizeMeters] de côté, et retourne la
/// médiane de prix/m² de chaque cellule non vide — palier le plus fin de la
/// carte de chaleur (zoom rue), la résolution native du jeu de données DVF
/// (pas de source de données supplémentaire, contrairement à un découpage
/// par IRIS/quartier officiel qui demanderait un nouveau jeu de données).
///
/// [referenceLatitude] (typiquement le centre de la zone visible) sert à
/// convertir la largeur de cellule en degrés de longitude — la distance
/// réelle d'un degré de longitude varie avec la latitude (elle rétrécit en
/// s'approchant des pôles), une seule référence pour tout l'appel garde des
/// cellules alignées entre elles plutôt que légèrement décalées vente par
/// vente.
Map<String, GridCell> aggregateGridSalePrices(
  List<DvfSale> sales,
  PropertyTypeFilter propertyType, {
  required double cellSizeMeters,
  required double referenceLatitude,
}) {
  final usable = [
    for (final sale in sales)
      if (sale.natureMutation == 'Vente' &&
          sale.valeurFonciere > 0 &&
          sale.surfaceReelleBati > 0 &&
          matchesPropertyType(sale.typeLocal, propertyType))
        sale,
  ];
  if (usable.isEmpty) return {};

  final latStepDeg = cellSizeMeters / _metersPerDegreeLatitude;
  final metersPerDegreeLongitude =
      _metersPerDegreeLatitude * cos(referenceLatitude * pi / 180).abs().clamp(0.01, 1.0);
  final lonStepDeg = cellSizeMeters / metersPerDegreeLongitude;

  final byCell = <(int, int), List<DvfSale>>{};
  for (final sale in usable) {
    final row = (sale.latitude / latStepDeg).floor();
    final col = (sale.longitude / lonStepDeg).floor();
    byCell.putIfAbsent((row, col), () => []).add(sale);
  }

  final result = <String, GridCell>{};
  for (final entry in byCell.entries) {
    final (row, col) = entry.key;
    final cellSales = entry.value;
    final prices = [for (final sale in cellSales) sale.pricePerSqm]..sort();
    result['$row:$col'] = GridCell(
      south: row * latStepDeg,
      north: (row + 1) * latStepDeg,
      west: col * lonStepDeg,
      east: (col + 1) * lonStepDeg,
      medianPricePerSqm: medianOf(prices),
      sampleSize: cellSales.length,
    );
  }
  return result;
}

/// Moyenne du loyer/m² par département, à partir de la table nationale
/// complète (voir `RentPriceService.loadNational`) — chaque [RentEstimate]
/// porte déjà son [RentEstimate.departmentCode], pas besoin d'une
/// correspondance commune → département séparée.
Map<String, double> aggregateDepartmentRents(
  Map<String, RentEstimate> nationalTable,
) {
  final byDept = <String, List<double>>{};
  for (final estimate in nationalTable.values) {
    byDept.putIfAbsent(estimate.departmentCode, () => []).add(estimate.loyerPredM2);
  }
  return {
    for (final entry in byDept.entries)
      entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length,
  };
}

const _heatmapGreen = Color(0xFF22C55E);
const _heatmapYellow = Color(0xFFEAB308);
const _heatmapRed = Color(0xFFEF4444);

/// Couleur d'un département sur la carte de chaleur — dégradé continu
/// vert → jaune → rouge entre deux bornes fixes ([greenAt]/[redAt]), pas un
/// calcul de percentile dynamique sur les valeurs du jour : la légende reste
/// cohérente d'un chargement à l'autre (les mêmes bornes affichent toujours
/// la même couleur), comme sur la carte de référence. Les valeurs hors
/// bornes sont bornées (`clamp`) plutôt qu'extrapolées.
Color heatmapColorFor(
  double value, {
  required double greenAt,
  required double redAt,
}) {
  final t = ((value - greenAt) / (redAt - greenAt)).clamp(0.0, 1.0);
  if (t <= 0.5) {
    return Color.lerp(_heatmapGreen, _heatmapYellow, t / 0.5)!;
  }
  return Color.lerp(_heatmapYellow, _heatmapRed, (t - 0.5) / 0.5)!;
}

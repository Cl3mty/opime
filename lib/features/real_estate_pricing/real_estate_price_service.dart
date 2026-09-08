import 'dvf_cache_repository.dart';
import 'geo_dvf_client.dart';
import 'price_estimator.dart';

/// Point d'entrée unique pour estimer un prix au m² à partir d'une
/// localisation : orchestration cache + client geo-dvf + estimateur pur
/// (`price_estimator.dart`), utilisé à la fois par l'écran "Estimation"
/// (`simulations/real_estate_estimation_screen.dart`) et par l'action
/// "Réestimer" d'un bien détenu (`investment_detail_screen.dart`).
///
/// C'est aussi le seul point où un futur import DVF+ Cerema (fichiers en
/// masse, voir le plan) pourrait remplacer [GeoDvfClient] sans toucher au
/// reste du pipeline (l'estimateur ne connaît que des [DvfSale], jamais la
/// source dont elles viennent).
class RealEstatePriceService {
  final GeoDvfClient client;
  final DvfCacheRepository cache;

  RealEstatePriceService({required this.client, required this.cache});

  /// Estime le prix au m² pour la commune/coordonnées données, sur les
  /// [years] demandées (les plus récentes en premier par défaut). Ne met en
  /// cache que les récupérations réussies (liste renvoyée, même vide sur un
  /// 404 confirmé) — un échec réseau (`null`) n'est jamais mis en cache,
  /// pour qu'un prochain essai (une fois le réseau revenu) retente vraiment.
  Future<PriceEstimate?> estimate({
    required String citycode,
    required double lat,
    required double lon,
    required PropertyTypeFilter propertyType,
    List<int> years = const [2025, 2024, 2023],
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final allSales = <DvfSale>[];
    for (final year in years) {
      final cached = await cache.load(citycode, year);
      if (cached != null) {
        allSales.addAll(cached);
        continue;
      }
      final fetched = await client.fetchCommuneYear(
        citycode: citycode,
        year: year,
        onNetworkError: onNetworkError,
        onNetworkSuccess: onNetworkSuccess,
      );
      if (fetched == null) continue; // échec réseau : pas de mise en cache
      await cache.save(citycode, year, fetched);
      allSales.addAll(fetched);
    }

    return estimatePricePerSqm(
      targetLat: lat,
      targetLon: lon,
      propertyType: propertyType,
      sales: allSales,
    );
  }
}

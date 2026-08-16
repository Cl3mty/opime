import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'rent_price_client.dart';

/// Cache local de la table nationale des loyers — un seul fichier JSON par
/// type de bien sous `<vault>/simulations/rent_cache/` (contrairement à
/// `DvfCacheRepository`, qui cache par commune : ici la source est déjà un
/// fichier national unique, pas la peine de le découper). Même convention
/// que le reste du dépôt : `JsonEncoder.withIndent('  ')`, lecture
/// défensive.
class RentPriceRepository {
  final String vaultPath;

  RentPriceRepository(this.vaultPath);

  File _fileFor(RentPropertyType type) => File(
    p.join(vaultPath, 'simulations', 'rent_cache', '${type.name}.json'),
  );

  Future<void> _ensureDir() async {
    final dir = Directory(p.join(vaultPath, 'simulations', 'rent_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  /// Table commune → loyer en cache, ou `null` si jamais téléchargée.
  Future<Map<String, RentEstimate>?> load(RentPropertyType type) async {
    final file = _fileFor(type);
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: RentEstimate.fromJson(entry.value as Map<String, dynamic>),
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RentPropertyType type, Map<String, RentEstimate> data) async {
    await _ensureDir();
    final jsonMap = {
      for (final entry in data.entries) entry.key: entry.value.toJson(),
    };
    await _fileFor(
      type,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(jsonMap));
  }
}

/// Point d'entrée unique pour lire un loyer/m² — orchestration cache +
/// client, même rôle que `RealEstatePriceService` côté prix de vente, mais
/// sans logique de rayon (lecture directe par code commune, voir
/// `rent_price_client.dart`).
class RentPriceService {
  final RentPriceClient client;
  final RentPriceRepository cache;

  RentPriceService({required this.client, required this.cache});

  /// Table nationale complète pour [type] — téléchargée une seule fois puis
  /// mise en cache (ne cache que sur succès confirmé, jamais un échec
  /// réseau, même politique que `RealEstatePriceService.estimate`).
  Future<Map<String, RentEstimate>?> loadNational(
    RentPropertyType type, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final cached = await cache.load(type);
    if (cached != null) return cached;
    final fetched = await client.fetchNational(
      type,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
    if (fetched == null) return null;
    await cache.save(type, fetched);
    return fetched;
  }

  /// Loyer/m² estimé pour une commune précise — `null` si la commune est
  /// absente de la table (rarissime, la couverture nationale est quasi
  /// complète) ou en cas d'échec réseau.
  Future<RentEstimate?> estimateForCommune(
    String communeCode,
    RentPropertyType type, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final all = await loadNational(
      type,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
    return all?[communeCode];
  }
}

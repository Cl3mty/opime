import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;

/// Une adresse suggérée par la BAN (Base Adresse Nationale), en réponse à
/// une recherche ([BanClient.search]) ou à un géocodage inverse
/// ([BanClient.reverseGeocode]). [cityCode] (code INSEE, 5 chiffres) est la
/// clé de jointure vers les données DVF (voir `geo_dvf_client.dart`).
class BanAddressSuggestion {
  final String label;
  final double lat;
  final double lon;
  final String? houseNumber;
  final String? street;
  final String postcode;
  final String city;
  final String cityCode;
  final double score;
  final String type;

  const BanAddressSuggestion({
    required this.label,
    required this.lat,
    required this.lon,
    this.houseNumber,
    this.street,
    required this.postcode,
    required this.city,
    required this.cityCode,
    required this.score,
    required this.type,
  });

  /// Décode une feature GeoJSON de la réponse BAN — `null` si la feature est
  /// malformée ou manque un champ requis (jamais d'exception propagée, même
  /// philosophie défensive que [MetalProductImage.parseCatalog]).
  static BanAddressSuggestion? _fromFeature(Map<String, dynamic> feature) {
    try {
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List?;
      final properties = feature['properties'] as Map<String, dynamic>?;
      if (coordinates == null || coordinates.length < 2 || properties == null) {
        return null;
      }
      final cityCode = properties['citycode'] as String?;
      final postcode = properties['postcode'] as String?;
      final city = properties['city'] as String?;
      final label = properties['label'] as String?;
      if (cityCode == null || postcode == null || city == null || label == null) {
        return null;
      }
      return BanAddressSuggestion(
        label: label,
        lon: (coordinates[0] as num).toDouble(),
        lat: (coordinates[1] as num).toDouble(),
        houseNumber: properties['housenumber'] as String?,
        street: properties['street'] as String?,
        postcode: postcode,
        city: city,
        cityCode: cityCode,
        score: (properties['score'] as num?)?.toDouble() ?? 0,
        type: properties['type'] as String? ?? 'housenumber',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Client pour la BAN (Base Adresse Nationale, `api-adresse.data.gouv.fr`) —
/// API publique, gratuite, sans clé. Même philosophie défensive que
/// [MetalPriceClient]/`YahooFinanceClient` : un échec (réseau, réponse
/// inattendue) retourne `null` plutôt que de propager une exception.
class BanClient {
  static const _baseUrl = 'https://api-adresse.data.gouv.fr';

  /// Suggestions d'adresse pour une recherche libre — `null` sur échec
  /// réseau, liste vide si aucune correspondance. [query] vide ne déclenche
  /// aucune requête (retourne directement une liste vide).
  Future<List<BanAddressSuggestion>?> search(
    String query, {
    int limit = 5,
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final uri = Uri.parse('$_baseUrl/search/').replace(
      queryParameters: {'q': trimmed, 'limit': '$limit'},
    );
    return _fetchSuggestions(
      uri,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
  }

  /// Adresse la plus proche d'un point (clic sur la carte) — `null` sur
  /// échec réseau ou si aucune adresse n'est trouvée à proximité.
  Future<BanAddressSuggestion?> reverseGeocode({
    required double lat,
    required double lon,
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final uri = Uri.parse('$_baseUrl/reverse/').replace(
      queryParameters: {'lon': '$lon', 'lat': '$lat'},
    );
    final results = await _fetchSuggestions(
      uri,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
    if (results == null || results.isEmpty) return null;
    return results.first;
  }

  Future<List<BanAddressSuggestion>?> _fetchSuggestions(
    Uri uri, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    try {
      final response = await http.get(uri);
      onNetworkSuccess?.call();
      if (response.statusCode != 200) return null;
      return parseFeatureCollection(response.body);
    } on SocketException catch (_) {
      onNetworkError?.call();
      return null;
    } on http.ClientException catch (_) {
      onNetworkError?.call();
      return null;
    } on TimeoutException catch (_) {
      onNetworkError?.call();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Décode une réponse GeoJSON `FeatureCollection` de la BAN — `null` si le
  /// JSON est illisible ou d'une forme inattendue ; les features
  /// individuellement malformées sont ignorées plutôt que de faire échouer
  /// toute la réponse.
  static List<BanAddressSuggestion>? parseFeatureCollection(String jsonBody) {
    try {
      final decoded = jsonDecode(jsonBody);
      if (decoded is! Map) return null;
      final features = decoded['features'] as List?;
      if (features == null) return null;
      final result = <BanAddressSuggestion>[];
      for (final feature in features) {
        if (feature is! Map<String, dynamic>) continue;
        final suggestion = BanAddressSuggestion._fromFeature(feature);
        if (suggestion != null) result.add(suggestion);
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}

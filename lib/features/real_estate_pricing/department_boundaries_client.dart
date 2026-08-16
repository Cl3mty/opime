import 'dart:async' show TimeoutException;
import 'dart:convert' show jsonDecode;
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

/// Frontière d'un département — [polygons] porte un ou plusieurs anneaux
/// extérieurs (plusieurs pour un département avec des îles, ex :
/// MultiPolygon), les trous éventuels (rares, sans intérêt pour un
/// remplissage de choroplèthe) ne sont pas conservés.
class DepartmentBoundary {
  final String code;
  final String name;
  final List<List<LatLng>> polygons;

  const DepartmentBoundary({
    required this.code,
    required this.name,
    required this.polygons,
  });
}

/// Client pour les frontières départementales (`france-geojson`, dépôt
/// public GitHub, gratuit, sans clé, licence ouverte) — utilisé pour le
/// fond de carte de la carte de chaleur nationale
/// (`real_estate_heatmap_map.dart`). Un seul fichier nnational, jamais mis à
/// jour en pratique (limites administratives stables) : voir
/// `department_boundaries_repository.dart` pour un cache définitif, sans
/// notion de rafraîchissement.
class DepartmentBoundariesClient {
  static const _url =
      'https://raw.githubusercontent.com/gregoiredavid/france-geojson/master/departements.geojson';

  Future<List<DepartmentBoundary>?> fetch({
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    try {
      final response = await http.get(Uri.parse(_url));
      onNetworkSuccess?.call();
      if (response.statusCode != 200) return null;
      return parseGeoJson(response.body);
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

  /// Décode le `FeatureCollection` — une géométrie `Polygon` ou
  /// `MultiPolygon` malformée est ignorée (le département disparaît alors
  /// silencieusement de la carte plutôt que de faire échouer tout le
  /// chargement).
  static List<DepartmentBoundary>? parseGeoJson(String jsonBody) {
    try {
      final decoded = jsonDecode(jsonBody);
      if (decoded is! Map) return null;
      final features = decoded['features'] as List?;
      if (features == null) return null;
      final result = <DepartmentBoundary>[];
      for (final feature in features) {
        if (feature is! Map) continue;
        try {
          final properties = feature['properties'] as Map?;
          final geometry = feature['geometry'] as Map?;
          final code = properties?['code'] as String?;
          final name = properties?['nom'] as String?;
          if (code == null || name == null || geometry == null) continue;
          final polygons = _outerRingsFrom(geometry);
          if (polygons.isEmpty) continue;
          result.add(DepartmentBoundary(code: code, name: name, polygons: polygons));
        } catch (_) {
          continue;
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Anneaux extérieurs d'une géométrie `Polygon` (un anneau, le premier de
  /// [coordinates]) ou `MultiPolygon` (un anneau par sous-polygone) — les
  /// coordonnées GeoJSON sont `[lon, lat]`, inversées ici vers [LatLng].
  static List<List<LatLng>> _outerRingsFrom(Map geometry) {
    final type = geometry['type'] as String?;
    final coordinates = geometry['coordinates'] as List?;
    if (coordinates == null) return const [];
    if (type == 'Polygon') {
      final outerRing = coordinates.isEmpty ? null : coordinates.first as List?;
      return outerRing == null ? const [] : [_toLatLngRing(outerRing)];
    }
    if (type == 'MultiPolygon') {
      final rings = <List<LatLng>>[];
      for (final polygon in coordinates) {
        final outerRing = (polygon as List).isEmpty ? null : polygon.first as List?;
        if (outerRing != null) rings.add(_toLatLngRing(outerRing));
      }
      return rings;
    }
    return const [];
  }

  static List<LatLng> _toLatLngRing(List ring) => [
    for (final point in ring)
      if (point is List && point.length >= 2)
        LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()),
  ];
}

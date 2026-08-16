import 'dart:async' show TimeoutException;
import 'dart:convert' show jsonDecode;
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

/// Frontière d'une commune — même structure que [DepartmentBoundary]
/// (`department_boundaries_client.dart`), à l'échelle communale.
class CommuneBoundary {
  final String code;
  final String name;
  final List<List<LatLng>> polygons;

  const CommuneBoundary({
    required this.code,
    required this.name,
    required this.polygons,
  });
}

/// Slug de dossier `france-geojson` pour chaque code département — table
/// statique (limites administratives stables, vérifiée en direct sur le
/// dépôt `gregoiredavid/france-geojson`), nécessaire pour construire l'URL
/// du fichier communal d'un département
/// (`departements/{code}-{slug}/communes-{code}-{slug}.geojson`, distinct
/// du fichier national `communes.geojson`, trop volumineux pour être
/// téléchargé d'un bloc).
const kDepartmentSlugs = {
  '01': 'ain', '02': 'aisne', '03': 'allier',
  '04': 'alpes-de-haute-provence', '05': 'hautes-alpes',
  '06': 'alpes-maritimes', '07': 'ardeche', '08': 'ardennes',
  '09': 'ariege', '10': 'aube', '11': 'aude', '12': 'aveyron',
  '13': 'bouches-du-rhone', '14': 'calvados', '15': 'cantal',
  '16': 'charente', '17': 'charente-maritime', '18': 'cher',
  '19': 'correze', '21': 'cote-d-or', '22': 'cotes-d-armor',
  '23': 'creuse', '24': 'dordogne', '25': 'doubs', '26': 'drome',
  '27': 'eure', '28': 'eure-et-loir', '29': 'finistere',
  '2A': 'corse-du-sud', '2B': 'haute-corse', '30': 'gard',
  '31': 'haute-garonne', '32': 'gers', '33': 'gironde',
  '34': 'herault', '35': 'ille-et-vilaine', '36': 'indre',
  '37': 'indre-et-loire', '38': 'isere', '39': 'jura',
  '40': 'landes', '41': 'loir-et-cher', '42': 'loire',
  '43': 'haute-loire', '44': 'loire-atlantique', '45': 'loiret',
  '46': 'lot', '47': 'lot-et-garonne', '48': 'lozere',
  '49': 'maine-et-loire', '50': 'manche', '51': 'marne',
  '52': 'haute-marne', '53': 'mayenne',
  '54': 'meurthe-et-moselle', '55': 'meuse', '56': 'morbihan',
  '57': 'moselle', '58': 'nievre', '59': 'nord', '60': 'oise',
  '61': 'orne', '62': 'pas-de-calais', '63': 'puy-de-dome',
  '64': 'pyrenees-atlantiques', '65': 'hautes-pyrenees',
  '66': 'pyrenees-orientales', '67': 'bas-rhin', '68': 'haut-rhin',
  '69': 'rhone', '70': 'haute-saone', '71': 'saone-et-loire',
  '72': 'sarthe', '73': 'savoie', '74': 'haute-savoie',
  '75': 'paris', '76': 'seine-maritime', '77': 'seine-et-marne',
  '78': 'yvelines', '79': 'deux-sevres', '80': 'somme',
  '81': 'tarn', '82': 'tarn-et-garonne', '83': 'var',
  '84': 'vaucluse', '85': 'vendee', '86': 'vienne',
  '87': 'haute-vienne', '88': 'vosges', '89': 'yonne',
  '90': 'territoire-de-belfort', '91': 'essonne',
  '92': 'hauts-de-seine', '93': 'seine-saint-denis',
  '94': 'val-de-marne', '95': 'val-d-oise',
  '971': 'guadeloupe', '972': 'martinique', '973': 'guyane',
  '974': 'la-reunion', '976': 'mayotte',
};

/// Client pour les frontières communales (`france-geojson`, même dépôt
/// public GitHub que [DepartmentBoundariesClient]) — un fichier **par
/// département** (`departements/{code}-{slug}/communes-{code}-{slug}.geojson`),
/// récupéré à la demande pour les départements visibles à l'écran (voir le
/// palier "Commune" de `real_estate_heatmap_map.dart`), jamais le fichier
/// national d'un bloc (plusieurs dizaines de Mo).
class CommuneBoundariesClient {
  static const _baseUrl =
      'https://raw.githubusercontent.com/gregoiredavid/france-geojson/master/departements';

  Future<List<CommuneBoundary>?> fetchForDepartment(
    String deptCode, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final slug = kDepartmentSlugs[deptCode];
    if (slug == null) return null;
    final uri = Uri.parse('$_baseUrl/$deptCode-$slug/communes-$deptCode-$slug.geojson');
    try {
      final response = await http.get(uri);
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

  /// Décode le `FeatureCollection` — même logique que
  /// [DepartmentBoundariesClient.parseGeoJson], à l'échelle communale
  /// (`properties.code`/`properties.nom` d'une commune plutôt que d'un
  /// département).
  static List<CommuneBoundary>? parseGeoJson(String jsonBody) {
    try {
      final decoded = jsonDecode(jsonBody);
      if (decoded is! Map) return null;
      final features = decoded['features'] as List?;
      if (features == null) return null;
      final result = <CommuneBoundary>[];
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
          result.add(CommuneBoundary(code: code, name: name, polygons: polygons));
        } catch (_) {
          continue;
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

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

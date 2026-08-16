import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path/path.dart' as p;
import 'department_boundaries_client.dart';

/// Cache local des frontières départementales — un seul fichier JSON sous
/// `<vault>/simulations/department_boundaries.json`, jamais rafraîchi une
/// fois présent (limites administratives stables, pas de notion
/// d'expiration comme pour les prix/loyers).
class DepartmentBoundariesRepository {
  final String vaultPath;

  DepartmentBoundariesRepository(this.vaultPath);

  File get _file =>
      File(p.join(vaultPath, 'simulations', 'department_boundaries.json'));

  Future<List<DepartmentBoundary>?> load() async {
    if (!await _file.exists()) return null;
    try {
      final content = await _file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content) as List;
      return [
        for (final entry in decoded)
          _fromJson(entry as Map<String, dynamic>),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<void> save(List<DepartmentBoundary> boundaries) async {
    final dir = Directory(p.join(vaultPath, 'simulations'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final jsonList = [for (final b in boundaries) _toJson(b)];
    await _file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
  }

  static Map<String, dynamic> _toJson(DepartmentBoundary boundary) => {
    'code': boundary.code,
    'name': boundary.name,
    'polygons': [
      for (final ring in boundary.polygons)
        [for (final point in ring) [point.latitude, point.longitude]],
    ],
  };

  static DepartmentBoundary _fromJson(Map<String, dynamic> json) => DepartmentBoundary(
    code: json['code'] as String,
    name: json['name'] as String,
    polygons: [
      for (final ring in json['polygons'] as List)
        [
          for (final point in ring as List)
            LatLng((point[0] as num).toDouble(), (point[1] as num).toDouble()),
        ],
    ],
  );
}

/// Point d'entrée unique : lit le cache, sinon télécharge et met en cache.
class DepartmentBoundariesService {
  final DepartmentBoundariesClient client;
  final DepartmentBoundariesRepository cache;

  DepartmentBoundariesService({required this.client, required this.cache});

  Future<List<DepartmentBoundary>?> load({
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final cached = await cache.load();
    if (cached != null) return cached;
    final fetched = await client.fetch(
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
    if (fetched == null) return null;
    await cache.save(fetched);
    return fetched;
  }
}

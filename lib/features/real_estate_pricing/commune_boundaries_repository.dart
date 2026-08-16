import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path/path.dart' as p;
import 'commune_boundaries_client.dart';

/// Cache local des frontières communales — un fichier JSON par département
/// sous `<vault>/simulations/commune_boundaries/<deptCode>.json`, jamais
/// rafraîchi une fois présent (mêmes limites administratives stables que
/// [DepartmentBoundariesRepository], simplement subdivisées par
/// département pour ne charger que ce qui est effectivement affiché).
class CommuneBoundariesRepository {
  final String vaultPath;

  CommuneBoundariesRepository(this.vaultPath);

  File _fileFor(String deptCode) =>
      File(p.join(vaultPath, 'simulations', 'commune_boundaries', '$deptCode.json'));

  Future<List<CommuneBoundary>?> load(String deptCode) async {
    final file = _fileFor(deptCode);
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content) as List;
      return [for (final entry in decoded) _fromJson(entry as Map<String, dynamic>)];
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String deptCode, List<CommuneBoundary> boundaries) async {
    final dir = Directory(p.join(vaultPath, 'simulations', 'commune_boundaries'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final jsonList = [for (final b in boundaries) _toJson(b)];
    await _fileFor(
      deptCode,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
  }

  static Map<String, dynamic> _toJson(CommuneBoundary boundary) => {
    'code': boundary.code,
    'name': boundary.name,
    'polygons': [
      for (final ring in boundary.polygons)
        [for (final point in ring) [point.latitude, point.longitude]],
    ],
  };

  static CommuneBoundary _fromJson(Map<String, dynamic> json) => CommuneBoundary(
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

/// Point d'entrée unique pour un département donné : lit le cache, sinon
/// télécharge et met en cache — même principe que
/// `DepartmentBoundariesService`, à l'échelle communale.
class CommuneBoundariesService {
  final CommuneBoundariesClient client;
  final CommuneBoundariesRepository cache;

  CommuneBoundariesService({required this.client, required this.cache});

  Future<List<CommuneBoundary>?> loadForDepartment(
    String deptCode, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final cached = await cache.load(deptCode);
    if (cached != null) return cached;
    final fetched = await client.fetchForDepartment(
      deptCode,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
    if (fetched == null) return null;
    await cache.save(deptCode, fetched);
    return fetched;
  }
}

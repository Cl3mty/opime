import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:opime/features/real_estate_pricing/commune_boundaries_client.dart';
import 'package:opime/features/real_estate_pricing/commune_boundaries_repository.dart';

class _FakeCommuneBoundariesClient extends CommuneBoundariesClient {
  int fetchCount = 0;
  final List<CommuneBoundary> boundaries;

  _FakeCommuneBoundariesClient(this.boundaries);

  @override
  Future<List<CommuneBoundary>?> fetchForDepartment(
    String deptCode, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    fetchCount++;
    onNetworkSuccess?.call();
    return boundaries;
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_commune_boundaries_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('sauvegarde puis relecture restitue les mêmes polygones', () async {
    final repo = CommuneBoundariesRepository(tempDir.path);
    const commune = CommuneBoundary(
      code: '01001',
      name: "L'Abergement-Clémenciat",
      polygons: [
        [LatLng(46.15, 4.90), LatLng(46.16, 4.91)],
      ],
    );

    await repo.save('01', [commune]);
    final loaded = await repo.load('01');

    expect(loaded, hasLength(1));
    expect(loaded!.single.code, '01001');
    expect(loaded.single.polygons.single.first.latitude, 46.15);
    expect(loaded.single.polygons.single.first.longitude, 4.90);
  });

  test('load sans cache existant renvoie null', () async {
    final repo = CommuneBoundariesRepository(tempDir.path);
    expect(await repo.load('01'), isNull);
  });

  test('les caches de départements différents sont indépendants', () async {
    final repo = CommuneBoundariesRepository(tempDir.path);
    await repo.save('01', const [
      CommuneBoundary(code: '01001', name: 'Commune 1', polygons: [[LatLng(46.15, 4.90)]]),
    ]);

    expect(await repo.load('02'), isNull);
    expect(await repo.load('01'), hasLength(1));
  });

  test('CommuneBoundariesService ne télécharge qu\'une seule fois par département', () async {
    final client = _FakeCommuneBoundariesClient(const [
      CommuneBoundary(code: '01001', name: 'Commune 1', polygons: [[LatLng(46.15, 4.90)]]),
    ]);
    final cache = CommuneBoundariesRepository(tempDir.path);
    final service = CommuneBoundariesService(client: client, cache: cache);

    final first = await service.loadForDepartment('01');
    final second = await service.loadForDepartment('01');

    expect(first, hasLength(1));
    expect(second, hasLength(1));
    expect(client.fetchCount, 1);
  });
}

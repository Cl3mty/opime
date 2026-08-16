import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:opime/features/real_estate_pricing/department_boundaries_client.dart';
import 'package:opime/features/real_estate_pricing/department_boundaries_repository.dart';

class _FakeDepartmentBoundariesClient extends DepartmentBoundariesClient {
  int fetchCount = 0;
  final List<DepartmentBoundary> boundaries;

  _FakeDepartmentBoundariesClient(this.boundaries);

  @override
  Future<List<DepartmentBoundary>?> fetch({
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
    tempDir = await Directory.systemTemp.createTemp('opime_dept_boundaries_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('sauvegarde puis relecture restitue les mêmes polygones', () async {
    final repo = DepartmentBoundariesRepository(tempDir.path);
    final boundary = DepartmentBoundary(
      code: '01',
      name: 'Ain',
      polygons: [
        [const LatLng(46.17, 4.78), const LatLng(46.18, 4.79)],
      ],
    );

    await repo.save([boundary]);
    final loaded = await repo.load();

    expect(loaded, hasLength(1));
    expect(loaded!.single.code, '01');
    expect(loaded.single.polygons.single.first.latitude, 46.17);
    expect(loaded.single.polygons.single.first.longitude, 4.78);
  });

  test('load sans cache existant renvoie null', () async {
    final repo = DepartmentBoundariesRepository(tempDir.path);
    expect(await repo.load(), isNull);
  });

  test('DepartmentBoundariesService ne télécharge qu\'une seule fois', () async {
    final client = _FakeDepartmentBoundariesClient([
      const DepartmentBoundary(code: '01', name: 'Ain', polygons: [[LatLng(46.17, 4.78)]]),
    ]);
    final cache = DepartmentBoundariesRepository(tempDir.path);
    final service = DepartmentBoundariesService(client: client, cache: cache);

    final first = await service.load();
    final second = await service.load();

    expect(first, hasLength(1));
    expect(second, hasLength(1));
    expect(client.fetchCount, 1);
  });
}

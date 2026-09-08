import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/dvf_department_cache_repository.dart';
import 'package:opime/features/real_estate_pricing/geo_dvf_client.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_dvf_dept_cache_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  DvfSale sale({String codeCommune = '01001'}) => DvfSale(
    natureMutation: 'Vente',
    valeurFonciere: 200000,
    typeLocal: 'Maison',
    surfaceReelleBati: 100,
    longitude: 4.9,
    latitude: 46.2,
    dateMutation: DateTime(2024, 3, 1),
    codeCommune: codeCommune,
  );

  test('save puis load restitue les mêmes ventes', () async {
    final repo = DvfDepartmentCacheRepository(tempDir.path);
    await repo.save('01', 2024, [sale(), sale(codeCommune: '01002')]);

    final loaded = await repo.load('01', 2024);

    expect(loaded, hasLength(2));
    expect(loaded!.map((s) => s.codeCommune), containsAll(['01001', '01002']));
  });

  test('load sans cache existant renvoie null', () async {
    final repo = DvfDepartmentCacheRepository(tempDir.path);
    expect(await repo.load('01', 2024), isNull);
  });

  test('les caches de départements/années différents sont indépendants', () async {
    final repo = DvfDepartmentCacheRepository(tempDir.path);
    await repo.save('01', 2024, [sale()]);

    expect(await repo.load('02', 2024), isNull);
    expect(await repo.load('01', 2023), isNull);
    expect(await repo.load('01', 2024), hasLength(1));
  });
}

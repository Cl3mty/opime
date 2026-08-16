import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/rent_price_client.dart';
import 'package:opime/features/real_estate_pricing/rent_price_repository.dart';

class _FakeRentPriceClient extends RentPriceClient {
  final Map<RentPropertyType, Map<String, RentEstimate>> tables;
  final List<RentPropertyType> requested = [];

  _FakeRentPriceClient(this.tables);

  @override
  Future<Map<String, RentEstimate>?> fetchNational(
    RentPropertyType type, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    requested.add(type);
    onNetworkSuccess?.call();
    return tables[type] ?? {};
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_rent_cache_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  RentEstimate estimate(String commune) => RentEstimate(
    communeCode: commune,
    departmentCode: commune.substring(0, 2),
    loyerPredM2: 15,
    lowerBound: 12,
    upperBound: 18,
    predictionType: 'commune',
    sampleSize: 100,
  );

  test('télécharge et met en cache la table nationale au premier appel', () async {
    final client = _FakeRentPriceClient({
      RentPropertyType.appartement: {'75056': estimate('75056')},
    });
    final cache = RentPriceRepository(tempDir.path);
    final service = RentPriceService(client: client, cache: cache);

    final result = await service.estimateForCommune('75056', RentPropertyType.appartement);

    expect(result, isNotNull);
    expect(result!.loyerPredM2, 15);
    expect(client.requested, [RentPropertyType.appartement]);

    final cached = await cache.load(RentPropertyType.appartement);
    expect(cached, hasLength(1));
  });

  test('un second appel utilise le cache, aucune nouvelle requête réseau', () async {
    final client = _FakeRentPriceClient({
      RentPropertyType.maison: {'80021': estimate('80021')},
    });
    final cache = RentPriceRepository(tempDir.path);
    await cache.save(RentPropertyType.maison, {'80021': estimate('80021')});

    final service = RentPriceService(client: client, cache: cache);
    final result = await service.estimateForCommune('80021', RentPropertyType.maison);

    expect(result, isNotNull);
    expect(client.requested, isEmpty);
  });

  test('commune absente de la table : null', () async {
    final client = _FakeRentPriceClient({
      RentPropertyType.appartement: {'75056': estimate('75056')},
    });
    final service = RentPriceService(
      client: client,
      cache: RentPriceRepository(tempDir.path),
    );

    final result = await service.estimateForCommune('99999', RentPropertyType.appartement);

    expect(result, isNull);
  });
}

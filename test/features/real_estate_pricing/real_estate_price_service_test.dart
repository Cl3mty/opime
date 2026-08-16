import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/dvf_cache_repository.dart';
import 'package:opime/features/real_estate_pricing/geo_dvf_client.dart';
import 'package:opime/features/real_estate_pricing/price_estimator.dart';
import 'package:opime/features/real_estate_pricing/real_estate_price_service.dart';

/// Même convention que `_FakeYahooFinanceClient`/`_FakeCoinGeckoClient`
/// ailleurs dans ce dépôt : sous-classe surchargeant la méthode réseau,
/// aucun appel réseau réel.
class _FakeGeoDvfClient extends GeoDvfClient {
  final Map<String, List<DvfSale>> salesByKey;
  final List<String> requestedKeys = [];

  _FakeGeoDvfClient(this.salesByKey);

  @override
  Future<List<DvfSale>?> fetchCommuneYear({
    required String citycode,
    required int year,
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final key = '${citycode}_$year';
    requestedKeys.add(key);
    onNetworkSuccess?.call();
    return salesByKey[key] ?? [];
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_dvf_cache_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  DvfSale sale({double valeurFonciere = 300000, double surface = 100}) => DvfSale(
    natureMutation: 'Vente',
    valeurFonciere: valeurFonciere,
    typeLocal: 'Maison',
    surfaceReelleBati: surface,
    longitude: 2.35,
    latitude: 48.85,
    dateMutation: DateTime(2024, 6, 1),
    codeCommune: '75056',
  );

  test('interroge le client et met en cache sur succès', () async {
    final client = _FakeGeoDvfClient({
      '75056_2025': [for (var i = 0; i < 5; i++) sale()],
    });
    final cache = DvfCacheRepository(tempDir.path);
    final service = RealEstatePriceService(client: client, cache: cache);

    final result = await service.estimate(
      citycode: '75056',
      lat: 48.85,
      lon: 2.35,
      propertyType: PropertyTypeFilter.maison,
      years: [2025],
    );

    expect(result, isNotNull);
    expect(client.requestedKeys, ['75056_2025']);
    // Mis en cache : un second appel ne redemande pas le réseau.
    final cached = await cache.load('75056', 2025);
    expect(cached, hasLength(5));
  });

  test('un cache déjà rempli évite un nouvel appel réseau', () async {
    final client = _FakeGeoDvfClient({
      '75056_2025': [for (var i = 0; i < 5; i++) sale()],
    });
    final cache = DvfCacheRepository(tempDir.path);
    await cache.save('75056', 2025, [for (var i = 0; i < 5; i++) sale()]);

    final service = RealEstatePriceService(client: client, cache: cache);
    final result = await service.estimate(
      citycode: '75056',
      lat: 48.85,
      lon: 2.35,
      propertyType: PropertyTypeFilter.maison,
      years: [2025],
    );

    expect(result, isNotNull);
    expect(client.requestedKeys, isEmpty);
  });

  test('fusionne plusieurs années', () async {
    final client = _FakeGeoDvfClient({
      '75056_2025': [for (var i = 0; i < 2; i++) sale()],
      '75056_2024': [for (var i = 0; i < 3; i++) sale()],
    });
    final cache = DvfCacheRepository(tempDir.path);
    final service = RealEstatePriceService(client: client, cache: cache);

    final result = await service.estimate(
      citycode: '75056',
      lat: 48.85,
      lon: 2.35,
      propertyType: PropertyTypeFilter.maison,
      years: [2025, 2024],
    );

    expect(result!.sampleSize, 5);
    expect(client.requestedKeys, ['75056_2025', '75056_2024']);
  });
}

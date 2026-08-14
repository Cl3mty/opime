import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/price_history_repository.dart';
import 'package:opime/features/investments/yahoo_finance_client.dart';

/// Faux client Yahoo Finance : [onFetch] reçoit le `since` demandé et
/// renvoie les points à "trouver" pour ce test, sans aucun appel réseau —
/// [PriceHistoryRepository] ne dépend que de [YahooFinanceClient.fetchDailyHistory],
/// surchargée ici.
class _FakeYahooFinanceClient extends YahooFinanceClient {
  final List<PricePoint> Function(DateTime? since) onFetch;
  int fetchCount = 0;
  DateTime? lastSince;

  _FakeYahooFinanceClient(this.onFetch);

  @override
  Future<({List<PricePoint> points, String? currency})> fetchDailyHistory(
    String symbol, {
    DateTime? since,
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    fetchCount++;
    lastSince = since;
    onNetworkSuccess?.call();
    return (points: onFetch(since), currency: 'EUR');
  }
}

DateTime _dateOnly(DateTime date) => DateTime.utc(date.year, date.month, date.day);

void main() {
  late Directory tempDir;
  late DateTime today;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_price_history_test');
    today = _dateOnly(DateTime.now());
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
      'étend le cache vers le passé quand neededSince est antérieur au '
      'premier point connu (régression : une transaction ajoutée après '
      'coup, plus ancienne que tout l\'historique déjà en cache, ne '
      'l\'étendait jamais en arrière)', () async {
    final client = _FakeYahooFinanceClient((since) {
      // Le faux serveur renvoie tout l'historique demandé depuis `since`.
      final start = since!;
      return [
        for (var d = 0; d <= today.difference(start).inDays; d++)
          PricePoint(start.add(Duration(days: d)), 100 + d.toDouble()),
      ];
    });
    final repo = PriceHistoryRepository(tempDir.path, client: client);

    // Cache initial : ne couvre que les 5 derniers jours.
    final recentStart = today.subtract(const Duration(days: 5));
    await repo.save('FR0012345678', [
      for (var d = 0; d <= 5; d++)
        PricePoint(recentStart.add(Duration(days: d)), 200 + d.toDouble()),
    ]);

    final neededSince = today.subtract(const Duration(days: 400));
    final result = await repo.syncIfNeeded(
      'FR0012345678',
      'TTE.PA',
      neededSince: neededSince,
    );

    expect(client.fetchCount, 1);
    expect(client.lastSince, neededSince);
    expect(result.points.first.date, neededSince);
    expect(result.points.last.date, today);
  });

  test(
      'ne redemande rien si le cache couvre déjà [neededSince, aujourd\'hui]',
      () async {
    final client = _FakeYahooFinanceClient((since) => []);
    final repo = PriceHistoryRepository(tempDir.path, client: client);

    final neededSince = today.subtract(const Duration(days: 10));
    await repo.save('FR0012345678', [
      for (var d = 0; d <= 10; d++)
        PricePoint(neededSince.add(Duration(days: d)), 100 + d.toDouble()),
    ]);

    final result = await repo.syncIfNeeded(
      'FR0012345678',
      'TTE.PA',
      neededSince: neededSince,
    );

    expect(client.fetchCount, 0);
    expect(result.upToDate, isTrue);
    expect(result.points, hasLength(11));
  });

  test(
      'comble par interpolation un trou de quelques jours dans la réponse '
      '(source ponctuellement indisponible malgré la requête)', () async {
    final start = today.subtract(const Duration(days: 20));
    final client = _FakeYahooFinanceClient((since) {
      // Trou volontaire de 6 jours (> minGapDays, <= maxGapDays) entre le
      // 4e et le 10e jour.
      return [
        for (var d = 0; d <= 20; d++)
          if (d <= 4 || d >= 10)
            PricePoint(start.add(Duration(days: d)), 100 + d.toDouble()),
      ];
    });
    final repo = PriceHistoryRepository(tempDir.path, client: client);

    final result = await repo.syncIfNeeded(
      'FR0012345678',
      'TTE.PA',
      neededSince: start,
    );

    // Les jours 5 à 9 doivent avoir été comblés par interpolation linéaire
    // entre la valeur du jour 4 (104) et celle du jour 10 (110).
    final byDate = {for (final p in result.points) p.date: p.close};
    for (var d = 5; d <= 9; d++) {
      final expected = 104 + (110 - 104) * (d - 4) / (10 - 4);
      expect(
        byDate[start.add(Duration(days: d))],
        closeTo(expected, 1e-9),
        reason: 'jour $d non interpolé comme attendu',
      );
    }
  });

  test(
      'ne comble jamais un trou de week-end (2-3 jours) — la dernière '
      'valeur connue fait déjà foi jusqu\'au point suivant', () async {
    final start = today.subtract(const Duration(days: 10));
    final client = _FakeYahooFinanceClient((since) {
      // Vendredi (jour 0) puis lundi (jour 3) : trou de week-end normal.
      return [
        PricePoint(start, 100),
        PricePoint(start.add(const Duration(days: 3)), 110),
      ];
    });
    final repo = PriceHistoryRepository(tempDir.path, client: client);

    final result = await repo.syncIfNeeded(
      'FR0012345678',
      'TTE.PA',
      neededSince: start,
    );

    expect(result.points, hasLength(2));
  });

  test(
      'ne comble jamais un trou trop long (indisponibilité prolongée '
      'probable) — pas de tendance inventée sur plusieurs semaines',
      () async {
    final start = today.subtract(const Duration(days: 40));
    final client = _FakeYahooFinanceClient((since) {
      return [
        PricePoint(start, 100),
        PricePoint(start.add(const Duration(days: 30)), 200),
      ];
    });
    final repo = PriceHistoryRepository(tempDir.path, client: client);

    final result = await repo.syncIfNeeded(
      'FR0012345678',
      'TTE.PA',
      neededSince: start,
    );

    expect(result.points, hasLength(2));
  });
}

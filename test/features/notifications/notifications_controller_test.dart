import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/yahoo_finance_client.dart';
import 'package:opime/features/notifications/coingecko_client.dart';
import 'package:opime/features/notifications/notification_models.dart';
import 'package:opime/features/notifications/notifications_controller.dart';

/// Faux client Yahoo : renvoie les articles préparés pour le [query] reçu,
/// sans aucun appel réseau — même convention que `_FakeYahooFinanceClient`
/// dans `test/features/investments/price_history_repository_test.dart`.
class _FakeYahooFinanceClient extends YahooFinanceClient {
  final Map<String, List<NewsArticleItem>> newsByQuery;
  final List<String> queriesReceived = [];

  _FakeYahooFinanceClient(this.newsByQuery);

  @override
  Future<List<NewsArticleItem>> fetchNews(
    String query, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    queriesReceived.add(query);
    onNetworkSuccess?.call();
    return newsByQuery[query] ?? [];
  }
}

class _FakeCoinGeckoClient extends CoinGeckoClient {
  final Map<String, String> coinIdByTicker;
  final List<CoinMarketData> marketData;
  final List<String> resolveQueriesReceived = [];
  List<String>? marketDataIdsReceived;

  _FakeCoinGeckoClient({required this.coinIdByTicker, required this.marketData});

  @override
  Future<String?> resolveCoinId(
    String ticker, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    resolveQueriesReceived.add(ticker);
    onNetworkSuccess?.call();
    return coinIdByTicker[ticker];
  }

  @override
  Future<List<CoinMarketData>> fetchMarketData(
    List<String> coinIds, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    marketDataIdsReceived = coinIds;
    onNetworkSuccess?.call();
    return marketData;
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_notifications_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  InvestmentAccount stockAccount(Investment investment) => InvestmentAccount(
    assetClass: AssetClass.actionsEtFonds,
    name: 'CTO',
    investments: [investment],
  );

  InvestmentAccount cryptoAccount(Investment investment) => InvestmentAccount(
    assetClass: AssetClass.crypto,
    name: 'Wallet',
    investments: [investment],
  );

  Investment stock({required String isin, String? symbol}) => Investment(
    isin: isin,
    label: isin,
    symbol: symbol,
    transactions: const [],
  );

  Investment crypto(String ticker) => Investment(
    isin: ticker,
    label: ticker,
    transactions: const [],
  );

  test('actualités Yahoo pour un titre détenu, dédupliquées par uuid', () async {
    final article = NewsArticleItem(
      uuid: 'a1',
      title: 'Titre',
      publisher: 'Reuters',
      link: 'https://example.com/a1',
      publishedAt: DateTime.utc(2026, 8, 10),
      relatedSymbol: 'AAPL',
    );
    final yahoo = _FakeYahooFinanceClient({'AAPL': [article]});
    final coinGecko = _FakeCoinGeckoClient(coinIdByTicker: const {}, marketData: const []);
    final repo = InvestmentsRepository(tempDir.path);
    await repo.saveAccount(stockAccount(stock(isin: 'US0378331005', symbol: 'AAPL')));

    final controller = NotificationsController(yahoo: yahoo, coinGecko: coinGecko);
    await controller.refresh(tempDir.path);

    expect(controller.items, hasLength(1));
    expect((controller.items.first as NewsArticleItem).uuid, 'a1');
    expect(yahoo.queriesReceived, ['AAPL']);
  });

  test('titre détenu sans symbole résolu : requête par ISIN en repli', () async {
    final yahoo = _FakeYahooFinanceClient(const {});
    final coinGecko = _FakeCoinGeckoClient(coinIdByTicker: const {}, marketData: const []);
    final repo = InvestmentsRepository(tempDir.path);
    await repo.saveAccount(stockAccount(stock(isin: 'US0378331005')));

    final controller = NotificationsController(yahoo: yahoo, coinGecko: coinGecko);
    await controller.refresh(tempDir.path);

    expect(yahoo.queriesReceived, ['US0378331005']);
  });

  test('alerte crypto générée seulement au-delà du seuil de notabilité', () async {
    final yahoo = _FakeYahooFinanceClient(const {});
    final coinGecko = _FakeCoinGeckoClient(
      coinIdByTicker: const {'BTC': 'bitcoin', 'ETH': 'ethereum'},
      marketData: [
        CoinMarketData(
          id: 'bitcoin', symbol: 'BTC', name: 'Bitcoin',
          currentPrice: 50000, changePercent24h: 8.0, changePercent7d: -1.0,
        ),
        CoinMarketData(
          id: 'ethereum', symbol: 'ETH', name: 'Ethereum',
          currentPrice: 3000, changePercent24h: 1.0, changePercent7d: 2.0,
        ),
      ],
    );
    final repo = InvestmentsRepository(tempDir.path);
    await repo.saveAccount(cryptoAccount(crypto('BTC')));
    await repo.saveAccount(cryptoAccount(crypto('ETH')));

    final controller = NotificationsController(yahoo: yahoo, coinGecko: coinGecko);
    await controller.refresh(tempDir.path);

    expect(controller.items, hasLength(1));
    expect((controller.items.first as CryptoAlertItem).symbol, 'BTC');
    // Un seul appel groupé pour toutes les cryptos détenues.
    expect(coinGecko.marketDataIdsReceived, unorderedEquals(['bitcoin', 'ethereum']));
  });

  test('alerte exactement au seuil (5%) est générée (test de borne)', () async {
    final yahoo = _FakeYahooFinanceClient(const {});
    final coinGecko = _FakeCoinGeckoClient(
      coinIdByTicker: const {'BTC': 'bitcoin'},
      marketData: [
        CoinMarketData(
          id: 'bitcoin', symbol: 'BTC', name: 'Bitcoin',
          currentPrice: 50000, changePercent24h: 5.0, changePercent7d: null,
        ),
      ],
    );
    final repo = InvestmentsRepository(tempDir.path);
    await repo.saveAccount(cryptoAccount(crypto('BTC')));

    final controller = NotificationsController(yahoo: yahoo, coinGecko: coinGecko);
    await controller.refresh(tempDir.path);

    expect(controller.items, hasLength(1));
  });

  test('fusion et tri par date décroissante entre Yahoo et CoinGecko', () async {
    final older = NewsArticleItem(
      uuid: 'old', title: 'Ancien', publisher: 'P', link: 'https://x/old',
      publishedAt: DateTime.utc(2026, 1, 1), relatedSymbol: 'AAPL',
    );
    final yahoo = _FakeYahooFinanceClient({'AAPL': [older]});
    final coinGecko = _FakeCoinGeckoClient(
      coinIdByTicker: const {'BTC': 'bitcoin'},
      marketData: [
        CoinMarketData(
          id: 'bitcoin', symbol: 'BTC', name: 'Bitcoin',
          currentPrice: 50000, changePercent24h: 10.0, changePercent7d: null,
        ),
      ],
    );
    final repo = InvestmentsRepository(tempDir.path);
    await repo.saveAccount(stockAccount(stock(isin: 'US0378331005', symbol: 'AAPL')));
    await repo.saveAccount(cryptoAccount(crypto('BTC')));

    final controller = NotificationsController(yahoo: yahoo, coinGecko: coinGecko);
    await controller.refresh(tempDir.path);

    // L'alerte crypto (observée maintenant) est plus récente que l'article
    // Yahoo daté du 1er janvier 2026 : elle doit passer en premier.
    expect(controller.items.first, isA<CryptoAlertItem>());
    expect(controller.items.last, isA<NewsArticleItem>());
  });

  test('positions en devise et classes hors actions/crypto sont exclues', () async {
    final yahoo = _FakeYahooFinanceClient(const {});
    final coinGecko = _FakeCoinGeckoClient(coinIdByTicker: const {}, marketData: const []);
    final repo = InvestmentsRepository(tempDir.path);
    // Épargne en devise (isCurrency) : ne doit générer aucune requête.
    await repo.saveAccount(
      InvestmentAccount(
        assetClass: AssetClass.epargne,
        name: 'Livret',
        investments: [stock(isin: 'EUR')],
      ),
    );

    final controller = NotificationsController(yahoo: yahoo, coinGecko: coinGecko);
    await controller.refresh(tempDir.path);

    expect(controller.items, isEmpty);
    expect(yahoo.queriesReceived, isEmpty);
    expect(coinGecko.resolveQueriesReceived, isEmpty);
  });

  group('unreadCount', () {
    test('sans lastSeen, tous les éléments sont non lus', () async {
      final article = NewsArticleItem(
        uuid: 'a1', title: 'T', publisher: 'P', link: 'https://x/a1',
        publishedAt: DateTime.utc(2026, 8, 10), relatedSymbol: 'AAPL',
      );
      final yahoo = _FakeYahooFinanceClient({'AAPL': [article]});
      final coinGecko = _FakeCoinGeckoClient(coinIdByTicker: const {}, marketData: const []);
      final repo = InvestmentsRepository(tempDir.path);
      await repo.saveAccount(stockAccount(stock(isin: 'US0378331005', symbol: 'AAPL')));

      final controller = NotificationsController(yahoo: yahoo, coinGecko: coinGecko);
      await controller.refresh(tempDir.path);

      expect(controller.unreadCount.value, 1);
    });

    test('markAllSeen exclut les éléments antérieurs à la date de consultation', () async {
      final article = NewsArticleItem(
        uuid: 'a1', title: 'T', publisher: 'P', link: 'https://x/a1',
        publishedAt: DateTime.utc(2026, 8, 10), relatedSymbol: 'AAPL',
      );
      final yahoo = _FakeYahooFinanceClient({'AAPL': [article]});
      final coinGecko = _FakeCoinGeckoClient(coinIdByTicker: const {}, marketData: const []);
      final repo = InvestmentsRepository(tempDir.path);
      await repo.saveAccount(stockAccount(stock(isin: 'US0378331005', symbol: 'AAPL')));

      final controller = NotificationsController(yahoo: yahoo, coinGecko: coinGecko);
      controller.markAllSeen(DateTime.utc(2026, 8, 20));
      await controller.refresh(tempDir.path, lastSeen: DateTime.utc(2026, 8, 20));

      expect(controller.unreadCount.value, 0);
    });
  });
}

import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;

/// Données de marché CoinGecko pour une cryptomonnaie — champs mappés
/// directement depuis `/api/v3/coins/markets` (confirmés par un appel
/// réel : `id`, `symbol`, `name`, `current_price`,
/// `price_change_percentage_24h_in_currency`,
/// `price_change_percentage_7d_in_currency` — ces deux derniers
/// n'apparaissent que si `price_change_percentage=24h,7d` est demandé).
class CoinMarketData {
  final String id;
  final String symbol;
  final String name;
  final double currentPrice;
  final double? changePercent24h;
  final double? changePercent7d;

  CoinMarketData({
    required this.id,
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.changePercent24h,
    required this.changePercent7d,
  });

  factory CoinMarketData.fromJson(Map<String, dynamic> json) => CoinMarketData(
    id: json['id'] as String? ?? '',
    symbol: (json['symbol'] as String? ?? '').toUpperCase(),
    name: json['name'] as String? ?? '',
    currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0,
    changePercent24h: (json['price_change_percentage_24h_in_currency'] as num?)
        ?.toDouble(),
    changePercent7d: (json['price_change_percentage_7d_in_currency'] as num?)
        ?.toDouble(),
  );
}

/// Client pour l'API publique et gratuite de CoinGecko (pas de clé
/// nécessaire pour ces deux endpoints — vérifié : `/api/v3/news`, lui,
/// répond 401 sans clé payante, donc non utilisé ici, voir
/// `notifications_controller.dart`). Même philosophie défensive que
/// [YahooFinanceClient] (`investments/yahoo_finance_client.dart`) : chaque
/// appel est protégé par un `try/catch`, un échec réseau retourne
/// simplement un résultat vide plutôt que de propager une exception.
class CoinGeckoClient {
  /// Résout un ticker (ex : "BTC") vers l'identifiant CoinGecko
  /// correspondant (ex : "bitcoin") via `/search` — pas de table de
  /// correspondance codée en dur : les rebrands (MATIC → POL, vérifié en
  /// direct) la rendraient périmée silencieusement. Prend le premier
  /// résultat de `coins` dont `symbol` correspond exactement (insensible à
  /// la casse) au ticker demandé — CoinGecko trie déjà par pertinence/
  /// capitalisation, donc une correspondance de nom approximative n'est
  /// jamais utilisée en repli. `null` si aucun résultat ne correspond
  /// exactement, ou en cas d'échec réseau.
  Future<String?> resolveCoinId(
    String ticker, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.coingecko.com/api/v3/search'
          '?query=${Uri.encodeComponent(ticker)}',
        ),
      );
      onNetworkSuccess?.call();
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final coins = json['coins'] as List?;
      if (coins == null || coins.isEmpty) return null;
      final normalized = ticker.trim().toUpperCase();
      for (final entry in coins) {
        final coin = entry as Map<String, dynamic>;
        if ((coin['symbol'] as String?)?.toUpperCase() == normalized) {
          return coin['id'] as String?;
        }
      }
      return null;
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

  /// Prix et variations 24h/7j pour un lot d'identifiants CoinGecko, en un
  /// seul appel groupé (peu importe le nombre de cryptos détenues). Liste
  /// vide si [coinIds] est vide ou en cas d'échec réseau.
  Future<List<CoinMarketData>> fetchMarketData(
    List<String> coinIds, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    if (coinIds.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.coingecko.com/api/v3/coins/markets'
          '?vs_currency=eur&ids=${coinIds.map(Uri.encodeComponent).join(",")}'
          '&price_change_percentage=24h,7d',
        ),
      );
      onNetworkSuccess?.call();
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body) as List;
      return json
          .map((e) => CoinMarketData.fromJson(e as Map<String, dynamic>))
          .toList();
    } on SocketException catch (_) {
      onNetworkError?.call();
      return [];
    } on http.ClientException catch (_) {
      onNetworkError?.call();
      return [];
    } on TimeoutException catch (_) {
      onNetworkError?.call();
      return [];
    } catch (_) {
      return [];
    }
  }
}

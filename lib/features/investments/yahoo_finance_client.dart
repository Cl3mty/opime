import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;

/// Un point de cours quotidien (clôture) pour un actif.
class PricePoint {
  final DateTime date;
  final double close;

  const PricePoint(this.date, this.close);
}

/// Cryptomonnaies majeures, choisies pour leur liquidité et la fiabilité de
/// leur cotation `TICKER-EUR` sur Yahoo Finance — proposées en liste
/// déroulante à la création d'un investissement crypto plutôt qu'en texte
/// libre (voir `investments_models.dart`'s `identifierOptionsFor`), pour
/// éviter un ticker mal orthographié ou inexistant sur Yahoo Finance.
const kKnownCryptoTickers = [
  'BTC',
  'ETH',
  'USDT',
  'BNB',
  'SOL',
  'XRP',
  'USDC',
  'ADA',
  'DOGE',
  'AVAX',
  'TRX',
  'DOT',
  'LINK',
  'MATIC',
  'LTC',
  'BCH',
  'XLM',
  'ATOM',
  'ETC',
  'UNI',
];

/// Client pour l'API gratuite et non officielle de Yahoo Finance (pas de
/// clé, pas de garantie de disponibilité ni de contrat de service) — même
/// philosophie défensive que [UpdateChecker]
/// (`core/updates/update_checker.dart`) : chaque appel est protégé par un
/// `try/catch`, un échec réseau retourne simplement un résultat vide
/// plutôt que de propager une exception, pour ne jamais bloquer l'UI. En
/// cas d'échec, l'app retombe sur la valorisation au coût d'achat déjà en
/// place avant l'intégration de cette API.
class YahooFinanceClient {
  /// Construit directement le ticker Yahoo Finance d'une cryptomonnaie
  /// (ex : "BTC" → "BTC-EUR", voir
  /// https://finance.yahoo.com/quote/BTC-EUR/) plutôt que de passer par
  /// [resolveSymbol] : les cryptos n'ont pas de code ISIN, donc la
  /// recherche par ISIN échoue systématiquement pour elles. Le libellé
  /// entré par l'utilisateur (simple ticker, ou déjà au format Yahoo
  /// `TICKER-DEVISE`) est normalisé plutôt que résolu via une recherche
  /// réseau, en devise euro par défaut pour rester cohérent avec le reste
  /// de l'application (`displayEuros`).
  String resolveCryptoSymbol(String ticker) {
    final normalized = ticker.trim().toUpperCase();
    return normalized.contains('-') ? normalized : '$normalized-EUR';
  }

  /// Résout un code ISIN vers le ticker Yahoo Finance correspondant, ou
  /// `null` si la recherche échoue ou ne retourne aucun résultat.
  ///
  /// [onNetworkError] et [onNetworkSuccess] distinguent une véritable
  /// coupure réseau (pour piloter [PriceSyncStatusController]) d'une
  /// simple absence de résultat (ISIN inconnu de Yahoo Finance) : le
  /// second cas obtient bien une réponse du serveur, donc n'indique aucun
  /// problème de connexion.
  Future<String?> resolveSymbol(
    String isin, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://query1.finance.yahoo.com/v1/finance/search'
          '?q=${Uri.encodeComponent(isin)}',
        ),
      );
      onNetworkSuccess?.call();
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final quotes = json['quotes'] as List?;
      if (quotes == null || quotes.isEmpty) return null;
      final first = quotes.first as Map<String, dynamic>;
      return first['symbol'] as String?;
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

  /// Historique quotidien des cours de clôture. Si [since] est fourni, ne
  /// demande que la période depuis cette date (avec un jour de marge, pour
  /// couvrir le dernier point déjà en cache) ; sinon récupère 5 ans.
  Future<List<PricePoint>> fetchDailyHistory(
    String symbol, {
    DateTime? since,
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    try {
      final uri = since != null
          ? Uri.parse(
              'https://query1.finance.yahoo.com/v8/finance/chart/'
              '${Uri.encodeComponent(symbol)}?interval=1d'
              '&period1=${_epochSeconds(since.subtract(const Duration(days: 1)))}'
              '&period2=${_epochSeconds(DateTime.now())}',
            )
          : Uri.parse(
              'https://query1.finance.yahoo.com/v8/finance/chart/'
              '${Uri.encodeComponent(symbol)}?interval=1d&range=5y',
            );
      final response = await http.get(uri);
      onNetworkSuccess?.call();
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results =
          (json['chart'] as Map<String, dynamic>?)?['result'] as List?;
      if (results == null || results.isEmpty) return [];
      final result = results.first as Map<String, dynamic>;

      final points = <PricePoint>[];
      final timestamps = (result['timestamp'] as List?)?.cast<num>();
      final quoteList =
          (result['indicators'] as Map<String, dynamic>?)?['quote'] as List?;
      final closes = (quoteList != null && quoteList.isNotEmpty)
          ? (quoteList.first as Map<String, dynamic>)['close'] as List?
          : null;
      if (timestamps != null && closes != null) {
        for (var i = 0; i < timestamps.length && i < closes.length; i++) {
          final close = closes[i];
          if (close == null) continue;
          final utcDate = DateTime.fromMillisecondsSinceEpoch(
            timestamps[i].toInt() * 1000,
            isUtc: true,
          );
          points.add(
            PricePoint(
              DateTime.utc(utcDate.year, utcDate.month, utcDate.day),
              (close as num).toDouble(),
            ),
          );
        }
      }

      // Repli pour les fonds/ETC sans historique quotidien : certains (ex :
      // un ETC or coté à Stuttgart, `FR0013416716.SG`) sont bien résolus
      // par l'API search mais n'exposent aucun point via l'API chart —
      // seulement un prix en direct dans `meta.regularMarketPrice`. Sans ce
      // repli sur ce dernier cours, leur investissement resterait à jamais
      // "cours introuvable" malgré un prix bien réel sur Yahoo.
      if (points.isEmpty) {
        final meta = result['meta'] as Map<String, dynamic>?;
        final metaTime = (meta?['regularMarketTime'] as num?)?.toInt();
        final metaPrice = (meta?['regularMarketPrice'] as num?)?.toDouble();
        if (metaTime != null && metaPrice != null) {
          final utcDate = DateTime.fromMillisecondsSinceEpoch(
            metaTime * 1000,
            isUtc: true,
          );
          points.add(
            PricePoint(
              DateTime.utc(utcDate.year, utcDate.month, utcDate.day),
              metaPrice,
            ),
          );
        }
      }
      return points;
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

  int _epochSeconds(DateTime date) => date.millisecondsSinceEpoch ~/ 1000;
}

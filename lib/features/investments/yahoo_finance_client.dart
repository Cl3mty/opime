import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import '../notifications/notification_models.dart' show NewsArticleItem;

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

/// Suffixe de ticker Yahoo Finance (place de cotation, ex ".PA" = Paris) →
/// code pays ISO 3166-1 alpha-2 utilisé par [kInvestmentCountries]. Liste
/// volontairement non exhaustive et conservatrice : seules les places dont
/// le suffixe est documenté et sans ambiguïté sont incluses — mieux vaut
/// laisser [YahooFinanceClient.countryCodeForSymbol] renvoyer `null` (et
/// laisser l'utilisateur classer à la main, voir [Investment.countryCode])
/// que risquer un pays erroné sur une place mal identifiée.
///
/// Piège volontairement évité : le suffixe Yahoo de la Bourse de Berlin est
/// ".BE", qui collisionnerait visuellement avec le code ISO de la Belgique
/// ("BE") — cette place allemande mineure est donc délibérément absente de
/// la table plutôt que risquer la confusion ; Bruxelles (Belgique) est
/// ".BR", sans ambiguïté.
const _yahooSuffixToCountryCode = <String, String>{
  // Amérique du Nord/Sud
  'TO': 'CA', 'V': 'CA', 'CN': 'CA', 'NE': 'CA',
  'MX': 'MX',
  'SA': 'BR',
  'BA': 'AR',
  'SN': 'CL',
  // Europe
  'L': 'GB',
  'PA': 'FR',
  'DE': 'DE', 'F': 'DE', 'MU': 'DE', 'SG': 'DE', 'DU': 'DE', 'HM': 'DE', 'HA': 'DE',
  'BR': 'BE',
  'AS': 'NL',
  'LS': 'PT',
  'MI': 'IT',
  'MC': 'ES',
  'SW': 'CH', 'VX': 'CH',
  'ST': 'SE',
  'OL': 'NO',
  'CO': 'DK',
  'HE': 'FI',
  'VI': 'AT',
  'AT': 'GR', // Bourse d'Athènes — pas le code ISO de l'Autriche (voir [VI] ci-dessus).
  'WA': 'PL',
  // Asie-Pacifique
  'T': 'JP',
  'SS': 'CN', 'SZ': 'CN',
  'HK': 'HK',
  'TW': 'TW', 'TWO': 'TW',
  'KS': 'KR', 'KQ': 'KR',
  'NS': 'IN', 'BO': 'IN',
  'SI': 'SG',
  'JK': 'ID',
  'BK': 'TH',
  'KL': 'MY',
  'AX': 'AU',
  'NZ': 'NZ',
  // Moyen-Orient / Afrique
  'JO': 'ZA',
  'SR': 'SA',
  'TA': 'IL',
  'IS': 'TR',
};

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

  /// Déduit le pays de cotation d'un ticker Yahoo Finance depuis son
  /// suffixe de place boursière (ex : "TTE.PA" → "FR", voir
  /// [_yahooSuffixToCountryCode]) — `null` sans suffixe reconnu, y compris
  /// pour un ticker sans suffixe du tout (place américaine, mais aussi
  /// parfois une paire de change ou un ticker crypto : pas assez fiable
  /// pour en déduire "US" par défaut).
  String? countryCodeForSymbol(String symbol) {
    final dotIndex = symbol.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == symbol.length - 1) return null;
    final suffix = symbol.substring(dotIndex + 1).toUpperCase();
    return _yahooSuffixToCountryCode[suffix];
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

  /// Secteur d'activité (vocabulaire Yahoo brut, ex "Technology" — à
  /// convertir en [Sector] via `Sector.fromYahooLabel` côté appelant,
  /// `investments_models.dart` n'étant pas une dépendance de ce fichier),
  /// pays de cotation (voir [countryCodeForSymbol]), et type d'instrument
  /// brut Yahoo (ex "EQUITY", "ETF", "MUTUALFUND" — à convertir en
  /// [FundStyle] via `FundStyle.fromYahooQuoteType` côté appelant, même
  /// raison) pour [symbol], déjà résolu au préalable (ex : par
  /// [resolveSymbol]). Chaque champ est `null` indépendamment des autres si
  /// l'info manque — la plupart des ETF/fonds n'ont par exemple pas de
  /// secteur chez Yahoo, contrairement aux actions individuelles, mais ont
  /// bien un suffixe de place de cotation exploitable.
  ///
  /// Même philosophie défensive que le reste du client : jamais
  /// d'exception propagée, un échec (réseau, symbole inconnu, réponse
  /// inattendue) renvoie simplement des champs `null` — l'investissement
  /// reste alors "non classé" comme avant cet appel, à retenter au
  /// prochain rafraîchissement plutôt que d'être marqué en échec permanent
  /// (voir `price_refresh_service.dart`, qui ne retente que tant que
  /// [Investment.sector]/[Investment.countryCode]/[Investment.fundStyle]
  /// restent `null`).
  Future<({String? sector, String? countryCode, String? quoteType})>
  fetchClassification(
    String symbol, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://query1.finance.yahoo.com/v1/finance/search'
          '?q=${Uri.encodeComponent(symbol)}',
        ),
      );
      onNetworkSuccess?.call();
      if (response.statusCode != 200) {
        return (sector: null, countryCode: null, quoteType: null);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final quotes = json['quotes'] as List?;
      if (quotes == null || quotes.isEmpty) {
        return (sector: null, countryCode: null, quoteType: null);
      }
      // Le symbole cherché est déjà connu avec certitude (contrairement à
      // [resolveSymbol], parti d'un ISIN) : on cherche sa propre entrée
      // exacte dans les résultats plutôt que de faire confiance au premier
      // (le meilleur score de recherche peut être un homonyme sur une
      // autre place), avec repli sur le premier résultat si l'exact match
      // n'apparaît pas (réponse Yahoo parfois incomplète).
      final match = quotes.cast<Map<String, dynamic>>().firstWhere(
        (q) => (q['symbol'] as String?)?.toUpperCase() == symbol.toUpperCase(),
        orElse: () => quotes.first as Map<String, dynamic>,
      );
      return (
        sector: match['sector'] as String?,
        countryCode: countryCodeForSymbol(symbol),
        quoteType: match['quoteType'] as String?,
      );
    } on SocketException catch (_) {
      onNetworkError?.call();
      return (sector: null, countryCode: null, quoteType: null);
    } on http.ClientException catch (_) {
      onNetworkError?.call();
      return (sector: null, countryCode: null, quoteType: null);
    } on TimeoutException catch (_) {
      onNetworkError?.call();
      return (sector: null, countryCode: null, quoteType: null);
    } catch (_) {
      return (sector: null, countryCode: null, quoteType: null);
    }
  }

  /// Historique quotidien des cours de clôture. Si [since] est fourni, ne
  /// demande que la période depuis cette date (avec un jour de marge, pour
  /// couvrir le dernier point déjà en cache) ; sinon récupère 5 ans.
  ///
  /// Retourne aussi la devise de cotation de l'actif (`meta.currency` de
  /// l'API chart — `USD` pour META, `EUR` pour un titre français, ...) :
  /// c'est elle qui permet de savoir si le cours brut doit être converti en
  /// euros pour valoriser la position (voir `price_refresh_service.dart`).
  /// `null` si l'API n'expose pas ce champ.
  Future<({List<PricePoint> points, String? currency})> fetchDailyHistory(
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
      if (response.statusCode != 200) {
        return (points: const <PricePoint>[], currency: null);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results =
          (json['chart'] as Map<String, dynamic>?)?['result'] as List?;
      if (results == null || results.isEmpty) {
        return (points: const <PricePoint>[], currency: null);
      }
      final result = results.first as Map<String, dynamic>;

      final meta = result['meta'] as Map<String, dynamic>?;
      final currency = meta?['currency'] as String?;

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
      return (points: points, currency: currency);
    } on SocketException catch (_) {
      onNetworkError?.call();
      return (points: const <PricePoint>[], currency: null);
    } on http.ClientException catch (_) {
      onNetworkError?.call();
      return (points: const <PricePoint>[], currency: null);
    } on TimeoutException catch (_) {
      onNetworkError?.call();
      return (points: const <PricePoint>[], currency: null);
    } catch (_) {
      return (points: const <PricePoint>[], currency: null);
    }
  }

  /// Actualités liées à [query] (ticker de préférence — [Investment.symbol]
  /// — ISIN en repli si le cours n'a pas encore été résolu), extraites du
  /// même endpoint de recherche que [resolveSymbol] (le champ `news`,
  /// jusqu'ici totalement ignoré) — appel séparé de [resolveSymbol] car les
  /// deux sont invoqués à des moments différents (résolution de cours
  /// pendant le rafraîchissement des prix, actualités au démarrage/à
  /// l'ouverture du panneau de notifications), pas dans la même passe. Ne
  /// garde que les entrées avec un identifiant et un lien exploitables.
  Future<List<NewsArticleItem>> fetchNews(
    String query, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://query1.finance.yahoo.com/v1/finance/search'
          '?q=${Uri.encodeComponent(query)}',
        ),
      );
      onNetworkSuccess?.call();
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final news = json['news'] as List?;
      if (news == null) return [];
      return news
          .map((e) {
            final item = e as Map<String, dynamic>;
            final publishTime = (item['providerPublishTime'] as num?)
                ?.toInt();
            return NewsArticleItem(
              uuid: item['uuid'] as String? ?? '',
              title: item['title'] as String? ?? '',
              publisher: item['publisher'] as String? ?? '',
              link: item['link'] as String? ?? '',
              publishedAt: publishTime != null
                  ? DateTime.fromMillisecondsSinceEpoch(publishTime * 1000)
                  : DateTime.now(),
              relatedSymbol: query,
            );
          })
          .where((a) => a.uuid.isNotEmpty && a.link.isNotEmpty)
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

  int _epochSeconds(DateTime date) => date.millisecondsSinceEpoch ~/ 1000;
}

/// Un élément du panneau de notifications : soit un article Yahoo Finance
/// pour un titre détenu ([NewsArticleItem]), soit une alerte de variation de
/// prix CoinGecko pour une crypto détenue ([CryptoAlertItem]). Interlacés
/// dans une seule liste triée par [sortKey] (le plus récent en premier) par
/// `NotificationsController`. Aucune dépendance vers `investments/` ici,
/// pour éviter tout couplage circulaire avec `yahoo_finance_client.dart`
/// (qui, lui, dépend de ce fichier).
abstract class NotificationItem {
  DateTime get sortKey;
}

class NewsArticleItem extends NotificationItem {
  /// Clé de déduplication — un même article peut ressortir pour deux
  /// titres détenus (ex : une actualité sectorielle citant plusieurs
  /// entreprises du portefeuille).
  final String uuid;
  final String title;
  final String publisher;
  final String link;
  final DateTime publishedAt;

  /// Ticker/ISIN interrogé qui a produit ce résultat.
  final String relatedSymbol;

  NewsArticleItem({
    required this.uuid,
    required this.title,
    required this.publisher,
    required this.link,
    required this.publishedAt,
    required this.relatedSymbol,
  });

  @override
  DateTime get sortKey => publishedAt;
}

class CryptoAlertItem extends NotificationItem {
  /// Seuil (en %, valeur absolue) au-delà duquel une variation de prix sur
  /// 24h ou 7j est jugée assez notable pour générer une alerte — pas une
  /// alerte pour chaque crypto détenue à chaque rafraîchissement, seulement
  /// les mouvements significatifs.
  static const notableThreshold = 5.0;

  final String coinId;
  final String symbol;
  final String name;
  final double currentPrice;
  final double? changePercent24h;
  final double? changePercent7d;

  /// Moment du calcul — CoinGecko ne fournit pas de timestamp serveur
  /// fiable pour une variation de prix (contrairement à un article daté).
  final DateTime observedAt;

  CryptoAlertItem({
    required this.coinId,
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.changePercent24h,
    required this.changePercent7d,
    required this.observedAt,
  });

  @override
  DateTime get sortKey => observedAt;
}

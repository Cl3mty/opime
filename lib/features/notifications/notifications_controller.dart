import 'package:flutter/foundation.dart';
import '../investments/investments_models.dart' show AssetClass;
import '../investments/investments_repository.dart';
import '../investments/yahoo_finance_client.dart';
import 'coingecko_client.dart';
import 'notification_models.dart';

/// Orchestre le chargement des notifications pour le profil actif :
/// actualités Yahoo Finance pour chaque action/ETF détenu, alertes de
/// variation de prix CoinGecko pour chaque crypto détenue. Ne lève jamais
/// d'exception — chaque sous-appel réseau se protège déjà lui-même (voir
/// [YahooFinanceClient]/[CoinGeckoClient]).
class NotificationsController extends ChangeNotifier {
  final YahooFinanceClient _yahoo;
  final CoinGeckoClient _coinGecko;

  NotificationsController({YahooFinanceClient? yahoo, CoinGeckoClient? coinGecko})
    : _yahoo = yahoo ?? YahooFinanceClient(),
      _coinGecko = coinGecko ?? CoinGeckoClient();

  List<NotificationItem> _items = [];
  List<NotificationItem> get items => List.unmodifiable(_items);

  bool _loading = false;
  bool get loading => _loading;

  DateTime? _lastSeen;

  /// Nombre d'éléments plus récents que la dernière consultation — même
  /// pattern que `AssistantChatController.unreadResponses`, pour que le
  /// badge de la top bar ne se reconstruise que sur ce compteur, pas sur
  /// tout le controller.
  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  @override
  void dispose() {
    unreadCount.dispose();
    super.dispose();
  }

  /// Recharge la liste pour le vault [vaultPath] : actualités Yahoo pour
  /// chaque action/ETF détenu, alertes de variation CoinGecko pour chaque
  /// crypto détenue dont la variation dépasse
  /// [CryptoAlertItem.notableThreshold].
  Future<void> refresh(String vaultPath, {DateTime? lastSeen}) async {
    _lastSeen = lastSeen ?? _lastSeen;
    _loading = true;
    notifyListeners();

    final accounts = await InvestmentsRepository(vaultPath).listAll();

    final stockQueries = <String>{};
    final cryptoTickers = <String>{};
    for (final account in accounts) {
      for (final investment in account.investments) {
        if (investment.isCurrency) continue;
        final effectiveClass = investment.assetClass ?? account.assetClass;
        if (effectiveClass == AssetClass.crypto) {
          cryptoTickers.add(investment.isin.trim().toUpperCase());
        } else if (effectiveClass == AssetClass.actionsEtFonds) {
          final query = investment.symbol ?? investment.isin;
          if (query.isNotEmpty) stockQueries.add(query);
        }
      }
    }

    final items = <NotificationItem>[];

    // Actualités Yahoo : un appel par titre détenu — même échelle qu'un
    // rafraîchissement de cours (un appel réseau par investissement).
    final seenUuids = <String>{};
    for (final query in stockQueries) {
      final articles = await _yahoo.fetchNews(query);
      for (final article in articles) {
        if (seenUuids.add(article.uuid)) items.add(article);
      }
    }

    // Alertes crypto : résolution ticker -> id CoinGecko (une requête par
    // ticker distinct détenu), puis un seul appel groupé pour les prix.
    final coinIds = <String>[];
    for (final ticker in cryptoTickers) {
      final id = await _coinGecko.resolveCoinId(ticker);
      if (id != null) coinIds.add(id);
    }
    if (coinIds.isNotEmpty) {
      final market = await _coinGecko.fetchMarketData(coinIds);
      final now = DateTime.now();
      for (final coin in market) {
        final change24 = coin.changePercent24h;
        final change7 = coin.changePercent7d;
        final notable =
            (change24 != null &&
                change24.abs() >= CryptoAlertItem.notableThreshold) ||
            (change7 != null &&
                change7.abs() >= CryptoAlertItem.notableThreshold);
        if (!notable) continue;
        items.add(
          CryptoAlertItem(
            coinId: coin.id,
            symbol: coin.symbol,
            name: coin.name,
            currentPrice: coin.currentPrice,
            changePercent24h: change24,
            changePercent7d: change7,
            observedAt: now,
          ),
        );
      }
    }

    // Nettoyage automatique : un article Yahoo pour un titre peu suivi peut
    // rester le "plus récent" renvoyé par l'API pendant des semaines — sans
    // cette coupure, le panneau finirait par accumuler des actualités
    // obsolètes plutôt que de rester centré sur ce qui vient de se passer.
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    items.retainWhere((item) => item.sortKey.isAfter(cutoff));

    items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    _items = items;
    _loading = false;
    _recomputeUnread();
    notifyListeners();
  }

  void _recomputeUnread() {
    final seen = _lastSeen;
    unreadCount.value = seen == null
        ? _items.length
        : _items.where((i) => i.sortKey.isAfter(seen)).length;
  }

  /// Appelé à l'ouverture du panneau : remet le badge à zéro immédiatement,
  /// indépendamment de ce qu'un [refresh] en cours va ramener de nouveau —
  /// "vu" signifie "panneau ouvert", pas "chaque élément lu
  /// individuellement". La persistance du timestamp (`shared_preferences`)
  /// reste la responsabilité de l'appelant
  /// (`NotificationsSettingsController.markSeen`), pas de ce controller.
  void markAllSeen(DateTime when) {
    _lastSeen = when;
    _recomputeUnread();
  }
}

import 'investments_models.dart';
import 'investments_repository.dart';
import 'metal_price_client.dart';
import 'price_history_repository.dart';
import 'price_sync_status_controller.dart';
import 'yahoo_finance_client.dart';

/// Rafraîchit le cours de tous les investissements de tous les comptes en
/// une seule passe, déclenchée à l'ouverture du Dashboard (voir
/// `dashboard_screen.dart`) plutôt qu'à l'ouverture de chaque investissement
/// individuellement (l'ancien comportement, retiré d'`InvestmentDetailView`)
/// — pour que la valorisation et la performance affichées soient déjà à
/// jour dès l'arrivée sur le Dashboard.
///
/// Une seule sauvegarde par compte (toutes ses mises à jour d'investissement
/// regroupées), pas une par investissement : plusieurs sauvegardes
/// successives sur le même compte se seraient sinon écrasées les unes les
/// autres (chacune partant d'un instantané du compte déjà périmé par la
/// précédente).
Future<void> refreshAllPrices({
  required String vaultPath,
  required List<InvestmentAccount> accounts,
  required InvestmentsRepository repo,
  required PriceSyncStatusController priceSyncStatus,
}) async {
  // Un seul scraping par métal pour toute la passe (pas un par
  // investissement) : la page achat-or-et-argent.fr liste déjà toutes les
  // pièces/lingots en une seule requête, la refaire pour chaque
  // investissement serait à la fois inutile et impoli envers ce site.
  // `null` tant qu'aucun investissement de ce métal n'a été rencontré —
  // évite un scraping pour rien si le vault n'en contient pas.
  MetalPriceSnapshot? goldSnapshot;
  MetalPriceSnapshot? silverSnapshot;
  var goldFetchAttempted = false;
  var silverFetchAttempted = false;

  void onNetworkError() => priceSyncStatus.reportOffline();
  void onNetworkSuccess() => priceSyncStatus.reportOnline();

  for (final account in accounts) {
    var changed = false;
    final updatedInvestments = <Investment>[];
    for (final investment in account.investments) {
      final effectiveClass = investment.assetClass ?? account.assetClass;
      Investment? updated;
      if (effectiveClass == AssetClass.metauxPrecieux) {
        if (_pricedToday(investment)) {
          updated = null;
        } else if (_isSilver(investment.label) || _isSilver(investment.isin)) {
          if (!silverFetchAttempted) {
            silverFetchAttempted = true;
            silverSnapshot = await MetalPriceClient().fetchSilverSnapshot(
              onNetworkError: onNetworkError,
              onNetworkSuccess: onNetworkSuccess,
            );
          }
          updated = _resolveMetalPrice(
            investment: investment,
            snapshot: silverSnapshot,
          );
        } else {
          if (!goldFetchAttempted) {
            goldFetchAttempted = true;
            goldSnapshot = await MetalPriceClient().fetchGoldSnapshot(
              onNetworkError: onNetworkError,
              onNetworkSuccess: onNetworkSuccess,
            );
          }
          updated = _resolveMetalPrice(
            investment: investment,
            snapshot: goldSnapshot,
          );
        }
      } else {
        updated = await _resolveInvestmentPrice(
          vaultPath: vaultPath,
          account: account,
          investment: investment,
          priceSyncStatus: priceSyncStatus,
        );
      }
      if (updated == null) {
        updatedInvestments.add(investment);
      } else {
        updatedInvestments.add(updated);
        changed = true;
      }
    }
    if (changed) {
      await repo.saveAccount(account.copyWith(investments: updatedInvestments));
    }
  }
}

/// Résout (si besoin) et synchronise le cours d'un seul investissement.
/// Retourne l'investissement mis à jour, ou `null` si rien n'a changé
/// (cours déjà à jour aujourd'hui, classe sans source de cours, échec).
Future<Investment?> _resolveInvestmentPrice({
  required String vaultPath,
  required InvestmentAccount account,
  required Investment investment,
  required PriceSyncStatusController priceSyncStatus,
}) async {
  final effectiveClass = investment.assetClass ?? account.assetClass;

  // L'épargne (Livret A, fonds euro...) n'a pas de cours de marché : la
  // résoudre comme une action via Yahoo Finance matchait par erreur des
  // tickers de devises (la "performance" affichée était alors une
  // variation de change EUR, pas un vrai rendement) — on ne tente donc
  // jamais de résolution pour elle, la valorisation reste le montant net
  // investi.
  if (effectiveClass == AssetClass.epargne) return null;

  void onNetworkError() => priceSyncStatus.reportOffline();
  void onNetworkSuccess() => priceSyncStatus.reportOnline();

  final yahoo = YahooFinanceClient();
  var symbol = investment.symbol;
  if (symbol == null) {
    if (effectiveClass == AssetClass.crypto) {
      // Le ticker construit localement (ex : "BTC-EUR") sert de requête à
      // la vraie API de recherche Yahoo Finance plutôt que d'être utilisé
      // tel quel : ça confirme qu'il correspond bien à un symbole
      // existant, avec un repli sur la construction locale si la
      // recherche échoue (API indisponible, résultat inattendu...).
      final directTicker = yahoo.resolveCryptoSymbol(investment.isin);
      symbol =
          await yahoo.resolveSymbol(
            directTicker,
            onNetworkError: onNetworkError,
            onNetworkSuccess: onNetworkSuccess,
          ) ??
          directTicker;
    } else {
      symbol = await yahoo.resolveSymbol(
        investment.isin,
        onNetworkError: onNetworkError,
        onNetworkSuccess: onNetworkSuccess,
      );
    }
    if (symbol == null) return null;
  }

  final priceRepo = PriceHistoryRepository(vaultPath, client: yahoo);
  final result = await priceRepo.syncIfNeeded(
    investment.isin,
    symbol,
    round: effectiveClass != AssetClass.crypto,
    onNetworkError: onNetworkError,
    onNetworkSuccess: onNetworkSuccess,
  );
  if (result.points.isEmpty) return null;

  final latest = result.points.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  return investment.copyWith(
    symbol: symbol,
    lastPrice: latest.close,
    lastPriceDate: latest.date,
  );
}

bool _pricedToday(Investment investment) {
  final lastFetch = investment.lastPriceDate;
  if (lastFetch == null) return false;
  final today = DateTime.now();
  return lastFetch.year == today.year &&
      lastFetch.month == today.month &&
      lastFetch.day == today.day;
}

/// Or/argent physique : pas de ticker, un prix par pièce/lingot extrait
/// directement du tableau détaillé de la page de cours (voir
/// [MetalPriceClient.fetchGoldSnapshot]/[fetchSilverSnapshot]) — une pièce
/// choisie dans la liste déroulante (voir [kKnownGoldProducts]/
/// [kKnownSilverProducts]) est valorisée à son propre prix de rachat, pas
/// au cours au gramme multiplié par un poids théorique (une pièce
/// numismatique se négocie avec une prime propre à chaque modèle). Un
/// identifiant plus ancien ou saisi librement, absent du tableau, retombe
/// sur le cours au gramme × [Investment.quantityHeld] grammes détenus —
/// comportement historique, avant l'ajout de la liste déroulante.
/// [snapshot] est `null` si le scraping (fait une seule fois par métal
/// pour toute la passe, voir [refreshAllPrices]) a échoué.
Investment? _resolveMetalPrice({
  required Investment investment,
  required MetalPriceSnapshot? snapshot,
}) {
  if (snapshot == null) return null;

  final productPrice =
      snapshot.productPrices[investment.isin] ??
      snapshot.productPrices[investment.label];
  final price = productPrice ?? snapshot.pricePerGram;

  return investment.copyWith(lastPrice: price, lastPriceDate: DateTime.now());
}

bool _isSilver(String text) {
  if (kKnownSilverProducts.contains(text)) return true;
  if (kKnownGoldProducts.contains(text)) return false;
  final lower = text.toLowerCase();
  return lower.contains('argent') || lower.contains('silver');
}

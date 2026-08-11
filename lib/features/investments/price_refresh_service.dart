import 'investments_models.dart';
import 'investments_repository.dart';
import 'metal_image_repository.dart';
import 'metal_price_client.dart';
import 'metal_price_repository.dart';
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
///
/// Métaux précieux : un seul scraping par métal pour toute la passe (la page
/// catalogue achat-or-et-argent.fr liste déjà toutes les pièces/lingots en
/// une seule requête), une seule fois par jour — les relevés sont stockés
/// dans `MetalPriceRepository` (voir [_resolveMetalSnapshots]) et réutilisés
/// ensuite, même hors ligne.
Future<void> refreshAllPrices({
  required String vaultPath,
  required List<InvestmentAccount> accounts,
  required InvestmentsRepository repo,
  required PriceSyncStatusController priceSyncStatus,
}) async {
  // Relevés or/argent de la journée, stockés ou fraîchement scrapés (voir
  // [_resolveMetalSnapshots]). `null` si aucune donnée n'est disponible
  // (premier lancement hors ligne) — les investissements métaux restent
  // alors sur leur dernière valorisation connue.
  final metalSnapshots = await _resolveMetalSnapshots(
    vaultPath: vaultPath,
    priceSyncStatus: priceSyncStatus,
  );

  // Photos des pièces/lingots physiques détenus, téléchargées si besoin
  // (voir [_ensureMetalImages]) — le nom de fichier local est ensuite
  // rattaché à chaque investissement via `Investment.imageFileName`.
  final metalImageFiles = await _ensureMetalImages(
    vaultPath: vaultPath,
    accounts: accounts,
    priceSyncStatus: priceSyncStatus,
  );

  for (final account in accounts) {
    var changed = false;
    final updatedInvestments = <Investment>[];
    for (final investment in account.investments) {
      final effectiveClass = investment.assetClass ?? account.assetClass;
      Investment? updated;
      if (effectiveClass == AssetClass.metauxPrecieux) {
        if (isMetalEtc(account)) {
          // ETC or/argent logé dans un CTO : coté en Bourse comme un titre,
          // son cours se résout sur Yahoo Finance (même chemin que les
          // actions, ISIN → ticker) — pas via les cours au gramme du site
          // marchand réservés aux pièces/lingots physiques (voir
          // [_resolveMetalPrice]).
          //
          // On repasse par Yahoo aussi quand aucun ticker n'a jamais été
          // résolu : un ETC dont le `lastPrice` avait été écrit par
          // l'ancien chemin "cours au gramme" (avant que l'enveloppe du
          // compte ne devienne un CTO) porte un cours sans `symbol`, et
          // `_pricedToday` l'empêcherait sinon de se corriger.
          if (!_pricedToday(investment) || investment.symbol == null) {
            updated = await _resolveInvestmentPrice(
              vaultPath: vaultPath,
              account: account,
              investment: investment,
              priceSyncStatus: priceSyncStatus,
            );
          }
        } else {
          final metal = metalKindForInvestment(
            isin: investment.isin,
            label: investment.label,
          );
          final imageFileName =
              metalImageFiles[investment.isin] ??
              metalImageFiles[investment.label];
          if (_pricedToday(investment)) {
            // Déjà valorisé aujourd'hui : au plus rattacher l'image
            // fraîchement résolue, sans écraser le cours.
            if (imageFileName != null &&
                investment.imageFileName != imageFileName) {
              updated = investment.copyWith(imageFileName: imageFileName);
            }
          } else {
            updated = _resolveMetalPrice(
              investment: investment,
              snapshot: metal == MetalKind.argent
                  ? metalSnapshots.silver
                  : metalSnapshots.gold,
            );
            if (updated != null && imageFileName != null) {
              updated = updated.copyWith(imageFileName: imageFileName);
            }
          }
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
///
/// Quand le cours est *cherché* mais introuvable (identifiant inconnu de
/// Yahoo Finance, actif non coté, réponse sans données) — sans panne
/// réseau, qui, elle, laisse le dernier cours connu tel quel — marque
/// [Investment.priceUnavailable] pour que l'UI l'indique clairement plutôt
/// que de retomber silencieusement sur le montant investi. Seules les
/// classes où un cours de marché est attendu sont concernées
/// ([_expectsMarketPrice]) : un prêt immobilier ou un objet d'art n'a
/// jamais de cours Yahoo, ce n'est pas un échec à signaler.
Future<Investment?> _resolveInvestmentPrice({
  required String vaultPath,
  required InvestmentAccount account,
  required Investment investment,
  required PriceSyncStatusController priceSyncStatus,
}) async {
  final effectiveClass = investment.assetClass ?? account.assetClass;

  // L'épargne n'a pas de cours de marché comme un titre : tenue en euros,
  // elle est valorisée au pair (1 EUR = 1 EUR) et aucune résolution n'est
  // tentée. Une épargne tenue en devise étrangère (GBP, USD...) est en
  // revanche valorisée en euros au taux de change courant — la paire
  // `CODE-EUR` de Yahoo Finance est construite directement plus bas plutôt
  // que cherchée comme un ticker d'action (la recherche matchait par erreur
  // des devises sans rapport).

  // Une panne réseau n'est pas un "cours introuvable" : on ne marque alors
  // pas [Investment.priceUnavailable], et on retombe sur le dernier cours
  // connu (ou le montant investi) comme avant.
  var networkError = false;
  void onNetworkError() {
    networkError = true;
    priceSyncStatus.reportOffline();
  }

  void onNetworkSuccess() => priceSyncStatus.reportOnline();

  final yahoo = YahooFinanceClient();
  var symbol = investment.symbol;
  if (symbol == null) {
    if (effectiveClass == AssetClass.epargne) {
      // Épargne en devise étrangère : le symbole est la paire de devises
      // elle-même (`GBP` + `EUR` → "GBPEUR=X"), qui donne en euro la valeur
      // d'une unité — pas de recherche de ticker. L'épargne en euros, elle,
      // reste au pair : rien à résoudre.
      final currency = investment.isin.trim().toUpperCase();
      if (currency.isEmpty || currency == 'EUR') return null;
      symbol = '${currency}EUR=X';
    } else if (effectiveClass == AssetClass.crypto) {
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
    if (symbol == null) {
      // Identifiant inconnu de Yahoo (ou panne réseau, distinguée plus
      // haut) : pas de cours possible.
      if (networkError || !_expectsMarketPrice(effectiveClass)) return null;
      return investment.copyWith(priceUnavailable: true);
    }
  }

  final priceRepo = PriceHistoryRepository(vaultPath, client: yahoo);
  final result = await priceRepo.syncIfNeeded(
    investment.isin,
    symbol,
    round: !requiresFullPricePrecision(effectiveClass),
    onNetworkError: onNetworkError,
    onNetworkSuccess: onNetworkSuccess,
  );
  if (result.points.isEmpty) {
    if (networkError || !_expectsMarketPrice(effectiveClass)) return null;
    return investment.copyWith(priceUnavailable: true);
  }

  final latest = result.points.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  return investment.copyWith(
    symbol: symbol,
    lastPrice: latest.close,
    lastPriceDate: latest.date,
    // Un cours vient d'être trouvé : le drapeau "introuvable" est levé.
    priceUnavailable: false,
  );
}

/// Classes d'actif où un cours de marché (Yahoo Finance) est *attendu* : un
/// échec de résolution y vaut "cours introuvable" et mérite d'être signalé
/// (voir [_resolveInvestmentPrice]) — contrairement aux classes sans cotation
/// (immobilier, private equity, autres), où il est simplement normal de
/// rester valorisé au montant investi.
bool _expectsMarketPrice(AssetClass assetClass) =>
    assetClass == AssetClass.actionsEtFonds ||
    assetClass == AssetClass.crypto ||
    assetClass == AssetClass.metauxPrecieux;

/// Relevés d'or et d'argent à utiliser pour la passe : s'ils sont déjà
/// stockés pour aujourd'hui (`MetalPriceRepository`), réutilisés tels quels
/// sans aucun appel réseau ; sinon les deux pages sont scrapées une seule
/// fois (métal par métal) et le résultat stocké pour la journée. En cas
/// d'échec réseau, repli sur le dernier relevé stocké (même périmé) pour
/// continuer à valoriser les métaux hors ligne.
Future<({MetalPriceSnapshot? gold, MetalPriceSnapshot? silver})>
    _resolveMetalSnapshots({
  required String vaultPath,
  required PriceSyncStatusController priceSyncStatus,
}) async {
  void onNetworkError() => priceSyncStatus.reportOffline();
  void onNetworkSuccess() => priceSyncStatus.reportOnline();

  final repo = MetalPriceRepository(vaultPath);
  final gold = await _resolveMetalSnapshot(
    repo,
    MetalKind.or,
    onNetworkError: onNetworkError,
    onNetworkSuccess: onNetworkSuccess,
  );
  final silver = await _resolveMetalSnapshot(
    repo,
    MetalKind.argent,
    onNetworkError: onNetworkError,
    onNetworkSuccess: onNetworkSuccess,
  );
  return (gold: gold, silver: silver);
}

Future<MetalPriceSnapshot?> _resolveMetalSnapshot(
  MetalPriceRepository repo,
  MetalKind metal, {
  required void Function() onNetworkError,
  required void Function() onNetworkSuccess,
}) async {
  final today = DateTime.now();
  final stored = await repo.latest(metal);
  if (stored != null &&
      stored.date.year == today.year &&
      stored.date.month == today.month &&
      stored.date.day == today.day) {
    return stored.snapshot;
  }
  final fetched = await MetalPriceClient().fetchSnapshot(
    metal,
    onNetworkError: onNetworkError,
    onNetworkSuccess: onNetworkSuccess,
  );
  if (fetched == null) return stored?.snapshot;
  await repo.save(metal, fetched, date: today);
  return fetched;
}

bool _pricedToday(Investment investment) {
  final lastFetch = investment.lastPriceDate;
  if (lastFetch == null) return false;
  final today = DateTime.now();
  return lastFetch.year == today.year &&
      lastFetch.month == today.month &&
      lastFetch.day == today.day;
}

/// Or/argent physique : pas de ticker, un prix par pièce/lingot extrait du
/// JSON embarqué sur les pages catalogue achat-or-et-argent.fr (voir
/// [MetalPriceClient.fetchSnapshot]) — une pièce choisie dans la liste
/// déroulante (voir [kKnownGoldProducts]/[kKnownSilverProducts]) est
/// valorisée à son propre prix de rachat, pas au cours au gramme multiplié
/// par un poids théorique (une pièce numismatique se négocie avec une prime
/// propre à chaque modèle). Un identifiant plus ancien ou saisi librement,
/// absent des prix de rachat (ou sans marché de revente), retombe sur le
/// cours au gramme × [Investment.quantityHeld] grammes détenus —
/// comportement historique, avant l'ajout de la liste déroulante.
/// [snapshot] est `null` si aucune donnée n'est disponible (premier
/// lancement hors ligne, voir [_resolveMetalSnapshots]).
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

/// Télécharge (si besoin) la photo du produit de chaque métal *physique*
/// détenu (pièce/lingot — pas les ETC logés dans un CTO, qui n'ont pas de
/// produit associé sur achat-or-et-argent.fr) et retourne, pour chaque
/// produit, le nom de fichier local de son image : clé = isin ou libellé de
/// l'investissement, valeur = fichier dans `investissements/metaux/images/`.
///
/// Voir `metal_image_repository.dart` pour le cache local : les produits
/// déjà téléchargés (fichier présent) sont réutilisés sans aucun appel
/// réseau ; pour les autres, le catalogue des images est récupéré une seule
/// fois par métal (`workerApi getProducts`, voir
/// [MetalPriceClient.fetchProductImages]) et les photos manquantes sont
/// téléchargées. Un échec (réseau, produit inconnu du catalogue) laisse
/// simplement l'investissement sans image — l'avatar à initiales fait
/// alors office de repli.
Future<Map<String, String>> _ensureMetalImages({
  required String vaultPath,
  required List<InvestmentAccount> accounts,
  required PriceSyncStatusController priceSyncStatus,
}) async {
  void onNetworkError() => priceSyncStatus.reportOffline();
  void onNetworkSuccess() => priceSyncStatus.reportOnline();

  // Produits voulus : libellé -> métal. Un même produit peut être détenu
  // dans plusieurs comptes ; le métal d'un produit ne varie pas, on garde
  // donc un seul métal par produit.
  final wanted = <String, MetalKind>{};
  for (final account in accounts) {
    for (final investment in account.investments) {
      final effectiveClass = investment.assetClass ?? account.assetClass;
      if (effectiveClass != AssetClass.metauxPrecieux) continue;
      // Un ETC logé dans un CTO n'a pas de produit physique associé sur le
      // site marchand — pas d'image à chercher pour lui.
      if (isMetalEtc(account)) continue;
      final product = investment.isin.isNotEmpty
          ? investment.isin
          : investment.label;
      if (product.isEmpty) continue;
      wanted[product] = metalKindForInvestment(
        isin: investment.isin,
        label: investment.label,
      );
    }
  }
  if (wanted.isEmpty) return {};

  final repo = MetalImageRepository(vaultPath);
  final index = await repo.readIndex();

  // Produits déjà en cache local : pas de réseau nécessaire.
  final done = <String, String>{};
  final toFetch = <String, MetalKind>{};
  for (final entry in wanted.entries) {
    final info = index[entry.key];
    if (info != null && info.file.isNotEmpty && await repo.fileFor(info.file).exists()) {
      done[entry.key] = info.file;
    } else {
      toFetch[entry.key] = entry.value;
    }
  }
  if (toFetch.isEmpty) return done;

  // Catalogue des images, une seule requête par métal concerné, puis
  // téléchargement des photos manquantes.
  final metalsToFetch = toFetch.values.toSet();
  for (final metal in metalsToFetch) {
    final catalog = await MetalPriceClient().fetchProductImages(
      metal,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
    if (catalog == null) continue;
    final byLabel = {for (final product in catalog) product.label: product};
    for (final entry in toFetch.entries) {
      if (entry.value != metal) continue;
      final product = byLabel[entry.key];
      if (product == null) continue;
      final fileName = await repo.download(product);
      if (fileName == null) continue;
      index[entry.key] = MetalImageEntry(file: fileName, url: product.imageUrl);
      done[entry.key] = fileName;
    }
  }
  await repo.writeIndex(index);
  return done;
}

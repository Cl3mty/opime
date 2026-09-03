import 'investments_models.dart';
import 'investments_repository.dart';
import 'leveraged_position.dart';
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
          // `isPriceFresh` l'empêcherait sinon de se corriger.
          if (!investment.isPriceFresh || investment.symbol == null) {
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
          if (investment.isPriceFresh) {
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

    // Positions à effet de levier crypto : cours actualisé automatiquement
    // comme un investissement spot classique (voir la doc de tête de
    // `LeveragedPosition`) — Actions & Fonds (CFD/action sur marge, pas de
    // ticker Yahoo fiable) reste en saisie manuelle, seule la crypto a une
    // source de cours automatique exploitable ici.
    var updatedLeveragedPositions = account.leveragedPositions;
    if (account.assetClass == AssetClass.crypto) {
      final newPositions = <LeveragedPosition>[];
      var leveragedChanged = false;
      for (final position in account.leveragedPositions) {
        final updated = position.isOpen && !position.isMarkPriceFresh
            ? await _resolveLeveragedPositionPrice(
                vaultPath: vaultPath,
                position: position,
                priceSyncStatus: priceSyncStatus,
              )
            : null;
        if (updated == null) {
          newPositions.add(position);
        } else {
          newPositions.add(updated);
          leveragedChanged = true;
        }
      }
      if (leveragedChanged) {
        updatedLeveragedPositions = newPositions;
        changed = true;
      }
    }

    if (changed) {
      await repo.saveAccount(
        account.copyWith(
          investments: updatedInvestments,
          leveragedPositions: updatedLeveragedPositions,
        ),
      );
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
/// jamais de cours Yahoo, ce n'est pas un échec à signaler — pas plus
/// qu'un fonds PEE/PEG/PER sans ISIN public, identifié par un id auto-généré
/// ("fcpe-...") plutôt qu'un vrai ticker.
Future<Investment?> _resolveInvestmentPrice({
  required String vaultPath,
  required InvestmentAccount account,
  required Investment investment,
  required PriceSyncStatusController priceSyncStatus,
}) async {
  final effectiveClass = investment.assetClass ?? account.assetClass;

  // Le Private Equity n'a jamais de vrai ticker à résoudre (club deal, FCPR
  // — voir [isinOptionalFor]) : contrairement aux autres classes sans
  // cotation, son identifiant est le plus souvent un nom de fonds tapé
  // librement (pas forcément un id auto-généré filtré par
  // [isGeneratedIdentifier] plus bas), qui risquerait sinon de matcher par
  // coïncidence un vrai ticker/nom d'entreprise coté sur Yahoo Finance —
  // en plus de gaspiller un appel réseau à chaque rafraîchissement pour une
  // recherche vouée à l'échec.
  if (effectiveClass == AssetClass.privateEquity) return null;

  // Une position en devise — épargne tenue en USD, ou dollars créés dans un
  // compte-titres via le flux de complétion (voir `Investment.isCurrency`) —
  // n'a pas de cours de marché comme un titre : tenue en euros, elle est
  // valorisée au pair (1 EUR = 1 EUR) et aucune résolution n'est tentée.
  // Tenue en devise étrangère (GBP, USD...), elle est valorisée en euros au
  // taux de change courant — la paire `CODE-EUR` de Yahoo Finance est
  // construite directement plus bas plutôt que cherchée comme un ticker
  // d'action (la recherche matchait par erreur des devises sans rapport).
  final isCurrency = investment.isCurrency;
  // Une devise n'est jamais "introuvable" chez Yahoo : un échec de la paire
  // de change (hors panne réseau) laisse simplement le dernier cours connu.
  // Un fonds PEE/PEG/PER sans ISIN public (identifiant auto-généré "fcpe-...",
  // voir [isinOptionalFor]) n'a pas non plus de cours à chercher — comme un
  // objet "autre-..." ou un bien "immobilier-...", jamais réellement coté
  // (déjà exclus par [_expectsMarketPrice] via leur classe, voir
  // [isGeneratedIdentifier]).
  final expectsMarketPrice =
      !isCurrency &&
      !isGeneratedIdentifier(investment.isin) &&
      _expectsMarketPrice(effectiveClass);
  // Le taux de change (1 JPY ≈ 0,006 €) et le cours d'une devise ont besoin
  // d'une précision au-delà du centime, même logés dans un compte-titres.
  final fullPrecision = isCurrency || requiresFullPricePrecision(effectiveClass);

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
    if (isCurrency) {
      // Position en devise étrangère : le symbole est la paire de devises
      // elle-même (`GBP` + `EUR` → "GBPEUR=X"), qui donne en euro la valeur
      // d'une unité — pas de recherche de ticker. Une position en euros,
      // elle, reste au pair : rien à résoudre.
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
      if (networkError || !expectsMarketPrice) return null;
      return investment.copyWith(priceUnavailable: true);
    }
  }

  // Diversification géographique/sectorielle automatique (voir
  // `Investment.sector`/`countryCode`) : un seul essai tant que le champ
  // reste `null`, jamais réessayé une fois renseigné — que ce soit par cet
  // appel ou par une classification manuelle de l'utilisateur, qui doit
  // toujours pouvoir écraser une valeur auto-détectée sans qu'elle ne
  // revienne au rafraîchissement suivant. Un échec (Yahoo sans secteur
  // pour cet actif, suffixe de place non reconnu, panne réseau) laisse
  // simplement le ou les champs à `null`, retentés au prochain passage —
  // pas de drapeau d'échec permanent comme [Investment.priceUnavailable],
  // `null` étant déjà l'état "non classé" existant avant cette
  // fonctionnalité.
  Sector? autoSector;
  String? autoCountryCode;
  if (effectiveClass == AssetClass.actionsEtFonds &&
      !isCurrency &&
      (investment.sector == null || investment.countryCode == null)) {
    final classification = await yahoo.fetchClassification(
      symbol,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
    if (investment.sector == null) {
      autoSector = Sector.fromYahooLabel(classification.sector);
    }
    if (investment.countryCode == null) {
      autoCountryCode = classification.countryCode;
    }
  }

  // Date la plus ancienne à couvrir par l'historique de cours — la
  // transaction la plus ancienne de l'investissement, pour qu'une
  // estimation de performance sur toute sa durée de détention (voir
  // `real_patrimoine_adapter.dart`'s `_valuationAt`) dispose de vrais
  // cours plutôt que d'un repli sur le montant investi faute d'historique.
  final neededSince = _earliestTransactionDate(investment);

  final priceRepo = PriceHistoryRepository(vaultPath, client: yahoo);
  final result = await priceRepo.syncIfNeeded(
    investment.isin,
    symbol,
    neededSince: neededSince,
    round: !fullPrecision,
    onNetworkError: onNetworkError,
    onNetworkSuccess: onNetworkSuccess,
  );
  if (result.points.isEmpty) {
    if (networkError || !expectsMarketPrice) {
      return autoSector == null && autoCountryCode == null
          ? null
          : investment.copyWith(sector: autoSector, countryCode: autoCountryCode);
    }
    return investment.copyWith(
      priceUnavailable: true,
      sector: autoSector,
      countryCode: autoCountryCode,
    );
  }

  final latest = result.points.reduce((a, b) => a.date.isAfter(b.date) ? a : b);

  // Devise de cotation du titre, résolue depuis les métadonnées de l'API
  // chart (`meta.currency`) puis mise en cache sur l'investissement : un
  // titre coté en monnaie étrangère (ex : META en USD) a un cours brut en
  // devise, qu'il faut convertir en euros pour valoriser la position. Une
  // position en devise (elle est déjà un taux de change en euros) n'a pas
  // de devise de cotation à retenir.
  String? quoteCurrency = investment.quoteCurrency;
  if (quoteCurrency == null && result.currency != null && !isCurrency) {
    quoteCurrency = result.currency;
  }

  // Taux de change vers l'euro (1 [quoteCurrency] = X €) pour la devise de
  // cotation, synchronisé via la paire `<devise>EUR=X` de Yahoo Finance —
  // mise en cache localement comme n'importe quel historique de cours (le
  // pseudo-ISIN est la paire elle-même), en pleine précision (1 JPY ≈
  // 0,006 € ne survivrait pas à l'arrondi au centime). Une devise de
  // cotation en euros n'appelle aucun taux.
  double? fxRateToEur = investment.lastFxRateToEur;
  if (quoteCurrency != null && quoteCurrency.toUpperCase() != 'EUR') {
    final pair = '${quoteCurrency.toUpperCase()}EUR=X';
    final fxResult = await priceRepo.syncIfNeeded(
      pair,
      pair,
      // Même besoin de recul que le cours du titre lui-même : convertir sa
      // valorisation à une date ancienne suppose un taux de change connu à
      // cette même date.
      neededSince: neededSince,
      round: false,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
    if (fxResult.points.isNotEmpty) {
      fxRateToEur = fxResult.points.last.close;
    }
  }

  return investment.copyWith(
    symbol: symbol,
    lastPrice: latest.close,
    lastPriceDate: latest.date,
    quoteCurrency: quoteCurrency,
    lastFxRateToEur: fxRateToEur,
    // Un cours vient d'être trouvé : le drapeau "introuvable" est levé.
    priceUnavailable: false,
    sector: autoSector,
    countryCode: autoCountryCode,
  );
}

/// Résout (si besoin) le cours actuel (mark price) d'une position à effet
/// de levier crypto — [LeveragedPosition.market] est un ticker de
/// [kKnownCryptoTickers] (voir `leveraged_position_dialog.dart`), résolu en
/// euros directement comme n'importe quelle position spot crypto (voir
/// [YahooFinanceClient.resolveCryptoSymbol], pas de conversion de devise
/// séparée nécessaire). Partage le même cache que la position spot
/// éventuelle du même ticker (`market` sert de pseudo-ISIN, comme
/// `investment.isin` pour un investissement) — un seul appel réseau par
/// ticker et par jour, quel que soit le nombre de positions (spot et à
/// effet de levier) qui le suivent. `null` si le cours est déjà à jour
/// aujourd'hui, ou si aucun cours n'a pu être résolu (panne réseau, ticker
/// inconnu de Yahoo Finance) — le liquidationPrice/funding restent alors
/// sur leur dernière valeur saisie à la main, jamais écrasés ici.
Future<LeveragedPosition?> _resolveLeveragedPositionPrice({
  required String vaultPath,
  required LeveragedPosition position,
  required PriceSyncStatusController priceSyncStatus,
}) async {
  final yahoo = YahooFinanceClient();
  final symbol = yahoo.resolveCryptoSymbol(position.market);
  final priceRepo = PriceHistoryRepository(vaultPath, client: yahoo);
  final result = await priceRepo.syncIfNeeded(
    position.market,
    symbol,
    round: false,
    onNetworkError: () => priceSyncStatus.reportOffline(),
    onNetworkSuccess: () => priceSyncStatus.reportOnline(),
  );
  if (result.points.isEmpty) return null;
  final latest = result.points.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  return position.copyWith(markPrice: latest.close, markPriceAt: DateTime.now());
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

/// Date de la transaction la plus ancienne de [investment] — `null` sans
/// transaction (investissement tout juste créé, avant tout achat), auquel
/// cas [PriceHistoryRepository.syncIfNeeded] ne cherche pas à couvrir plus
/// que la journée courante.
DateTime? _earliestTransactionDate(Investment investment) {
  DateTime? earliest;
  for (final t in investment.transactions) {
    if (earliest == null || t.date.isBefore(earliest)) earliest = t.date;
  }
  return earliest;
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

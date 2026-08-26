import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, Color;
import '../dashboard/patrimoine_models.dart';
import 'investments_models.dart';
import 'metal_price_client.dart';
import 'metal_price_repository.dart';
import 'price_history_repository.dart';
import 'yahoo_finance_client.dart';

/// Adapte les comptes de placement réels (`InvestmentAccount`) vers le
/// modèle générique du Dashboard (`dashboard/patrimoine_models.dart`) pour
/// réutiliser telles quelles ses cartes (`AllocationCard`, `TopAssetsRow`,
/// `CategoryBreakdownCard`, `CategoryDetailScreen`) plutôt que d'en écrire
/// des équivalents dédiés aux données réelles.
const _categoryMeta = {
  AssetClass.immobilier: (
    LucideIcons.house,
    Color(0xFFEF4444),
    AllocationTier.croissance,
    'Résidence principale et parts de SCPI détenues en direct.',
  ),
  AssetClass.actionsEtFonds: (
    LucideIcons.chartLine,
    Color(0xFF8B5CF6),
    AllocationTier.croissance,
    'Actions, ETF et fonds détenus sur vos comptes-titres et PEA.',
  ),
  AssetClass.epargne: (
    LucideIcons.piggyBank,
    Color(0xFF60A5FA),
    AllocationTier.fondation,
    'Livrets réglementés et fonds euros — la part la plus liquide et '
        'sécurisée du patrimoine.',
  ),
  AssetClass.crypto: (
    LucideIcons.bitcoin,
    // Orange, pour se distinguer du jaune des métaux précieux
    // (`0xFFEAB308`) avec lequel l'ancien ambre était confondu.
    Color(0xFFF97316),
    AllocationTier.opportuniste,
    'Cryptomonnaies détenues sur wallet froid ou plateforme.',
  ),
  AssetClass.privateEquity: (
    LucideIcons.rocket,
    Color(0xFF34D399),
    AllocationTier.opportuniste,
    'Participations non cotées dans des entreprises ou fonds de '
        'capital-investissement.',
  ),
  AssetClass.metauxPrecieux: (
    LucideIcons.gem,
    Color(0xFFEAB308),
    AllocationTier.opportuniste,
    'Or et argent physiques, valeur refuge peu corrélée aux marchés '
        'financiers.',
  ),
  AssetClass.autres: (
    LucideIcons.boxes,
    Color(0xFF94A3B8),
    AllocationTier.opportuniste,
    'Art, objets de collection, véhicules, montres, droits musicaux... '
        'des actifs non classés ailleurs.',
  ),
};

/// Charge, en une passe, l'historique de cours en cache (lecture locale
/// uniquement — aucun appel réseau ici) de chaque investissement présent
/// dans [accounts], pour être réutilisé par les autres fonctions de ce
/// fichier sans relire le disque à chaque fois.
Future<Map<String, List<PricePoint>>> loadAllPriceHistories(
  String vaultPath,
  List<InvestmentAccount> accounts,
) async {
  final repo = PriceHistoryRepository(vaultPath);
  // Les métaux précieux physiques n'ont pas d'historique Yahoo Finance :
  // leur série est reconstruite depuis les relevés journaliers stockés par
  // `price_refresh_service.dart` (voir
  // [MetalPriceRepository.pricePointsFor]) — même clé (l'ISIN, qui porte le
  // nom de la pièce/lingot) et même repli sur le cours au gramme qu'à la
  // valorisation. Un ETC or/argent logé dans un CTO, lui, est un titre coté
  // dont le cours et l'historique passent par Yahoo Finance, comme le fait
  // déjà le rafraîchissement des cours.
  final metalRepo = MetalPriceRepository(vaultPath);
  final result = <String, List<PricePoint>>{};
  for (final account in accounts) {
    for (final investment in account.investments) {
      final effectiveClass = investment.assetClass ?? account.assetClass;
      if (effectiveClass == AssetClass.metauxPrecieux && !isMetalEtc(account)) {
        result[investment.isin] = await metalRepo.pricePointsFor(
          metalKindForInvestment(
            isin: investment.isin,
            label: investment.label,
          ),
          investment.isin,
        );
      } else {
        result[investment.isin] = await repo.load(investment.isin);
      }
    }
  }
  return result;
}

/// Regroupe les investissements réels par classe d'actif *effective* en
/// [PatrimoineCategory], une par classe effectivement présente : celle de
/// [Investment.assetClass] si l'investissement en porte une (ex : un ETC or
/// logé dans un CTO "Actions & Fonds" — voir
/// [accountAcceptsCrossClassInvestment]), sinon celle de son compte
/// porteur. Chaque *investissement* (pas chaque compte) devient une ligne
/// [PatrimoineAccount] — un compte réel peut contenir plusieurs
/// investissements, la granularité "feuille" du Dashboard reste
/// l'investissement, cohérente avec le tableau ISIN déjà affiché par
/// `CategoryDetailScreen`.
List<PatrimoineCategory> buildRealCategories(
  List<InvestmentAccount> accounts,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final byClass = <AssetClass, List<(InvestmentAccount, Investment)>>{};
  for (final account in accounts) {
    for (final investment in account.investments) {
      // Une position entièrement vendue (quantité nulle) est un historique,
      // pas une détention actuelle — même filtre que [buildRealTopAssets],
      // pour ne pas laisser traîner une ligne à ~0 € dans la vue "par
      // investissement".
      if (investment.quantityHeld <= 0) continue;
      final effectiveClass = investment.assetClass ?? account.assetClass;
      byClass.putIfAbsent(effectiveClass, () => []).add((account, investment));
    }
  }
  return [
    for (final entry in byClass.entries)
      _buildCategory(entry.key, entry.value, priceHistories, vaultPath),
  ];
}

PatrimoineCategory _buildCategory(
  AssetClass assetClass,
  List<(InvestmentAccount, Investment)> pairs,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final meta = _categoryMeta[assetClass]!;
  final leaves = <PatrimoineAccount>[
    for (final (account, investment) in pairs)
      _buildLeaf(account, investment, vaultPath),
  ];
  return PatrimoineCategory(
    id: assetClass.categoryId,
    label: assetClass.label,
    icon: meta.$1,
    color: meta.$2,
    tier: meta.$3,
    description: meta.$4,
    accounts: leaves,
  );
}

/// Comme [buildRealCategories], mais chaque *compte* (pas chaque
/// investissement) devient une ligne [PatrimoineAccount], son montant/plus-
/// value étant la somme de ses investissements pour la classe effective
/// concernée (un même compte peut apparaître dans deux catégories s'il
/// porte des investissements à classe effective différente — voir
/// [accountAcceptsCrossClassInvestment]). Utilisé pour l'accordéon du
/// Dashboard ([CategoryBreakdownCard]) et pour la vue "par compte" de la
/// Distribution ([CategoryDetailScreen]) — le détail par investissement
/// reste sur la page dédiée à la classe d'actif via [buildRealCategories].
List<PatrimoineCategory> buildRealCategoriesByAccount(
  List<InvestmentAccount> accounts,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final byClass = <AssetClass, List<(InvestmentAccount, Investment)>>{};
  // Un compte sans aucun investissement (tout juste créé, ou vidé après
  // suppression de sa dernière position) ne produit aucune paire ci-dessous
  // — sans ce repli, il resterait invisible de tout accordéon établissement
  // → comptes et donc inatteignable pour être complété ou supprimé. Il est
  // rattaché à sa seule classe connue, la sienne (pas de notion de classe
  // effective possible sans investissement porteur — voir
  // [accountAcceptsCrossClassInvestment]).
  final emptyAccountsByClass = <AssetClass, List<InvestmentAccount>>{};
  for (final account in accounts) {
    if (account.investments.isEmpty) {
      emptyAccountsByClass
          .putIfAbsent(account.assetClass, () => [])
          .add(account);
      continue;
    }
    for (final investment in account.investments) {
      final effectiveClass = investment.assetClass ?? account.assetClass;
      byClass.putIfAbsent(effectiveClass, () => []).add((account, investment));
    }
  }
  return [
    for (final assetClass in {...byClass.keys, ...emptyAccountsByClass.keys})
      _buildCategoryByAccount(
        assetClass,
        byClass[assetClass] ?? const [],
        emptyAccountsByClass[assetClass] ?? const [],
        priceHistories,
        vaultPath,
      ),
  ];
}

PatrimoineCategory _buildCategoryByAccount(
  AssetClass assetClass,
  List<(InvestmentAccount, Investment)> pairs,
  List<InvestmentAccount> emptyAccounts,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final meta = _categoryMeta[assetClass]!;
  final byAccountId = <String, List<(InvestmentAccount, Investment)>>{};
  for (final pair in pairs) {
    byAccountId.putIfAbsent(pair.$1.id, () => []).add(pair);
  }
  final leaves = <PatrimoineAccount>[
    for (final accountPairs in byAccountId.values)
      _buildAccountLeaf(accountPairs.first.$1, accountPairs, vaultPath),
    for (final account in emptyAccounts)
      _buildAccountLeaf(account, const [], vaultPath),
  ];
  return PatrimoineCategory(
    id: assetClass.categoryId,
    label: assetClass.label,
    icon: meta.$1,
    color: meta.$2,
    tier: meta.$3,
    description: meta.$4,
    accounts: leaves,
  );
}

PatrimoineAccount _buildAccountLeaf(
  InvestmentAccount account,
  List<(InvestmentAccount, Investment)> pairs,
  String vaultPath,
) {
  // Seules les positions encore détenues représentent ce que le compte
  // contient *actuellement* — une position entièrement soldée (ex : un
  // titre entièrement revendu, une devise entièrement dépensée) disparaît
  // de l'accordéon établissement → comptes, mais reste visible dans son
  // historique de transactions (`investment_detail_screen.dart`, qui lit
  // `Investment.transactions` directement, indépendamment de cette
  // fonction) — voir aussi [buildRealTopAssets], qui applique déjà le même
  // filtre pour les meilleurs actifs du Dashboard.
  //
  // Les positions en devise (cash tenu dans le compte — voir
  // [isCurrencyInvestment]) sont reléguées après les titres : elles
  // représentent des liquidités en attente plutôt que des placements, pas
  // ce que l'utilisateur vient chercher en premier dans la liste. L'ordre
  // relatif au sein de chaque groupe est conservé (deux boucles plutôt
  // qu'un tri, qui ne serait pas garanti stable).
  final heldPairs = [
    for (final pair in pairs)
      if (pair.$2.quantityHeld > 0 && !isCurrencyInvestment(pair.$1, pair.$2))
        pair,
    for (final pair in pairs)
      if (pair.$2.quantityHeld > 0 && isCurrencyInvestment(pair.$1, pair.$2))
        pair,
  ];
  var valeur = 0.0;
  var plusValueAbs = 0.0;
  var costBasis = 0.0;
  for (final (_, investment) in heldPairs) {
    // Un investissement exclu du patrimoine (voir
    // Investment.excludedFromPatrimoine) reste compté ici : cette somme
    // alimente le total propre du compte/de sa catégorie
    // ([PatrimoineCategory.montant]), qui continue de tout comptabiliser —
    // seuls les agrégats globaux du Dashboard l'ignorent (voir
    // [PatrimoineCategory.montantPatrimoine] et
    // [investmentsForEffectiveClass]).
    final v = investment.effectiveMarketValue ?? investment.investedAmount;
    final gain = investment.unrealizedGain ?? 0;
    valeur += v;
    plusValueAbs += gain;
    costBasis += v - gain;
  }
  return PatrimoineAccount(
    id: account.id,
    // Pour l'épargne, l'identité d'un compte est son type (l'enveloppe
    // fiscale — Livret A, LDDS...) en première ligne, avec une description
    // facultative en dessous : le nom de la banque est déjà porté par la
    // ligne de l'établissement de l'accordéon (voir `_buildAccountAccordions`).
    // Les autres classes gardent le nom du compte + son enveloppe. Un compte
    // d'épargne *sans* banque (créé avant l'introduction du champ) garde
    // quant à lui son nom réel en première ligne : sans établissement pour
    // porter l'identité, c'est son nom qui la porte — et la clé de
    // groupement de l'accordéon (`bankName ?? name`, voir
    // `category_detail_screen.dart`) retombe dessus plutôt que sur le
    // libellé d'enveloppe, ce qui fusionnerait des comptes différents du
    // même type (deux "Livret A" dans des banques distinctes) en un seul
    // accordéon et ferait disparaître la banque.
    name: account.assetClass == AssetClass.epargne && account.bankName != null
        ? account.envelope?.label ?? account.name
        : account.name,
    // Comme pour l'épargne, les comptes "Actions & Fonds" (PEA, CTO,
    // assurance vie...) présentent la description facultative en seconde
    // ligne : leur nom porte déjà le type (le libellé d'enveloppe — voir
    // `_selectAccountEnvelope` dans `complete_patrimoine_dialog.dart`), un
    // sous-titre répétant l'enveloppe ne ferait que dupliquer le nom. Les
    // autres classes gardent le nom du compte + son enveloppe en sous-titre.
    subtitle:
        account.assetClass == AssetClass.epargne ||
            account.assetClass == AssetClass.actionsEtFonds
        ? account.description
        : account.customOtherCategory ?? account.envelope?.label,
    // L'établissement du compte réel — la clé de groupement "banque" de
    // l'accordéon (`category_detail_screen.dart`), et le nom sous lequel le
    // logo de la banque est importé (`bank_logo_repository.dart`).
    bankName: account.bankName,
    valeur: valeur,
    plusValueAbs: plusValueAbs,
    plusValuePercent: costBasis == 0 ? 0 : plusValueAbs / costBasis * 100,
    // Affiche le badge "Hors patrimoine global" sur la ligne compte quand
    // l'utilisateur a exclu le compte entier du patrimoine — [valeur]
    // ci-dessus reste la vraie somme, seul l'agrégat global du Dashboard
    // (jamais construit à partir de cette fonction, voir
    // [investmentsForEffectiveClass]) en tient compte.
    excludedFromPatrimoine: account.excludedFromPatrimoine,
    investments: [
      for (final (investmentAccount, investment) in heldPairs)
        _buildLeaf(
          investmentAccount,
          investment,
          vaultPath,
          // Sous-titre du compte porteur inutile ici : ces lignes sont déjà
          // affichées à l'intérieur du compte (et de la banque pour
          // l'épargne) — une ligne simple par devise, sans répétition.
          showAccountSubtitle: false,
        ),
    ],
    // Reflète l'état du compte réel dans son ensemble, pas seulement ses
    // investissements de cette classe : un compte avec des transactions
    // dans une autre classe (cross-class) ne doit pas non plus être
    // supprimable depuis ici.
    canDelete: account.investments.every((i) => i.transactions.isEmpty),
  );
}

/// Comme [buildRealCategoriesByAccount], mais toujours les 7 classes
/// réelles (vides via [emptyCategoryFor] pour celles sans compte) — même
/// principe que [buildAllRealCategories].
List<PatrimoineCategory> buildAllRealCategoriesByAccount(
  List<InvestmentAccount> accounts,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final populated = {
    for (final c in buildRealCategoriesByAccount(
      accounts,
      priceHistories,
      vaultPath,
    ))
      c.id: c,
  };
  return [
    for (final assetClass in AssetClass.values)
      populated[assetClass.categoryId] ??
          emptyCategoryFor(assetClass.categoryId),
  ];
}

/// Comme [buildRealCategories], mais toujours les 7 classes d'actif réelles
/// dans le même ordre que [AssetClass.values] (donc que la sidebar et le
/// Dashboard de démo), vides via [emptyCategoryFor] pour celles sans
/// compte — pour que le Dashboard affiche l'intégralité des classes
/// d'actifs plutôt que seulement celles déjà alimentées.
List<PatrimoineCategory> buildAllRealCategories(
  List<InvestmentAccount> accounts,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final populated = {
    for (final c in buildRealCategories(accounts, priceHistories, vaultPath))
      c.id: c,
  };
  return [
    for (final assetClass in AssetClass.values)
      populated[assetClass.categoryId] ??
          emptyCategoryFor(assetClass.categoryId),
  ];
}

/// Catégorie vide (aucun compte) pour une classe d'actif réelle sans
/// donnée pour l'instant — même apparence (icône/couleur/description)
/// qu'une catégorie peuplée, pour que [CategoryDetailScreen] affiche un
/// état vide cohérent plutôt que de planter faute de catégorie trouvée.
PatrimoineCategory emptyCategoryFor(String categoryId) {
  final assetClass = AssetClass.values.firstWhere(
    (c) => c.categoryId == categoryId,
  );
  final meta = _categoryMeta[assetClass]!;
  return PatrimoineCategory(
    id: categoryId,
    label: assetClass.label,
    icon: meta.$1,
    color: meta.$2,
    tier: meta.$3,
    description: meta.$4,
    accounts: const [],
  );
}

/// Feuille d'investissement d'une catégorie : une ligne par actif détenu.
/// [showAccountSubtitle] ajoute en sous-titre le nom du compte porteur —
/// utile dans la vue "Par actif" (les lignes y sont mélangées entre
/// comptes), redondant dans l'accordéon d'un compte (les lignes y sont déjà
/// "à l'intérieur" du compte, voir `_buildAccountLeaf` — l'épargne y garde
/// une ligne simple pour sa devise, sans rappeler banque/compte).
PatrimoineAccount _buildLeaf(
  InvestmentAccount account,
  Investment investment,
  String vaultPath, {
  bool showAccountSubtitle = true,
}) {
  final valeur = investment.effectiveMarketValue ?? investment.investedAmount;
  final plusValueAbs = investment.unrealizedGain ?? 0;
  final costBasis = valeur - plusValueAbs;
  return PatrimoineAccount(
    id: investment.id,
    name: investment.label,
    subtitle: showAccountSubtitle ? account.name : null,
    quantite: investment.quantityHeld == 0 ? null : investment.quantityHeld,
    // Le cours est toujours affiché en euros : un titre coté en devise
    // étrangère (META en USD) voit son dernier cours converti au taux de
    // change enregistré (voir [Investment.quoteCurrency]).
    cours: _lastPriceToEur(investment),
    valeur: valeur,
    pru: investment.pru,
    priceUnavailable: investment.priceUnavailable,
    lastPriceDate: investment.lastPriceDate,
    plusValueAbs: plusValueAbs,
    plusValuePercent: costBasis == 0 ? 0 : plusValueAbs / costBasis * 100,
    // Métaux précieux : l'avatar affiche la photo du produit (pièce/lingot)
    // téléchargée localement quand elle existe — sauf ETC logé dans un CTO,
    // sans produit physique associé, où l'avatar affiche "ETC". Position en
    // devise (épargne, ou devise d'un compte-titres) : l'avatar affiche le
    // code de la devise tenue (EUR, GBP...).
    avatarImagePath: _metalAvatarImagePath(account, investment, vaultPath),
    avatarInitials:
        _currencyAvatarInitials(account, investment) ??
        _metalAvatarInitials(account, investment),
    isCurrency: isCurrencyInvestment(account, investment),
    // La ligne continue d'afficher la vraie valeur (voir doc de
    // `PatrimoineAccount.excludedFromPatrimoine`) — seul l'agrégat global du
    // Dashboard ([PatrimoineCategory.montantPatrimoine], utilisé par la
    // carte Allocation) l'ignore, jamais le total propre de sa catégorie
    // ([PatrimoineCategory.montant]). Un compte exclu dans son ensemble
    // (voir `InvestmentAccount.excludedFromPatrimoine`) marque chacune de
    // ses lignes, même sans exclusion individuelle.
    excludedFromPatrimoine:
        investment.excludedFromPatrimoine || account.excludedFromPatrimoine,
  );
}

/// Position en devise (épargne tenue en EUR/USD/GBP..., ou devise logée dans
/// un compte-titres — la devise est alors l'identifiant de l'investissement,
/// voir `identifierOptionsFor`) : l'avatar affiche le code de la devise
/// plutôt que des initiales dérivées du libellé, pour distinguer au premier
/// coup d'œil les comptes multi-devises.
String? _currencyAvatarInitials(
  InvestmentAccount account,
  Investment investment,
) {
  if (!isCurrencyInvestment(account, investment)) return null;
  final currency = investment.isin.trim().toUpperCase();
  return currency.isEmpty ? null : currency;
}

/// Métal précieux *physique* : chemin absolu de l'image locale du produit,
/// ou `null` si aucune n'a encore été téléchargée (voir
/// `price_refresh_service.dart`'s `_ensureMetalImages` et
/// `metal_image_repository.dart`) ou si l'investissement est un ETC coté
/// ([account] dans un CTO), qui n'a pas de produit sur le site marchand.
String? _metalAvatarImagePath(
  InvestmentAccount account,
  Investment investment,
  String vaultPath,
) {
  if ((investment.assetClass ?? account.assetClass) !=
      AssetClass.metauxPrecieux) {
    return null;
  }
  if (isMetalEtc(account)) return null;
  final fileName = investment.imageFileName;
  if (fileName == null || fileName.isEmpty) return null;
  return p.join(vaultPath, 'investissements', 'metaux', 'images', fileName);
}

/// Initiales d'avatar affichées à la place de celles dérivées du nom — "ETC"
/// pour un métal précieux coté détenu dans un CTO (l'image du produit n'a
/// pas de sens pour un titre financier).
String? _metalAvatarInitials(InvestmentAccount account, Investment investment) {
  if ((investment.assetClass ?? account.assetClass) !=
      AssetClass.metauxPrecieux) {
    return null;
  }
  return isMetalEtc(account) ? 'ETC' : null;
}

/// Le cours en euros affiché en colonne "Cours" : le dernier cours de
/// marché (dans sa devise de cotation, voir [Investment.lastPrice])
/// converti au taux de change enregistré ([Investment.lastFxRateToEur]) —
/// vaut le cours brut pour un titre coté en euros. Sans cours de marché
/// (ex : un objet "Autres"), retombe sur le cours estimé à la main par
/// l'utilisateur ([Investment.manualPrice], toujours en euros) ; `null`
/// sans aucun des deux.
double? _lastPriceToEur(Investment investment) {
  final lastPrice = investment.lastPrice;
  if (lastPrice != null) {
    return lastPrice * (investment.lastFxRateToEur ?? 1.0);
  }
  return investment.manualPrice;
}

/// Cours le plus proche à ou avant [date] dans [history] (triée par date
/// croissante) — prolonge le plus ancien cours connu vers le passé plutôt
/// que de renvoyer `null` quand [date] précède le premier point (un
/// produit dont l'historique Yahoo commence après l'achat, par exemple),
/// pour éviter une pique verticale trompeuse en début de courbe. `null`
/// seulement si [history] est vide. Public (contrairement aux autres
/// fonctions internes de ce fichier) : réutilisé tel quel par
/// `analyses_screen.dart` pour la comparaison au benchmark, plutôt que d'y
/// dupliquer une variante qui ne prolonge pas vers le passé.
double? priceAt(List<PricePoint> history, DateTime date) {
  double? priceAtDate;
  for (final p in history) {
    if (p.date.isAfter(date)) break;
    priceAtDate = p.close;
  }
  if (priceAtDate == null && history.isNotEmpty) {
    priceAtDate = history.first.close;
  }
  return priceAtDate;
}

/// Quelques dates régulièrement espacées entre [start] et [end] inclus,
/// toujours terminées par [end] — même principe que [evenDateGrid], mais
/// avec beaucoup moins de points : suffisant pour une sparkline de
/// quelques dizaines de pixels dans "Mes meilleures performances", pas
/// besoin de la résolution ~30 points du graphique principal.
List<DateTime> _sparklineDateGrid(
  DateTime start,
  DateTime end, {
  int points = 8,
}) {
  if (!end.isAfter(start)) return [start, end];
  final totalDays = end.difference(start).inDays;
  final stepDays = math.max(1, (totalDays / (points - 1)).ceil());
  final dates = <DateTime>[
    for (var offset = 0; offset < totalDays; offset += stepDays)
      start.add(Duration(days: offset)),
  ];
  dates.add(end);
  return dates;
}

/// Rendement de MA position sur [period] : la valeur de la position
/// aujourd'hui comparée à sa valeur en tout début de période, plus les
/// flux réels (achats/ventes) survenus depuis — même modèle que le
/// rendement money-weighted "période courte" de [calculateMwr]
/// (`performance_calculator.dart`), simplement amorcé par la valeur de la
/// position en début de période plutôt que par zéro. Contrairement à
/// l'ancien [_priceReturnForPeriod] (rendement du cours seul), reflète ce
/// que j'ai réellement gagné ou perdu sur MA position — une position
/// achetée en cours de période n'est jamais pénalisée/avantagée par un
/// mouvement de cours antérieur à mon achat. `null` seulement si rien
/// n'était investi ni détenu au départ (position ouverte pile aujourd'hui).
({double euros, double? percent})? _positionReturnForPeriod(
  Investment investment,
  Map<String, List<PricePoint>> priceHistories,
  DashboardPeriod period,
) {
  final today = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final earliest = earliestTransactionDate([investment]) ?? today;
  final start = period.startFor(today: today, earliest: earliest);
  var netInvested = _valuationAt([investment], priceHistories, start);
  for (final t in investment.transactions) {
    if (!_onOrBeforeDay(t.date, start)) {
      netInvested += t.isBuy ? t.amount : -t.amount;
    }
  }
  final valuationToday = _valuationAt([investment], priceHistories, today);
  final euros = valuationToday - netInvested;
  final percent = netInvested > 0 ? euros / netInvested * 100 : null;
  return (euros: euros, percent: percent);
}

/// Un [DashboardAsset] par investissement valorisé, pour réutiliser
/// [TopAssetsRow] tel quel — [DashboardAsset.changeForPeriod] donne MA
/// performance sur la position (voir [_positionReturnForPeriod]), le même
/// calcul pour les 6 périodes.
List<DashboardAsset> buildRealTopAssets(
  List<InvestmentAccount> accounts,
  Map<String, List<PricePoint>> priceHistories,
) {
  final assets = <DashboardAsset>[];
  for (final account in accounts) {
    for (final investment in account.investments) {
      if (investment.quantityHeld <= 0) continue;
      // Un investissement (ou un compte entier) exclu du patrimoine n'a pas
      // sa place dans un classement de performance — contrairement aux
      // tableaux de positions "bruts", où il reste toujours visible (juste
      // marqué).
      if (investment.excludedFromPatrimoine || account.excludedFromPatrimoine) {
        continue;
      }
      final history = priceHistories[investment.isin] ?? const [];
      assets.add(
        DashboardAsset(
          name: investment.label,
          ticker: investment.isin,
          sparklineForPeriod: (period) {
            if (history.length < 2) {
              // Sans historique, la sparkline en deux points compare le PRU
              // au dernier cours — en euros, taux de change compris, pour
              // rester homogène (voir [_lastPriceToEur]).
              return [
                investment.pru,
                _lastPriceToEur(investment) ?? investment.pru,
              ];
            }
            final today = DateTime.utc(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            );
            final earliest = earliestTransactionDate([investment]) ?? today;
            final start = period.startFor(today: today, earliest: earliest);
            return [
              for (final date in _sparklineDateGrid(start, today))
                _valuationAt([investment], priceHistories, date),
            ];
          },
          changeForPeriod: (period) =>
              _positionReturnForPeriod(investment, priceHistories, period),
        ),
      );
    }
  }
  return assets;
}

/// Première date de transaction, tous [investments] confondus — `null` sans
/// aucune transaction. Sert de repli pour la borne de départ de la période
/// "Tout" (voir `DashboardPeriod.all`), jamais remontée plus tôt qu'elle.
DateTime? earliestTransactionDate(List<Investment> investments) {
  DateTime? earliest;
  for (final investment in investments) {
    for (final t in investment.transactions) {
      if (earliest == null || t.date.isBefore(earliest)) earliest = t.date;
    }
  }
  if (earliest == null) return null;
  return DateTime.utc(earliest.year, earliest.month, earliest.day);
}

/// ~30 dates régulièrement espacées entre [start] et [end] inclus, toujours
/// terminées par [end] — grille partagée par le côté actif
/// ([netWorthHistoryFor]) et passif (`real_passifs_adapter.dart`) du
/// Dashboard, pour qu'une même période sélectionnée produise le même
/// domaine de dates des deux côtés (nécessaire pour soustraire terme à
/// terme dans `buildPatrimoineChartData`).
List<DateTime> evenDateGrid(DateTime start, DateTime end) {
  if (!end.isAfter(start)) return [start, end];
  final totalDays = end.difference(start).inDays;
  final stepDays = math.max(1, (totalDays / 30).ceil());
  final dates = <DateTime>[
    for (var offset = 0; offset < totalDays; offset += stepDays)
      start.add(Duration(days: offset)),
  ];
  dates.add(end);
  return dates;
}

/// Reconstruit un historique de patrimoine (somme, jour par jour, de
/// `quantité détenue × cours à cette date`) depuis les transactions et
/// l'historique de cours en cache de [investments], entre [start] et [end]
/// (voir [evenDateGrid]) — bornes calculées par l'appelant à partir de la
/// période sélectionnée (voir `DashboardPeriod.startFor`), pas dérivées ici
/// de la première transaction : la même fonction sert aussi bien "1M" que
/// "Tout" sans jamais générer une grille sur l'historique complet puis la
/// trancher a posteriori (ancien bug de correspondance période ↔ durée).
List<NetWorthPoint> netWorthHistoryFor(
  List<Investment> investments,
  Map<String, List<PricePoint>> priceHistories, {
  required DateTime start,
  required DateTime end,
}) {
  final points = [
    for (final date in evenDateGrid(start, end))
      NetWorthPoint(date, _valuationAt(investments, priceHistories, date)),
  ];
  // Une période qui ne contient qu'un seul jour (`start == end`, ex. "1J"
  // sur un compte créé aujourd'hui) ne produirait qu'un seul point — le
  // graphique d'évolution exige au moins deux points (voir `NetWorthChart`)
  // et afficherait sinon "Pas assez de données sur cette période". On
  // ajoute le point de départ, au même jour et à la même valeur : la
  // courbe se réduit à une ligne plate, ce qui reflète honnêtement
  // l'absence d'historique sur cette période.
  if (points.length < 2) {
    points.insert(
      0,
      NetWorthPoint(start, _valuationAt(investments, priceHistories, start)),
    );
  }
  return points;
}

/// `true` si [when] tombe le même jour calendaire ou avant [date]. Les dates
/// de la grille sont des minuits UTC alors que les transactions peuvent être
/// horodatées dans la journée (ex : le dialogue de complétion rapide repart
/// de `DateTime.now()`) : comparer par instant rejetterait une transaction du
/// jour même dès que son heure locale dépasse minuit UTC (en été en France,
/// tout achat saisi après 02:00 du matin disparaissait du dernier point, et
/// la série entière d'un actif créé aujourd'hui tombait à zéro).
bool _onOrBeforeDay(DateTime when, DateTime date) {
  return when.year < date.year ||
      (when.year == date.year &&
          (when.month < date.month ||
              (when.month == date.month && when.day <= date.day)));
}

double _valuationAt(
  List<Investment> investments,
  Map<String, List<PricePoint>> priceHistories,
  DateTime date,
) {
  var total = 0.0;
  for (final investment in investments) {
    var quantity = 0.0;
    var invested = 0.0;
    for (final t in investment.transactions) {
      if (_onOrBeforeDay(t.date, date)) {
        quantity += t.isBuy ? t.quantity : -t.quantity;
        invested += t.isBuy ? t.amount : -t.amount;
      }
    }
    if (quantity == 0) continue;

    // [priceAt] prolonge le plus ancien cours connu vers le passé plutôt
    // que de renvoyer `null` avant le premier point (un produit métal dont
    // le premier relevé quotidien est plus récent que l'achat, ou un titre
    // acheté avant le début de son historique Yahoo) : sans ce repli, la
    // courbe sautait d'un seul coup du montant investi au cours de marché
    // au premier point de cours, créant une pique verticale trompeuse en
    // bout de graphique. Même convention que `calculateTwr`
    // (`performance_calculator.dart`), qui valorise déjà la période
    // antérieure au premier cours au prix de ce premier cours.
    final history = priceHistories[investment.isin] ?? const [];
    final priceAtDate = priceAt(history, date);
    if (priceAtDate != null) {
      total += quantity * priceAtDate;
    } else {
      total += _manualValuationAt(investment, quantity, date) ?? invested;
    }
  }
  return total;
}

/// Valorisation manuelle d'un investissement sans cours de marché (voir
/// [_valuationAt]) : cours estimé à la main × [quantity] détenue à [date]
/// pour un objet "Autres" ([Investment.manualPrice]), ou surface × prix/m²
/// estimé pour l'immobilier ([Investment.estimatedPricePerSqm]) — `null`
/// avant que l'utilisateur n'ait renseigné une estimation (voir
/// [Investment.manualPriceAt]/[Investment.estimatedValueAt]), auquel cas
/// [_valuationAt] retombe sur le montant investi comme avant cette date.
double? _manualValuationAt(Investment investment, double quantity, DateTime date) {
  final manualPrice = investment.manualPrice;
  final manualPriceAt = investment.manualPriceAt;
  if (manualPrice != null &&
      manualPriceAt != null &&
      _onOrBeforeDay(manualPriceAt, date)) {
    return quantity * manualPrice;
  }
  final estimatedPricePerSqm = investment.estimatedPricePerSqm;
  final estimatedValueAt = investment.estimatedValueAt;
  if (investment.surfaceM2 != null &&
      estimatedPricePerSqm != null &&
      estimatedValueAt != null &&
      _onOrBeforeDay(estimatedValueAt, date)) {
    return investment.surfaceM2! * estimatedPricePerSqm;
  }
  return null;
}

/// Première date de transaction, tous [accounts] confondus — `null` sans
/// aucun investissement. Même rôle que [earliestTransactionDate], mais à
/// l'échelle de tous les comptes (le Dashboard doit borner sa période
/// "Tout" sur la donnée la plus ancienne toutes classes confondues, pas
/// classe par classe) plutôt que d'une seule liste d'investissements déjà
/// filtrée par classe.
DateTime? earliestTransactionDateAcrossAccounts(
  List<InvestmentAccount> accounts,
) {
  DateTime? earliest;
  for (final account in accounts) {
    final candidate = earliestTransactionDate(account.investments);
    if (candidate == null) continue;
    if (earliest == null || candidate.isBefore(earliest)) earliest = candidate;
  }
  return earliest;
}

/// Investissements dont la classe effective (voir [buildRealCategories])
/// est [assetClass], tous comptes confondus — pour isoler la série
/// d'une seule classe avant de l'évaluer sur une grille commune via
/// [categoryHistoryOnGrid].
///
/// [excludeFlagged] (`false` par défaut) omet les investissements — ou les
/// comptes entiers — marqués "exclus du patrimoine" (voir
/// [Investment.excludedFromPatrimoine]/[InvestmentAccount.excludedFromPatrimoine]).
/// Seule la courbe "Patrimoine net/brut" du Dashboard
/// (`dashboard_screen.dart`'s `_actifsHistoryFor`) le met à `true` : les
/// pages de catégorie et Analyses continuent de tout comptabiliser.
List<Investment> investmentsForEffectiveClass(
  List<InvestmentAccount> accounts,
  AssetClass assetClass, {
  bool excludeFlagged = false,
}) {
  return [
    for (final account in accounts)
      for (final investment in account.investments)
        if ((investment.assetClass ?? account.assetClass) == assetClass &&
            (!excludeFlagged ||
                (!investment.excludedFromPatrimoine &&
                    !account.excludedFromPatrimoine)))
          investment,
  ];
}

/// Grille quotidienne complète entre [start] et [end] (bornes incluses) —
/// contrairement à [evenDateGrid] (~30 points espacés, conçue pour
/// l'économie de rendu du graphique dashboard), chaque jour calendaire est
/// représenté. Nécessaire aux séries de rendements de l'écran Analyses
/// (volatilité, corrélation...) : annualiser un écart-type par
/// `sqrt(365)` suppose un pas régulier d'un jour — un pas plus grossier
/// (mensuel sur une longue période avec [evenDateGrid]) rendrait ce facteur
/// faux.
List<DateTime> dailyDateGrid(DateTime start, DateTime end) => [
  for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) d,
];

/// Comme [netWorthHistoryFor], mais évalué aux dates de [grid] (voir
/// [evenDateGrid]) plutôt que sur une grille propre à [investments] — pour
/// que plusieurs classes d'actif partagent les mêmes abscisses et puissent
/// être empilées dans le graphique "Patrimoine complet".
List<NetWorthPoint> categoryHistoryOnGrid(
  List<Investment> investments,
  Map<String, List<PricePoint>> priceHistories,
  List<DateTime> grid,
) {
  return [
    for (final date in grid)
      NetWorthPoint(date, _valuationAt(investments, priceHistories, date)),
  ];
}

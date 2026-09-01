import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, Color;
import '../dashboard/patrimoine_models.dart';
import 'investments_models.dart';
import 'leveraged_position.dart';
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
  final leveragedByClass =
      <AssetClass, List<(InvestmentAccount, LeveragedPosition)>>{};
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
    // Une position à effet de levier n'a pas de classe effective propre
    // (pas d'ISIN, pas de notion de "titre logé dans un compte d'une autre
    // classe" comme un ETC métaux dans un CTO) : elle compte toujours pour
    // la classe de son compte porteur.
    for (final position in account.leveragedPositions) {
      if (!position.isOpen) continue;
      leveragedByClass
          .putIfAbsent(account.assetClass, () => [])
          .add((account, position));
    }
  }
  return [
    for (final assetClass in {...byClass.keys, ...leveragedByClass.keys})
      _buildCategory(
        assetClass,
        byClass[assetClass] ?? const [],
        leveragedByClass[assetClass] ?? const [],
        priceHistories,
        vaultPath,
      ),
  ];
}

PatrimoineCategory _buildCategory(
  AssetClass assetClass,
  List<(InvestmentAccount, Investment)> pairs,
  List<(InvestmentAccount, LeveragedPosition)> leveragedPairs,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final meta = _categoryMeta[assetClass]!;
  final leaves = <PatrimoineAccount>[
    for (final (account, investment) in pairs)
      _buildLeaf(account, investment, vaultPath, priceHistories),
    for (final (account, position) in leveragedPairs)
      _buildLeveragedLeaf(account, position),
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
/// Dashboard ([CategoryBreakdownCard]) et pour la vue "par compte" de
/// l'Allocation ([CategoryDetailScreen]) — le détail par investissement
/// reste sur la page dédiée à la classe d'actif via [buildRealCategories].
List<PatrimoineCategory> buildRealCategoriesByAccount(
  List<InvestmentAccount> accounts,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final byClass = <AssetClass, List<(InvestmentAccount, Investment)>>{};
  // Comptes qui ont besoin d'une feuille dans LEUR PROPRE classe sans y
  // avoir de paire spot (via [byClass]) : soit un compte sans aucun
  // investissement (tout juste créé, ou vidé après suppression de sa
  // dernière position — sans ce repli, il resterait invisible de tout
  // accordéon établissement → comptes et donc inatteignable pour être
  // complété ou supprimé), soit un compte dont tous les investissements
  // sont redirigés vers une autre classe (cross-class, voir
  // [accountAcceptsCrossClassInvestment]) mais qui porte aussi une position
  // à effet de levier — toujours comptée dans SA classe, jamais celle d'un
  // investissement cross-class (voir [_buildAccountLeaf]), elle y
  // deviendrait sinon invisible faute de toute feuille "Actions & Fonds"/
  // "Crypto" pour ce compte.
  final ownClassLeafNeededFor = <AssetClass, List<InvestmentAccount>>{};
  for (final account in accounts) {
    if (account.investments.isEmpty) {
      ownClassLeafNeededFor
          .putIfAbsent(account.assetClass, () => [])
          .add(account);
      continue;
    }
    var hasOwnClassInvestment = false;
    for (final investment in account.investments) {
      final effectiveClass = investment.assetClass ?? account.assetClass;
      if (effectiveClass == account.assetClass) hasOwnClassInvestment = true;
      byClass.putIfAbsent(effectiveClass, () => []).add((account, investment));
    }
    if (!hasOwnClassInvestment &&
        account.leveragedPositions.any((p) => p.isOpen)) {
      ownClassLeafNeededFor
          .putIfAbsent(account.assetClass, () => [])
          .add(account);
    }
  }
  return [
    for (final assetClass in {...byClass.keys, ...ownClassLeafNeededFor.keys})
      _buildCategoryByAccount(
        assetClass,
        byClass[assetClass] ?? const [],
        ownClassLeafNeededFor[assetClass] ?? const [],
        priceHistories,
        vaultPath,
      ),
  ];
}

PatrimoineCategory _buildCategoryByAccount(
  AssetClass assetClass,
  List<(InvestmentAccount, Investment)> pairs,
  // Comptes sans paire spot dans [pairs] pour cette classe (vide, ou
  // entièrement cross-class) mais qui ont quand même besoin d'une feuille
  // ici — voir la doc de [buildRealCategoriesByAccount]'s
  // `ownClassLeafNeededFor`.
  List<InvestmentAccount> accountsWithoutOwnClassPair,
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
      _buildAccountLeaf(
        accountPairs.first.$1,
        accountPairs,
        vaultPath,
        priceHistories,
        assetClass: assetClass,
      ),
    for (final account in accountsWithoutOwnClassPair)
      _buildAccountLeaf(
        account,
        const [],
        vaultPath,
        priceHistories,
        assetClass: assetClass,
      ),
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
  Map<String, List<PricePoint>> priceHistories, {
  // Une position à effet de levier compte toujours pour la classe du
  // compte porteur (voir `_buildLeveragedLeaf`), jamais une classe
  // "effective" cross-class (ex : un ETC métaux logé dans un CTO) — sans ce
  // garde-fou, un compte Actions & Fonds qui porte À LA FOIS un ETC métaux
  // ET une position à effet de levier verrait cette dernière comptée deux
  // fois (une fois dans la catégorie "Métaux précieux", une fois dans
  // "Actions & Fonds"), cette fonction étant appelée une fois par classe
  // effective présente sur le compte.
  required AssetClass assetClass,
}) {
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
    final v = investment.displayValue;
    final gain = investment.unrealizedGain ?? 0;
    valeur += v;
    plusValueAbs += gain;
    costBasis += v - gain;
  }
  // Positions à effet de levier du compte (voir `LeveragedPosition`) — même
  // principe qu'un investissement spot : `displayValue` (marge + PnL
  // latent, jamais la valeur notionnelle) alimente `valeur`, la marge
  // engagée tient lieu de "coût d'acquisition" pour le calcul du
  // pourcentage de plus-value. Ignore les positions fermées (`displayValue`
  // vaut alors 0, `pnl` déjà réalisé) — et, hors de la classe propre du
  // compte, ne compte que pour elle (voir la doc du paramètre [assetClass]
  // ci-dessus, contre un double comptage sur un compte cross-class).
  final openLeveragedPositions = assetClass == account.assetClass
      ? [for (final p in account.leveragedPositions) if (p.isOpen) p]
      : const <LeveragedPosition>[];
  for (final position in openLeveragedPositions) {
    valeur += position.displayValue;
    plusValueAbs += position.pnl ?? 0;
    costBasis += position.margin;
  }
  final investmentsIci = [
    for (final (_, investment) in heldPairs) investment,
  ];
  // Contribution des positions à effet de levier du compte, constante quelle
  // que soit la période choisie (voir `_buildLeveragedLeaf`) — ajoutée telle
  // quelle au calcul, forcément period-aware, des positions spot du compte.
  final leveragedPnl = openLeveragedPositions.fold(
    0.0,
    (sum, p) => sum + (p.pnl ?? 0),
  );
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
    // `null` (pas `0`) sans coût d'acquisition (ex : un objet "Autres" reçu
    // en cadeau) — une plus-value relative à 0 € investi est infinie, pas
    // nulle : voir `PatrimoineAccount.plusValuePercent`.
    plusValuePercent: costBasis == 0 ? null : plusValueAbs / costBasis * 100,
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
          priceHistories,
          // Sous-titre du compte porteur inutile ici : ces lignes sont déjà
          // affichées à l'intérieur du compte (et de la banque pour
          // l'épargne) — une ligne simple par devise, sans répétition.
          showAccountSubtitle: false,
        ),
      for (final position in openLeveragedPositions)
        _buildLeveragedLeaf(account, position, showAccountSubtitle: false),
    ],
    // Reflète l'état du compte réel dans son ensemble, pas seulement ses
    // investissements de cette classe : un compte avec des transactions
    // dans une autre classe (cross-class) ne doit pas non plus être
    // supprimable depuis ici.
    canDelete: account.investments.every((i) => i.transactions.isEmpty),
    periodChangeFor: (period) {
      final r = periodValueChangeFor(investmentsIci, priceHistories, period);
      final euros = r.euros + leveragedPnl;
      final startValue = valeur - euros;
      return (
        euros: euros,
        percent: startValue != 0 ? euros / startValue * 100 : null,
      );
    },
    periodPnlFor: (period) {
      final r = periodReturnFor(investmentsIci, priceHistories, period);
      final euros = r.euros + leveragedPnl;
      final netInvested = valeur - euros;
      return (
        euros: euros,
        percent: netInvested > 0 ? euros / netInvested * 100 : null,
      );
    },
  );
}

/// Comme [buildRealCategoriesByAccount], mais chaque *investissement réel*
/// (identifié par son ISIN) devient une ligne [PatrimoineAccount] fusionnée
/// entre tous les comptes qui le détiennent — quantité/coût/valeur/plus-
/// value sommés, PRU recalculé sur l'ensemble (moyenne pondérée par la
/// quantité, la même formule que [Investment.pru] à l'échelle d'un seul
/// investissement). Sert la bascule "Par compte / Par investissement" des
/// comptes-titres (`category_detail_screen.dart`'s `_AccountsCard`) : un
/// même titre détenu dans plusieurs comptes (PEA et CTO, par exemple) n'y
/// forme plus qu'une seule ligne, le détail par compte restant disponible
/// en dépliant son chevron (voir [_buildMergedInvestmentLeaf]) plutôt que
/// dupliqué en plusieurs lignes à PRU différents.
List<PatrimoineCategory> buildRealCategoriesByInvestment(
  List<InvestmentAccount> accounts,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final byClass = <AssetClass, List<(InvestmentAccount, Investment)>>{};
  final leveragedByClass =
      <AssetClass, List<(InvestmentAccount, LeveragedPosition)>>{};
  for (final account in accounts) {
    for (final investment in account.investments) {
      // Même filtre que [buildRealCategories] : une position entièrement
      // soldée est un historique, pas une détention actuelle.
      if (investment.quantityHeld <= 0) continue;
      final effectiveClass = investment.assetClass ?? account.assetClass;
      byClass.putIfAbsent(effectiveClass, () => []).add((account, investment));
    }
    // Même principe que [buildRealCategories] : une position à effet de
    // levier n'a pas de classe effective propre, elle compte toujours pour
    // celle de son compte porteur — jamais fusionnée avec un titre spot
    // (voir [_buildCategoryByInvestment], une ligne à part par position).
    for (final position in account.leveragedPositions) {
      if (!position.isOpen) continue;
      leveragedByClass
          .putIfAbsent(account.assetClass, () => [])
          .add((account, position));
    }
  }
  return [
    for (final assetClass in {...byClass.keys, ...leveragedByClass.keys})
      _buildCategoryByInvestment(
        assetClass,
        byClass[assetClass] ?? const [],
        leveragedByClass[assetClass] ?? const [],
        priceHistories,
        vaultPath,
      ),
  ];
}

PatrimoineCategory _buildCategoryByInvestment(
  AssetClass assetClass,
  List<(InvestmentAccount, Investment)> pairs,
  List<(InvestmentAccount, LeveragedPosition)> leveragedPairs,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final meta = _categoryMeta[assetClass]!;
  final byIsin = <String, List<(InvestmentAccount, Investment)>>{};
  for (final pair in pairs) {
    byIsin.putIfAbsent(pair.$2.isin, () => []).add(pair);
  }
  final leaves = <PatrimoineAccount>[
    for (final group in byIsin.values)
      _buildMergedInvestmentLeaf(group, vaultPath, priceHistories),
    for (final (account, position) in leveragedPairs)
      _buildLeveragedLeaf(account, position),
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

/// Une ligne pour [group], un même ISIN détenu dans un ou plusieurs comptes.
/// Un seul compte : identique à [_buildLeaf] (rien à fusionner, le sous-
/// titre affiche déjà le compte porteur). Plusieurs comptes : quantité/
/// valeur/plus-value sommées et PRU recalculé en moyenne pondérée (coût
/// total investi ÷ quantité totale détenue), avec le détail par compte
/// porté par [PatrimoineAccount.investments] pour le second niveau de
/// l'accordéon — [_AccountAccordionTile] de `category_detail_screen.dart`
/// sait déjà déplier ce champ (utilisé jusqu'ici pour les investissements
/// d'un compte, réutilisé tel quel ici pour les comptes d'un investissement).
PatrimoineAccount _buildMergedInvestmentLeaf(
  List<(InvestmentAccount, Investment)> group,
  String vaultPath,
  Map<String, List<PricePoint>> priceHistories,
) {
  if (group.length == 1) {
    final (account, investment) = group.single;
    return _buildLeaf(
      account,
      investment,
      vaultPath,
      priceHistories,
      showAccountSubtitle: true,
    );
  }
  final first = group.first.$2;
  var quantite = 0.0;
  var investedAmount = 0.0;
  var valeur = 0.0;
  var plusValueAbs = 0.0;
  DateTime? lastPriceDate;
  for (final (_, investment) in group) {
    quantite += investment.quantityHeld;
    investedAmount += investment.investedAmount;
    valeur += investment.displayValue;
    plusValueAbs += investment.unrealizedGain ?? 0;
    final date = investment.lastPriceDate;
    if (date != null &&
        (lastPriceDate == null || date.isAfter(lastPriceDate))) {
      lastPriceDate = date;
    }
  }
  final costBasis = valeur - plusValueAbs;
  // Le cours de marché est le même quel que soit le compte porteur (même
  // titre réel) : on prend celui du premier investissement du groupe qui en
  // connaît un, plutôt que d'en faire une moyenne qui n'aurait pas de sens
  // pour un cours coté.
  var priced = first;
  for (final (_, investment) in group) {
    if (investment.lastPrice != null) {
      priced = investment;
      break;
    }
  }
  return PatrimoineAccount(
    id: 'merged_${first.isin}',
    name: first.label,
    subtitle: '${group.length} comptes',
    quantite: quantite == 0 ? null : quantite,
    cours: _lastPriceToEur(priced),
    valeur: valeur,
    pru: quantite == 0 ? 0 : investedAmount / quantite,
    priceUnavailable: priced.priceUnavailable,
    lastPriceDate: lastPriceDate,
    manualPriceAt: priced.lastPrice == null ? priced.manualPriceAt : null,
    plusValueAbs: plusValueAbs,
    // `null` (pas `0`) sans coût d'acquisition — voir
    // `PatrimoineAccount.plusValuePercent`.
    plusValuePercent: costBasis == 0 ? null : plusValueAbs / costBasis * 100,
    isCurrency: isCurrencyInvestment(group.first.$1, first),
    avatarCryptoSymbol: _cryptoAvatarSymbol(group.first.$1, first),
    // Fusionnée uniquement si *toutes* les positions sources le sont : une
    // fusion partiellement exclue continue de compter partiellement dans les
    // agrégats réels, pas la peine d'induire en erreur avec un badge sur
    // l'ensemble de la ligne — voir `Investment.excludedFromPatrimoine`.
    excludedFromPatrimoine: group.every((p) => p.$2.excludedFromPatrimoine),
    investments: [
      for (final (account, investment) in group)
        _buildLeaf(
          account,
          investment,
          vaultPath,
          priceHistories,
          showAccountSubtitle: true,
        ),
    ],
    canDelete: false,
    periodChangeFor: (period) => periodValueChangeFor(
      [for (final (_, investment) in group) investment],
      priceHistories,
      period,
    ),
    periodPnlFor: (period) => periodReturnFor(
      [for (final (_, investment) in group) investment],
      priceHistories,
      period,
    ),
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
  String vaultPath,
  Map<String, List<PricePoint>> priceHistories, {
  bool showAccountSubtitle = true,
}) {
  final valeur = investment.displayValue;
  // `null` (pas `0`) sans valorisation jamais connue (ni cours de marché,
  // ni estimation manuelle) — distinct d'une plus-value réellement nulle,
  // voir la doc de [PatrimoineAccount.plusValueAbs].
  final plusValueAbs = investment.unrealizedGain;
  final costBasis = plusValueAbs == null ? null : valeur - plusValueAbs;
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
    // Seulement quand le cours vient bien de cette estimation (pas d'un
    // cours de marché récupéré depuis) — voir `_lastPriceToEur`, qui ne se
    // rabat sur `manualPrice` que si `lastPrice` est `null`.
    manualPriceAt: investment.lastPrice == null
        ? investment.manualPriceAt
        : null,
    plusValueAbs: plusValueAbs,
    // `null` (pas `0`) sans coût d'acquisition (ex : un objet "Autres" reçu
    // en cadeau) — une plus-value relative à 0 € investi est infinie, pas
    // nulle : voir `PatrimoineAccount.plusValuePercent`. `null` aussi,
    // logiquement, quand [plusValueAbs] lui-même l'est.
    plusValuePercent: costBasis == null || costBasis == 0
        ? null
        : plusValueAbs! / costBasis * 100,
    // Métaux précieux : l'avatar affiche la photo du produit (pièce/lingot)
    // téléchargée localement quand elle existe — sauf ETC logé dans un CTO,
    // sans produit physique associé, où l'avatar affiche "ETC". Position en
    // devise (épargne, ou devise d'un compte-titres) : l'avatar affiche le
    // code de la devise tenue (EUR, GBP...).
    avatarImagePath: _metalAvatarImagePath(account, investment, vaultPath),
    avatarInitials:
        _currencyAvatarInitials(account, investment) ??
        _metalAvatarInitials(account, investment),
    avatarCryptoSymbol: _cryptoAvatarSymbol(account, investment),
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
    periodChangeFor: (period) =>
        periodValueChangeFor([investment], priceHistories, period),
    periodPnlFor: (period) =>
        periodReturnFor([investment], priceHistories, period),
  );
}

/// Feuille d'une position à effet de levier — une ligne par position
/// ouverte, comme [_buildLeaf] pour un investissement spot. [id] pointe
/// vers le COMPTE (pas la position, qui n'a pas d'écran dédié) : cliquer la
/// ligne ouvre le compte, où l'onglet "Positions à effet de levier" prend
/// le relais pour modifier/clôturer — [canDelete] reste `false`, le menu
/// générique de suppression d'un investissement ne sait pas résoudre l'id
/// d'une [LeveragedPosition]. [showAccountSubtitle] suit la même convention
/// que [_buildLeaf] : `false` quand la ligne est déjà nichée dans
/// l'accordéon de son compte porteur (voir [_buildAccountLeaf]), où
/// répéter son nom en sous-titre serait redondant.
PatrimoineAccount _buildLeveragedLeaf(
  InvestmentAccount account,
  LeveragedPosition position, {
  bool showAccountSubtitle = true,
}) {
  final leverageLabel = position.leverage == position.leverage.roundToDouble()
      ? position.leverage.toStringAsFixed(0)
      : position.leverage.toString();
  return PatrimoineAccount(
    id: account.id,
    name: '${position.market} ${position.side.label}',
    subtitle: showAccountSubtitle ? account.name : null,
    // Taille de la position (unités du sous-jacent) tient lieu de
    // "quantité" — [pru] est le prix d'entrée (converti en euros, voir
    // [LeveragedPosition.entryPriceInEur]), [cours] le dernier prix de
    // référence connu ([LeveragedPosition.markPrice], déjà en euros que la
    // position soit crypto — auto-actualisé, voir `price_refresh_service
    // .dart` — ou Actions & Fonds — saisi à la main, jamais en devise
    // étrangère) : mêmes colonnes qu'une position spot, pour une lecture
    // cohérente du tableau.
    quantite: position.size,
    cours: position.markPrice,
    pru: position.entryPriceInEur,
    lastPriceDate: position.markPriceAt,
    valeur: position.displayValue,
    // `null` (pas `0`) tant que [LeveragedPosition.markPrice] n'a jamais été
    // connu — même principe que [_buildLeaf], voir la doc de
    // `PatrimoineAccount.plusValueAbs`. [roePercent] est déjà `null` dans ce
    // cas (voir sa doc), rien à ajuster côté pourcentage.
    plusValueAbs: position.pnl,
    plusValuePercent: position.roePercent,
    // Même logo crypto qu'une position spot du même ticker (voir
    // [_cryptoAvatarSymbol]) — sans objet `Investment` ici pour le
    // réutiliser tel quel, reconstruit directement depuis [position.market].
    avatarCryptoSymbol: account.assetClass == AssetClass.crypto
        ? position.market.trim().toUpperCase()
        : null,
    canDelete: false,
    excludedFromPatrimoine: account.excludedFromPatrimoine,
    leverageBadge: '${leverageLabel}x',
    // Pas d'historique de cours quotidien fiable pour une position à effet
    // de levier (voir la doc de classe) : plutôt que de la faire disparaître
    // des colonnes Évolution/PnL des tableaux génériques dès qu'une période
    // autre que "Tout" est choisie, ces closures ignorent [period] et
    // renvoient toujours le PnL/ROE depuis l'ouverture — déjà ce
    // qu'affichaient [plusValueAbs]/[plusValuePercent] ci-dessus.
    periodChangeFor: (_) => (euros: position.pnl ?? 0, percent: position.roePercent),
    periodPnlFor: (_) => (euros: position.pnl ?? 0, percent: position.roePercent),
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

/// Ticker d'une position crypto (ex : "BTC") — voir [PatrimoineAccount.
/// avatarCryptoSymbol]. `null` hors crypto : l'identifiant y sert de ticker
/// (pas d'ISIN pour une crypto, voir `identifierOptionsFor`), contrairement
/// aux autres classes où [investment.isin] n'a pas ce sens.
String? _cryptoAvatarSymbol(InvestmentAccount account, Investment investment) {
  if ((investment.assetClass ?? account.assetClass) != AssetClass.crypto) {
    return null;
  }
  final ticker = investment.isin.trim().toUpperCase();
  return ticker.isEmpty ? null : ticker;
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

/// Rendement de MES positions sur [period] : leur valeur cumulée aujourd'hui
/// comparée à leur valeur cumulée en tout début de période, plus les flux
/// réels (achats/ventes) survenus depuis — même modèle que le rendement
/// money-weighted "période courte" de [calculateMwr]
/// (`performance_calculator.dart`), simplement amorcé par la valeur de la
/// position en début de période plutôt que par zéro. Contrairement à
/// [periodValueChangeFor] (delta brut de valorisation), reflète ce que j'ai
/// réellement gagné ou perdu — un versement/retrait pendant la période ne
/// fausse jamais ce nombre, ni une position achetée en cours de période
/// pénalisée/avantagée par un mouvement de cours antérieur à mon achat.
/// Généralisée depuis l'ancienne `_positionReturnForPeriod` (un seul
/// [Investment]) pour pouvoir aussi être appelée sur tout un compte ou toute
/// une catégorie — voir [PatrimoineAccount.periodPnlFor].
({double euros, double? percent}) periodReturnFor(
  List<Investment> investments,
  Map<String, List<PricePoint>> priceHistories,
  DashboardPeriod period,
) {
  final today = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final earliest = earliestTransactionDate(investments) ?? today;
  final start = period.startFor(today: today, earliest: earliest);
  var netInvested = _valuationAt(investments, priceHistories, start);
  for (final investment in investments) {
    for (final t in investment.transactions) {
      if (!_onOrBeforeDay(t.date, start)) {
        netInvested += t.isBuy ? t.amount : -t.amount;
      }
    }
  }
  final valuationToday = _valuationAt(investments, priceHistories, today);
  final euros = valuationToday - netInvested;
  final percent = netInvested > 0 ? euros / netInvested * 100 : null;
  return (euros: euros, percent: percent);
}

/// Delta brut de valorisation de MES positions sur [period] : leur valeur
/// cumulée aujourd'hui moins leur valeur cumulée en tout début de période —
/// contrairement à [periodReturnFor], n'exclut PAS l'effet d'un versement ou
/// retrait survenu pendant la période (un dépôt qui finance un nouvel achat
/// augmente ce nombre autant qu'une vraie plus-value). C'est la colonne
/// "Évolution" des tableaux d'actifs — voir [PatrimoineAccount.periodChangeFor].
({double euros, double? percent}) periodValueChangeFor(
  List<Investment> investments,
  Map<String, List<PricePoint>> priceHistories,
  DashboardPeriod period,
) {
  final today = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final earliest = earliestTransactionDate(investments) ?? today;
  final start = period.startFor(today: today, earliest: earliest);
  final startValue = _valuationAt(investments, priceHistories, start);
  final endValue = _valuationAt(investments, priceHistories, today);
  final euros = endValue - startValue;
  final percent = startValue != 0 ? euros / startValue * 100 : null;
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
              periodReturnFor([investment], priceHistories, period),
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
      total +=
          quantity * priceAtDate * _fxRateAt(investment, priceHistories, date);
    } else {
      total += _manualValuationAt(investment, quantity, date) ?? invested;
    }
  }
  return total;
}

/// Taux de change (1 [Investment.quoteCurrency] = X €) à appliquer à un
/// cours coté en devise étrangère pour l'exprimer en euros, à [date] —
/// cherché dans le même historique synchronisé que le cours du titre
/// (`price_refresh_service.dart` met en cache la paire `<devise>EUR=X` sous
/// ce même nom dans [priceHistories]) plutôt que de se limiter à
/// [Investment.lastFxRateToEur] (le taux du jour), pour que les points
/// passés de la courbe reflètent le taux de change de l'époque plutôt que
/// celui d'aujourd'hui. `1.0` pour un titre coté en euros (rien à
/// convertir) — sans quoi un titre en devise (ex : AAPL en USD) était
/// valorisé comme si son cours brut était déjà en euros, faisant décrocher
/// la courbe de la vraie valeur actuelle du compte.
double _fxRateAt(
  Investment investment,
  Map<String, List<PricePoint>> priceHistories,
  DateTime date,
) {
  final quoteCurrency = investment.quoteCurrency;
  if (quoteCurrency == null || quoteCurrency.toUpperCase() == 'EUR') {
    return 1.0;
  }
  final pair = '${quoteCurrency.toUpperCase()}EUR=X';
  final rateAtDate = priceAt(priceHistories[pair] ?? const [], date);
  return rateAtDate ?? investment.lastFxRateToEur ?? 1.0;
}

/// Valorisation manuelle d'un investissement sans cours de marché (voir
/// [_valuationAt]) : cours estimé à la main × [quantity] détenue à [date]
/// pour un objet "Autres" ([Investment.manualPrice]), ou surface × prix/m²
/// estimé pour l'immobilier ([Investment.estimatedPricePerSqm]) — `null`
/// avant que l'utilisateur n'ait renseigné une estimation (voir
/// [Investment.manualPriceAt]/[Investment.estimatedValueAt]), auquel cas
/// [_valuationAt] retombe sur le montant investi comme avant cette date.
double? _manualValuationAt(
  Investment investment,
  double quantity,
  DateTime date,
) {
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

/// Valeur des positions à effet de levier ENCORE OUVERTES du compte porteur
/// dont la classe (toujours la sienne propre, jamais cross-class — voir
/// [_buildAccountLeaf]) vaut [assetClass], à [date] — à ajouter au résultat
/// de [investmentsForEffectiveClass]/[_valuationAt] pour que la courbe
/// "Patrimoine net/brut" du Dashboard (`dashboard_screen.dart`'s
/// `_actifsHistoryFor`) compte les mêmes lignes que la carte Allocation
/// ([PatrimoineCategory.montantPatrimoine], qui les compte déjà via
/// [_buildLeveragedLeaf]) : sans cette prise en compte, ni
/// [investmentsForEffectiveClass] ni [_valuationAt] ne lisent jamais
/// [InvestmentAccount.leveragedPositions], et tout utilisateur avec une
/// position ouverte voyait deux totaux différents pour "le même patrimoine"
/// sur le même écran (régression trouvée en investiguant un signalement).
///
/// Contrairement à un titre spot, une position à effet de levier n'a pas
/// d'historique de cours journalier (voir [PricePoint]) : seule sa valeur
/// actuelle ([LeveragedPosition.displayValue]) est connue. Elle est donc
/// comptée à cette valeur constante à partir de sa date d'ouverture
/// ([LeveragedPosition.openedAt]) — jamais avant, pour ne pas la faire
/// apparaître avant qu'elle n'ait existé — plutôt que de reconstituer une
/// fausse courbe de PnL quotidien qu'aucune donnée ne permet de calculer.
///
/// [excludeFlagged] : même règle que [investmentsForEffectiveClass] — omet
/// les positions d'un compte marqué "exclu du patrimoine" (voir
/// [InvestmentAccount.excludedFromPatrimoine], seul niveau d'exclusion
/// disponible pour une position à effet de levier, voir
/// [_buildLeveragedLeaf]).
double leveragedValueForEffectiveClass(
  List<InvestmentAccount> accounts,
  AssetClass assetClass,
  DateTime date, {
  bool excludeFlagged = false,
}) {
  var total = 0.0;
  for (final account in accounts) {
    if (account.assetClass != assetClass) continue;
    if (excludeFlagged && account.excludedFromPatrimoine) continue;
    for (final position in account.leveragedPositions) {
      if (position.isOpen && _onOrBeforeDay(position.openedAt, date)) {
        total += position.displayValue;
      }
    }
  }
  return total;
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

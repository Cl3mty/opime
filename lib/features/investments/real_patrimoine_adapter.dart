import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, Color;
import '../dashboard/dashboard_dummy_data.dart';
import 'investments_models.dart';
import 'metal_price_client.dart';
import 'metal_price_repository.dart';
import 'price_history_repository.dart';
import 'yahoo_finance_client.dart';

/// Adapte les comptes de placement réels (`InvestmentAccount`) vers les
/// mêmes types que les données de démo (`dashboard/dashboard_dummy_data.dart`)
/// pour réutiliser telles quelles les cartes du Dashboard (`PatrimoineCard`
/// simplifiée, `AllocationCard`, `TopAssetsRow`, `CategoryBreakdownCard`,
/// `CategoryDetailScreen`) plutôt que d'en écrire des équivalents dédiés
/// aux données réelles.
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
    history: netWorthHistoryFor([
      for (final (_, investment) in pairs) investment,
    ], priceHistories),
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
      emptyAccountsByClass.putIfAbsent(account.assetClass, () => []).add(account);
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
    history: netWorthHistoryFor([
      for (final (_, investment) in pairs) investment,
    ], priceHistories),
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
    final v = investment.marketValue ?? investment.investedAmount;
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
    subtitle: account.assetClass == AssetClass.epargne ||
            account.assetClass == AssetClass.actionsEtFonds
        ? account.description
        : account.envelope?.label,
    // L'établissement du compte réel — la clé de groupement "banque" de
    // l'accordéon (`category_detail_screen.dart`), et le nom sous lequel le
    // logo de la banque est importé (`bank_logo_repository.dart`).
    bankName: account.bankName,
    valeur: valeur,
    plusValueAbs: plusValueAbs,
    plusValuePercent: costBasis == 0 ? 0 : plusValueAbs / costBasis * 100,
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
    for (final c in buildRealCategoriesByAccount(accounts, priceHistories, vaultPath))
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
    history: const [],
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
  final valeur = investment.marketValue ?? investment.investedAmount;
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
  return p.join(
    vaultPath,
    'investissements',
    'metaux',
    'images',
    fileName,
  );
}

/// Initiales d'avatar affichées à la place de celles dérivées du nom — "ETC"
/// pour un métal précieux coté détenu dans un CTO (l'image du produit n'a
/// pas de sens pour un titre financier).
String? _metalAvatarInitials(
  InvestmentAccount account,
  Investment investment,
) {
  if ((investment.assetClass ?? account.assetClass) !=
      AssetClass.metauxPrecieux) {
    return null;
  }
  return isMetalEtc(account) ? 'ETC' : null;
}

/// Le cours de marché en euros : le dernier cours brut (dans sa devise de
/// cotation, voir [Investment.lastPrice]) converti au taux de change
/// enregistré ([Investment.lastFxRateToEur]) — vaut le cours brut pour un
/// titre coté en euros, `null` sans cours connu.
double? _lastPriceToEur(Investment investment) {
  final lastPrice = investment.lastPrice;
  if (lastPrice == null) return null;
  return lastPrice * (investment.lastFxRateToEur ?? 1.0);
}

/// Un [DashboardAsset] par investissement valorisé, pour réutiliser
/// [TopAssetsRow] tel quel. [DashboardAsset.changePercent] est ici la
/// plus-value latente réelle (pas de retour réel par période — la
/// période choisie dans [TopAssetsRow] continue d'appliquer la même
/// formule synthétique d'échelle qu'en démo, appliquée cette fois à un
/// vrai chiffre de base plutôt qu'à un chiffre d'exemple).
List<DashboardAsset> buildRealTopAssets(
  List<InvestmentAccount> accounts,
  Map<String, List<PricePoint>> priceHistories,
) {
  final assets = <DashboardAsset>[];
  for (final account in accounts) {
    for (final investment in account.investments) {
      if (investment.quantityHeld <= 0) continue;
      final invested = investment.investedAmount;
      final gain = investment.unrealizedGain;
      final changePercent = (gain == null || invested == 0)
          ? 0.0
          : gain / invested * 100;
      final history = priceHistories[investment.isin] ?? const [];
      final sparkline = history.length >= 2
          ? [
              for (final p in history.skip(math.max(0, history.length - 10)))
                p.close,
            ]
          : [
              investment.pru,
              // Sans historique, la sparkline en deux points compare le PRU
              // au dernier cours — en euros, taux de change compris, pour
              // rester homogène (voir [_lastPriceToEur]).
              _lastPriceToEur(investment) ?? investment.pru,
            ];
      assets.add(
        DashboardAsset(
          name: investment.label,
          ticker: investment.isin,
          changePercent: changePercent,
          sparkline: sparkline,
        ),
      );
    }
  }
  return assets;
}

/// Reconstruit un historique de patrimoine (somme, jour par jour, de
/// `quantité détenue × cours à cette date`) depuis les transactions et
/// l'historique de cours en cache de [investments] — de la première
/// transaction à aujourd'hui. Sans cours connu à une date donnée, retombe
/// sur le montant investi jusqu'à cette date (même repli que partout
/// ailleurs sans cours). Retourne une liste vide si [investments] n'a
/// aucune transaction.
List<NetWorthPoint> netWorthHistoryFor(
  List<Investment> investments,
  Map<String, List<PricePoint>> priceHistories,
) {
  DateTime? earliest;
  for (final investment in investments) {
    for (final t in investment.transactions) {
      if (earliest == null || t.date.isBefore(earliest)) earliest = t.date;
    }
  }
  if (earliest == null) return [];

  final start = DateTime.utc(earliest.year, earliest.month, earliest.day);
  final now = DateTime.now();
  final end = DateTime.utc(now.year, now.month, now.day);
  final totalDays = end.difference(start).inDays;

  // ~30 points répartis sur toute la période (même densité que l'historique
  // de démo), avec toujours un dernier point à aujourd'hui.
  final stepDays = math.max(1, (totalDays / 30).ceil());
  final points = <NetWorthPoint>[];
  for (var offset = 0; offset < totalDays; offset += stepDays) {
    final date = start.add(Duration(days: offset));
    points.add(
      NetWorthPoint(date, _valuationAt(investments, priceHistories, date)),
    );
  }
  points.add(
    NetWorthPoint(end, _valuationAt(investments, priceHistories, end)),
  );
  // Un compte dont la première transaction est aujourd'hui (totalDays == 0)
  // ne produirait qu'un seul point — le graphique d'évolution exige au
  // moins deux points (voir `NetWorthChart`) et afficherait sinon "Pas
  // assez de données sur cette période". On ajoute le point de départ,
  // au même jour et à la même valeur : la courbe se réduit à une ligne
  // plate, ce qui reflète honnêtement l'absence d'historique.
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

    final history = priceHistories[investment.isin] ?? const [];
    double? priceAtDate;
    for (final p in history) {
      if (p.date.isAfter(date)) break;
      priceAtDate = p.close;
    }
    // Aucun cours à cette date ni avant ? S'il en existe un plus tard (un
    // produit métal dont le premier relevé quotidien est plus récent que
    // l'achat, ou un titre acheté avant le début de son historique Yahoo),
    // on prolonge le plus ancien cours connu vers le passé plutôt que de
    // retomber sur le coût d'achat : sans ce repli, la courbe sautait d'un
    // seul coup du montant investi au cours de marché au premier point de
    // cours, créant une pique verticale trompeuse en bout de graphique (ex :
    // la classe "Métaux précieux" tant que les relevés n'ont pas accumulé
    // d'historique). Même convention que `calculateTwr`
    // (`performance_calculator.dart`), qui valorise déjà la période
    // antérieure au premier cours au prix de ce premier cours.
    if (priceAtDate == null && history.isNotEmpty) {
      priceAtDate = history.first.close;
    }
    total += priceAtDate != null ? quantity * priceAtDate : invested;
  }
  return total;
}

/// Grille de dates commune à toutes les classes d'actif, depuis la toute
/// première transaction (tous comptes confondus) jusqu'à aujourd'hui —
/// contrairement à [netWorthHistoryFor], dont la grille est propre à
/// chaque sous-ensemble d'investissements passé en argument. Nécessaire
/// pour empiler plusieurs classes sur les mêmes abscisses dans le
/// graphique "Patrimoine complet" (voir [categoryHistoryOnGrid]).
List<DateTime> sharedDateGrid(List<InvestmentAccount> accounts) {
  DateTime? earliest;
  for (final account in accounts) {
    for (final investment in account.investments) {
      for (final t in investment.transactions) {
        if (earliest == null || t.date.isBefore(earliest)) earliest = t.date;
      }
    }
  }
  if (earliest == null) return [];

  final start = DateTime.utc(earliest.year, earliest.month, earliest.day);
  final now = DateTime.now();
  final end = DateTime.utc(now.year, now.month, now.day);
  final totalDays = end.difference(start).inDays;
  final stepDays = math.max(1, (totalDays / 30).ceil());
  final dates = <DateTime>[
    for (var offset = 0; offset < totalDays; offset += stepDays)
      start.add(Duration(days: offset)),
  ];
  dates.add(end);
  return dates;
}

/// Investissements dont la classe effective (voir [buildRealCategories])
/// est [assetClass], tous comptes confondus — pour isoler la série
/// d'une seule classe avant de l'évaluer sur une grille commune via
/// [categoryHistoryOnGrid].
List<Investment> investmentsForEffectiveClass(
  List<InvestmentAccount> accounts,
  AssetClass assetClass,
) {
  return [
    for (final account in accounts)
      for (final investment in account.investments)
        if ((investment.assetClass ?? account.assetClass) == assetClass)
          investment,
  ];
}

/// Comme [netWorthHistoryFor], mais évalué aux dates de [grid] (voir
/// [sharedDateGrid]) plutôt que sur une grille propre à [investments] —
/// pour que plusieurs classes d'actif partagent les mêmes abscisses et
/// puissent être empilées dans le graphique "Patrimoine complet".
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

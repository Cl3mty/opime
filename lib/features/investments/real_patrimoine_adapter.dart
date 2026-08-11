import 'dart:math' as math;
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, Color;
import '../dashboard/dashboard_dummy_data.dart';
import 'investments_models.dart';
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
    Color(0xFFFBBF24),
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
  final result = <String, List<PricePoint>>{};
  for (final account in accounts) {
    for (final investment in account.investments) {
      result[investment.isin] = await repo.load(investment.isin);
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
      _buildCategory(entry.key, entry.value, priceHistories),
  ];
}

PatrimoineCategory _buildCategory(
  AssetClass assetClass,
  List<(InvestmentAccount, Investment)> pairs,
  Map<String, List<PricePoint>> priceHistories,
) {
  final meta = _categoryMeta[assetClass]!;
  final leaves = <PatrimoineAccount>[
    for (final (account, investment) in pairs) _buildLeaf(account, investment),
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
      _buildCategoryByAccount(entry.key, entry.value, priceHistories),
  ];
}

PatrimoineCategory _buildCategoryByAccount(
  AssetClass assetClass,
  List<(InvestmentAccount, Investment)> pairs,
  Map<String, List<PricePoint>> priceHistories,
) {
  final meta = _categoryMeta[assetClass]!;
  final byAccountId = <String, List<(InvestmentAccount, Investment)>>{};
  for (final pair in pairs) {
    byAccountId.putIfAbsent(pair.$1.id, () => []).add(pair);
  }
  final leaves = <PatrimoineAccount>[
    for (final accountPairs in byAccountId.values)
      _buildAccountLeaf(accountPairs),
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
  List<(InvestmentAccount, Investment)> pairs,
) {
  final account = pairs.first.$1;
  var valeur = 0.0;
  var plusValueAbs = 0.0;
  var costBasis = 0.0;
  for (final (_, investment) in pairs) {
    final v = investment.marketValue ?? investment.investedAmount;
    final gain = investment.unrealizedGain ?? 0;
    valeur += v;
    plusValueAbs += gain;
    costBasis += v - gain;
  }
  return PatrimoineAccount(
    id: account.id,
    name: account.name,
    subtitle: account.envelope?.label,
    valeur: valeur,
    plusValueAbs: plusValueAbs,
    plusValuePercent: costBasis == 0 ? 0 : plusValueAbs / costBasis * 100,
    investments: [
      for (final (investmentAccount, investment) in pairs)
        _buildLeaf(investmentAccount, investment),
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
) {
  final populated = {
    for (final c in buildRealCategoriesByAccount(accounts, priceHistories))
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
) {
  final populated = {
    for (final c in buildRealCategories(accounts, priceHistories)) c.id: c,
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

PatrimoineAccount _buildLeaf(InvestmentAccount account, Investment investment) {
  final valeur = investment.marketValue ?? investment.investedAmount;
  final plusValueAbs = investment.unrealizedGain ?? 0;
  final costBasis = valeur - plusValueAbs;
  return PatrimoineAccount(
    id: investment.id,
    name: investment.label,
    subtitle: account.name,
    quantite: investment.quantityHeld == 0 ? null : investment.quantityHeld,
    cours: investment.lastPrice,
    valeur: valeur,
    pru: investment.pru,
    plusValueAbs: plusValueAbs,
    plusValuePercent: costBasis == 0 ? 0 : plusValueAbs / costBasis * 100,
  );
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
          : [investment.pru, investment.lastPrice ?? investment.pru];
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

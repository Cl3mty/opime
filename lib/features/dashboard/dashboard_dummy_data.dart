/// Données d'exemple pour poser la structure visuelle du Dashboard, en
/// s'inspirant des captures Finary fournies — avant que le vrai module
/// Patrimoine (transactions, import, calcul de performance) existe. Un
/// seul point d'entrée ([dashboardSampleData]) : le futur repository
/// réel remplacera cette classe sans que les widgets aient à changer.
library;

import 'dart:math' as math;
import 'package:flutter/widgets.dart' show Color, IconData;
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import '../investments/investments_models.dart' show AssetClass;

/// Un point de la courbe de patrimoine net dans le temps.
class NetWorthPoint {
  final DateTime date;
  final double value;

  const NetWorthPoint(this.date, this.value);
}

/// Un actif affiché dans "Mes meilleurs actifs".
class DashboardAsset {
  final String name;
  final String ticker;
  final double changePercent;
  final List<double> sparkline;

  const DashboardAsset({
    required this.name,
    required this.ticker,
    required this.changePercent,
    required this.sparkline,
  });

  String get initials => initialsFor(name);

  /// Rendement synthétique sur une période de [days] jours, dérivé de
  /// [changePercent] (traité comme le rendement plein historique, "Tout") :
  /// mis à l'échelle de la période avec une légère ondulation déphasée par
  /// actif, pour que le classement varie de façon crédible selon la
  /// période choisie — un vrai calcul par période remplacera ceci sans
  /// changer la signature.
  double changePercentForDays(int days) {
    const referenceDays = 220.0;
    final fraction = (days / referenceDays).clamp(0.03, 1.0);
    final phase = (name.hashCode % 10) * 0.37;
    return changePercent *
        fraction *
        (1 + 0.2 * math.sin(fraction * 6 + phase));
  }
}

/// Initiales (1 ou 2 lettres) dérivées d'un nom, pour les avatars sans
/// vraie image/logo — partagé par [DashboardAsset] et [PatrimoineAccount].
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

/// Classe d'actif sélectionnable dans le filtre multi-sélection de la carte
/// Patrimoine : `id` sert de clé pour [DashboardSampleData.seriesFor],
/// `color` est réutilisée à la fois comme légende dans la liste déroulante
/// et comme couleur de la bande empilée correspondante dans le graphique,
/// `weight` est la part du patrimoine total que représente cette classe.
class AssetFilter {
  final String id;
  final String label;
  final Color color;
  final double weight;

  const AssetFilter({
    required this.id,
    required this.label,
    required this.color,
    required this.weight,
  });
}

/// Poids choisis pour sommer exactement à 1.0 : quand toutes les classes
/// sont sélectionnées, la somme des courbes empilées doit correspondre au
/// patrimoine total, lisible en ordonnée.
const dashboardAssetFilters = [
  AssetFilter(
    id: 'immobilier',
    label: 'Immobilier',
    color: Color(0xFFEF4444),
    weight: 0.82,
  ),
  AssetFilter(
    id: 'bourse',
    label: 'Bourse',
    color: Color(0xFF8B5CF6),
    weight: 0.13,
  ),
  AssetFilter(
    id: 'epargne',
    label: 'Épargne',
    color: Color(0xFF60A5FA),
    weight: 0.043,
  ),
  AssetFilter(
    id: 'crypto',
    label: 'Crypto',
    color: Color(0xFFFBBF24),
    weight: 0.007,
  ),
];

/// Palier de risque/liquidité d'une catégorie d'allocation, utilisé par la
/// vue "pyramide" de la carte Allocation pour regrouper les catégories du
/// socle (épargne de précaution) au sommet (spéculatif).
enum AllocationTier { fondation, croissance, opportuniste }

/// Une ligne (compte, wallet, contrat...) au sein d'une [PatrimoineCategory].
/// `quantite`/`cours`/`pru` sont nuls pour les actifs non-unitaires
/// (immobilier, liquidités, paniers agrégés...) : `pru` (Prix de Revient
/// Unitaire) est le prix d'achat moyen par unité, comparable à `cours` pour
/// lire la plus-value unitaire — seulement pertinent quand `quantite` est
/// renseignée.
class PatrimoineAccount {
  final String name;
  final String? subtitle;
  final double? quantite;
  final double? cours;
  final double valeur;
  final double? pru;
  final double plusValueAbs;
  final double plusValuePercent;

  /// Identifiant de l'investissement réel source de cette ligne (`null`
  /// pour les données de démo) — permet à [CategoryDetailScreen] de
  /// retrouver l'investissement réel correspondant quand une ligne est
  /// cliquée, sans coupler ce modèle générique au module Investissements.
  final String? id;

  /// Investissements individuels regroupés dans cette ligne, quand elle
  /// représente un *compte* plutôt qu'un investissement unique — voir
  /// `real_patrimoine_adapter.dart`'s `buildRealCategoriesByAccount`. Vide
  /// pour une ligne qui représente déjà un investissement unique (données
  /// de démo, ou vue "par actif"). Permet à [CategoryBreakdownCard]
  /// d'imbriquer un second niveau d'accordéon : compte → investissements.
  final List<PatrimoineAccount> investments;

  /// `false` pour un compte réel qui porte encore au moins une transaction
  /// (même dans une autre classe d'actif que celle affichée) — même garde-
  /// fou que `AccountDetailView`'s `_hasTransactions`, exposé ici pour que
  /// le menu "Modifier/Supprimer" de l'accordéon d'une catégorie
  /// (`category_detail_screen.dart`) puisse désactiver la suppression sans
  /// dépendre du module Investissements. Toujours `true` pour une ligne qui
  /// ne représente pas un compte (investissement individuel, démo...).
  final bool canDelete;

  /// Chemin absolu d'une image locale affichée à la place des initiales de
  /// l'avatar — pour les métaux précieux physiques, la photo du produit
  /// (pièce/lingot) scrapée du site marchand et stockée dans
  /// `investissements/metaux/images/` (voir `metal_image_repository.dart`).
  /// `null` (défaut) affiche l'avatar à initiales.
  final String? avatarImagePath;

  /// Initiales affichées à la place de celles dérivées du nom — "ETC" pour
  /// un métal précieux coté détenu dans un CTO (pas de produit physique
  /// associé, donc pas d'image non plus).
  final String? avatarInitials;

  /// `true` quand un cours a été cherché (Yahoo Finance) et n'a pas été
  /// trouvé — voir `Investment.priceUnavailable` côté réel, propagé par
  /// `real_patrimoine_adapter.dart`'s `_buildLeaf`. Le tableau de détail
  /// affiche alors un avertissement plutôt qu'un simple « — » dans la
  /// colonne Cours.
  final bool? priceUnavailable;

  /// Établissement (banque) de ce compte réel — la clé qui regroupe les
  /// comptes d'une même banque sous un accordéon avec logo sur les pages de
  /// catégorie (voir `category_detail_screen.dart`'s `_BankAccordionTile`).
  /// `null` pour les données de démo et pour un compte sans banque
  /// distincte (son nom tient alors lieu de banque).
  final String? bankName;

  const PatrimoineAccount({
    this.id,
    required this.name,
    this.subtitle,
    this.quantite,
    this.cours,
    required this.valeur,
    this.pru,
    required this.plusValueAbs,
    required this.plusValuePercent,
    this.investments = const [],
    this.canDelete = true,
    this.avatarImagePath,
    this.avatarInitials,
    this.priceUnavailable,
    this.bankName,
  });

  String get initials => initialsFor(name);
}

/// Une catégorie d'actif ou de passif (même `id` que dans
/// `patrimoineGroup` de `nav_models.dart`), source unique pour la carte
/// Allocation, les cartes Actifs/Passifs du Dashboard et la page de détail
/// générique par catégorie. `tier` sert uniquement à la vue "pyramide" de
/// l'Allocation (les catégories de passif partagent un palier neutre).
/// `history` est une série synthétique (même technique que
/// [DashboardSampleData.seriesFor]), pour le graphique de la page détail.
class PatrimoineCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final AllocationTier tier;
  final String description;
  final List<PatrimoineAccount> accounts;
  final List<NetWorthPoint> history;

  const PatrimoineCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.tier,
    required this.description,
    required this.accounts,
    required this.history,
  });

  double get montant => accounts.fold(0.0, (sum, a) => sum + a.valeur);

  double get plusValueAbs =>
      accounts.fold(0.0, (sum, a) => sum + a.plusValueAbs);

  double get plusValuePercent {
    final costBasis = montant - plusValueAbs;
    if (costBasis == 0) return 0;
    return plusValueAbs / costBasis * 100;
  }

  /// Vrai pour les classes d'actif "unitaires" — une quantité et un cours
  /// par ligne, où le PRU (Prix de Revient Unitaire, voir
  /// [PatrimoineAccount.pru]) a un sens : actions & fonds, crypto, private
  /// equity, métaux précieux et autres. L'immobilier n'a pas de cours de
  /// marché et l'épargne est tenue en devise sans unité comparable : leur
  /// tableau de détail n'affiche pas de colonne PRU.
  bool get showsPruColumn {
    for (final assetClass in AssetClass.values) {
      if (assetClass.categoryId == id) {
        return !const {AssetClass.immobilier, AssetClass.epargne}
            .contains(assetClass);
      }
    }
    return false;
  }
}

class DashboardSampleData {
  final List<NetWorthPoint> netWorthHistory;
  final List<NetWorthPoint> grossWorthHistory;
  final List<DashboardAsset> topAssets;

  const DashboardSampleData({
    required this.netWorthHistory,
    required this.grossWorthHistory,
    required this.topAssets,
  });

  double get latestValue => netWorthHistory.last.value;

  /// Série d'une classe d'actif ([AssetFilter.id]) pour un mode (net/brut)
  /// donné : dérivée de la série totale, mise à l'échelle du poids de la
  /// classe, avec une légère ondulation déterministe (déphasée par classe)
  /// pour que les bandes empilées ne bougent pas toutes à l'unisson — un
  /// vrai repository par classe d'actif remplacera ceci sans changer la
  /// signature.
  List<NetWorthPoint> seriesFor(String filterId, {required bool gross}) {
    final base = gross ? grossWorthHistory : netWorthHistory;
    final filter = dashboardAssetFilters.firstWhere((f) => f.id == filterId);
    final phase = (filter.id.hashCode % 10) * 0.31;
    return [
      for (var i = 0; i < base.length; i++)
        NetWorthPoint(
          base[i].date,
          base[i].value *
              filter.weight *
              (1 + 0.03 * math.sin(i * 0.7 + phase)),
        ),
    ];
  }

  /// Extrait la portion d'une série correspondant à une période (les N
  /// derniers points), sans jamais renvoyer moins de 2 points — un vrai
  /// repository ferait ça via une requête bornée par date.
  List<NetWorthPoint> sliceForDays(List<NetWorthPoint> points, int days) {
    if (days >= points.length) return points;
    final start = (points.length - days).clamp(0, points.length - 2);
    return points.sublist(start);
  }

  /// Plus-value en % entre le premier et le dernier point d'une période.
  double changePercentFor(List<NetWorthPoint> points) {
    if (points.length < 2 || points.first.value == 0) return 0;
    return (points.last.value - points.first.value) / points.first.value * 100;
  }
}

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

NetWorthPoint _point(int daysAgo, double value) =>
    NetWorthPoint(_daysAgo(daysAgo), value);

/// Ajoute une dette synthétique linéairement décroissante (remboursement de
/// prêt) à une série nette pour obtenir le patrimoine brut correspondant —
/// pas un vrai modèle de passifs, juste un overlay pour la structure
/// visuelle du sélecteur net/brut.
List<NetWorthPoint> _addLiabilities(
  List<NetWorthPoint> net,
  double startDebt,
  double endDebt,
) {
  return [
    for (var i = 0; i < net.length; i++)
      NetWorthPoint(
        net[i].date,
        net[i].value +
            startDebt +
            (endDebt - startDebt) * (i / (net.length - 1)),
      ),
  ];
}

/// Environ 7 mois d'historique (un point par semaine), avec une légère
/// tendance haussière et un repli récent — même silhouette que les
/// courbes vues sur les captures Finary fournies.
final _netWorthHistory = [
  _point(210, 231000),
  _point(203, 233500),
  _point(196, 235800),
  _point(189, 234200),
  _point(182, 238900),
  _point(175, 241300),
  _point(168, 240100),
  _point(161, 244600),
  _point(154, 247800),
  _point(147, 246200),
  _point(140, 249900),
  _point(133, 253400),
  _point(126, 252100),
  _point(119, 256700),
  _point(112, 259300),
  _point(105, 258000),
  _point(98, 261900),
  _point(91, 264500),
  _point(84, 263100),
  _point(77, 267800),
  _point(70, 270200),
  _point(63, 269400),
  _point(56, 272600),
  _point(49, 275100),
  _point(42, 273900),
  _point(35, 276800),
  _point(28, 274300),
  _point(21, 268900),
  _point(14, 264200),
  _point(7, 260800),
  _point(0, 258400),
];

final dashboardSampleData = DashboardSampleData(
  netWorthHistory: _netWorthHistory,
  grossWorthHistory: _addLiabilities(_netWorthHistory, 44000, 38500),
  topAssets: [
    DashboardAsset(
      name: 'TotalEnergies SE',
      ticker: 'TTE',
      changePercent: 8.68,
      sparkline: [10, 11, 10.5, 12, 13, 12.5, 14, 15, 16, 18],
    ),
    DashboardAsset(
      name: 'Amundi PEA S&P 500',
      ticker: 'PE500',
      changePercent: 12.4,
      sparkline: [8, 8.5, 9, 8.7, 9.4, 10.1, 10.6, 11.2, 12, 13.1],
    ),
    DashboardAsset(
      name: 'BNP Paribas Easy',
      ticker: 'ESE',
      changePercent: 2.48,
      sparkline: [14, 13.6, 13.9, 13.7, 14.1, 13.9, 14.3, 14.2, 14.5, 14.4],
    ),
    DashboardAsset(
      name: 'Sopra Steria',
      ticker: 'SOP',
      changePercent: -4.32,
      sparkline: [22, 21.6, 21.8, 21, 20.4, 20.7, 19.9, 19.5, 19.2, 18.8],
    ),
    DashboardAsset(
      name: 'Bitcoin',
      ticker: 'BTC',
      changePercent: 30.45,
      sparkline: [5, 5.4, 5.2, 6, 6.8, 6.5, 7.4, 8.1, 7.9, 9],
    ),
    DashboardAsset(
      name: 'LVMH',
      ticker: 'MC',
      changePercent: -1.85,
      sparkline: [30, 29.4, 29.8, 29.1, 28.6, 28.9, 28.2, 27.9, 28.1, 27.6],
    ),
    DashboardAsset(
      name: 'Air Liquide',
      ticker: 'AI',
      changePercent: 5.21,
      sparkline: [17, 17.3, 17.1, 17.6, 18, 17.8, 18.4, 18.7, 18.5, 19],
    ),
    DashboardAsset(
      name: 'Ethereum',
      ticker: 'ETH',
      changePercent: 22.6,
      sparkline: [6, 6.4, 6.2, 7, 7.5, 7.2, 8, 8.6, 8.3, 9.2],
    ),
    DashboardAsset(
      name: 'SCPI Corum Origin',
      ticker: 'SCPI',
      changePercent: 1.12,
      sparkline: [12, 12.1, 12.2, 12.1, 12.3, 12.4, 12.3, 12.5, 12.6, 12.6],
    ),
    DashboardAsset(
      name: 'Amundi ETF World',
      ticker: 'CW8',
      changePercent: 9.34,
      sparkline: [20, 20.6, 20.3, 21.1, 21.6, 21.3, 22, 22.6, 22.3, 23],
    ),
    DashboardAsset(
      name: 'Livret A',
      ticker: 'LVA',
      changePercent: 0.85,
      sparkline: [25, 25.1, 25.2, 25.3, 25.4, 25.5, 25.6, 25.7, 25.8, 25.9],
    ),
    DashboardAsset(
      name: 'Vinci',
      ticker: 'DG',
      changePercent: 3.67,
      sparkline: [15, 15.2, 15.1, 15.5, 15.7, 15.6, 15.9, 16.1, 16, 16.3],
    ),
  ],
);

/// Construit une [PatrimoineCategory] et sa série synthétique
/// (`history`) : même technique que [DashboardSampleData.seriesFor],
/// échelle du poids de la catégorie dans le patrimoine total, avec une
/// ondulation déphasée par catégorie pour éviter des courbes identiques.
PatrimoineCategory _category({
  required String id,
  required String label,
  required IconData icon,
  required Color color,
  required AllocationTier tier,
  required String description,
  required List<PatrimoineAccount> accounts,
}) {
  final montant = accounts.fold(0.0, (sum, a) => sum + a.valeur);
  final weight = montant / dashboardSampleData.latestValue;
  final phase = (id.hashCode % 10) * 0.31;
  final history = [
    for (var i = 0; i < _netWorthHistory.length; i++)
      NetWorthPoint(
        _netWorthHistory[i].date,
        _netWorthHistory[i].value *
            weight *
            (1 + 0.05 * math.sin(i * 0.6 + phase)),
      ),
  ];
  return PatrimoineCategory(
    id: id,
    label: label,
    icon: icon,
    color: color,
    tier: tier,
    description: description,
    accounts: accounts,
    history: history,
  );
}

/// Catégories d'actifs (mêmes `id` que `patrimoineGroup` dans
/// `nav_models.dart`) — montants choisis pour sommer exactement au
/// patrimoine net total ([DashboardSampleData.latestValue]).
final dashboardActifsCategories = [
  _category(
    id: 'actifs_immobilier',
    label: 'Immobilier',
    icon: LucideIcons.house,
    color: const Color(0xFFEF4444),
    tier: AllocationTier.croissance,
    description: 'Résidence principale et parts de SCPI détenues en direct.',
    accounts: const [
      PatrimoineAccount(
        name: 'Résidence principale',
        valeur: 180000,
        plusValueAbs: 35000,
        plusValuePercent: 24.14,
      ),
      PatrimoineAccount(
        name: 'SCPI Corum Origin',
        valeur: 31700,
        plusValueAbs: 1200,
        plusValuePercent: 3.94,
      ),
    ],
  ),
  _category(
    id: 'actifs_actions_fonds',
    label: 'Actions & Fonds',
    icon: LucideIcons.chartLine,
    color: const Color(0xFF8B5CF6),
    tier: AllocationTier.croissance,
    description: 'Actions, ETF et fonds détenus sur vos comptes-titres et PEA.',
    accounts: const [
      PatrimoineAccount(
        name: 'PEA Boursorama',
        subtitle: 'Panier multi-actifs',
        valeur: 14200,
        plusValueAbs: 2850,
        plusValuePercent: 25.11,
      ),
      PatrimoineAccount(
        name: 'CTO Trade Republic',
        subtitle: 'Panier multi-actifs',
        valeur: 7200,
        plusValueAbs: 640,
        plusValuePercent: 9.76,
      ),
    ],
  ),
  _category(
    id: 'actifs_epargne',
    label: 'Épargne',
    icon: LucideIcons.piggyBank,
    color: const Color(0xFF60A5FA),
    tier: AllocationTier.fondation,
    description:
        'Livrets réglementés et fonds euros — la part la plus liquide et '
        'sécurisée du patrimoine.',
    accounts: const [
      PatrimoineAccount(
        name: 'Livret A',
        valeur: 6300,
        plusValueAbs: 95,
        plusValuePercent: 1.53,
      ),
      PatrimoineAccount(
        name: 'Fonds euros Assurance-vie',
        valeur: 5000,
        plusValueAbs: 140,
        plusValuePercent: 2.88,
      ),
    ],
  ),
  _category(
    id: 'actifs_crypto',
    label: 'Crypto',
    icon: LucideIcons.bitcoin,
    color: const Color(0xFFFBBF24),
    tier: AllocationTier.opportuniste,
    description: 'Cryptomonnaies détenues sur wallet froid ou plateforme.',
    accounts: const [
      PatrimoineAccount(
        name: 'Ledger Eth',
        subtitle: '0,42 ETH',
        quantite: 0.42,
        cours: 3452,
        pru: 2232.86,
        valeur: 1450,
        plusValueAbs: 512,
        plusValuePercent: 54.6,
      ),
      PatrimoineAccount(
        name: 'Binance',
        subtitle: 'Panier multi-actifs',
        valeur: 380,
        plusValueAbs: -45,
        plusValuePercent: -10.6,
      ),
    ],
  ),
  _category(
    id: 'actifs_private_equity',
    label: 'Private Equity',
    icon: LucideIcons.rocket,
    color: const Color(0xFF34D399),
    tier: AllocationTier.opportuniste,
    description:
        'Participations non cotées dans des entreprises ou fonds de '
        'capital-investissement.',
    accounts: const [
      PatrimoineAccount(
        name: 'Anaxago — SCPI opportuniste',
        valeur: 5200,
        plusValueAbs: 180,
        plusValuePercent: 3.59,
      ),
    ],
  ),
  _category(
    id: 'actifs_metaux_precieux',
    label: 'Métaux précieux',
    icon: LucideIcons.gem,
    color: const Color(0xFFEAB308),
    tier: AllocationTier.opportuniste,
    description:
        'Or et argent physiques, valeur refuge peu corrélée aux marchés '
        'financiers.',
    accounts: const [
      PatrimoineAccount(
        name: 'Or physique — VeraCash',
        subtitle: '28,5 g',
        quantite: 28.5,
        cours: 73.68,
        pru: 62.82,
        valeur: 2100,
        plusValueAbs: 310,
        plusValuePercent: 17.3,
      ),
    ],
  ),
  _category(
    id: 'actifs_autres',
    label: 'Autres',
    icon: LucideIcons.boxes,
    color: const Color(0xFF94A3B8),
    tier: AllocationTier.opportuniste,
    description: 'Liquidités et actifs divers non classés ailleurs.',
    accounts: const [
      PatrimoineAccount(
        name: 'Compte courant',
        valeur: 4870,
        plusValueAbs: 0,
        plusValuePercent: 0,
      ),
    ],
  ),
];

/// Catégories de passifs — montants cohérents avec l'écart net/brut posé
/// par [_addLiabilities] (44 000 € → 38 500 €).
final dashboardPassifsCategories = [
  _category(
    id: 'passifs_prets_immobiliers',
    label: 'Crédits immobiliers',
    icon: LucideIcons.house,
    color: const Color(0xFFDC2626),
    tier: AllocationTier.croissance,
    description:
        'Capital restant dû sur les prêts liés à l\'acquisition de biens '
        'immobiliers.',
    accounts: const [
      PatrimoineAccount(
        name: 'Crédit immobilier — Résidence principale',
        valeur: 34500,
        plusValueAbs: -5500,
        plusValuePercent: -13.75,
      ),
    ],
  ),
  _category(
    id: 'passifs_emprunts',
    label: 'Emprunts',
    icon: LucideIcons.handCoins,
    color: const Color(0xFFF97316),
    tier: AllocationTier.croissance,
    description: 'Crédits à la consommation et prêts personnels en cours.',
    accounts: const [
      PatrimoineAccount(
        name: 'Prêt personnel — Véhicule',
        valeur: 4000,
        plusValueAbs: -1200,
        plusValuePercent: -23.08,
      ),
    ],
  ),
];

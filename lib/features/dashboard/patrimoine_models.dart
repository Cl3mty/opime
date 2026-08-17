/// Modèle générique du Dashboard Patrimoine — partagé entre toutes les
/// classes d'actif/passif réelles (`real_patrimoine_adapter.dart`,
/// `real_passifs_adapter.dart`) et les widgets qui les affichent
/// (`CategoryDetailScreen`, `AllocationCard`, `TopAssetsRow`...), sans
/// coupler ce fichier au module Investissements ou Passifs.
library;

import 'package:flutter/widgets.dart' show Color, IconData;
import '../investments/investments_models.dart' show AssetClass;

/// Un point de la courbe de patrimoine net dans le temps.
class NetWorthPoint {
  final DateTime date;
  final double value;

  const NetWorthPoint(this.date, this.value);
}

/// Période standard réutilisée par `RealPatrimoineCard`, la page de détail
/// catégorie et "Mes meilleurs actifs" — sert à borner la grille de dates
/// calculée pour la période choisie (voir `real_patrimoine_adapter.dart`'s
/// `netWorthHistoryFor`/`categoryHistoryOnGrid`), plutôt qu'à trancher une
/// série déjà calculée sur l'historique complet (ancien bug : "1M" sur un
/// compte de plusieurs années ne montrait pas du tout un mois réel).
enum DashboardPeriod {
  day1('1J'),
  days7('7J'),
  month1('1M'),
  ytd('YTD'),
  year1('1A'),
  all('Tout');

  final String label;
  const DashboardPeriod(this.label);

  /// Borne de départ pour ce filtre, jamais avant [earliest] (la donnée la
  /// plus ancienne réellement disponible) — [today]/[earliest] doivent être
  /// des minuits UTC, même convention que les grilles de dates générées par
  /// `real_patrimoine_adapter.dart`/`real_passifs_adapter.dart`. 1M/1A sont
  /// des durées fixes (30/365 jours), pas des mois/années calendaires : plus
  /// simple et sans cas particulier de `DateTime` (ex. 31 janvier − 1 mois).
  DateTime startFor({required DateTime today, required DateTime earliest}) {
    final candidate = switch (this) {
      DashboardPeriod.day1 => today.subtract(const Duration(days: 1)),
      DashboardPeriod.days7 => today.subtract(const Duration(days: 7)),
      DashboardPeriod.month1 => today.subtract(const Duration(days: 30)),
      DashboardPeriod.ytd => DateTime.utc(today.year, 1, 1),
      DashboardPeriod.year1 => today.subtract(const Duration(days: 365)),
      DashboardPeriod.all => earliest,
    };
    return candidate.isBefore(earliest) ? earliest : candidate;
  }
}

/// Un actif affiché dans "Mes meilleurs actifs".
class DashboardAsset {
  final String name;
  final String ticker;
  final List<double> sparkline;

  /// Rendement réel sur une période donnée, dérivé de l'historique de cours
  /// de l'investissement (voir `real_patrimoine_adapter.dart`'s
  /// `buildRealTopAssets`) — `null` sans historique de cours couvrant le
  /// début de la période (investissement tout juste ajouté, cours pas
  /// encore résolu...).
  final double? Function(DashboardPeriod period) changePercentForPeriod;

  const DashboardAsset({
    required this.name,
    required this.ticker,
    required this.sparkline,
    required this.changePercentForPeriod,
  });

  String get initials => initialsFor(name);
}

/// Initiales (1 ou 2 lettres) dérivées d'un nom, pour les avatars sans
/// vraie image/logo — partagé par [DashboardAsset] et [PatrimoineAccount].
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

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

  /// Identifiant de l'investissement réel source de cette ligne — permet à
  /// [CategoryDetailScreen] de retrouver l'investissement réel correspondant
  /// quand une ligne est cliquée, sans coupler ce modèle générique au module
  /// Investissements.
  final String? id;

  /// Investissements individuels regroupés dans cette ligne, quand elle
  /// représente un *compte* plutôt qu'un investissement unique — voir
  /// `real_patrimoine_adapter.dart`'s `buildRealCategoriesByAccount`. Vide
  /// pour une ligne qui représente déjà un investissement unique (vue "par
  /// actif"). Permet à [CategoryBreakdownCard] d'imbriquer un second niveau
  /// d'accordéon : compte → investissements.
  final List<PatrimoineAccount> investments;

  /// `false` pour un compte réel qui porte encore au moins une transaction
  /// (même dans une autre classe d'actif que celle affichée) — même garde-
  /// fou que `AccountDetailView`'s `_hasTransactions`, exposé ici pour que
  /// le menu "Modifier/Supprimer" de l'accordéon d'une catégorie
  /// (`category_detail_screen.dart`) puisse désactiver la suppression sans
  /// dépendre du module Investissements. Toujours `true` pour une ligne qui
  /// ne représente pas un compte (investissement individuel).
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

  /// Date de dernière récupération de [cours] — voir `Investment.
  /// lastPriceDate` côté réel, propagé par `real_patrimoine_adapter.dart`'s
  /// `_buildLeaf`. `null` pour une ligne qui représente un compte (pas un
  /// investissement unique) ou dont le cours n'a jamais été récupéré.
  final DateTime? lastPriceDate;

  /// Établissement (banque) de ce compte réel — la clé qui regroupe les
  /// comptes d'une même banque sous un accordéon avec logo sur les pages de
  /// catégorie (voir `category_detail_screen.dart`'s `_BankAccordionTile`).
  /// `null` pour un compte sans banque distincte (son nom tient alors lieu
  /// de banque).
  final String? bankName;

  /// `true` quand cette ligne représente une position en devise (épargne,
  /// ou devise tenue dans un compte-titres — voir `isCurrencyInvestment`
  /// dans `investments_models.dart`) plutôt qu'un titre coté. Sert à
  /// afficher ces lignes en dernier et à les distinguer visuellement des
  /// titres dans l'accordéon d'un compte (voir `_AccountLine` dans
  /// `category_detail_screen.dart`).
  final bool isCurrency;

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
    this.isCurrency = false,
    this.priceUnavailable,
    this.lastPriceDate,
    this.bankName,
  });

  String get initials => initialsFor(name);

  /// `true` si [lastPriceDate] tombe le jour calendaire courant — même
  /// logique que `Investment.isPriceFresh`, dupliquée ici plutôt que
  /// partagée pour garder ce fichier découplé du module Investissements
  /// (voir le commentaire d'en-tête du fichier).
  bool get isPriceFresh {
    final date = lastPriceDate;
    if (date == null) return false;
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }
}

/// Une catégorie d'actif ou de passif (même `id` que dans
/// `patrimoineGroup` de `nav_models.dart`), source unique pour la carte
/// Allocation, les cartes Actifs/Passifs du Dashboard et la page de détail
/// générique par catégorie. `tier` sert uniquement à la vue "pyramide" de
/// l'Allocation (les catégories de passif partagent un palier neutre).
class PatrimoineCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final AllocationTier tier;
  final String description;
  final List<PatrimoineAccount> accounts;

  const PatrimoineCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.tier,
    required this.description,
    required this.accounts,
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

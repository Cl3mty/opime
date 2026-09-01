import 'dart:math';
import 'currency_data.dart' show kKnownCurrencies;
import 'leveraged_position.dart' show LeveragedPosition;
import 'metal_price_client.dart' show kKnownGoldProducts, kKnownSilverProducts;
import 'real_estate/rent_models.dart' show RentPeriod, WorkItem;
import 'yahoo_finance_client.dart' show kKnownCryptoTickers;

String generateInvestmentId(String prefix) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  final suffix = List.generate(
    8,
    (_) => chars[rand.nextInt(chars.length)],
  ).join();
  return '${prefix}_$suffix';
}

/// Classe d'actif choisie à la création d'un compte — mêmes 7 catégories
/// que celles du modèle générique du Dashboard
/// (`dashboard/patrimoine_models.dart`, `PatrimoineCategory`) et de la
/// sidebar (`actifs_*` dans `nav_models.dart`), pour que les comptes réels
/// alimentent les mêmes vues (Allocation, répartition Actifs/Passifs...)
/// via [categoryId].
enum AssetClass {
  immobilier,
  actionsEtFonds,
  epargne,
  crypto,
  privateEquity,
  metauxPrecieux,
  autres;

  String get label {
    switch (this) {
      case AssetClass.immobilier:
        return 'Immobilier';
      case AssetClass.actionsEtFonds:
        return 'Actions & Fonds';
      case AssetClass.epargne:
        return 'Épargne';
      case AssetClass.crypto:
        return 'Crypto';
      case AssetClass.privateEquity:
        return 'Private Equity';
      case AssetClass.metauxPrecieux:
        return 'Métaux précieux';
      case AssetClass.autres:
        return 'Autres';
    }
  }

  /// Identifiant de catégorie correspondant (`actifs_*` de
  /// `nav_models.dart`/`patrimoine_models.dart`), pour relier plus tard
  /// les comptes réels aux mêmes vues que les données de démo.
  String get categoryId {
    switch (this) {
      case AssetClass.immobilier:
        return 'actifs_immobilier';
      case AssetClass.actionsEtFonds:
        return 'actifs_actions_fonds';
      case AssetClass.epargne:
        return 'actifs_epargne';
      case AssetClass.crypto:
        return 'actifs_crypto';
      case AssetClass.privateEquity:
        return 'actifs_private_equity';
      case AssetClass.metauxPrecieux:
        return 'actifs_metaux_precieux';
      case AssetClass.autres:
        return 'actifs_autres';
    }
  }

  static AssetClass fromName(String name) => AssetClass.values.firstWhere(
    (t) => t.name == name,
    orElse: () => AssetClass.autres,
  );
}

/// Type d'un bien détenu directement ou via une SCPI. Il appartient au bien
/// lui-même — et non au compte technique qui les regroupe — car un même
/// patrimoine peut contenir plusieurs usages immobiliers.
enum RealEstateType {
  residencePrincipale,
  residenceSecondaire,
  locationCourteDuree,
  locationLongueDureeNue,
  locationLongueDureeLmp,
  locationLongueDureeLmnp,
  scpi;

  String get label => switch (this) {
    RealEstateType.residencePrincipale => 'Résidence principale',
    RealEstateType.residenceSecondaire => 'Résidence secondaire',
    RealEstateType.locationCourteDuree => 'Location courte durée',
    RealEstateType.locationLongueDureeNue => 'Location longue durée nue',
    RealEstateType.locationLongueDureeLmp => 'Location longue durée LMP',
    RealEstateType.locationLongueDureeLmnp => 'Location longue durée LMNP',
    RealEstateType.scpi => 'SCPI',
  };

  static RealEstateType? fromName(String? name) {
    if (name == null) return null;
    for (final type in RealEstateType.values) {
      if (type.name == name) return type;
    }
    return null;
  }
}

/// Style de gestion d'un investissement `actionsEtFonds`, renseigné
/// manuellement par l'utilisateur (aucune heuristique automatique sur le
/// libellé/ISIN, trop peu fiable) — sert à calculer la répartition gestion
/// active/passive dans l'écran Analyses (voir `analyses_calculations.dart`'s
/// `fundStyleAllocation`). `null` sur [Investment.fundStyle] tant que
/// l'utilisateur ne l'a pas classé : traité comme "non classé", jamais deviné.
enum FundStyle {
  activeGere,
  indiciel,
  actionIndividuelle,
  autre;

  String get label => switch (this) {
    FundStyle.activeGere => 'Géré activement',
    FundStyle.indiciel => 'Indiciel (ETF, tracker)',
    FundStyle.actionIndividuelle => 'Action individuelle',
    FundStyle.autre => 'Autre',
  };

  static FundStyle? fromName(String? name) {
    if (name == null) return null;
    for (final style in FundStyle.values) {
      if (style.name == name) return style;
    }
    return null;
  }
}

/// Variante d'un investissement `privateEquity`, renseignée à la création et
/// **immuable** ensuite (contrairement à [FundStyle]/[RealEstateType]) : elle
/// détermine si une transaction représente un montant total (voir
/// [usesTotalAmountTransaction]) ou une quantité réelle × un prix unitaire,
/// deux interprétations incompatibles qu'on ne peut pas mélanger après coup
/// sur un même historique de transactions. `null` sur
/// [Investment.privateEquityKind] (toute position créée avant l'ajout de ce
/// champ) équivaut à [fonds] : comportement inchangé, pas de migration.
enum PrivateEquityKind {
  /// Fonds d'investissement (club deal, FCPR, FCPI, crowdequity...) : les
  /// transactions sont des versements/distributions en montant total, la
  /// valorisation est celle, totale, communiquée par le gérant
  /// ([Investment.manualValuation]).
  fonds,

  /// Non coté reçu en rémunération (BSPCE, stock-options, actions gratuites)
  /// : le nombre de titres/options compte réellement, chaque transaction est
  /// une quantité × un prix unitaire (prix d'exercice, ou 0 pour une
  /// attribution gratuite — voir [allowsFreeTransactionPrice]), la
  /// valorisation se fait par titre ([Investment.manualPrice], comme pour
  /// "Autres").
  actionsSalarie;

  String get label => switch (this) {
    PrivateEquityKind.fonds => 'Fonds (club deal, FCPR...)',
    PrivateEquityKind.actionsSalarie =>
      'Rémunération en actions (BSPCE, stock-options, AGA)',
  };

  static PrivateEquityKind? fromName(String? name) {
    if (name == null) return null;
    for (final kind in PrivateEquityKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// Retrouve la [AssetClass] correspondant à un id de catégorie Dashboard
/// (`'actifs_crypto'`...), ou `null` s'il n'y en a pas (id inconnu, ou
/// catégorie de passifs — pas encore de classe d'actif réelle associée).
/// Utilisé pour présélectionner la classe d'actif du flux "Compléter mon
/// patrimoine" quand il est ouvert depuis la page de détail d'une catégorie.
AssetClass? assetClassForCategoryId(String categoryId) {
  for (final assetClass in AssetClass.values) {
    if (assetClass.categoryId == categoryId) return assetClass;
  }
  return null;
}

/// Options fixes proposées en liste déroulante pour le champ "identifiant"
/// d'un nouvel investissement de [assetClass], à la place d'un champ libre
/// — `null` pour les classes où ce champ reste un texte libre. Crypto :
/// tickers majeurs fiables sur Yahoo Finance (voir [kKnownCryptoTickers]).
/// Épargne : devise dans laquelle l'investissement est tenu (voir
/// [kKnownCurrencies]) — l'enveloppe fiscale (Livret A, LDDS, LEP...) se
/// choisit déjà au niveau du compte porteur ([accountEnvelopesFor]), pas
/// ici. Métaux précieux : pièces et lingots d'or et d'argent listés sur
/// achat-or-et-argent.fr (voir [kKnownGoldProducts], [kKnownSilverProducts])
/// — sauf pour un ETC détenu dans un CTO ([accountEnvelope] à
/// [AccountEnvelope.cto]), identifié par un vrai ISIN en texte libre comme
/// n'importe quel autre titre coté, pas par un choix de pièce/lingot
/// physique.
List<String>? identifierOptionsFor(
  AssetClass assetClass, {
  AccountEnvelope? accountEnvelope,
}) {
  switch (assetClass) {
    case AssetClass.crypto:
      return kKnownCryptoTickers;
    case AssetClass.epargne:
      return kKnownCurrencies;
    case AssetClass.metauxPrecieux:
      if (accountEnvelope == AccountEnvelope.cto) return null;
      return [...kKnownGoldProducts, ...kKnownSilverProducts];
    case AssetClass.immobilier:
    case AssetClass.actionsEtFonds:
    case AssetClass.privateEquity:
    case AssetClass.autres:
      return null;
  }
}

/// À la création d'un investissement, faut-il un champ "libellé" séparé
/// du champ "identifiant" ? — `false` quand le libellé découle directement
/// du produit choisi dans la liste déroulante de [identifierOptionsFor] :
/// c'est le cas des métaux précieux physiques (pièce ou lingot sélectionné,
/// le libellé est celui du produit, pré-rempli automatiquement) et de
/// l'épargne (la devise choisie — EUR, USD... — tient lieu de libellé,
/// pas besoin de le répéter dans un champ séparé). L'immobilier garde
/// toujours son libellé (nom du bien), comme toutes les autres classes.
bool requiresLabelFieldFor(
  AssetClass assetClass, {
  AccountEnvelope? accountEnvelope,
}) {
  if (assetClass == AssetClass.immobilier) return true;
  if (identifierOptionsFor(assetClass, accountEnvelope: accountEnvelope) !=
      null) {
    return false;
  }
  return true;
}

/// À la création d'un investissement, l'identifiant (ISIN) peut-il rester
/// vide ? Toujours vrai pour l'immobilier, "Autres" et le Private Equity, qui
/// n'ont pas de vrai identifiant financier (voir [_commitCreateInvestment]
/// dans `complete_patrimoine_dialog.dart`, qui en génère un si laissé vide) —
/// un club deal/FCPR n'a pas d'ISIN, seulement le nom du fonds (déjà saisi
/// dans le libellé). Vrai aussi pour "Actions & Fonds" détenu en PEE/PEG/PER :
/// les fonds internes à l'entreprise ou au contrat (FCPE, unités de compte du
/// PER...) n'ont souvent pas d'ISIN public — l'estimation manuelle du cours
/// ([Investment.manualPrice]) prend alors le relais d'un cours de marché
/// introuvable, comme pour "Autres".
bool isinOptionalFor(
  AssetClass assetClass, {
  AccountEnvelope? accountEnvelope,
}) {
  if (assetClass == AssetClass.immobilier ||
      assetClass == AssetClass.autres ||
      assetClass == AssetClass.privateEquity) {
    return true;
  }
  return assetClass == AssetClass.actionsEtFonds &&
      (accountEnvelope == AccountEnvelope.peg ||
          accountEnvelope == AccountEnvelope.pee ||
          accountEnvelope == AccountEnvelope.per);
}

/// `true` si [isin] est l'identifiant technique auto-généré à la création
/// d'un investissement laissé sans identifiant (voir
/// [isinOptionalFor]/`_commitCreateInvestment` dans
/// `complete_patrimoine_dialog.dart`, préfixes `'immobilier-'`, `'autre-'`,
/// `'fcpe-'`, `'pe-'`) plutôt qu'un vrai ISIN/ticker saisi par l'utilisateur
/// ou choisi dans une liste connue — un tel identifiant n'a rien d'utile à
/// montrer à l'écran (voir `positions_table.dart`/
/// `position_detail_dialog.dart`).
bool isGeneratedIdentifier(String isin) =>
    isin.startsWith('immobilier-') ||
    isin.startsWith('autre-') ||
    isin.startsWith('fcpe-') ||
    isin.startsWith('pe-');

/// Identifiant technique généré pour un investissement "Autres", un fonds
/// PEE/PEG/PER ou un Private Equity (voir [isinOptionalFor]) laissé sans
/// identifiant — que ce soit à la création, ou en édition quand un ISIN
/// saisi par erreur est retiré à nouveau (voir `_commitEditInvestment` dans
/// `position_detail_dialog.dart`/`investment_detail_screen.dart`, qui
/// rejetaient auparavant tout enregistrement à identifiant vide au lieu d'y
/// regénérer un placeholder). Sans branche immobilier : l'immobilier ne
/// propose jamais ce champ à la saisie, son propre préfixe
/// (`'immobilier-'`) reste généré séparément là où le compte est créé.
String placeholderIsinFor(AssetClass assetClass) => switch (assetClass) {
  AssetClass.autres => 'autre-${generateInvestmentId('bien')}',
  AssetClass.privateEquity => 'pe-${generateInvestmentId('fonds')}',
  _ => 'fcpe-${generateInvestmentId('bien')}',
};

/// Une transaction de [assetClass] représente-t-elle un montant total plutôt
/// qu'une quantité × un prix unitaire ? Vrai pour l'immobilier (un bien
/// s'achète en une seule "part", seul le prix payé compte) et pour un
/// Private Equity de type [PrivateEquityKind.fonds] (un versement/une
/// distribution, pas un nombre de parts significatif pour la plupart des
/// véhicules — club deal, FCPR...) — mais pas pour
/// [PrivateEquityKind.actionsSalarie] (BSPCE/stock-options/AGA), où le
/// nombre de titres/options compte réellement : ce cas suit le flux
/// générique quantité × prix, comme "Actions & Fonds". `privateEquityKind`
/// à `null` (position créée avant l'ajout de cette variante) équivaut à
/// [PrivateEquityKind.fonds]. Quand vrai, `quantity` vaut toujours `1.0` et
/// le champ affiché à la saisie reçoit directement le montant total (voir
/// `_commitCreateTransaction` dans `position_detail_dialog.dart`/
/// `add_transaction_dialog.dart`/`complete_patrimoine_dialog.dart`, qui
/// partagent ce même traitement).
bool usesTotalAmountTransaction(
  AssetClass assetClass, {
  PrivateEquityKind? privateEquityKind,
}) =>
    assetClass == AssetClass.immobilier ||
    (assetClass == AssetClass.privateEquity &&
        privateEquityKind != PrivateEquityKind.actionsSalarie);

/// Une transaction de [assetClass] peut-elle avoir un prix unitaire nul ?
/// Vrai pour "Autres" (un objet peut avoir été reçu en cadeau) et pour un
/// Private Equity [PrivateEquityKind.actionsSalarie] (une attribution
/// gratuite d'actions — AGA — n'a pas de prix d'exercice, contrairement à un
/// BSPCE/stock-option classique). Dans les deux cas, `PerformanceAmount`
/// masque le pourcentage de plus-value plutôt que d'afficher un chiffre
/// infini — voir `_commitCreateTransaction`/`_commitEditTransaction` dans
/// `position_detail_dialog.dart`/`add_transaction_dialog.dart`/
/// `complete_patrimoine_dialog.dart`, qui partagent ce même garde-fou.
bool allowsFreeTransactionPrice(
  AssetClass assetClass, {
  PrivateEquityKind? privateEquityKind,
}) =>
    assetClass == AssetClass.autres ||
    (assetClass == AssetClass.privateEquity &&
        privateEquityKind == PrivateEquityKind.actionsSalarie);

/// Une valeur a-t-elle besoin d'une précision au-delà du centime ? Les
/// cryptomonnaies (quantités et cours ont un sens en dessous du centime) et
/// les taux de change d'une épargne en devise étrangère (1 JPY ≈ 0,006 € —
/// un arrondi à 2 décimales le fausserait d'un ordre de grandeur) en ont
/// toujours besoin ; les autres classes se satisfont généralement d'une
/// précision au centime pour l'AFFICHAGE (voir `price_refresh_service`'s
/// `_resolveInvestmentPrice`) — la persistance sur disque, elle, garde
/// systématiquement la pleine précision saisie, voir `Transaction.toJson`.
bool requiresFullPricePrecision(AssetClass assetClass) =>
    assetClass == AssetClass.crypto || assetClass == AssetClass.epargne;

/// Formate une quantité d'actifs pour l'affichage : les pièces et lingots
/// de métaux précieux se comptent en unités entières (« 2 » et non
/// « 2,00 »), les autres quantités (parts d'ETF, unités de crypto, grammes
/// d'une épargne devise...) gardent deux décimales.
String formatQuantity(double quantity, AssetClass assetClass) {
  if (assetClass == AssetClass.metauxPrecieux) {
    return quantity.toStringAsFixed(0);
  }
  return quantity.toStringAsFixed(2);
}

/// Nature d'une [Transaction] au-delà du simple achat/vente d'un titre —
/// utile pour les mouvements de cash importés d'un relevé de courtier
/// (dividende, retenue à la source, frais, dépôt/retrait, conversion de
/// devise) qui s'enregistrent comme des achats/ventes d'une position-devise
/// (voir [isCurrencyInvestment]) mais ne doivent pas s'afficher comme un
/// simple "Achat"/"Vente" de titre. `null` sur [Transaction.type] — un achat
/// ou une vente de titre saisi manuellement, ou une transaction historique
/// antérieure à l'introduction de ce champ — garde l'affichage "Achat"/
/// "Vente" habituel, voir [Transaction.displayLabel].
enum TransactionType {
  dividend,
  withholdingTax,
  fee,
  deposit,
  withdrawal,
  fxConversion,
  other,
  // Un même titre déplacé d'un compte vers un autre (voir
  // `transfer_arbitrage_dialog.dart`) — la vente sur le compte source et
  // l'achat sur le compte destination portent tous deux ce type, avec un
  // PRU identique (conservé, pas recalculé au cours du marché) et
  // `Transaction.linkedTransactionId` pointant l'un vers l'autre.
  transfer,
  // Vente d'un titre au cours du marché suivie de l'achat d'un autre titre
  // avec le produit, au sein d'un même compte (assurance vie, PER...) —
  // même mécanique de paire liée que [transfer], mais entre deux titres
  // différents plutôt qu'un même titre entre deux comptes.
  arbitrage;

  String get label {
    switch (this) {
      case TransactionType.dividend:
        return 'Dividende';
      case TransactionType.withholdingTax:
        return 'Retenue à la source';
      case TransactionType.fee:
        return 'Frais';
      case TransactionType.deposit:
        return 'Dépôt';
      case TransactionType.withdrawal:
        return 'Retrait';
      case TransactionType.fxConversion:
        return 'Conversion de devise';
      case TransactionType.other:
        return 'Autre';
      case TransactionType.transfer:
        return 'Transfert';
      case TransactionType.arbitrage:
        return 'Arbitrage';
    }
  }

  static TransactionType? fromName(String? name) {
    if (name == null) return null;
    for (final type in TransactionType.values) {
      if (type.name == name) return type;
    }
    return null;
  }
}

/// Une transaction d'achat ou de vente sur un [Investment].
class Transaction {
  final String id;
  final DateTime date;
  final bool isBuy;
  final double quantity;
  final double unitPrice;

  /// Nature du mouvement quand ce n'est pas un simple achat/vente de titre
  /// (dividende, frais...) — voir [TransactionType]. `null` pour un achat/
  /// vente classique.
  final TransactionType? type;

  /// Précision facultative sur l'origine du mouvement (ex : "Dividende
  /// AAPL", ou le libellé brut d'un relevé importé dont le type n'est pas
  /// reconnu) — affichée en complément de [displayLabel], jamais utilisée
  /// dans les calculs.
  final String? note;

  /// Devise dans laquelle [unitPrice] est exprimé (EUR par défaut — voir
  /// [kKnownCurrencies]). Une action cotée en monnaie étrangère (ex : META
  /// à New York) peut être saisie dans sa devise de cotation (USD) plutôt
  /// que convertie mentalement en euros : le prix d'achat réel est alors
  /// conservé tel quel et seul [amount] (en euros) alimente les
  /// agrégations du patrimoine.
  final String currency;

  /// Taux de change appliqué : valeur de 1 unité de [currency] en euros
  /// (ex : 1 USD ≈ 0,92 €). Vaut toujours 1 pour une transaction en euros.
  /// Résolu automatiquement depuis Yahoo Finance (paire `<devise>EUR=X`)
  /// avec repli sur la saisie manuelle — voir
  /// `TransactionPriceCurrencyController`.
  final double fxRateToEur;

  /// Date de déblocage saisie à la main pour un versement PEG/PEE, en
  /// substitution de la règle par défaut (5 ans après [date], voir
  /// [pegPeeUnlockDateFor]/[pegPeeUnlockTranches]) — pour couvrir un cas de
  /// déblocage anticipé (achat de la résidence principale, mariage,
  /// invalidité...) ou tout autre écart avec la règle générale. `null`
  /// (l'immense majorité des cas) : la date par défaut s'applique.
  final DateTime? manualUnlockDate;

  /// Id de la transaction contrepartie d'un transfert/arbitrage (voir
  /// [TransactionType.transfer]/[TransactionType.arbitrage]) — la vente
  /// d'un côté pointe vers l'achat de l'autre et réciproquement. `null`
  /// pour toute transaction normale (l'immense majorité des cas). Sert
  /// uniquement à retrouver et supprimer la contrepartie ensemble (voir
  /// `InvestmentsRepository.deleteTransaction`) — aucun calcul de
  /// valorisation/performance n'a besoin de le lire.
  final String? linkedTransactionId;

  Transaction({
    String? id,
    required this.date,
    required this.isBuy,
    required this.quantity,
    required this.unitPrice,
    this.currency = 'EUR',
    this.fxRateToEur = 1.0,
    this.type,
    this.note,
    this.manualUnlockDate,
    this.linkedTransactionId,
  }) : id = id ?? generateInvestmentId('txn');

  /// Montant de la transaction en euros (la devise de compte) : quantité ×
  /// prix unitaire × taux de change. C'est ce montant que retiennent toutes
  /// les agrégations ([Investment.investedAmount], la performance, le
  /// miroir métaux...).
  double get amount => quantity * unitPrice * fxRateToEur;

  /// Montant brut dans la devise de cotation [currency], sans conversion.
  double get amountInCurrency => quantity * unitPrice;

  /// Libellé affiché pour cette transaction — celui de [type] s'il est
  /// renseigné (dividende, frais...), sinon le "Achat"/"Vente" habituel.
  String get displayLabel => type?.label ?? (isBuy ? 'Achat' : 'Vente');

  /// `true` si [note] est renseigné avec autre chose que des espaces — voir
  /// `TransactionRow.centerDate` dans `widgets/transaction_widgets.dart`,
  /// seul appelant : la date d'une liste de transactions n'est centrée que
  /// tant qu'aucune de ses lignes ne porte de commentaire.
  bool get hasNote => note != null && note!.trim().isNotEmpty;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String? ?? generateInvestmentId('txn'),
    date: DateTime.parse(json['date'] as String),
    isBuy: json['isBuy'] as bool? ?? true,
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
    // Transactions historiques sans devise : l'euro, avec un taux de change
    // unitaire — le JSON reste rétro-compatible.
    currency: json['currency'] as String? ?? 'EUR',
    fxRateToEur: (json['fxRateToEur'] as num?)?.toDouble() ?? 1.0,
    type: TransactionType.fromName(json['type'] as String?),
    note: json['note'] as String?,
    manualUnlockDate: json['manualUnlockDate'] != null
        ? DateTime.parse(json['manualUnlockDate'] as String)
        : null,
    linkedTransactionId: json['linkedTransactionId'] as String?,
  );

  /// Quantité et prix toujours écrits en pleine précision — jamais arrondis
  /// à la sauvegarde, quelle que soit la classe d'actif : une part de fonds
  /// (PEG/PER...) achetée par prélèvements réguliers accumule couramment
  /// plus de deux décimales (ex : 3,2557 parts), et arrondir à chaque
  /// écriture fait dériver silencieusement la quantité réellement détenue
  /// au fil des sauvegardes successives. Seul l'AFFICHAGE arrondit (voir
  /// [formatQuantity], `displayEuros`) — jamais la donnée persistée.
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'isBuy': isBuy,
    'quantity': quantity,
    'unitPrice': unitPrice,
    // Seule une transaction hors euros porte sa devise et son taux.
    if (currency != 'EUR') 'currency': currency,
    if (type != null) 'type': type!.name,
    if (note != null) 'note': note,
    if (currency != 'EUR') 'fxRateToEur': fxRateToEur,
    if (manualUnlockDate != null)
      'manualUnlockDate': manualUnlockDate!.toIso8601String(),
    if (linkedTransactionId != null) 'linkedTransactionId': linkedTransactionId,
  };
}

/// Un investissement identifié par son code ISIN au sein d'un
/// [InvestmentAccount]. Sans API de cours pour l'instant, sa valorisation
/// affichée est le montant net investi (coût de la position ouverte), pas
/// une valeur de marché — voir [investedAmount]/[pru].
class Investment {
  final String id;
  final String isin;
  final String label;
  final List<Transaction> transactions;

  /// Ticker Yahoo Finance résolu depuis [isin] (mis en cache pour ne
  /// chercher qu'une fois), et dernier cours connu — `null` tant qu'aucune
  /// actualisation n'a réussi, auquel cas l'UI retombe sur [investedAmount].
  final String? symbol;
  final double? lastPrice;
  final DateTime? lastPriceDate;

  /// Devise dans laquelle [lastPrice] est coté sur le marché — `null` (et
  /// donc l'euro) tant qu'aucun cours n'a été récupéré. Résolue depuis les
  /// métadonnées de Yahoo Finance (`meta.currency`) au rafraîchissement des
  /// cours (voir `price_refresh_service.dart`) : le cours brut d'une action
  /// US (META...) est en dollars, pas en euros.
  final String? quoteCurrency;

  /// Taux de change (1 [quoteCurrency] = X €) appliqué à [lastPrice] pour
  /// la valorisation en euros — `null` tant que la devise de cotation est
  /// l'euro ou que le taux n'a pas été résolu (voir
  /// `price_refresh_service.dart`'s `_resolveInvestmentPrice`).
  final double? lastFxRateToEur;

  /// Nom du fichier local de la photo du produit (pièce/lingot) scrapée du
  /// catalogue achat-or-et-argent.fr et téléchargée dans
  /// `investissements/metaux/images/` — voir `metal_image_repository.dart`
  /// et `price_refresh_service.dart`'s `_ensureMetalImages`. `null` tant
  /// qu'aucune image n'a été téléchargée (ou pour un ETC coté, voir
  /// [identifierOptionsFor]) : l'avatar affiche alors des initiales.
  final String? imageFileName;

  /// `true` quand un cours a été *cherché* sur Yahoo Finance et n'a pas été
  /// trouvé (identifiant inconnu de Yahoo, actif non coté, pas de données) —
  /// sans qu'il s'agisse d'une panne réseau, qui, elle, laisse le dernier
  /// cours connu tel quel (voir `price_refresh_service.dart`'s
  /// `_resolveInvestmentPrice`). Distinct d'un [lastPrice] simplement absent
  /// (jamais cherché, ou mise à jour jamais tentée) : ce drapeau permet
  /// d'afficher clairement "cours introuvable" plutôt que de retomber
  /// silencieusement sur le montant investi — utile notamment pour un ETC
  /// or/argent (voir [isMetalEtc]) dont l'ISIN serait mal saisi.
  final bool? priceUnavailable;

  /// Classe d'actif spécifique à cet investissement, différente de celle
  /// du compte qui le porte — `null` dans l'immense majorité des cas
  /// (hérite alors de [InvestmentAccount.assetClass] via
  /// [PatrimoineCategory.id] côté adaptateur). Sert par exemple à loger un
  /// ETC or dans un CTO "Actions & Fonds" tout en le comptant dans
  /// "Métaux précieux" — voir [accountAcceptsCrossClassInvestment].
  final AssetClass? assetClass;
  final RealEstateType? realEstateType;

  /// Style de gestion (actif/passif/stock-picking), pertinent seulement pour
  /// la classe `actionsEtFonds` — voir [FundStyle].
  final FundStyle? fundStyle;

  /// Variante d'un investissement `privateEquity`, pertinente seulement pour
  /// cette classe — voir [PrivateEquityKind] (immuable après création,
  /// contrairement à [fundStyle]/[realEstateType]).
  final PrivateEquityKind? privateEquityKind;

  /// Cliff et durée totale de vesting (en mois) d'un Private Equity
  /// [PrivateEquityKind.actionsSalarie] (BSPCE/stock-options/AGA) — voir
  /// [vestedQuantityFor]. `null` sur l'un ou l'autre signifie "vesting non
  /// suivi" : [quantityHeld] est alors considéré entièrement acquis, comme
  /// avant l'ajout de ces champs (purement additif). Un seul planning
  /// s'applique à toutes les transactions de la position, comme
  /// [pegPeeUnlockDateFor] applique une seule règle à 5 ans à chaque
  /// versement PEG/PEE — pour un planning réellement différent par
  /// attribution, créer une seconde position séparée plutôt que de forcer
  /// un planning unique à s'appliquer à des lots hétérogènes. Contrairement
  /// à [privateEquityKind], ces champs restent éditables après création : le
  /// cliff/la durée exacts peuvent être mal connus au moment du grant, ou le
  /// plan peut être amendé.
  final int? vestingCliffMonths;
  final int? vestingDurationMonths;

  /// Date limite d'exercice d'un Private Equity [PrivateEquityKind.actionsSalarie]
  /// (BSPCE/stock-options) — un rappel proactif à son approche est affiché
  /// par `ReminderBanner` (`investment_reminder_banner.dart`), sur le même
  /// principe que [accountFiscalMilestone] pour un compte. `null` tant que
  /// non renseignée (pas de rappel).
  final DateTime? exerciseDeadline;

  /// Surface habitable (m²) d'un bien immobilier — avec
  /// [estimatedPricePerSqm], permet de calculer [estimatedValue]. `null`
  /// tant que le bien n'a jamais été estimé (voir "Réestimer" dans
  /// `investment_detail_screen.dart`) — pertinent uniquement pour la classe
  /// `immobilier`.
  final double? surfaceM2;

  /// Adresse et localisation du bien, telles que retenues lors de la
  /// dernière estimation (voir `real_estate_pricing/`) — [addressCityCode]
  /// (code INSEE) est la clé de jointure vers les données DVF, réutilisée
  /// pour une réestimation ultérieure sans redemander l'adresse.
  final String? addressLabel;
  final String? addressCityCode;
  final double? addressLat;
  final double? addressLon;

  /// Dernier prix au m² estimé (voir `real_estate_pricing/price_estimator.dart`)
  /// et date de cette estimation — un seul instantané conservé (pas un
  /// historique), mis à jour uniquement par une action explicite de
  /// l'utilisateur, jamais automatiquement (voir [_expectsMarketPrice] dans
  /// `price_refresh_service.dart`, qui exclut toujours `immobilier`).
  final double? estimatedPricePerSqm;
  final DateTime? estimatedValueAt;

  /// Cours (prix unitaire) estimé à la main par l'utilisateur — ex : un
  /// objet de collection (montre, voiture, art...) sans cours de marché ni
  /// estimation automatique possible, voir [_expectsMarketPrice] qui
  /// n'attend jamais de cours pour `AssetClass.autres` — et la date de
  /// cette estimation. Alimente [estimatedValue] (multiplié par
  /// [quantityHeld], comme [marketValue] l'est avec [lastPrice]) au même
  /// titre que [surfaceM2]/[estimatedPricePerSqm] pour l'immobilier — les
  /// deux mécanismes ne se recouvrent jamais (l'un ou l'autre est renseigné
  /// selon la classe d'actif, jamais les deux).
  final double? manualPrice;
  final DateTime? manualPriceAt;

  /// Valorisation totale estimée à la main, et la date de cette estimation —
  /// utilisée par le Private Equity (voir [usesTotalAmountTransaction]) :
  /// un fonds de club deal/FCPR n'a pas de notion de part boursière comme
  /// un objet "Autres", seule la dernière valorisation communiquée par le
  /// gérant (le NAV du fonds) compte, en montant total — contrairement à
  /// [manualPrice] (un prix par unité, multiplié par [quantityHeld]) qui ne
  /// conviendrait pas puisque [quantityHeld] n'a ici aucun sens de "parts
  /// détenues" (chaque versement/distribution vaut toujours 1 en quantité,
  /// voir `_commitCreateTransaction` dans `position_detail_dialog.dart`).
  /// Alimente [estimatedValue] directement, sans multiplication.
  final double? manualValuation;
  final DateTime? manualValuationAt;

  final List<VaultDocument> documents;

  /// Historique des loyers d'un bien immobilier loué — voir
  /// `real_estate/rent_models.dart`'s `RentPeriod`. Vide hors immobilier, ou
  /// pour une résidence principale/secondaire non louée.
  final List<RentPeriod> rentPeriods;

  /// Postes de travaux (rénovation, entretien lourd...) d'un bien
  /// immobilier — voir `real_estate/rent_models.dart`'s `WorkItem`. Leur
  /// somme s'ajoute à [investedAmount] dans le coût total du projet utilisé
  /// par la rentabilité, jamais dans la valorisation patrimoine (un poste de
  /// travaux n'est pas un achat de titre).
  final List<WorkItem> workItems;

  /// `true` si l'utilisateur a explicitement choisi d'exclure cet
  /// investissement du patrimoine global — il reste visible partout où il
  /// apparaît aujourd'hui (position, transaction, compte, page de
  /// catégorie...) avec sa vraie valeur, marqué "non comptabilisé" : seuls
  /// les agrégats globaux du Dashboard (courbe/montant "Patrimoine net/
  /// brut" et carte Allocation) l'ignorent — voir
  /// `real_patrimoine_adapter.dart`'s `investmentsForEffectiveClass`/
  /// `buildRealTopAssets`/`_buildLeaf`. Une exclusion peut aussi porter sur
  /// le compte entier ([InvestmentAccount.excludedFromPatrimoine]).
  final bool excludedFromPatrimoine;

  Investment({
    String? id,
    required this.isin,
    required this.label,
    required this.transactions,
    this.symbol,
    this.lastPrice,
    this.lastPriceDate,
    this.quoteCurrency,
    this.lastFxRateToEur,
    this.imageFileName,
    this.priceUnavailable,
    this.assetClass,
    this.realEstateType,
    this.fundStyle,
    this.privateEquityKind,
    this.vestingCliffMonths,
    this.vestingDurationMonths,
    this.exerciseDeadline,
    this.surfaceM2,
    this.addressLabel,
    this.addressCityCode,
    this.addressLat,
    this.addressLon,
    this.estimatedPricePerSqm,
    this.estimatedValueAt,
    this.manualPrice,
    this.manualPriceAt,
    this.manualValuation,
    this.manualValuationAt,
    this.documents = const [],
    this.rentPeriods = const [],
    this.workItems = const [],
    this.excludedFromPatrimoine = false,
  }) : id = id ?? generateInvestmentId('inv');

  Investment copyWith({
    List<Transaction>? transactions,
    String? symbol,
    double? lastPrice,
    DateTime? lastPriceDate,
    String? quoteCurrency,
    double? lastFxRateToEur,
    String? imageFileName,
    bool? priceUnavailable,
    AssetClass? assetClass,
    RealEstateType? realEstateType,
    FundStyle? fundStyle,
    PrivateEquityKind? privateEquityKind,
    int? vestingCliffMonths,
    int? vestingDurationMonths,
    DateTime? exerciseDeadline,
    double? surfaceM2,
    String? addressLabel,
    String? addressCityCode,
    double? addressLat,
    double? addressLon,
    double? estimatedPricePerSqm,
    DateTime? estimatedValueAt,
    double? manualPrice,
    DateTime? manualPriceAt,
    double? manualValuation,
    DateTime? manualValuationAt,
    List<VaultDocument>? documents,
    List<RentPeriod>? rentPeriods,
    List<WorkItem>? workItems,
    bool? excludedFromPatrimoine,
  }) => Investment(
    id: id,
    isin: isin,
    label: label,
    transactions: transactions ?? this.transactions,
    symbol: symbol ?? this.symbol,
    lastPrice: lastPrice ?? this.lastPrice,
    lastPriceDate: lastPriceDate ?? this.lastPriceDate,
    quoteCurrency: quoteCurrency ?? this.quoteCurrency,
    lastFxRateToEur: lastFxRateToEur ?? this.lastFxRateToEur,
    imageFileName: imageFileName ?? this.imageFileName,
    priceUnavailable: priceUnavailable ?? this.priceUnavailable,
    assetClass: assetClass ?? this.assetClass,
    realEstateType: realEstateType ?? this.realEstateType,
    fundStyle: fundStyle ?? this.fundStyle,
    privateEquityKind: privateEquityKind ?? this.privateEquityKind,
    vestingCliffMonths: vestingCliffMonths ?? this.vestingCliffMonths,
    vestingDurationMonths: vestingDurationMonths ?? this.vestingDurationMonths,
    exerciseDeadline: exerciseDeadline ?? this.exerciseDeadline,
    surfaceM2: surfaceM2 ?? this.surfaceM2,
    addressLabel: addressLabel ?? this.addressLabel,
    addressCityCode: addressCityCode ?? this.addressCityCode,
    addressLat: addressLat ?? this.addressLat,
    addressLon: addressLon ?? this.addressLon,
    estimatedPricePerSqm: estimatedPricePerSqm ?? this.estimatedPricePerSqm,
    estimatedValueAt: estimatedValueAt ?? this.estimatedValueAt,
    manualPrice: manualPrice ?? this.manualPrice,
    manualPriceAt: manualPriceAt ?? this.manualPriceAt,
    manualValuation: manualValuation ?? this.manualValuation,
    manualValuationAt: manualValuationAt ?? this.manualValuationAt,
    documents: documents ?? this.documents,
    rentPeriods: rentPeriods ?? this.rentPeriods,
    workItems: workItems ?? this.workItems,
    excludedFromPatrimoine:
        excludedFromPatrimoine ?? this.excludedFromPatrimoine,
  );

  double get quantityHeld => transactions.fold(
    0.0,
    (sum, t) => sum + (t.isBuy ? t.quantity : -t.quantity),
  );

  /// `true` si l'identifiant est un code de devise connu (EUR, USD, GBP... —
  /// voir [kKnownCurrencies]) : la position est tenue à un taux de change
  /// plutôt qu'à un cours de titre. C'est le cas de toute épargne (dont
  /// l'identifiant EST la devise tenue, voir `identifierOptionsFor`) et d'une
  /// devise créée dans un compte-titres via l'étape "Investissement et/ou
  /// devises" du flux de complétion — un compte qui peut donc contenir des
  /// titres ET des devises côte à côte. Voir aussi [isCurrencyInvestment],
  /// qui couvre en plus l'épargne dont l'identifiant serait hors liste.
  bool get isCurrency => kKnownCurrencies.contains(isin.trim().toUpperCase());

  /// Transactions du plus récent au plus ancien, quel que soit l'ordre de
  /// saisie — c'est l'ordre d'affichage utilisé partout (liste des
  /// transactions, choix "rattacher à quelle transaction ?"...).
  List<Transaction> get transactionsByDateDesc =>
      [...transactions]..sort((a, b) => b.date.compareTo(a.date));

  /// Coût net de la position actuellement détenue (achats − ventes).
  double get investedAmount => transactions.fold(
    0.0,
    (sum, t) => sum + (t.isBuy ? t.amount : -t.amount),
  );

  /// Prix de Revient Unitaire : coût moyen par unité actuellement détenue.
  double get pru => quantityHeld == 0 ? 0 : investedAmount / quantityHeld;

  /// Valorisation au dernier cours connu, convertie en euros — `null` si
  /// aucun cours n'a encore été récupéré. Un titre coté en devise étrangère
  /// (ex : META en USD) est valorisé au taux de change enregistré
  /// ([lastFxRateToEur]).
  double? get marketValue {
    if (lastPrice == null) return null;
    return quantityHeld * lastPrice! * (lastFxRateToEur ?? 1.0);
  }

  /// `true` si [lastPriceDate] tombe le jour calendaire courant — sert à
  /// afficher un badge "à jour" dans l'UI et, côté
  /// `price_refresh_service.dart`, à éviter de rafraîchir un cours déjà
  /// récupéré aujourd'hui.
  bool get isPriceFresh {
    final date = lastPriceDate;
    if (date == null) return false;
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  /// Valeur estimée quand aucun cours de marché n'est possible : surface ×
  /// dernier prix/m² estimé pour l'immobilier (voir
  /// `real_estate_pricing/`), quantité détenue × cours estimé à la main par
  /// l'utilisateur pour un objet de collection ([manualPrice] — montre,
  /// voiture, art...), ou [manualValuation] tel quel (déjà un montant total,
  /// pas un prix par unité) pour un Private Equity, exactement comme
  /// [marketValue] avec [lastPrice]. `null` tant qu'aucune des trois n'est
  /// renseignée. Un bien immobilier est toujours détenu en une seule unité
  /// ([quantityHeld] == 1), donc [surfaceM2] × [estimatedPricePerSqm] est
  /// déjà directement comparable à [investedAmount] sans multiplication de
  /// quantité supplémentaire.
  double? get estimatedValue =>
      (surfaceM2 != null && estimatedPricePerSqm != null)
      ? surfaceM2! * estimatedPricePerSqm!
      : manualPrice != null
      ? quantityHeld * manualPrice!
      : manualValuation;

  /// Meilleure valorisation connue hors montant investi : un cours de
  /// marché ([marketValue], jamais renseigné pour l'immobilier aujourd'hui)
  /// sinon une estimation €/m² ([estimatedValue]) si l'utilisateur en a
  /// demandé une. Ne remplace jamais [marketValue] lui-même : la jauge
  /// TWR/MWR de `investment_detail_screen.dart` continue de dépendre
  /// uniquement d'un vrai historique de cours, qu'une estimation ponctuelle
  /// ne fournit pas.
  double? get effectiveMarketValue => marketValue ?? estimatedValue;

  /// Plus/moins-value latente par rapport au coût d'achat, ou `null` sans
  /// valorisation connue (ni cours de marché, ni estimation).
  double? get unrealizedGain => effectiveMarketValue == null
      ? null
      : effectiveMarketValue! - investedAmount;

  /// Valeur à afficher/agréger pour cette position — [effectiveMarketValue]
  /// si connue, sinon [investedAmount] à défaut. Une position SOLDÉE
  /// (quantityHeld ~ 0, ex : entièrement vendue, transférée ou arbitrée
  /// ailleurs — voir [PositionsTable]'s même seuil) vaut TOUJOURS 0 ici,
  /// jamais son [investedAmount] : celui-ci est un simple résidu algébrique
  /// (somme signée achats moins ventes, chacun à son propre prix) qui ne
  /// s'annule pas forcément à 0 une fois la position vidée — une vente à un
  /// cours différent du PRU moyen y laisse un écart qui n'a plus aucun sens
  /// une fois qu'il ne reste plus rien à valoriser. Utilisé partout où une
  /// valeur de position doit être sommée/affichée (totaux de compte,
  /// Dashboard, Analyses...) plutôt que de dupliquer ce garde-fou.
  double get displayValue {
    if (quantityHeld <= 1e-9) return 0;
    return effectiveMarketValue ?? investedAmount;
  }

  factory Investment.fromJson(Map<String, dynamic> json) => Investment(
    id: json['id'] as String? ?? generateInvestmentId('inv'),
    isin: json['isin'] as String? ?? '',
    label: json['label'] as String? ?? '',
    transactions: (json['transactions'] as List? ?? [])
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList(),
    symbol: json['symbol'] as String?,
    lastPrice: (json['lastPrice'] as num?)?.toDouble(),
    lastPriceDate: json['lastPriceDate'] != null
        ? DateTime.parse(json['lastPriceDate'] as String)
        : null,
    quoteCurrency: json['quoteCurrency'] as String?,
    lastFxRateToEur: (json['lastFxRateToEur'] as num?)?.toDouble(),
    imageFileName: json['imageFileName'] as String?,
    priceUnavailable: json['priceUnavailable'] as bool?,
    assetClass: json['assetClass'] != null
        ? AssetClass.fromName(json['assetClass'] as String)
        : null,
    realEstateType: RealEstateType.fromName(json['realEstateType'] as String?),
    fundStyle: FundStyle.fromName(json['fundStyle'] as String?),
    privateEquityKind: PrivateEquityKind.fromName(
      json['privateEquityKind'] as String?,
    ),
    vestingCliffMonths: json['vestingCliffMonths'] as int?,
    vestingDurationMonths: json['vestingDurationMonths'] as int?,
    exerciseDeadline: json['exerciseDeadline'] != null
        ? DateTime.parse(json['exerciseDeadline'] as String)
        : null,
    surfaceM2: (json['surfaceM2'] as num?)?.toDouble(),
    addressLabel: json['addressLabel'] as String?,
    addressCityCode: json['addressCityCode'] as String?,
    addressLat: (json['addressLat'] as num?)?.toDouble(),
    addressLon: (json['addressLon'] as num?)?.toDouble(),
    estimatedPricePerSqm: (json['estimatedPricePerSqm'] as num?)?.toDouble(),
    estimatedValueAt: json['estimatedValueAt'] != null
        ? DateTime.parse(json['estimatedValueAt'] as String)
        : null,
    manualPrice: (json['manualPrice'] as num?)?.toDouble(),
    manualPriceAt: json['manualPriceAt'] != null
        ? DateTime.parse(json['manualPriceAt'] as String)
        : null,
    manualValuation: (json['manualValuation'] as num?)?.toDouble(),
    manualValuationAt: json['manualValuationAt'] != null
        ? DateTime.parse(json['manualValuationAt'] as String)
        : null,
    documents: (json['documents'] as List? ?? [])
        .map((e) => VaultDocument.fromJson(e as Map<String, dynamic>))
        .toList(),
    rentPeriods: (json['rentPeriods'] as List? ?? [])
        .map((e) => RentPeriod.fromJson(e as Map<String, dynamic>))
        .toList(),
    workItems: (json['workItems'] as List? ?? [])
        .map((e) => WorkItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    excludedFromPatrimoine: json['excludedFromPatrimoine'] as bool? ?? false,
  );

  /// Voir [Transaction.toJson] : quantité/prix jamais arrondis à la
  /// sauvegarde, seulement à l'affichage.
  Map<String, dynamic> toJson() => {
    'id': id,
    'isin': isin,
    'label': label,
    'transactions': transactions.map((t) => t.toJson()).toList(),
    if (symbol != null) 'symbol': symbol,
    if (lastPrice != null) 'lastPrice': lastPrice,
    if (lastPriceDate != null)
      'lastPriceDate': lastPriceDate!.toIso8601String(),
    // La devise de cotation et le taux de change ne s'écrivent qu'une fois
    // connus, et le taux toujours en pleine précision (0,006 € pour 1 JPY).
    if (quoteCurrency != null) 'quoteCurrency': quoteCurrency,
    if (lastFxRateToEur != null) 'lastFxRateToEur': lastFxRateToEur,
    if (imageFileName != null) 'imageFileName': imageFileName,
    if (priceUnavailable != null) 'priceUnavailable': priceUnavailable,
    if (assetClass != null) 'assetClass': assetClass!.name,
    if (realEstateType != null) 'realEstateType': realEstateType!.name,
    if (fundStyle != null) 'fundStyle': fundStyle!.name,
    if (privateEquityKind != null)
      'privateEquityKind': privateEquityKind!.name,
    if (vestingCliffMonths != null) 'vestingCliffMonths': vestingCliffMonths,
    if (vestingDurationMonths != null)
      'vestingDurationMonths': vestingDurationMonths,
    if (exerciseDeadline != null)
      'exerciseDeadline': exerciseDeadline!.toIso8601String(),
    if (surfaceM2 != null) 'surfaceM2': surfaceM2,
    if (addressLabel != null) 'addressLabel': addressLabel,
    if (addressCityCode != null) 'addressCityCode': addressCityCode,
    if (addressLat != null) 'addressLat': addressLat,
    if (addressLon != null) 'addressLon': addressLon,
    if (estimatedPricePerSqm != null)
      'estimatedPricePerSqm': estimatedPricePerSqm,
    if (estimatedValueAt != null)
      'estimatedValueAt': estimatedValueAt!.toIso8601String(),
    if (manualPrice != null) 'manualPrice': manualPrice,
    if (manualPriceAt != null)
      'manualPriceAt': manualPriceAt!.toIso8601String(),
    if (manualValuation != null) 'manualValuation': manualValuation,
    if (manualValuationAt != null)
      'manualValuationAt': manualValuationAt!.toIso8601String(),
    if (documents.isNotEmpty)
      'documents': documents.map((d) => d.toJson()).toList(),
    if (rentPeriods.isNotEmpty)
      'rentPeriods': rentPeriods.map((r) => r.toJson()).toList(),
    if (workItems.isNotEmpty)
      'workItems': workItems.map((w) => w.toJson()).toList(),
    if (excludedFromPatrimoine)
      'excludedFromPatrimoine': excludedFromPatrimoine,
  };
}

/// Métadonnées d'un document rattaché à un [InvestmentAccount] ou un
/// [Investment] (contrat d'ouverture, facture d'achat, photo pour
/// assurance...) — le fichier lui-même est stocké à part sur disque (voir
/// `document_storage.dart`), seules les métadonnées voyagent dans le JSON
/// du compte pour ne pas l'alourdir.
class VaultDocument {
  final String id;
  final String fileName;
  final DateTime uploadedAt;
  final String? note;

  /// [Transaction.id] de la transaction dont ce document est la pièce
  /// justificative (facture, photo...), ou `null` s'il n'est rattaché à
  /// aucune transaction en particulier. Utilisé notamment pour les métaux
  /// précieux, où chaque achat physique doit pouvoir être justifié
  /// individuellement — voir `DocumentsSection`'s `transactions` param.
  final String? transactionId;

  /// Regroupement libre utilisé par l'immobilier ("Facture", "Plan",
  /// "Photo", "Quittance", "Autre" — voir `real_estate/` : documents
  /// organisés par bien plutôt qu'en une seule liste, contrairement aux
  /// autres classes). `null` partout ailleurs, sans effet sur
  /// [DocumentsSection] hors immobilier.
  final String? category;

  VaultDocument({
    String? id,
    required this.fileName,
    DateTime? uploadedAt,
    this.note,
    this.transactionId,
    this.category,
  }) : id = id ?? generateInvestmentId('doc'),
       uploadedAt = uploadedAt ?? DateTime.now();

  VaultDocument copyWith({String? note, String? category}) => VaultDocument(
    id: id,
    fileName: fileName,
    uploadedAt: uploadedAt,
    note: note ?? this.note,
    transactionId: transactionId,
    category: category ?? this.category,
  );

  factory VaultDocument.fromJson(Map<String, dynamic> json) => VaultDocument(
    id: json['id'] as String? ?? generateInvestmentId('doc'),
    fileName: json['fileName'] as String? ?? '',
    uploadedAt: json['uploadedAt'] != null
        ? DateTime.parse(json['uploadedAt'] as String)
        : null,
    note: json['note'] as String?,
    transactionId: json['transactionId'] as String?,
    category: json['category'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'uploadedAt': uploadedAt.toIso8601String(),
    if (note != null) 'note': note,
    if (transactionId != null) 'transactionId': transactionId,
    if (category != null) 'category': category,
  };
}

/// Type de compte (l'enveloppe fiscale/juridique concrète, ex : PEA, CTO,
/// Livret A) choisi à la création d'un [InvestmentAccount], en plus de sa
/// [AssetClass]. Les enveloppes proposées dépendent de la classe d'actif
/// choisie — voir [accountEnvelopesFor] — chaque classe se terminant par
/// [autre] comme échappatoire pour les cas non couverts.
enum AccountEnvelope {
  pea,
  peaPme,
  cto,
  peg,
  pee,
  per,
  assuranceVie,
  contratCapitalisation,
  livretA,
  ldds,
  lep,
  pel,
  residencePrincipale,
  residenceSecondaire,
  investissementLocatif,
  scpi,
  crowdfundingImmobilier,
  plateformeEchange,
  walletPersonnel,
  clubDeal,
  fcprFcpi,
  crowdequity,
  crowdlending,
  coffrePersonnel,
  coffreBancaire,
  art,
  carteDeCollection,
  voiture,
  montre,
  droitsMusicaux,
  autre;

  String get label {
    switch (this) {
      case AccountEnvelope.pea:
        return 'PEA';
      case AccountEnvelope.peaPme:
        return 'PEA-PME';
      case AccountEnvelope.cto:
        return 'CTO';
      case AccountEnvelope.peg:
        return 'PEG';
      case AccountEnvelope.pee:
        return 'PEE';
      case AccountEnvelope.per:
        return 'PER';
      case AccountEnvelope.assuranceVie:
        return 'Assurance Vie';
      case AccountEnvelope.contratCapitalisation:
        return 'Contrat de Capitalisation';
      case AccountEnvelope.livretA:
        return 'Livret A';
      case AccountEnvelope.ldds:
        return 'LDDS';
      case AccountEnvelope.lep:
        return 'LEP';
      case AccountEnvelope.pel:
        return 'PEL';
      case AccountEnvelope.residencePrincipale:
        return 'Résidence principale';
      case AccountEnvelope.residenceSecondaire:
        return 'Résidence secondaire';
      case AccountEnvelope.investissementLocatif:
        return 'Investissement locatif';
      case AccountEnvelope.scpi:
        return 'SCPI';
      case AccountEnvelope.crowdfundingImmobilier:
        return 'Crowdfunding immobilier';
      case AccountEnvelope.plateformeEchange:
        return 'Plateforme d\'échange';
      case AccountEnvelope.walletPersonnel:
        return 'Wallet personnel';
      case AccountEnvelope.clubDeal:
        return 'Club deal';
      case AccountEnvelope.fcprFcpi:
        return 'FCPR / FCPI';
      case AccountEnvelope.crowdequity:
        return 'Crowdequity';
      case AccountEnvelope.crowdlending:
        return 'Crowdlending';
      case AccountEnvelope.coffrePersonnel:
        return 'Coffre personnel';
      case AccountEnvelope.coffreBancaire:
        return 'Coffre bancaire';
      case AccountEnvelope.art:
        return 'Art';
      case AccountEnvelope.carteDeCollection:
        return 'Cartes de collection';
      case AccountEnvelope.voiture:
        return 'Voiture';
      case AccountEnvelope.montre:
        return 'Montre';
      case AccountEnvelope.droitsMusicaux:
        return 'Droits musicaux';
      case AccountEnvelope.autre:
        return 'Autre';
    }
  }

  static AccountEnvelope fromName(String name) => AccountEnvelope.values
      .firstWhere((e) => e.name == name, orElse: () => AccountEnvelope.autre);
}

/// Enveloppes proposées à la création d'un compte, selon la classe d'actif
/// déjà choisie — chaque liste se termine par [AccountEnvelope.autre].
List<AccountEnvelope> accountEnvelopesFor(AssetClass assetClass) {
  switch (assetClass) {
    case AssetClass.immobilier:
      return const [
        AccountEnvelope.residencePrincipale,
        AccountEnvelope.residenceSecondaire,
        AccountEnvelope.investissementLocatif,
        AccountEnvelope.scpi,
        AccountEnvelope.crowdfundingImmobilier,
        AccountEnvelope.autre,
      ];
    case AssetClass.actionsEtFonds:
      return const [
        AccountEnvelope.pea,
        AccountEnvelope.peaPme,
        AccountEnvelope.cto,
        AccountEnvelope.peg,
        AccountEnvelope.pee,
        AccountEnvelope.per,
        // L'assurance vie et le contrat de capitalisation détiennent des
        // fonds/ETF/actions comme un compte-titres : beaucoup les gèrent
        // avec leur bourse, en plus de leur volet épargne (voir la liste
        // de la classe épargne). Créés ici, ces comptes héritent du flux
        // compte-titres (ISIN + libellé, plusieurs contrats par
        // établissement — voir `accountEnvelopeIsUniquePerEstablishment`).
        AccountEnvelope.assuranceVie,
        AccountEnvelope.contratCapitalisation,
        AccountEnvelope.autre,
      ];
    case AssetClass.epargne:
      return const [
        AccountEnvelope.livretA,
        AccountEnvelope.ldds,
        AccountEnvelope.lep,
        AccountEnvelope.pel,
        AccountEnvelope.assuranceVie,
        AccountEnvelope.contratCapitalisation,
        AccountEnvelope.autre,
      ];
    case AssetClass.crypto:
      return const [
        AccountEnvelope.plateformeEchange,
        AccountEnvelope.walletPersonnel,
        AccountEnvelope.autre,
      ];
    case AssetClass.privateEquity:
      return const [
        AccountEnvelope.clubDeal,
        AccountEnvelope.fcprFcpi,
        AccountEnvelope.crowdequity,
        AccountEnvelope.crowdlending,
        AccountEnvelope.autre,
      ];
    case AssetClass.metauxPrecieux:
      return const [
        AccountEnvelope.coffrePersonnel,
        AccountEnvelope.coffreBancaire,
        // Un ETC (Exchange Traded Commodity) réplique le cours de l'or/
        // argent en Bourse plutôt qu'en détention physique : logé dans un
        // CTO, comme n'importe quel autre titre — voir
        // [identifierOptionsFor], qui bascule alors sur un ISIN en texte
        // libre plutôt que la liste déroulante de pièces/lingots.
        AccountEnvelope.cto,
        AccountEnvelope.autre,
      ];
    case AssetClass.autres:
      return const [
        AccountEnvelope.art,
        AccountEnvelope.carteDeCollection,
        AccountEnvelope.voiture,
        AccountEnvelope.montre,
        AccountEnvelope.droitsMusicaux,
        AccountEnvelope.autre,
      ];
  }
}

/// Un investissement est-il une position en devise (tenue à un taux de
/// change, pas à un cours de titre) ? — toujours vrai pour une épargne (dont
/// l'identifiant est le code de la devise tenue, voir `identifierOptionsFor`,
/// même si ce code manquait dans [kKnownCurrencies]), et vrai pour toute
/// autre détention identifiée par un code de devise connu (ex : des dollars
/// tenus en cash dans un CTO, créés via l'étape "Investissement et/ou
/// devises" du flux de complétion). Voir aussi [Investment.isCurrency].
bool isCurrencyInvestment(InvestmentAccount account, Investment investment) {
  final effectiveClass = investment.assetClass ?? account.assetClass;
  if (effectiveClass == AssetClass.epargne) return true;
  return kKnownCurrencies.contains(investment.isin.trim().toUpperCase());
}

/// Enveloppe d'épargne unique par banque — donc réutilisée quand elle est
/// recréée (voir `_selectAccountEnvelope` dans
/// `complete_patrimoine_dialog.dart`) : un produit d'épargne réglementée
/// (Livret A, LDDS, LEP, PEL) ne peut être ouvert qu'une seule fois par
/// établissement. L'assurance vie, le contrat de capitalisation et le
/// compte "autre" peuvent au contraire être ouverts plusieurs fois, y
/// compris dans une même banque (un contrat par assureur, une poche par
/// projet...) : un nouveau compte est alors créé à chaque fois.
bool epargneEnvelopeIsUniquePerBank(AccountEnvelope envelope) =>
    envelope != AccountEnvelope.assuranceVie &&
    envelope != AccountEnvelope.contratCapitalisation &&
    envelope != AccountEnvelope.autre;

/// L'enveloppe d'un compte de [assetClass] est-elle unique par
/// établissement — donc réutilisée quand elle est recréée au même
/// établissement (voir `_selectAccountEnvelope`) ? L'épargne réglementée
/// (Livret A, LDDS, LEP, PEL) et le PEA / PEA-PME (un seul par personne en
/// France) ne peuvent être ouverts qu'une seule fois par établissement. Tout
/// le reste (CTO, assurance vie, contrat de capitalisation, épargne
/// entreprise, club deal, art...) peut être ouvert plusieurs fois, y compris
/// dans une même banque : un nouveau compte est alors créé à chaque fois.
bool accountEnvelopeIsUniquePerEstablishment(
  AssetClass assetClass,
  AccountEnvelope envelope,
) {
  switch (assetClass) {
    case AssetClass.epargne:
      return epargneEnvelopeIsUniquePerBank(envelope);
    case AssetClass.actionsEtFonds:
      return envelope == AccountEnvelope.pea ||
          envelope == AccountEnvelope.peaPme;
    case AssetClass.privateEquity:
    case AssetClass.autres:
    case AssetClass.immobilier:
    case AssetClass.crypto:
    case AssetClass.metauxPrecieux:
      return false;
  }
}

/// Un CTO "Actions & Fonds" peut aussi loger un ETC (Exchange-Traded
/// Commodity) sur métaux précieux : plutôt que d'imposer un compte dédié,
/// le flux "Compléter mon patrimoine" propose ces comptes-titres existants
/// comme destination valide quand la classe choisie est Métaux précieux —
/// l'investissement qui y est créé porte alors sa propre [Investment.assetClass]
/// (métaux précieux), différente de celle du compte qui le contient. Même
/// principe pour une SCPI logée dans un contrat d'assurance vie "Actions &
/// Fonds" existant (fiscalité de l'assurance vie, pas celle des revenus
/// fonciers d'une SCPI en direct) plutôt que dans un compte immobilier
/// dédié — un même contrat AV peut ainsi porter à la fois des fonds/ETF et
/// des parts de SCPI, comme dans la réalité (un seul contrat multi-support).
bool accountAcceptsCrossClassInvestment(
  InvestmentAccount account,
  AssetClass targetClass,
) {
  return (targetClass == AssetClass.metauxPrecieux &&
          account.assetClass == AssetClass.actionsEtFonds &&
          account.envelope == AccountEnvelope.cto) ||
      (targetClass == AssetClass.immobilier &&
          account.assetClass == AssetClass.actionsEtFonds &&
          account.envelope == AccountEnvelope.assuranceVie);
}

/// Un métal précieux *coté* plutôt que physique : un ETC (Exchange Traded
/// Commodity) or/argent est logé dans un CTO ([AccountEnvelope.cto]) comme
/// n'importe quel titre, et son cours se résout en Bourse sur Yahoo Finance
/// (voir `price_refresh_service.dart`) — pas via les cours au gramme du
/// site marchand, réservés aux pièces/lingots physiques (pièce ou lingot
/// réellement détenu, coffre ou autre, identifié par son nom de produit).
bool isMetalEtc(InvestmentAccount account) =>
    account.envelope == AccountEnvelope.cto;

/// Classes d'actif dont chaque compte est détenu chez un établissement
/// financier (banque, broker, assureur, plateforme...) : le flux de
/// complétion ("Compléter mon patrimoine", `complete_patrimoine_dialog.dart`)
/// y commence par l'étape "Quel établissement ?" puis "Quel compte ?"
/// (l'enveloppe fiscale), comme pour l'épargne — plutôt que par le formulaire
/// de compte avec champ banque libre des autres classes. L'immobilier, la
/// crypto, les métaux précieux et "Autres" n'y passent pas : "Autres" (objets
/// de collection — montres, voitures, art...) n'a pas de notion
/// d'établissement financier, chaque objet est nommé librement à l'étape
/// compte classique, comme la crypto ou l'immobilier.
bool assetClassRequiresEstablishmentStep(AssetClass assetClass) {
  switch (assetClass) {
    case AssetClass.epargne:
    case AssetClass.actionsEtFonds:
    case AssetClass.privateEquity:
      return true;
    case AssetClass.immobilier:
    case AssetClass.crypto:
    case AssetClass.metauxPrecieux:
    case AssetClass.autres:
      return false;
  }
}

/// Une date d'ouverture a-t-elle un sens pour un compte de [assetClass] ? —
/// les comptes d'investissement détenus chez un établissement (épargne,
/// compte-titres, PEA, assurance vie, private equity) s'ouvrent à une date
/// précise, à saisir à la création/édition (voir
/// `complete_patrimoine_dialog.dart` et `account_detail_screen.dart`).
/// "Autres" (montres, voitures de collection, art...) n'a plus de notion
/// d'établissement (voir [assetClassRequiresEstablishmentStep]) mais garde
/// une date d'ouverture pertinente : la date d'acquisition de l'objet. La
/// crypto (portefeuille auto-détenu), les métaux physiques (pièce ou lingot
/// en coffre) et le compte technique de l'immobilier n'ont pas de date
/// d'ouverture — une SCPI logée en assurance vie n'a pas son propre compte
/// immobilier distinct (voir `accountAcceptsCrossClassInvestment`), elle
/// vit dans un compte Actions & Fonds/assurance vie déjà couvert par le cas
/// général ci-dessous.
bool accountHasOpeningDate(AssetClass assetClass) {
  if (assetClass == AssetClass.autres) return true;
  return assetClassRequiresEstablishmentStep(assetClass);
}

/// Nature du jalon fiscal associé à une enveloppe, voir
/// [accountFiscalMilestone] — un avantage fiscal reste accessible en
/// laissant les fonds sur le compte (PEA, assurance vie). Le déblocage
/// PEG/PEE n'est PAS de cette nature (jalon unique sur le compte) : chaque
/// versement (intéressement, participation, abondement...) se débloque
/// séparément 5 ans après sa propre date, pas après l'ouverture du compte —
/// voir [pegPeeUnlockTranches].
enum FiscalMilestoneKind { avantageFiscal }

/// Jalon fiscal d'un compte : sa nature ([kind]), sa date, et si elle est
/// déjà atteinte à la date de calcul — voir [accountFiscalMilestone].
typedef FiscalMilestone = ({
  FiscalMilestoneKind kind,
  DateTime date,
  bool reached,
});

/// Jalon fiscal associé à une enveloppe, calculé à partir de sa date
/// d'ouverture — `null` si l'enveloppe n'a pas de jalon connu à durée fixe
/// sur le compte entier (CTO, épargne réglementée, PER — dont le déblocage
/// dépend du départ à la retraite, pas d'une durée fixe —, immobilier...),
/// si [openingDate] est inconnue, ou pour PEG/PEE dont le déblocage se
/// calcule par versement, pas sur le compte entier — voir
/// [pegPeeUnlockTranches].
///  - **PEA/PEA-PME** : exonération d'impôt sur le revenu sur les gains
///    après 5 ans (seuls les prélèvements sociaux, ~17,2 %, restent dus) —
///    un retrait avant cette date clôture en général le plan.
///  - **Assurance vie/contrat de capitalisation** : abattement annuel sur
///    les gains retirés après 8 ans (4 600 €, ou 9 200 € pour un couple),
///    en plus d'un taux de prélèvement forfaitaire réduit sur une partie de
///    l'encours.
FiscalMilestone? accountFiscalMilestone({
  required AccountEnvelope? envelope,
  required DateTime? openingDate,
  DateTime? today,
}) {
  if (envelope == null || openingDate == null) return null;
  final int years;
  switch (envelope) {
    case AccountEnvelope.pea:
    case AccountEnvelope.peaPme:
      years = 5;
    case AccountEnvelope.assuranceVie:
    case AccountEnvelope.contratCapitalisation:
      years = 8;
    default:
      return null;
  }
  final milestoneDate = DateTime(
    openingDate.year + years,
    openingDate.month,
    openingDate.day,
  );
  final now = today ?? DateTime.now();
  return (
    kind: FiscalMilestoneKind.avantageFiscal,
    date: milestoneDate,
    reached: !milestoneDate.isAfter(now),
  );
}

/// Date de déblocage PEG/PEE d'un versement fait le [date] : 5 ans après sa
/// propre date, voir [pegPeeUnlockTranches]. Extrait en fonction pure pour
/// être réutilisé tel quel dès la saisie d'une transaction (avant même
/// qu'elle existe), sans avoir besoin d'un [Investment] complet — voir
/// `TransactionForm`'s `projectedUnlockDate`.
DateTime pegPeeUnlockDateFor(DateTime date) =>
    DateTime(date.year + 5, date.month, date.day);

/// Une tranche de déblocage PEG/PEE : un versement (intéressement,
/// participation, abondement, versement volontaire...) et sa propre date de
/// déblocage, 5 ans après sa date — voir [pegPeeUnlockTranches].
typedef UnlockTranche = ({
  DateTime date,
  double amount,
  DateTime unlockDate,
  bool unlocked,
});

/// Échéancier de déblocage d'un compte PEG/PEE : contrairement au PEA ou à
/// l'assurance vie, le jalon ne porte pas sur le compte entier mais sur
/// chaque versement séparément — un intéressement perçu il y a 3 ans n'est
/// pas débloqué en même temps qu'un versement de la première année. Une
/// tranche par achat ([Transaction.isBuy]) toutes investissements confondus
/// sur le compte, chacune débloquée 5 ans après sa propre date. Triée par
/// date de versement croissante (donc aussi par date de déblocage, l'écart
/// étant constant).
List<UnlockTranche> pegPeeUnlockTranches({
  required List<Investment> investments,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final tranches =
      [
          for (final investment in investments)
            for (final tx in investment.transactions)
              if (tx.isBuy) tx,
        ].map((tx) {
          final unlockDate =
              tx.manualUnlockDate ?? pegPeeUnlockDateFor(tx.date);
          return (
            date: tx.date,
            amount: tx.amount,
            unlockDate: unlockDate,
            unlocked: !unlockDate.isAfter(now),
          );
        }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  return tranches;
}

/// Quantité vestée de [investment] à [asOf] (aujourd'hui par défaut) —
/// pertinent seulement pour un Private Equity [PrivateEquityKind.actionsSalarie]
/// suivant un cliff/une durée de vesting (voir [Investment.vestingCliffMonths]/
/// [vestingDurationMonths]). Retourne [Investment.quantityHeld] tel quel si
/// l'un des deux est `null` (vesting non suivi) : purement additif, ne change
/// aucun calcul existant pour une position qui ne renseigne pas ces champs.
///
/// Chaque transaction d'achat véste linéairement entre sa date + le cliff
/// (0 avant) et sa date + la durée totale (acquise à 100 % après) ; une
/// vente est simplement soustraite du total vesté, sans appariement FIFO
/// contre une tranche précise — c'est une métrique d'AFFICHAGE, jamais un
/// calcul fiscal/légal, et dans l'usage réel une vente ne peut normalement
/// intervenir qu'après livraison (donc après vesting complet), cas où les
/// deux méthodes coïncident. `DateTime(year, month + N, day)` déborde
/// correctement sur l'année suivante, mais pour un grant daté du 29-31 d'un
/// mois, la date de cliff/vesting complet peut dériver de 1 à 3 jours sur le
/// mois suivant si celui-ci est plus court (ex : 31 janvier + 1 mois → 2 ou
/// 3 mars) — même tolérance que [pegPeeUnlockDateFor] pour l'année
/// bissextile, acceptable pour une estimation d'affichage.
double vestedQuantityFor(Investment investment, {DateTime? asOf}) {
  final cliff = investment.vestingCliffMonths;
  final duration = investment.vestingDurationMonths;
  if (cliff == null || duration == null) return investment.quantityHeld;
  final now = asOf ?? DateTime.now();
  double vested = 0;
  double sold = 0;
  for (final t in investment.transactions) {
    if (!t.isBuy) {
      sold += t.quantity;
      continue;
    }
    final cliffDate = DateTime(t.date.year, t.date.month + cliff, t.date.day);
    final fullyVestedDate = DateTime(
      t.date.year,
      t.date.month + duration,
      t.date.day,
    );
    if (!now.isBefore(fullyVestedDate)) {
      vested += t.quantity;
    } else if (!now.isBefore(cliffDate)) {
      final totalDays = fullyVestedDate.difference(t.date).inDays;
      final elapsedDays = now.difference(t.date).inDays;
      vested += t.quantity * (totalDays == 0 ? 1 : elapsedDays / totalDays);
    }
  }
  final result = vested - sold;
  if (result <= 1e-9) return 0;
  return result > investment.quantityHeld ? investment.quantityHeld : result;
}

/// Un établissement (banque, broker...) a-t-il un sens pour un compte de
/// [assetClass] ? — l'identité qui groupe les comptes en accordéons "banque
/// → comptes" (`category_detail_screen.dart`) et sous laquelle le logo est
/// importé (`bank_logo_repository.dart`). L'immobilier (bien détenu en
/// direct), la crypto (portefeuille auto-détenu) et les métaux physiques
/// (pièce ou lingot en coffre) n'ont pas de banque ; tout le reste
/// (compte-titres, assurance-vie, épargne...) est bien détenu chez un
/// établissement. Pour les métaux, l'enveloppe tranche : seule une
/// détention en CTO ([AccountEnvelope.cto], un ETC coté) est bancaire. Une
/// SCPI logée en assurance vie n'a pas son propre compte immobilier
/// distinct (voir `accountAcceptsCrossClassInvestment`) : elle vit dans un
/// compte Actions & Fonds/assurance vie, déjà bancaire par ce cas général.
bool assetClassSupportsBankName(
  AssetClass assetClass, {
  AccountEnvelope? envelope,
}) {
  switch (assetClass) {
    case AssetClass.immobilier:
    case AssetClass.crypto:
    case AssetClass.autres:
      return false;
    case AssetClass.metauxPrecieux:
      return envelope == AccountEnvelope.cto;
    case AssetClass.actionsEtFonds:
    case AssetClass.epargne:
    case AssetClass.privateEquity:
      return true;
  }
}

/// Comme [assetClassSupportsBankName], pour un [InvestmentAccount] réel —
/// l'enveloppe du compte tranche pour les métaux précieux.
bool supportsBankName(InvestmentAccount account) =>
    assetClassSupportsBankName(account.assetClass, envelope: account.envelope);

/// Un compte de placement créé par l'utilisateur (PEA, CTO...), contenant
/// ses investissements identifiés par ISIN.
class InvestmentAccount {
  final String id;
  final AssetClass assetClass;
  final AccountEnvelope? envelope;
  final String name;

  /// Établissement qui détient le compte (ex : "Boursorama") — la clé de
  /// groupement des comptes en accordéons "banque → comptes" sur les pages
  /// de catégorie (voir `category_detail_screen.dart`) et l'identité du
  /// logo importé par l'utilisateur (voir `bank_logo_repository.dart`).
  /// `null` (défaut) pour un compte dont le nom tient lieu de banque (une
  /// épargne créée avant l'introduction du champ, ex : "Livret A"), ou qui
  /// n'a simplement pas d'établissement renseigné.
  final String? bankName;

  /// Description facultative saisie par l'utilisateur (ex : "Épargne
  /// vacances"), affichée en seconde ligne sous le type du compte sur les
  /// accordéons de catégorie (voir `real_patrimoine_adapter.dart`) — saisie
  /// à la création d'un compte d'épargne (étape "Quel compte ?", voir
  /// `complete_patrimoine_dialog.dart`), éditable ensuite.
  final String? description;

  /// Date d'ouverture du compte (ex : ouverture du Livret A en 2021) —
  /// pertinente pour les comptes d'investissement détenus chez un
  /// établissement (voir [accountHasOpeningDate]), affichée dans le détail
  /// du compte. `null` si inconnue / non pertinente.
  final DateTime? openingDate;

  final List<Investment> investments;

  /// Positions à effet de levier (perpétuels crypto, marge) — un compte
  /// Actions & Fonds/Crypto peut porter les deux à la fois (positions spot
  /// dans [investments], positions à levier ici), comme un exchange
  /// affichant des onglets "Balances"/"Positions" pour un seul compte. Voir
  /// [LeveragedPosition] pour pourquoi ce n'est pas modélisé comme un
  /// [Investment] à quantité négative.
  final List<LeveragedPosition> leveragedPositions;
  final List<VaultDocument> documents;

  /// Libellé personnalisé choisi par l'utilisateur pour un compte "Autres"
  /// (voir `CustomOtherCategoriesRepository`), quand il ne s'agit d'aucune
  /// des enveloppes fixes (Art, Voiture, Montre...) — `null` sinon.
  /// Prioritaire sur [AccountEnvelope.label] partout où le type du compte
  /// est affiché.
  final String? customOtherCategory;

  /// `true` si l'utilisateur a explicitement choisi d'exclure le compte
  /// entier du patrimoine global — même portée et même principe que
  /// [Investment.excludedFromPatrimoine], mais pour tous ses investissements
  /// d'un coup plutôt qu'un par un. Le compte et ses positions restent
  /// visibles partout avec leur vraie valeur ; seuls les agrégats globaux du
  /// Dashboard l'ignorent.
  final bool excludedFromPatrimoine;

  /// Valeur sentinelle privée de [InvestmentAccount.copyWith] : distingue
  /// "paramètre non fourni" (conserve la valeur existante) de "`null`
  /// explicite" (efface le champ) — `copyWith` ne pouvant pas exprimer
  /// l'effacement d'un champ nullable avec le pattern `x ?? this.x`.
  static const Object _unsetBankName = Object();
  static const Object _unsetDescription = Object();
  static const Object _unsetOpeningDate = Object();
  static const Object _unsetCustomOtherCategory = Object();

  InvestmentAccount({
    String? id,
    required this.assetClass,
    this.envelope,
    required this.name,
    this.bankName,
    this.description,
    this.openingDate,
    required this.investments,
    this.leveragedPositions = const [],
    this.documents = const [],
    this.customOtherCategory,
    this.excludedFromPatrimoine = false,
  }) : id = id ?? generateInvestmentId('account');

  InvestmentAccount copyWith({
    String? name,
    AccountEnvelope? envelope,
    List<Investment>? investments,
    List<LeveragedPosition>? leveragedPositions,
    List<VaultDocument>? documents,
    Object? bankName = _unsetBankName,
    Object? description = _unsetDescription,
    Object? openingDate = _unsetOpeningDate,
    Object? customOtherCategory = _unsetCustomOtherCategory,
    bool? excludedFromPatrimoine,
  }) => InvestmentAccount(
    id: id,
    assetClass: assetClass,
    envelope: envelope ?? this.envelope,
    name: name ?? this.name,
    bankName: identical(bankName, _unsetBankName)
        ? this.bankName
        : bankName as String?,
    description: identical(description, _unsetDescription)
        ? this.description
        : description as String?,
    openingDate: identical(openingDate, _unsetOpeningDate)
        ? this.openingDate
        : openingDate as DateTime?,
    investments: investments ?? this.investments,
    leveragedPositions: leveragedPositions ?? this.leveragedPositions,
    documents: documents ?? this.documents,
    customOtherCategory:
        identical(customOtherCategory, _unsetCustomOtherCategory)
        ? this.customOtherCategory
        : customOtherCategory as String?,
    excludedFromPatrimoine:
        excludedFromPatrimoine ?? this.excludedFromPatrimoine,
  );

  /// Total réel du compte, tous investissements confondus — n'ignore jamais
  /// un investissement/compte marqué "exclu du patrimoine" (voir
  /// [Investment.excludedFromPatrimoine]/[excludedFromPatrimoine]) : cette
  /// exclusion ne porte que sur les agrégats globaux du Dashboard, pas sur
  /// le total propre du compte affiché sur sa page.
  double get totalInvested =>
      investments.fold(0.0, (sum, i) => sum + i.investedAmount);

  /// Somme des valorisations de marché connues, avec repli sur le montant
  /// investi pour les investissements sans cours connu — voir
  /// [Investment.displayValue] (jamais l'invested amount résiduel d'une
  /// position soldée).
  double get totalMarketValue =>
      investments.fold(0.0, (sum, i) => sum + i.displayValue);

  /// Somme des positions à effet de levier ENCORE OUVERTES, valorisées à
  /// [LeveragedPosition.displayValue] (marge + PnL latent, jamais la valeur
  /// notionnelle) — une position fermée ne compte plus pour rien, son PnL
  /// étant déjà réalisé.
  double get totalLeveragedValue =>
      leveragedPositions.fold(0.0, (sum, p) => sum + p.displayValue);

  factory InvestmentAccount.fromJson(Map<String, dynamic> json) {
    // Champ banque normalisé : une chaîne vide (effacement saisi en tant
    // que tel) vaut `null`.
    final rawBankName = json['bankName'] as String?;
    final bankName = (rawBankName == null || rawBankName.trim().isEmpty)
        ? null
        : rawBankName.trim();
    return InvestmentAccount(
      id: json['id'] as String? ?? generateInvestmentId('account'),
      assetClass: AssetClass.fromName(json['assetClass'] as String? ?? ''),
      envelope: json['envelope'] != null
          ? AccountEnvelope.fromName(json['envelope'] as String)
          : null,
      name: json['name'] as String? ?? '',
      bankName: bankName,
      description: json['description'] as String?,
      openingDate: json['openingDate'] != null
          ? DateTime.parse(json['openingDate'] as String)
          : null,
      investments: (json['investments'] as List? ?? [])
          .map((e) => Investment.fromJson(e as Map<String, dynamic>))
          .toList(),
      leveragedPositions: (json['leveragedPositions'] as List? ?? [])
          .map((e) => LeveragedPosition.fromJson(e as Map<String, dynamic>))
          .toList(),
      documents: (json['documents'] as List? ?? [])
          .map((e) => VaultDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
      customOtherCategory: json['customOtherCategory'] as String?,
      excludedFromPatrimoine: json['excludedFromPatrimoine'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetClass': assetClass.name,
    if (envelope != null) 'envelope': envelope!.name,
    'name': name,
    // `fromJson` normalise déjà une chaîne vide en `null` : seul le test
    // de null suffit ici (pas de risque de persister une chaîne vide).
    if (bankName != null) 'bankName': bankName,
    if (description != null) 'description': description,
    // Promotion d'un champ public impossible dans l'élément d'un
    // collection-if : le `!` est explicite, comme `envelope!.name`.
    if (openingDate != null) 'openingDate': openingDate!.toIso8601String(),
    // Voir `Transaction.toJson` : quantité/prix jamais arrondis à la
    // sauvegarde, pour toute classe d'actif.
    'investments': investments.map((i) => i.toJson()).toList(),
    if (leveragedPositions.isNotEmpty)
      'leveragedPositions': leveragedPositions.map((p) => p.toJson()).toList(),
    if (documents.isNotEmpty)
      'documents': documents.map((d) => d.toJson()).toList(),
    if (customOtherCategory != null) 'customOtherCategory': customOtherCategory,
    if (excludedFromPatrimoine)
      'excludedFromPatrimoine': excludedFromPatrimoine,
  };
}

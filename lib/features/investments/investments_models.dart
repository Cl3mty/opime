import 'dart:math';
import '../../core/money_format.dart' show round2;
import 'currency_data.dart' show kKnownCurrencies;
import 'metal_price_client.dart' show kKnownGoldProducts, kKnownSilverProducts;
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

/// Une valeur a-t-elle besoin d'une précision au-delà du centime à la
/// persistance sur disque ? Les cryptomonnaies (quantités et cours ont un
/// sens en dessous du centime) et les taux de change d'une épargne en
/// devise étrangère (1 JPY ≈ 0,006 € — un arrondi à 2 décimales le
/// fausserait d'un ordre de grandeur) échappent à [round2] ; toutes les
/// autres classes se satisfont d'une précision au centime. Voir [round2] et
/// ses appelants (`InvestmentAccount.toJson`, `price_refresh_service`'s
/// `_resolveInvestmentPrice`).
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
  other;

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
  );

  /// [round] à `false` pour les cryptomonnaies (quantité/le cours en
  /// dessous du centime) et les épargnes en devise étrangère (taux de
  /// change — voir [requiresFullPricePrecision]) — voir [round2] et
  /// `InvestmentAccount.toJson`, seul appelant qui connaît la classe
  /// d'actif effective de l'investissement porteur. Le taux de change, lui,
  /// est toujours écrit en pleine précision (un taux JPY ≈ 0,006 € ne
  /// survivrait pas à [round2]).
  Map<String, dynamic> toJson({bool round = true}) => {
    'id': id,
    'date': date.toIso8601String(),
    'isBuy': isBuy,
    'quantity': round ? round2(quantity) : quantity,
    'unitPrice': round ? round2(unitPrice) : unitPrice,
    // Seule une transaction hors euros porte sa devise et son taux.
    if (currency != 'EUR') 'currency': currency,
    if (type != null) 'type': type!.name,
    if (note != null) 'note': note,
    if (currency != 'EUR') 'fxRateToEur': fxRateToEur,
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

  final List<VaultDocument> documents;

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
    this.surfaceM2,
    this.addressLabel,
    this.addressCityCode,
    this.addressLat,
    this.addressLon,
    this.estimatedPricePerSqm,
    this.estimatedValueAt,
    this.documents = const [],
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
    double? surfaceM2,
    String? addressLabel,
    String? addressCityCode,
    double? addressLat,
    double? addressLon,
    double? estimatedPricePerSqm,
    DateTime? estimatedValueAt,
    List<VaultDocument>? documents,
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
    surfaceM2: surfaceM2 ?? this.surfaceM2,
    addressLabel: addressLabel ?? this.addressLabel,
    addressCityCode: addressCityCode ?? this.addressCityCode,
    addressLat: addressLat ?? this.addressLat,
    addressLon: addressLon ?? this.addressLon,
    estimatedPricePerSqm: estimatedPricePerSqm ?? this.estimatedPricePerSqm,
    estimatedValueAt: estimatedValueAt ?? this.estimatedValueAt,
    documents: documents ?? this.documents,
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

  /// Valeur estimée d'un bien immobilier (surface × dernier prix/m² estimé,
  /// voir `real_estate_pricing/`) — `null` tant que l'un des deux facteurs
  /// manque (bien jamais réestimé). Un bien immobilier est toujours détenu
  /// en une seule unité ([quantityHeld] == 1), donc directement comparable
  /// à [investedAmount], sans multiplication de quantité.
  double? get estimatedValue =>
      (surfaceM2 != null && estimatedPricePerSqm != null)
      ? surfaceM2! * estimatedPricePerSqm!
      : null;

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
    surfaceM2: (json['surfaceM2'] as num?)?.toDouble(),
    addressLabel: json['addressLabel'] as String?,
    addressCityCode: json['addressCityCode'] as String?,
    addressLat: (json['addressLat'] as num?)?.toDouble(),
    addressLon: (json['addressLon'] as num?)?.toDouble(),
    estimatedPricePerSqm: (json['estimatedPricePerSqm'] as num?)?.toDouble(),
    estimatedValueAt: json['estimatedValueAt'] != null
        ? DateTime.parse(json['estimatedValueAt'] as String)
        : null,
    documents: (json['documents'] as List? ?? [])
        .map((e) => VaultDocument.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// [round] à `false` pour les cryptomonnaies et les épargnes en devise
  /// étrangère — voir [requiresFullPricePrecision] et [round2].
  Map<String, dynamic> toJson({bool round = true}) => {
    'id': id,
    'isin': isin,
    'label': label,
    'transactions': transactions.map((t) => t.toJson(round: round)).toList(),
    if (symbol != null) 'symbol': symbol,
    if (lastPrice != null) 'lastPrice': round ? round2(lastPrice!) : lastPrice,
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
    if (surfaceM2 != null) 'surfaceM2': surfaceM2,
    if (addressLabel != null) 'addressLabel': addressLabel,
    if (addressCityCode != null) 'addressCityCode': addressCityCode,
    if (addressLat != null) 'addressLat': addressLat,
    if (addressLon != null) 'addressLon': addressLon,
    if (estimatedPricePerSqm != null)
      'estimatedPricePerSqm': estimatedPricePerSqm,
    if (estimatedValueAt != null)
      'estimatedValueAt': estimatedValueAt!.toIso8601String(),
    if (documents.isNotEmpty)
      'documents': documents.map((d) => d.toJson()).toList(),
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

  VaultDocument({
    String? id,
    required this.fileName,
    DateTime? uploadedAt,
    this.note,
    this.transactionId,
  }) : id = id ?? generateInvestmentId('doc'),
       uploadedAt = uploadedAt ?? DateTime.now();

  factory VaultDocument.fromJson(Map<String, dynamic> json) => VaultDocument(
    id: json['id'] as String? ?? generateInvestmentId('doc'),
    fileName: json['fileName'] as String? ?? '',
    uploadedAt: json['uploadedAt'] != null
        ? DateTime.parse(json['uploadedAt'] as String)
        : null,
    note: json['note'] as String?,
    transactionId: json['transactionId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'uploadedAt': uploadedAt.toIso8601String(),
    if (note != null) 'note': note,
    if (transactionId != null) 'transactionId': transactionId,
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
  investissementLocatif,
  scpi,
  plateformeEchange,
  walletPersonnel,
  clubDeal,
  fcprFcpi,
  crowdequity,
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
      case AccountEnvelope.investissementLocatif:
        return 'Investissement locatif';
      case AccountEnvelope.scpi:
        return 'SCPI';
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
        AccountEnvelope.investissementLocatif,
        AccountEnvelope.scpi,
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
/// (métaux précieux), différente de celle du compte qui le contient.
bool accountAcceptsCrossClassInvestment(
  InvestmentAccount account,
  AssetClass targetClass,
) {
  return targetClass == AssetClass.metauxPrecieux &&
      account.assetClass == AssetClass.actionsEtFonds &&
      account.envelope == AccountEnvelope.cto;
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
/// de compte avec champ banque libre des autres classes. "Autres" est inclus
/// (comptes ouverts chez un établissement : produits non classés, droits...),
/// au même titre que `assetClassSupportsBankName`. L'immobilier, la crypto,
/// les métaux précieux n'y passent pas : l'établissement n'y concerne qu'une
/// partie des enveloppes (les métaux en CTO — un ETC), et le choix de
/// l'enveloppe précède alors l'éventuel établissement (étape compte classique,
/// champ banque conditionnel).
bool assetClassRequiresEstablishmentStep(AssetClass assetClass) {
  switch (assetClass) {
    case AssetClass.epargne:
    case AssetClass.actionsEtFonds:
    case AssetClass.privateEquity:
    case AssetClass.autres:
      return true;
    case AssetClass.immobilier:
    case AssetClass.crypto:
    case AssetClass.metauxPrecieux:
      return false;
  }
}

/// Une date d'ouverture a-t-elle un sens pour un compte de [assetClass] ? —
/// les comptes d'investissement détenus chez un établissement (épargne,
/// compte-titres, PEA, assurance vie, private equity, "autres") s'ouvrent à
/// une date précise, à saisir à la création/édition (voir
/// `complete_patrimoine_dialog.dart` et `account_detail_screen.dart`). La
/// crypto (portefeuille auto-détenu), les métaux physiques (pièce ou lingot
/// en coffre) et le compte technique de l'immobilier n'ont pas de date
/// d'ouverture.
bool accountHasOpeningDate(AssetClass assetClass) =>
    assetClassRequiresEstablishmentStep(assetClass);

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
          final unlockDate = DateTime(
            tx.date.year + 5,
            tx.date.month,
            tx.date.day,
          );
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

/// Un établissement (banque, broker...) a-t-il un sens pour un compte de
/// [assetClass] ? — l'identité qui groupe les comptes en accordéons "banque
/// → comptes" (`category_detail_screen.dart`) et sous laquelle le logo est
/// importé (`bank_logo_repository.dart`). L'immobilier (bien détenu en
/// direct), la crypto (portefeuille auto-détenu) et les métaux physiques
/// (pièce ou lingot en coffre) n'ont pas de banque ; tout le reste
/// (compte-titres, assurance-vie, épargne...) est bien détenu chez un
/// établissement. Pour les métaux, l'enveloppe tranche : seule une
/// détention en CTO ([AccountEnvelope.cto], un ETC coté) est bancaire.
bool assetClassSupportsBankName(
  AssetClass assetClass, {
  AccountEnvelope? envelope,
}) {
  switch (assetClass) {
    case AssetClass.immobilier:
    case AssetClass.crypto:
      return false;
    case AssetClass.metauxPrecieux:
      return envelope == AccountEnvelope.cto;
    case AssetClass.actionsEtFonds:
    case AssetClass.epargne:
    case AssetClass.privateEquity:
    case AssetClass.autres:
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
  final List<VaultDocument> documents;

  /// Valeur sentinelle privée de [InvestmentAccount.copyWith] : distingue
  /// "paramètre non fourni" (conserve la valeur existante) de "`null`
  /// explicite" (efface le champ) — `copyWith` ne pouvant pas exprimer
  /// l'effacement d'un champ nullable avec le pattern `x ?? this.x`.
  static const Object _unsetBankName = Object();
  static const Object _unsetDescription = Object();
  static const Object _unsetOpeningDate = Object();

  InvestmentAccount({
    String? id,
    required this.assetClass,
    this.envelope,
    required this.name,
    this.bankName,
    this.description,
    this.openingDate,
    required this.investments,
    this.documents = const [],
  }) : id = id ?? generateInvestmentId('account');

  InvestmentAccount copyWith({
    String? name,
    AccountEnvelope? envelope,
    List<Investment>? investments,
    List<VaultDocument>? documents,
    Object? bankName = _unsetBankName,
    Object? description = _unsetDescription,
    Object? openingDate = _unsetOpeningDate,
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
    documents: documents ?? this.documents,
  );

  double get totalInvested =>
      investments.fold(0.0, (sum, i) => sum + i.investedAmount);

  /// Somme des valorisations de marché connues, avec repli sur le montant
  /// investi pour les investissements sans cours connu — cohérent avec le
  /// comportement de chaque [Investment] pris individuellement.
  double get totalMarketValue => investments.fold(
    0.0,
    (sum, i) => sum + (i.marketValue ?? i.investedAmount),
  );

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
      documents: (json['documents'] as List? ?? [])
          .map((e) => VaultDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
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
    // Un investissement crypto (le sien ou, à défaut, celui hérité de ce
    // compte), une épargne en devise étrangère ou toute autre position en
    // devise (ex : des dollars tenus dans un CTO — voir
    // `isCurrencyInvestment`) gardent leur précision d'origine — quantité/
    // cours en dessous du centime, taux de change — voir
    // [requiresFullPricePrecision].
    'investments': investments.map((i) {
      final effectiveClass = i.assetClass ?? assetClass;
      return i.toJson(
        round:
            !(requiresFullPricePrecision(effectiveClass) ||
                isCurrencyInvestment(this, i)),
      );
    }).toList(),
    if (documents.isNotEmpty)
      'documents': documents.map((d) => d.toJson()).toList(),
  };
}

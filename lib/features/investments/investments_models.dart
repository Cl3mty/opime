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
/// que celles du Dashboard de démo (`dashboard/dashboard_dummy_data.dart`,
/// `PatrimoineCategory`) et de la sidebar (`actifs_*` dans
/// `nav_models.dart`), pour que les comptes réels puissent un jour
/// alimenter les mêmes vues (Allocation, répartition Actifs/Passifs...)
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
  /// `nav_models.dart`/`dashboard_dummy_data.dart`), pour relier plus tard
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

/// Une transaction d'achat ou de vente sur un [Investment].
class Transaction {
  final String id;
  final DateTime date;
  final bool isBuy;
  final double quantity;
  final double unitPrice;

  Transaction({
    String? id,
    required this.date,
    required this.isBuy,
    required this.quantity,
    required this.unitPrice,
  }) : id = id ?? generateInvestmentId('txn');

  double get amount => quantity * unitPrice;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String? ?? generateInvestmentId('txn'),
    date: DateTime.parse(json['date'] as String),
    isBuy: json['isBuy'] as bool? ?? true,
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
  );

  /// [round] à `false` pour les cryptomonnaies (quantité/le cours en
  /// dessous du centime) et les épargnes en devise étrangère (taux de
  /// change — voir [requiresFullPricePrecision]) — voir [round2] et
  /// `InvestmentAccount.toJson`, seul appelant qui connaît la classe
  /// d'actif effective de l'investissement porteur.
  Map<String, dynamic> toJson({bool round = true}) => {
    'id': id,
    'date': date.toIso8601String(),
    'isBuy': isBuy,
    'quantity': round ? round2(quantity) : quantity,
    'unitPrice': round ? round2(unitPrice) : unitPrice,
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

  final List<VaultDocument> documents;

  Investment({
    String? id,
    required this.isin,
    required this.label,
    required this.transactions,
    this.symbol,
    this.lastPrice,
    this.lastPriceDate,
    this.imageFileName,
    this.priceUnavailable,
    this.assetClass,
    this.realEstateType,
    this.documents = const [],
  }) : id = id ?? generateInvestmentId('inv');

  Investment copyWith({
    List<Transaction>? transactions,
    String? symbol,
    double? lastPrice,
    DateTime? lastPriceDate,
    String? imageFileName,
    bool? priceUnavailable,
    AssetClass? assetClass,
    RealEstateType? realEstateType,
    List<VaultDocument>? documents,
  }) => Investment(
    id: id,
    isin: isin,
    label: label,
    transactions: transactions ?? this.transactions,
    symbol: symbol ?? this.symbol,
    lastPrice: lastPrice ?? this.lastPrice,
    lastPriceDate: lastPriceDate ?? this.lastPriceDate,
    imageFileName: imageFileName ?? this.imageFileName,
    priceUnavailable: priceUnavailable ?? this.priceUnavailable,
    assetClass: assetClass ?? this.assetClass,
    realEstateType: realEstateType ?? this.realEstateType,
    documents: documents ?? this.documents,
  );

  double get quantityHeld => transactions.fold(
    0.0,
    (sum, t) => sum + (t.isBuy ? t.quantity : -t.quantity),
  );

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

  /// Valorisation au dernier cours connu, ou `null` si aucun cours n'a
  /// encore été récupéré.
  double? get marketValue =>
      lastPrice == null ? null : quantityHeld * lastPrice!;

  /// Plus/moins-value latente par rapport au coût d'achat, ou `null` sans
  /// cours connu.
  double? get unrealizedGain =>
      marketValue == null ? null : marketValue! - investedAmount;

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
    imageFileName: json['imageFileName'] as String?,
    priceUnavailable: json['priceUnavailable'] as bool?,
    assetClass: json['assetClass'] != null
        ? AssetClass.fromName(json['assetClass'] as String)
        : null,
    realEstateType: RealEstateType.fromName(json['realEstateType'] as String?),
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
    if (imageFileName != null) 'imageFileName': imageFileName,
    if (priceUnavailable != null) 'priceUnavailable': priceUnavailable,
    if (assetClass != null) 'assetClass': assetClass!.name,
    if (realEstateType != null) 'realEstateType': realEstateType!.name,
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

/// Enveloppe d'épargne unique par banque — donc réutilisée quand elle est
/// recréée (voir `_selectEpargneEnvelope` dans
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
    assetClassSupportsBankName(
      account.assetClass,
      envelope: account.envelope,
    );

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

  final List<Investment> investments;
  final List<VaultDocument> documents;

  /// Valeur sentinelle privée de [InvestmentAccount.copyWith] : distingue
  /// "paramètre non fourni" (conserve la valeur existante) de "`null`
  /// explicite" (efface le champ) — `copyWith` ne pouvant pas exprimer
  /// l'effacement d'un champ nullable avec le pattern `x ?? this.x`.
  static const Object _unsetBankName = Object();
  static const Object _unsetDescription = Object();

  InvestmentAccount({
    String? id,
    required this.assetClass,
    this.envelope,
    required this.name,
    this.bankName,
    this.description,
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
    // Un investissement crypto (le sien ou, à défaut, celui hérité de ce
    // compte) ou une épargne en devise étrangère gardent leur précision
    // d'origine — quantité/cours en dessous du centime, taux de change —
    // voir [requiresFullPricePrecision].
    'investments': investments.map((i) {
      final effectiveClass = i.assetClass ?? assetClass;
      return i.toJson(round: !requiresFullPricePrecision(effectiveClass));
    }).toList(),
    if (documents.isNotEmpty)
      'documents': documents.map((d) => d.toJson()).toList(),
  };
}

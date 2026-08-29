import 'investments_models.dart' show VaultDocument, generateInvestmentId;

/// Sens d'une position à effet de levier — gagne quand le cours monte
/// ([long]) ou descend ([short]). Un compte spot classique
/// ([Investment]/[Transaction] dans `investments_models.dart`) n'a pas
/// cette notion : il ne peut détenir qu'une quantité positive.
enum PositionSide {
  long,
  short;

  String get label => this == PositionSide.long ? 'Long' : 'Short';

  static PositionSide? fromName(String? name) {
    if (name == null) return null;
    for (final side in PositionSide.values) {
      if (side.name == name) return side;
    }
    return null;
  }
}

/// Une position à effet de levier (perpétuel crypto, action/CFD sur marge)
/// — délibérément un modèle séparé de [Investment] plutôt qu'une extension
/// avec une quantité négative pour représenter une position courte :
/// `Investment.quantityHeld`/`displayValue` et les calculs de performance
/// (`real_patrimoine_adapter.dart`, `performance_calculator.dart`) supposent
/// tous une détention "long only", avec des garde-fous `quantityHeld <= 0`
/// qui traitent une quantité nulle/négative comme "position soldée" —
/// les détourner pour un short casserait ces garanties partout ailleurs
/// dans l'app plutôt que d'y ajouter proprement le concept.
///
/// [markPrice] d'une position crypto (compte [AssetClass.crypto]) est
/// actualisé automatiquement comme un investissement spot classique — voir
/// `price_refresh_service.dart`, qui résout [market] comme un ticker Yahoo
/// Finance (`TICKER-EUR`, directement en euros comme
/// `YahooFinanceClient.resolveCryptoSymbol`). Pour Actions & Fonds (CFD sur
/// marge, pas de ticker fiable), [markPrice] reste en saisie manuelle (voir
/// "Actualiser" dans l'UI). [cumulativeFunding] reste toujours saisi à la
/// main dans les deux cas (aucune source de cours n'expose les frais de
/// financement cumulés).
///
/// La marge ([margin]) n'est jamais saisie séparément — dérivée de
/// [size]/[entryPriceInEur]/[leverage], voir sa doc : la faire saisir à
/// part n'apportait qu'un risque d'incohérence (rien ne garantissait que la
/// marge tapée corresponde réellement à taille × prix ÷ levier) pour un
/// champ que l'utilisateur peut de toute façon déduire lui-même de ces
/// trois autres. Le prix de liquidation ([liquidationPrice]) reste, lui,
/// saisissable/corrigeable à la main (voir "Actualiser" dans l'UI) : les
/// vraies formules de marge de maintenance varient trop d'un exchange à
/// l'autre pour être reproduites exactement, mais [effectiveLiquidationPrice]
/// retombe sur une estimation calculée ([estimatedLiquidationPrice], marge
/// isolée sans marge de maintenance) tant que l'utilisateur n'a pas
/// recopié la valeur exacte de son exchange.
class LeveragedPosition {
  final String id;

  /// Marché/actif sous-jacent (ex : "BTC") — texte libre pour Actions &
  /// Fonds (pas d'ISIN, un perpétuel/CFD n'en a pas), choisi dans
  /// [kKnownCryptoTickers] pour un compte crypto (voir
  /// `leveraged_position_dialog.dart`) afin que [market] soit un ticker
  /// fiable pour la résolution automatique du cours.
  final String market;
  final PositionSide side;

  /// Multiplicateur de levier (2.0 pour "2x") — informatif, n'entre dans
  /// aucun calcul ([pnl]/[roePercent] utilisent [size]/[margin] directement,
  /// pas le levier affiché, qui peut légèrement différer de leur ratio réel
  /// selon l'exchange).
  final double leverage;

  /// Taille de la position en unités du sous-jacent (ex : 0.01291 BTC).
  final double size;

  /// Prix d'entrée dans [entryPriceCurrency] — voir [entryPriceInEur] pour
  /// la valeur convertie utilisée dans tous les calculs de PnL.
  final double entryPrice;

  /// Devise de saisie de [entryPrice] — "EUR" par défaut, ou toute devise
  /// de [kKnownCurrencies]/stablecoin de [kKnownStablecoins] pour une
  /// position crypto (voir `leveraged_position_dialog.dart`) : permet de
  /// saisir un prix d'entrée tel qu'affiché par l'exchange (ex : en USDC)
  /// sans conversion manuelle préalable.
  final String entryPriceCurrency;

  /// Taux de change vers l'euro au moment de l'entrée (1 [entryPriceCurrency]
  /// = X €) — `null` si [entryPriceCurrency] est "EUR" (aucun taux
  /// nécessaire) ou si non renseigné. Résolu automatiquement ou saisi à la
  /// main, même mécanique que `Transaction.fxRateToEur`.
  final double? entryPriceFxRateToEur;

  /// `null` tant que jamais actualisé après la création.
  final double? markPrice;
  final DateTime? markPriceAt;

  /// Saisi tel quel depuis l'exchange — voir la doc de tête de la classe.
  final double? liquidationPrice;

  /// Cumul des frais de financement perçus/payés depuis l'ouverture — signé
  /// (négatif : payé, positif : perçu), jamais recalculé.
  final double cumulativeFunding;

  final double? takeProfit;
  final double? stopLoss;

  final DateTime openedAt;

  /// `null` : position ouverte. Renseigné : position clôturée, [closePrice]
  /// fige alors le prix de sortie utilisé pour le PnL réalisé.
  final DateTime? closedAt;
  final double? closePrice;

  final String? note;
  final List<VaultDocument> documents;

  bool get isOpen => closedAt == null;

  static const Object _unset = Object();

  LeveragedPosition({
    String? id,
    required this.market,
    required this.side,
    required this.leverage,
    required this.size,
    required this.entryPrice,
    this.entryPriceCurrency = 'EUR',
    this.entryPriceFxRateToEur,
    this.markPrice,
    this.markPriceAt,
    this.liquidationPrice,
    this.cumulativeFunding = 0,
    this.takeProfit,
    this.stopLoss,
    DateTime? openedAt,
    this.closedAt,
    this.closePrice,
    this.note,
    this.documents = const [],
  }) : id = id ?? generateInvestmentId('lev'),
       openedAt = openedAt ?? DateTime.now();

  /// [entryPrice] converti en euros — ce qu'utilisent tous les calculs de
  /// PnL, comparé à [markPrice]/[closePrice] (toujours en euros). Vaut
  /// [entryPrice] tel quel en EUR ; sans taux résolu pour une devise
  /// étrangère (ne devrait pas arriver, le formulaire bloque
  /// l'enregistrement dans ce cas — voir `leveraged_position_dialog.dart`),
  /// retombe sur [entryPrice] non converti plutôt que de fausser
  /// silencieusement le calcul dans un sens ou l'autre.
  double get entryPriceInEur => entryPriceCurrency == 'EUR'
      ? entryPrice
      : entryPrice * (entryPriceFxRateToEur ?? 1.0);

  /// Montant de la position à l'entrée (taille × prix d'entrée, en euros) —
  /// utilisé pour dériver [margin], et affiché en direct dans le
  /// formulaire de saisie (`leveraged_position_dialog.dart`) pendant que
  /// l'utilisateur tape taille/prix d'entrée/levier, avant même
  /// l'enregistrement.
  double get entryNotionalValue => size * entryPriceInEur;

  /// Marge (cash) nominalement immobilisée sur cette position — dérivée du
  /// montant de la position à l'entrée ([entryNotionalValue]) rapporté au
  /// levier, jamais saisie séparément (voir la doc de tête de la classe :
  /// rien ne garantissait auparavant qu'une marge tapée à la main
  /// corresponde réellement à taille × prix d'entrée ÷ levier). `0` si
  /// [leverage] est nul ou négatif (ne devrait pas arriver, le formulaire
  /// exige un levier strictement positif).
  double get margin => leverage <= 0 ? 0 : entryNotionalValue / leverage;

  /// Prix de liquidation estimé pour une marge isolée, sans marge de
  /// maintenance (approximation : entrée × (1 ∓ 1/levier) selon le sens) —
  /// les vraies formules de marge de maintenance varient trop d'un
  /// exchange à l'autre pour être reproduites exactement. Sert de valeur
  /// par défaut tant que l'utilisateur n'a pas recopié la valeur exacte de
  /// son exchange (voir [effectiveLiquidationPrice]). `null` si [leverage]
  /// est nul ou négatif.
  double? get estimatedLiquidationPrice {
    if (leverage <= 0) return null;
    final entry = entryPriceInEur;
    final factor = 1 / leverage;
    return side == PositionSide.long
        ? entry * (1 - factor)
        : entry * (1 + factor);
  }

  /// Prix de liquidation effectif : [liquidationPrice] s'il a été
  /// saisi/corrigé à la main avec la valeur exacte de l'exchange, sinon
  /// [estimatedLiquidationPrice] (approximation calculée) — ce que tout le
  /// reste de l'app (distance de liquidation, tableau des positions) doit
  /// lire plutôt que [liquidationPrice] brut.
  double? get effectiveLiquidationPrice =>
      liquidationPrice ?? estimatedLiquidationPrice;

  /// `true` si [markPriceAt] tombe le jour calendaire courant — même
  /// principe que `Investment.isPriceFresh`, pour éviter à
  /// `price_refresh_service.dart` de re-résoudre un cours crypto déjà
  /// actualisé aujourd'hui.
  bool get isMarkPriceFresh {
    final date = markPriceAt;
    if (date == null) return false;
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  /// PnL latent (position ouverte, à partir de [markPrice]) ou réalisé
  /// (position fermée, à partir de [closePrice]) — jamais stocké
  /// séparément, dérivé à chaque lecture comme `Investment.pru`. `null`
  /// tant qu'aucun cours de référence n'est connu (position ouverte jamais
  /// actualisée).
  double? get pnl {
    final price = isOpen ? markPrice : closePrice;
    if (price == null) return null;
    final direction = side == PositionSide.long ? 1 : -1;
    return (price - entryPriceInEur) * size * direction;
  }

  /// Rendement en tenant compte du levier (PnL rapporté à la marge
  /// engagée, pas à la valeur notionnelle) — c'est le "ROE %" affiché par
  /// la plupart des exchanges à effet de levier. `null` sans [pnl] connu ou
  /// marge nulle.
  double? get roePercent {
    final p = pnl;
    if (p == null || margin == 0) return null;
    return p / margin * 100;
  }

  /// Valeur notionnelle de la position (taille × cours de référence) —
  /// jamais ce qui doit être compté dans le patrimoine, voir [displayValue].
  double? get notionalValue {
    final price = isOpen ? markPrice : closePrice;
    if (price == null) return null;
    return size * price;
  }

  /// Écart en % entre le cours de référence et le prix de liquidation —
  /// proche de 0 : liquidation imminente. `null` sans cours actualisé.
  /// Utilise [effectiveLiquidationPrice] (valeur exacte si saisie, sinon
  /// l'estimation calculée) — quasiment toujours défini dès que [leverage]
  /// est positif. Toujours calculé sur [markPrice] (une position fermée n'a
  /// plus de risque de liquidation).
  double? get liquidationDistancePercent {
    final price = markPrice;
    final liq = effectiveLiquidationPrice;
    if (!isOpen || price == null || liq == null || price == 0) return null;
    return ((price - liq) / price).abs() * 100;
  }

  /// Ratio risque/rendement classique — |take profit - entrée| rapporté à
  /// |entrée - stop loss|. `null` tant que l'un des deux n'est pas renseigné
  /// (un ratio n'a pas de sens avec un seul des deux bornes).
  double? get riskRewardRatio {
    final tp = takeProfit;
    final sl = stopLoss;
    if (tp == null || sl == null) return null;
    final entry = entryPriceInEur;
    final risk = (entry - sl).abs();
    if (risk == 0) return null;
    return (tp - entry).abs() / risk;
  }

  /// Valeur à agréger dans le patrimoine : ce que la clôture immédiate de
  /// la position rendrait (marge + PnL latent), jamais la valeur
  /// notionnelle totale — même principe que `Investment.displayValue` pour
  /// une position soldée. Une position fermée ne compte plus pour rien
  /// (son PnL est déjà réalisé, encaissé ailleurs).
  double get displayValue => isOpen ? margin + (pnl ?? 0) : 0;

  LeveragedPosition copyWith({
    String? market,
    PositionSide? side,
    double? leverage,
    double? size,
    double? entryPrice,
    String? entryPriceCurrency,
    Object? entryPriceFxRateToEur = _unset,
    Object? markPrice = _unset,
    Object? markPriceAt = _unset,
    Object? liquidationPrice = _unset,
    double? cumulativeFunding,
    Object? takeProfit = _unset,
    Object? stopLoss = _unset,
    Object? closedAt = _unset,
    Object? closePrice = _unset,
    Object? note = _unset,
    List<VaultDocument>? documents,
  }) => LeveragedPosition(
    id: id,
    market: market ?? this.market,
    side: side ?? this.side,
    leverage: leverage ?? this.leverage,
    size: size ?? this.size,
    entryPrice: entryPrice ?? this.entryPrice,
    entryPriceCurrency: entryPriceCurrency ?? this.entryPriceCurrency,
    entryPriceFxRateToEur: identical(entryPriceFxRateToEur, _unset)
        ? this.entryPriceFxRateToEur
        : (entryPriceFxRateToEur as num?)?.toDouble(),
    // `as double?` planterait sur un littéral entier (66000) passé là où un
    // double est attendu : la coercition implicite int → double de Dart ne
    // s'applique qu'à travers un paramètre typé `double`, pas à travers
    // `Object?` — même raison que `fromJson` passe par `num?` partout.
    markPrice: identical(markPrice, _unset)
        ? this.markPrice
        : (markPrice as num?)?.toDouble(),
    markPriceAt: identical(markPriceAt, _unset)
        ? this.markPriceAt
        : markPriceAt as DateTime?,
    liquidationPrice: identical(liquidationPrice, _unset)
        ? this.liquidationPrice
        : (liquidationPrice as num?)?.toDouble(),
    cumulativeFunding: cumulativeFunding ?? this.cumulativeFunding,
    takeProfit: identical(takeProfit, _unset)
        ? this.takeProfit
        : (takeProfit as num?)?.toDouble(),
    stopLoss: identical(stopLoss, _unset)
        ? this.stopLoss
        : (stopLoss as num?)?.toDouble(),
    openedAt: openedAt,
    closedAt: identical(closedAt, _unset)
        ? this.closedAt
        : closedAt as DateTime?,
    closePrice: identical(closePrice, _unset)
        ? this.closePrice
        : (closePrice as num?)?.toDouble(),
    note: identical(note, _unset) ? this.note : note as String?,
    documents: documents ?? this.documents,
  );

  factory LeveragedPosition.fromJson(Map<String, dynamic> json) =>
      LeveragedPosition(
        id: json['id'] as String?,
        market: json['market'] as String? ?? '',
        side: PositionSide.fromName(json['side'] as String?) ??
            PositionSide.long,
        leverage: (json['leverage'] as num?)?.toDouble() ?? 1,
        size: (json['size'] as num?)?.toDouble() ?? 0,
        entryPrice: (json['entryPrice'] as num?)?.toDouble() ?? 0,
        entryPriceCurrency: json['entryPriceCurrency'] as String? ?? 'EUR',
        entryPriceFxRateToEur:
            (json['entryPriceFxRateToEur'] as num?)?.toDouble(),
        // `margin`/`marginType` ne sont plus lus : un ancien fichier peut
        // encore porter ces clés (compatibilité descendante), désormais
        // ignorées — la marge est toujours dérivée (voir sa doc), et le
        // type de marge n'était qu'informatif, retiré de l'UI.
        markPrice: (json['markPrice'] as num?)?.toDouble(),
        markPriceAt: json['markPriceAt'] != null
            ? DateTime.parse(json['markPriceAt'] as String)
            : null,
        liquidationPrice: (json['liquidationPrice'] as num?)?.toDouble(),
        cumulativeFunding:
            (json['cumulativeFunding'] as num?)?.toDouble() ?? 0,
        takeProfit: (json['takeProfit'] as num?)?.toDouble(),
        stopLoss: (json['stopLoss'] as num?)?.toDouble(),
        openedAt: json['openedAt'] != null
            ? DateTime.parse(json['openedAt'] as String)
            : DateTime.now(),
        closedAt: json['closedAt'] != null
            ? DateTime.parse(json['closedAt'] as String)
            : null,
        closePrice: (json['closePrice'] as num?)?.toDouble(),
        note: json['note'] as String?,
        documents: (json['documents'] as List? ?? [])
            .map((e) => VaultDocument.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'market': market,
    'side': side.name,
    'leverage': leverage,
    'size': size,
    'entryPrice': entryPrice,
    'entryPriceCurrency': entryPriceCurrency,
    if (entryPriceFxRateToEur != null)
      'entryPriceFxRateToEur': entryPriceFxRateToEur,
    // Pas de `margin` ici : toujours dérivée à la lecture (voir sa doc),
    // jamais persistée — écrire une valeur qui serait de toute façon
    // ignorée au chargement induirait en erreur qui lirait le fichier.
    // Pas de `marginType` non plus : champ informatif retiré de l'UI.
    if (markPrice != null) 'markPrice': markPrice,
    if (markPriceAt != null) 'markPriceAt': markPriceAt!.toIso8601String(),
    if (liquidationPrice != null) 'liquidationPrice': liquidationPrice,
    'cumulativeFunding': cumulativeFunding,
    if (takeProfit != null) 'takeProfit': takeProfit,
    if (stopLoss != null) 'stopLoss': stopLoss,
    'openedAt': openedAt.toIso8601String(),
    if (closedAt != null) 'closedAt': closedAt!.toIso8601String(),
    if (closePrice != null) 'closePrice': closePrice,
    if (note != null) 'note': note,
    if (documents.isNotEmpty)
      'documents': documents.map((d) => d.toJson()).toList(),
  };
}

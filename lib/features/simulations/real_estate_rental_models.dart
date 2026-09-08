import '../investments/investments_models.dart' show generateInvestmentId;

/// Une chambre au sein d'une [RentalStrategy] de colocation — chaque
/// chambre a son propre loyer, sommés pour le revenu de l'unité.
class RentalRoom {
  final String id;
  final String label;
  final double monthlyRent;

  RentalRoom({String? id, required this.label, required this.monthlyRent})
    : id = id ?? generateInvestmentId('room');

  factory RentalRoom.fromJson(Map<String, dynamic> json) => RentalRoom(
    id: json['id'] as String?,
    label: json['label'] as String? ?? '',
    monthlyRent: (json['monthlyRent'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'monthlyRent': monthlyRent,
  };
}

/// Mode de location d'une [RentalUnit] — même convention de modélisation
/// que le reste du dépôt (`enum` + classe à champs nullable par variante,
/// voir `TransactionType`/`LoanType`), pas de `sealed class`.
enum RentalStrategyKind { longTerm, shortTerm, seasonalMix, colocation }

/// Stratégie locative d'une [RentalUnit] : longue durée (loyer mensuel
/// fixe), courte durée (tarif/nuit × taux d'occupation), mix saisonnier
/// (longue durée une partie de l'année, courte durée le reste — ex : hiver
/// long terme, été Airbnb), ou colocation (plusieurs [RentalRoom], chacune
/// avec son propre loyer). Une seule de ces stratégies s'applique par unité,
/// mais une même [RealEstateProject] (voir
/// `real_estate_profitability_calculator.dart`) peut avoir plusieurs
/// unités à stratégies différentes — c'est ce qui couvre nativement le
/// découpage en plusieurs biens.
class RentalStrategy {
  final RentalStrategyKind kind;
  final double? monthlyRent;
  final double? nightlyRate;
  final double? occupancyRatePercent;
  final int? longTermMonths;
  final double? longTermMonthlyRent;
  final int? shortTermMonths;
  final double? shortTermNightlyRate;
  final double? shortTermOccupancyRatePercent;
  final List<RentalRoom> rooms;

  const RentalStrategy._({
    required this.kind,
    this.monthlyRent,
    this.nightlyRate,
    this.occupancyRatePercent,
    this.longTermMonths,
    this.longTermMonthlyRent,
    this.shortTermMonths,
    this.shortTermNightlyRate,
    this.shortTermOccupancyRatePercent,
    this.rooms = const [],
  });

  factory RentalStrategy.longTerm({required double monthlyRent}) =>
      RentalStrategy._(kind: RentalStrategyKind.longTerm, monthlyRent: monthlyRent);

  factory RentalStrategy.shortTerm({
    required double nightlyRate,
    required double occupancyRatePercent,
  }) => RentalStrategy._(
    kind: RentalStrategyKind.shortTerm,
    nightlyRate: nightlyRate,
    occupancyRatePercent: occupancyRatePercent,
  );

  factory RentalStrategy.seasonalMix({
    required int longTermMonths,
    required double longTermMonthlyRent,
    required int shortTermMonths,
    required double shortTermNightlyRate,
    required double shortTermOccupancyRatePercent,
  }) => RentalStrategy._(
    kind: RentalStrategyKind.seasonalMix,
    longTermMonths: longTermMonths,
    longTermMonthlyRent: longTermMonthlyRent,
    shortTermMonths: shortTermMonths,
    shortTermNightlyRate: shortTermNightlyRate,
    shortTermOccupancyRatePercent: shortTermOccupancyRatePercent,
  );

  factory RentalStrategy.colocation({required List<RentalRoom> rooms}) =>
      RentalStrategy._(kind: RentalStrategyKind.colocation, rooms: rooms);

  /// Revenu locatif annuel brut de cette stratégie — un mois vaut 30.44
  /// jours (365.25/12) pour convertir les mois du mix saisonnier en jours
  /// d'occupation courte durée.
  double get annualGrossRevenue => switch (kind) {
    RentalStrategyKind.longTerm => (monthlyRent ?? 0) * 12,
    RentalStrategyKind.shortTerm =>
      (nightlyRate ?? 0) * 365 * ((occupancyRatePercent ?? 0) / 100),
    RentalStrategyKind.seasonalMix =>
      (longTermMonthlyRent ?? 0) * (longTermMonths ?? 0) +
          (shortTermNightlyRate ?? 0) *
              ((shortTermMonths ?? 0) * 30.44) *
              ((shortTermOccupancyRatePercent ?? 0) / 100),
    RentalStrategyKind.colocation =>
      rooms.fold(0.0, (sum, room) => sum + room.monthlyRent) * 12,
  };

  factory RentalStrategy.fromJson(Map<String, dynamic> json) => RentalStrategy._(
    kind: RentalStrategyKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => RentalStrategyKind.longTerm,
    ),
    monthlyRent: (json['monthlyRent'] as num?)?.toDouble(),
    nightlyRate: (json['nightlyRate'] as num?)?.toDouble(),
    occupancyRatePercent: (json['occupancyRatePercent'] as num?)?.toDouble(),
    longTermMonths: json['longTermMonths'] as int?,
    longTermMonthlyRent: (json['longTermMonthlyRent'] as num?)?.toDouble(),
    shortTermMonths: json['shortTermMonths'] as int?,
    shortTermNightlyRate: (json['shortTermNightlyRate'] as num?)?.toDouble(),
    shortTermOccupancyRatePercent:
        (json['shortTermOccupancyRatePercent'] as num?)?.toDouble(),
    rooms: (json['rooms'] as List? ?? [])
        .map((e) => RentalRoom.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (monthlyRent != null) 'monthlyRent': monthlyRent,
    if (nightlyRate != null) 'nightlyRate': nightlyRate,
    if (occupancyRatePercent != null) 'occupancyRatePercent': occupancyRatePercent,
    if (longTermMonths != null) 'longTermMonths': longTermMonths,
    if (longTermMonthlyRent != null) 'longTermMonthlyRent': longTermMonthlyRent,
    if (shortTermMonths != null) 'shortTermMonths': shortTermMonths,
    if (shortTermNightlyRate != null) 'shortTermNightlyRate': shortTermNightlyRate,
    if (shortTermOccupancyRatePercent != null)
      'shortTermOccupancyRatePercent': shortTermOccupancyRatePercent,
    if (rooms.isNotEmpty) 'rooms': rooms.map((r) => r.toJson()).toList(),
  };
}

/// Une unité locative d'un projet immobilier — un bien peut se découper en
/// plusieurs unités (ex : deux appartements séparés dans le même immeuble),
/// chacune avec sa propre [RentalStrategy]. Voir
/// `real_estate_profitability_calculator.dart` pour l'agrégation de
/// plusieurs unités en un seul résultat de rentabilité.
class RentalUnit {
  final String id;
  final String label;
  final RentalStrategy strategy;

  RentalUnit({String? id, required this.label, required this.strategy})
    : id = id ?? generateInvestmentId('unit');

  double get annualGrossRevenue => strategy.annualGrossRevenue;

  RentalUnit copyWith({String? label, RentalStrategy? strategy}) => RentalUnit(
    id: id,
    label: label ?? this.label,
    strategy: strategy ?? this.strategy,
  );

  factory RentalUnit.fromJson(Map<String, dynamic> json) => RentalUnit(
    id: json['id'] as String?,
    label: json['label'] as String? ?? '',
    strategy: RentalStrategy.fromJson(json['strategy'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'strategy': strategy.toJson(),
  };
}

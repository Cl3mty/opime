import '../investments/investments_models.dart' show generateInvestmentId;

/// Type d'une [BusinessEntity] — module réservé aux coffres-forts
/// professionnels (voir `core/storage/vault_folder_service.dart`'s
/// `VaultKind`).
enum EntityType {
  holding,
  societeCommerciale,
  sci,
  comptePro;

  String get label => switch (this) {
    EntityType.holding => 'Holding',
    EntityType.societeCommerciale => 'Société commerciale',
    EntityType.sci => 'SCI (société civile immobilière)',
    EntityType.comptePro => 'Compte pro',
  };

  static EntityType fromName(String? name) => EntityType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => EntityType.societeCommerciale,
  );
}

/// Une ligne nommée du petit bilan d'une [BusinessEntity] — même forme
/// pour un actif (ex : "Trésorerie", "Immeuble Lyon") ou un passif (ex :
/// "Emprunt bancaire") : juste un libellé et un montant, comme les postes
/// du budget prévisionnel.
class EntityLine {
  final String id;
  final String label;
  final double amount;

  const EntityLine({required this.id, required this.label, required this.amount});

  EntityLine copyWith({String? label, double? amount}) => EntityLine(
    id: id,
    label: label ?? this.label,
    amount: amount ?? this.amount,
  );

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'amount': amount};

  factory EntityLine.fromJson(Map<String, dynamic> json) => EntityLine(
    id: json['id'] as String,
    label: json['label'] as String,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
  );
}

/// Une entité professionnelle (holding, société commerciale, SCI, compte
/// pro) suivie dans un coffre-fort professionnel — voir la doc de tête de
/// `entities_repository.dart` pour le principe général du module :
/// chacune porte son propre petit bilan ([assets]/[liabilities]) et un
/// pourcentage de détention. Sa valeur nette détenue ([ownedNetValue]) est
/// consolidée dans le patrimoine global comme une catégorie de Dashboard à
/// part entière (voir `entities_patrimoine_adapter.dart`'s
/// `buildEntitiesCategory`, qui l'ajoute déjà nette de son propre passif —
/// sans catégorie Passifs miroir, ce serait compter [liabilities] une
/// seconde fois).
class BusinessEntity {
  final String id;
  final String name;
  final EntityType type;

  /// % détenu par l'utilisateur dans cette entité (0-100).
  final double ownershipPercent;
  final List<EntityLine> assets;
  final List<EntityLine> liabilities;
  final String? note;

  const BusinessEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.ownershipPercent,
    this.assets = const [],
    this.liabilities = const [],
    this.note,
  });

  double get grossAssets => assets.fold(0, (sum, a) => sum + a.amount);
  double get grossLiabilities => liabilities.fold(0, (sum, l) => sum + l.amount);

  /// Valeur nette de l'entité elle-même (100 % de son bilan), avant
  /// pondération par [ownershipPercent].
  double get netValue => grossAssets - grossLiabilities;

  /// Part de [netValue] réellement détenue par l'utilisateur — ce que
  /// `entities_screen.dart` additionne pour son total, jamais mélangé au
  /// patrimoine personnel.
  double get ownedNetValue => netValue * ownershipPercent / 100;

  BusinessEntity copyWith({
    String? name,
    EntityType? type,
    double? ownershipPercent,
    List<EntityLine>? assets,
    List<EntityLine>? liabilities,
    Object? note = _missingNote,
  }) => BusinessEntity(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    ownershipPercent: ownershipPercent ?? this.ownershipPercent,
    assets: assets ?? this.assets,
    liabilities: liabilities ?? this.liabilities,
    note: identical(note, _missingNote) ? this.note : note as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'ownershipPercent': ownershipPercent,
    'assets': assets.map((a) => a.toJson()).toList(),
    'liabilities': liabilities.map((l) => l.toJson()).toList(),
    if (note != null) 'note': note,
  };

  factory BusinessEntity.fromJson(Map<String, dynamic> json) => BusinessEntity(
    id: json['id'] as String,
    name: json['name'] as String,
    type: EntityType.fromName(json['type'] as String?),
    ownershipPercent: (json['ownershipPercent'] as num?)?.toDouble() ?? 100,
    assets:
        (json['assets'] as List?)
            ?.map((e) => EntityLine.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    liabilities:
        (json['liabilities'] as List?)
            ?.map((e) => EntityLine.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    note: json['note'] as String?,
  );
}

const _missingNote = Object();

String generateEntityId() => generateInvestmentId('entite');
String generateEntityLineId() => generateInvestmentId('ligne');

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

/// Une entité professionnelle (holding, société commerciale, SCI, compte
/// pro) suivie dans un coffre-fort professionnel — voir la doc de tête de
/// `entities_repository.dart` pour le principe général du module. Une
/// entité n'a pas de bilan qui lui soit propre : elle est juste une
/// identité (nom, type, % de détention) à laquelle de vrais comptes
/// (`InvestmentAccount.entityId`) et passifs (`Liability.entityId`) sont
/// rattachés — voir `entities_patrimoine_adapter.dart`'s
/// `buildEntitiesCategory`, qui calcule la valeur nette d'une entité à
/// partir de CES comptes/passifs (jamais stockée sur `BusinessEntity`
/// elle-même).
///
/// Une entité peut être détenue soit directement par l'utilisateur
/// ([parentEntityId] `null`), soit par une autre entité — typiquement une
/// filiale détenue par son holding ([parentEntityId] renseigné). Dans ce
/// second cas, [ownershipPercent] change de sens : ce n'est plus le %
/// détenu par l'utilisateur mais le % détenu par le parent immédiat. La
/// part réellement diluée jusqu'à l'utilisateur, en remontant toute la
/// chaîne de liens, se calcule via [effectiveOwnershipPercents]/
/// [effectiveOwnedNetValue].
class BusinessEntity {
  final String id;
  final String name;
  final EntityType type;

  /// % détenu — par l'utilisateur si [parentEntityId] est `null`, par
  /// l'entité parente sinon (0-100).
  final double ownershipPercent;

  /// Id de l'entité qui détient celle-ci, ou `null` si elle est détenue
  /// directement par l'utilisateur (entité de tête).
  final String? parentEntityId;
  final String? note;

  const BusinessEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.ownershipPercent,
    this.parentEntityId,
    this.note,
  });

  BusinessEntity copyWith({
    String? name,
    EntityType? type,
    double? ownershipPercent,
    Object? parentEntityId = _missingParentEntityId,
    Object? note = _missingNote,
  }) => BusinessEntity(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    ownershipPercent: ownershipPercent ?? this.ownershipPercent,
    parentEntityId: identical(parentEntityId, _missingParentEntityId)
        ? this.parentEntityId
        : parentEntityId as String?,
    note: identical(note, _missingNote) ? this.note : note as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'ownershipPercent': ownershipPercent,
    if (parentEntityId != null) 'parentEntityId': parentEntityId,
    if (note != null) 'note': note,
  };

  factory BusinessEntity.fromJson(Map<String, dynamic> json) => BusinessEntity(
    id: json['id'] as String,
    name: json['name'] as String,
    type: EntityType.fromName(json['type'] as String?),
    ownershipPercent: (json['ownershipPercent'] as num?)?.toDouble() ?? 100,
    parentEntityId: json['parentEntityId'] as String?,
    note: json['note'] as String?,
  );
}

const _missingNote = Object();
const _missingParentEntityId = Object();

String generateEntityId() => generateInvestmentId('entite');

/// Pour chaque entité, la part effectivement détenue par l'utilisateur en
/// remontant toute la chaîne de [BusinessEntity.parentEntityId] jusqu'à une
/// entité de tête (`parentEntityId == null`) — ex. holding détenu à 80 % par
/// l'utilisateur, lui-même détenant une filiale à 50 % : la filiale vaut
/// 40 % pour l'utilisateur (0.8 × 0.5), pas les 50 % de son seul lien direct
/// ([BusinessEntity.ownershipPercent]).
///
/// Détecte les cycles (une entité ne devrait jamais pouvoir se choisir
/// elle-même ou l'une de ses filles comme parent via l'UI — voir
/// `entities_screen.dart`'s sélecteur "Détenue par" — mais un JSON modifié
/// à la main pourrait en créer un) : une entité prise dans un cycle retombe
/// sur son [BusinessEntity.ownershipPercent] local, comme si elle était de
/// tête, plutôt que de provoquer une récursion infinie.
Map<String, double> effectiveOwnershipPercents(List<BusinessEntity> entities) {
  final byId = {for (final e in entities) e.id: e};

  // Détecte, pour chaque entité, si remonter sa chaîne de parents finit par
  // la recroiser elle-même sans jamais atteindre une entité de tête — un
  // cycle. Fait AVANT toute résolution de pourcentage : traiter une entité
  // cyclique comme si elle était de tête (parent ignoré) une fois pour
  // toutes évite qu'une valeur partiellement calculée au milieu d'un cycle
  // ne pollue le résultat final d'une autre entité du même cycle.
  bool isCyclic(String startId) {
    final visited = <String>{};
    var current = byId[startId];
    while (current != null) {
      if (!visited.add(current.id)) return true;
      final parentId = current.parentEntityId;
      current = parentId == null ? null : byId[parentId];
    }
    return false;
  }

  final cyclicIds = {
    for (final e in entities)
      if (isCyclic(e.id)) e.id,
  };

  final resolved = <String, double>{};
  double resolve(BusinessEntity entity) {
    final cached = resolved[entity.id];
    if (cached != null) return cached;
    final parentId = cyclicIds.contains(entity.id)
        ? null
        : entity.parentEntityId;
    final parent = parentId == null ? null : byId[parentId];
    final value = parent == null
        ? entity.ownershipPercent
        : resolve(parent) * entity.ownershipPercent / 100;
    resolved[entity.id] = value;
    return value;
  }

  for (final entity in entities) {
    resolve(entity);
  }
  return resolved;
}

/// Part de la valeur nette d'une entité (ses comptes/passifs propres, voir
/// `entities_patrimoine_adapter.dart` — PAS un champ de [BusinessEntity])
/// réellement détenue par l'utilisateur une fois toute la chaîne de liens
/// de possession prise en compte — voir [effectiveOwnershipPercents].
/// [netValue] est calculé par l'appelant (somme des comptes/passifs de
/// l'entité), passé ici plutôt que lu depuis [BusinessEntity] elle-même,
/// qui ne porte aucune donnée financière.
double effectiveOwnedNetValue(
  String entityId,
  double netValue,
  Map<String, double> effectivePercents,
) => netValue * (effectivePercents[entityId] ?? 100) / 100;

/// Ids de toutes les entités descendantes de [id] (filles, petites-filles,
/// ...) au sein de [entities] — utilisé pour interdire de choisir l'une
/// d'elles comme parent d'une entité (empêcherait un cycle).
Set<String> descendantEntityIds(String id, List<BusinessEntity> entities) {
  final children = <String, List<String>>{};
  for (final e in entities) {
    final parentId = e.parentEntityId;
    if (parentId != null) (children[parentId] ??= []).add(e.id);
  }
  final result = <String>{};
  void collect(String parentId) {
    for (final childId in children[parentId] ?? const <String>[]) {
      if (result.add(childId)) collect(childId);
    }
  }

  collect(id);
  return result;
}

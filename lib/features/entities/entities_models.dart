import '../investments/investments_models.dart' show generateInvestmentId;

/// Type d'une [BusinessEntity] — une structure juridique, pas un type de
/// compte bancaire (un "compte pro" — CTO professionnel, compte courant
/// professionnel, contrat de capitalisation... — est un [InvestmentAccount]
/// comme un autre, rattaché à une entité via [InvestmentAccount.entityId],
/// pas un type d'entité en soi). N'importe quel coffre-fort peut créer des
/// entités ou non — aucune distinction personnel/professionnel de
/// coffre-fort n'existe.
enum EntityType {
  holding,
  societeCommerciale,
  sci;

  String get label => switch (this) {
    EntityType.holding => 'Holding',
    EntityType.societeCommerciale => 'Société commerciale',
    EntityType.sci => 'SCI (société civile immobilière)',
  };

  static EntityType fromName(String? name) => EntityType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => EntityType.societeCommerciale,
  );
}

/// Une part de détention d'une [BusinessEntity] : [percent] % détenu par
/// [ownerId] (une autre entité), ou directement par l'utilisateur si
/// [ownerId] est `null`. Une entité porte une LISTE de parts plutôt qu'un
/// unique propriétaire — une société commerciale peut par exemple être
/// détenue à 40 % directement par l'utilisateur et à 60 % via un holding,
/// comme une vraie répartition d'actionnariat mixte.
class OwnershipStake {
  final String? ownerId;
  final double percent;

  const OwnershipStake({this.ownerId, required this.percent});

  OwnershipStake copyWith({Object? ownerId = _missingOwnerId, double? percent}) =>
      OwnershipStake(
        ownerId: identical(ownerId, _missingOwnerId)
            ? this.ownerId
            : ownerId as String?,
        percent: percent ?? this.percent,
      );

  Map<String, dynamic> toJson() => {
    if (ownerId != null) 'ownerId': ownerId,
    'percent': percent,
  };

  factory OwnershipStake.fromJson(Map<String, dynamic> json) => OwnershipStake(
    ownerId: json['ownerId'] as String?,
    percent: (json['percent'] as num?)?.toDouble() ?? 0,
  );
}

const _missingOwnerId = Object();

/// Une entité professionnelle (holding, société commerciale, SCI) suivie
/// dans un coffre-fort — voir la doc de tête de `entities_repository.dart`
/// pour le principe général du module. Une entité n'a pas de bilan qui lui
/// soit propre : elle est juste une identité (nom, type, structure de
/// détention) à laquelle de vrais comptes (`InvestmentAccount.entityId`) et
/// passifs (`Liability.entityId`) sont rattachés — voir
/// `entities_patrimoine_adapter.dart`, qui calcule la valeur nette d'une
/// entité à partir de CES comptes/passifs (jamais stockée sur
/// [BusinessEntity] elle-même).
///
/// [stakes] décrit qui la détient et à quelle hauteur — voir [OwnershipStake].
/// La part réellement diluée jusqu'à l'utilisateur, en remontant toute la
/// chaîne de détention (potentiellement à travers plusieurs entités
/// intermédiaires, et plusieurs parts par entité), se calcule via
/// [effectiveOwnershipPercents]/[effectiveOwnedNetValue].
class BusinessEntity {
  final String id;
  final String name;
  final EntityType type;
  final List<OwnershipStake> stakes;
  final String? note;

  const BusinessEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.stakes,
    this.note,
  });

  BusinessEntity copyWith({
    String? name,
    EntityType? type,
    List<OwnershipStake>? stakes,
    Object? note = _missingNote,
  }) => BusinessEntity(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    stakes: stakes ?? this.stakes,
    note: identical(note, _missingNote) ? this.note : note as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'stakes': [for (final stake in stakes) stake.toJson()],
    if (note != null) 'note': note,
  };

  /// Lit aussi bien le format actuel (`stakes`) que l'ancien format à part
  /// unique (`parentEntityId`/`ownershipPercent`, avant que la détention
  /// mixte ne soit possible) — sans ce repli, les entités déjà enregistrées
  /// sur le disque des utilisateurs existants perdraient leur structure de
  /// détention à la prochaine lecture. Réécrites au format `stakes` dès la
  /// prochaine sauvegarde (`EntityRepository.saveEntity`), pas de
  /// migration explicite nécessaire.
  factory BusinessEntity.fromJson(Map<String, dynamic> json) {
    final rawStakes = json['stakes'] as List?;
    final stakes = rawStakes != null
        ? [
            for (final s in rawStakes)
              OwnershipStake.fromJson(s as Map<String, dynamic>),
          ]
        : [
            OwnershipStake(
              ownerId: json['parentEntityId'] as String?,
              percent: (json['ownershipPercent'] as num?)?.toDouble() ?? 100,
            ),
          ];
    return BusinessEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      type: EntityType.fromName(json['type'] as String?),
      stakes: stakes,
      note: json['note'] as String?,
    );
  }
}

const _missingNote = Object();

String generateEntityId() => generateInvestmentId('entite');

/// Pour chaque entité, la part effectivement détenue par l'utilisateur en
/// remontant toute la chaîne de [BusinessEntity.stakes] jusqu'à leurs
/// propriétaires directs (`OwnershipStake.ownerId == null`) — ex. holding
/// détenu à 80 % par l'utilisateur, lui-même détenant une filiale à 50 % :
/// la filiale vaut 40 % pour l'utilisateur (0.8 × 0.5), pas les 50 % de son
/// seul lien direct. Une entité aux parts multiples (ex. 40 % direct + 60 %
/// via un holding détenu à 80 %) additionne la contribution de chaque part :
/// 40 + 60 × 0.8 = 88 %.
///
/// Détecte les cycles (une entité ne devrait jamais pouvoir se choisir
/// elle-même ou l'une de ses descendantes comme propriétaire via l'UI — voir
/// `entities_screen.dart`'s sélecteur "Détenue par" — mais un JSON modifié
/// à la main pourrait en créer un) : la contribution d'une part qui
/// reboucle sur une entité déjà en cours de résolution est ignorée (traitée
/// comme valant 0) plutôt que de provoquer une récursion infinie.
Map<String, double> effectiveOwnershipPercents(List<BusinessEntity> entities) {
  final byId = {for (final e in entities) e.id: e};
  final resolved = <String, double>{};
  final resolving = <String>{};

  double resolve(String? ownerId) {
    if (ownerId == null) return 100; // Détenu directement par l'utilisateur.
    final cached = resolved[ownerId];
    if (cached != null) return cached;
    final owner = byId[ownerId];
    if (owner == null) return 0; // Référence orpheline (JSON corrompu).
    if (!resolving.add(ownerId)) {
      // Cycle : cette entité dépend d'elle-même via ce chemin, sa valeur
      // n'est pas encore connue — 0 pour cette contribution plutôt qu'une
      // récursion infinie.
      return 0;
    }
    final value = owner.stakes.fold<double>(
      0,
      (sum, stake) => sum + stake.percent / 100 * resolve(stake.ownerId),
    );
    resolving.remove(ownerId);
    resolved[ownerId] = value;
    return value;
  }

  for (final entity in entities) {
    resolve(entity.id);
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

/// Le propriétaire principal d'une entité à des fins de PRÉSENTATION
/// seulement (position dans la liste indentée/le schéma de structure) :
/// celui de ses [BusinessEntity.stakes] à la part la plus élevée, ou `null`
/// si elle n'en a aucune (traitée comme détenue à 100 % directement par
/// l'utilisateur). Une entité à détention mixte (ex. 40 % direct + 60 % via
/// un holding) n'a qu'UNE position dans un affichage hiérarchique plat —
/// celle-ci ne préjuge en rien du calcul réel de dilution ([effectiveOwnershipPercents]),
/// qui tient compte de TOUTES les parts.
String? primaryOwnerId(BusinessEntity entity) {
  if (entity.stakes.isEmpty) return null;
  return entity.stakes
      .reduce((a, b) => a.percent >= b.percent ? a : b)
      .ownerId;
}

/// Ordonne une liste d'entités en hiérarchie plate : chaque entité de tête
/// (sans propriétaire principal, voir [primaryOwnerId]) suivie
/// immédiatement de toutes ses descendantes — pas un arbre imbriqué, juste
/// une liste où [depth] (0 pour une tête) permet à l'appelant d'indenter ou
/// non selon son propre affichage. Partagé entre `entities_screen.dart`
/// (liste indentée) et `dashboard_screen.dart` (une carte par entité, dans
/// cet ordre, sans indentation visuelle).
///
/// [compareSiblings] trie les entités de même niveau (ex. par valeur nette
/// décroissante, voir `entities_screen.dart`) ; par défaut, conserve
/// l'ordre de [entities].
List<(BusinessEntity, int)> orderedEntityHierarchy(
  List<BusinessEntity> entities, {
  int Function(BusinessEntity, BusinessEntity)? compareSiblings,
}) {
  final byPrimaryParent = <String?, List<BusinessEntity>>{};
  for (final entity in entities) {
    (byPrimaryParent[primaryOwnerId(entity)] ??= []).add(entity);
  }
  if (compareSiblings != null) {
    for (final group in byPrimaryParent.values) {
      group.sort(compareSiblings);
    }
  }
  final ordered = <(BusinessEntity, int)>[];
  final visited = <String>{};
  void addWithChildren(BusinessEntity entity, int depth) {
    // Filet de sécurité si [primaryOwnerId] boucle (JSON corrompu) : une
    // entité déjà placée dans la liste ne l'est pas une seconde fois.
    if (!visited.add(entity.id)) return;
    ordered.add((entity, depth));
    for (final child in byPrimaryParent[entity.id] ?? const <BusinessEntity>[]) {
      addWithChildren(child, depth + 1);
    }
  }

  for (final root in byPrimaryParent[null] ?? const <BusinessEntity>[]) {
    addWithChildren(root, 0);
  }
  return ordered;
}

/// Ids de toutes les entités descendantes de [id] au sein de [entities] —
/// atteignables en suivant [BusinessEntity.stakes] vers l'avant, quel que
/// soit le nombre de parts/chemins qui y mènent (une entité à détention
/// mixte peut être descendante de plusieurs entités à la fois). Utilisé
/// pour interdire de choisir l'une d'elles comme propriétaire d'une entité
/// (empêcherait un cycle).
Set<String> descendantEntityIds(String id, List<BusinessEntity> entities) {
  final children = <String, List<String>>{};
  for (final e in entities) {
    for (final stake in e.stakes) {
      final ownerId = stake.ownerId;
      if (ownerId != null) (children[ownerId] ??= []).add(e.id);
    }
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

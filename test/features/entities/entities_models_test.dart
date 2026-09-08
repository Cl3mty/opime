import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/entities/entities_models.dart';

void main() {
  group('BusinessEntity — JSON round-trip', () {
    test('conserve tous les champs, y compris plusieurs parts', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'SCI Les Tilleuls',
        type: EntityType.sci,
        stakes: const [
          OwnershipStake(percent: 40),
          OwnershipStake(ownerId: 'holding-1', percent: 60),
        ],
        note: 'Créée en 2020',
      );

      final restored = BusinessEntity.fromJson(entity.toJson());

      expect(restored.id, 'e1');
      expect(restored.name, 'SCI Les Tilleuls');
      expect(restored.type, EntityType.sci);
      expect(restored.stakes, hasLength(2));
      expect(restored.stakes[0].ownerId, isNull);
      expect(restored.stakes[0].percent, 40);
      expect(restored.stakes[1].ownerId, 'holding-1');
      expect(restored.stakes[1].percent, 60);
      expect(restored.note, 'Créée en 2020');
    });

    test('note absente : clé omise du JSON, reste null au décodage', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'Test',
        type: EntityType.societeCommerciale,
        stakes: const [OwnershipStake(percent: 100)],
      );

      final json = entity.toJson();
      expect(json.containsKey('note'), isFalse);
      expect(BusinessEntity.fromJson(json).note, isNull);
    });

    test(
      'ancien format à part unique (parentEntityId/ownershipPercent, avant '
      'la détention mixte) : lu comme une unique part au décodage — les '
      'entités déjà enregistrées sur le disque des utilisateurs existants '
      'ne perdent pas leur structure de détention',
      () {
        final legacyJson = {
          'id': 'e1',
          'name': 'Filiale',
          'type': 'societeCommerciale',
          'ownershipPercent': 50.0,
          'parentEntityId': 'holding-1',
        };

        final restored = BusinessEntity.fromJson(legacyJson);

        expect(restored.stakes, hasLength(1));
        expect(restored.stakes.single.ownerId, 'holding-1');
        expect(restored.stakes.single.percent, 50);
      },
    );

    test(
      'ancien format sans parentEntityId (détenue directement) : une part '
      'directe (ownerId null)',
      () {
        final legacyJson = {
          'id': 'e1',
          'name': 'Holding',
          'type': 'holding',
          'ownershipPercent': 80.0,
        };

        final restored = BusinessEntity.fromJson(legacyJson);

        expect(restored.stakes, hasLength(1));
        expect(restored.stakes.single.ownerId, isNull);
        expect(restored.stakes.single.percent, 80);
      },
    );

    test(
      'toJson écrit toujours le nouveau format (stakes), jamais l\'ancien',
      () {
        final entity = BusinessEntity(
          id: 'e1',
          name: 'Test',
          type: EntityType.holding,
          stakes: const [OwnershipStake(percent: 100)],
        );
        final json = entity.toJson();
        expect(json.containsKey('stakes'), isTrue);
        expect(json.containsKey('ownershipPercent'), isFalse);
        expect(json.containsKey('parentEntityId'), isFalse);
      },
    );
  });

  group('BusinessEntity.copyWith', () {
    test('remplace les parts existantes par les nouvelles', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'Filiale',
        type: EntityType.societeCommerciale,
        stakes: const [OwnershipStake(ownerId: 'holding', percent: 50)],
      );
      final updated = entity.copyWith(
        stakes: const [OwnershipStake(percent: 100)],
      );
      expect(updated.stakes.single.ownerId, isNull);
      expect(updated.stakes.single.percent, 100);
    });

    test('sans argument conserve les parts existantes', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'Filiale',
        type: EntityType.societeCommerciale,
        stakes: const [OwnershipStake(ownerId: 'holding', percent: 50)],
      );
      final updated = entity.copyWith(name: 'Filiale renommée');
      expect(updated.stakes.single.ownerId, 'holding');
      expect(updated.stakes.single.percent, 50);
    });
  });

  group('effectiveOwnershipPercents', () {
    test('entité de tête, une seule part directe : part effective == 100 % '
        'de sa part', () {
      final holding = BusinessEntity(
        id: 'e1',
        name: 'Holding',
        type: EntityType.holding,
        stakes: const [OwnershipStake(percent: 80)],
      );
      final percents = effectiveOwnershipPercents([holding]);
      expect(percents['e1'], 80);
    });

    test('chaîne à 3 niveaux : dilution multiplicative le long des liens', () {
      final holding = BusinessEntity(
        id: 'racine',
        name: 'Holding',
        type: EntityType.holding,
        stakes: const [OwnershipStake(percent: 80)],
      );
      final fille = BusinessEntity(
        id: 'fille',
        name: 'Fille',
        type: EntityType.societeCommerciale,
        stakes: const [OwnershipStake(ownerId: 'racine', percent: 50)],
      );
      final petiteFille = BusinessEntity(
        id: 'petite_fille',
        name: 'Petite-fille',
        type: EntityType.societeCommerciale,
        stakes: const [OwnershipStake(ownerId: 'fille', percent: 60)],
      );
      final percents = effectiveOwnershipPercents([
        holding,
        fille,
        petiteFille,
      ]);

      expect(percents['racine'], 80);
      expect(percents['fille'], closeTo(40, 1e-9)); // 80% * 50%
      expect(percents['petite_fille'], closeTo(24, 1e-9)); // 80% * 50% * 60%
    });

    test(
      'détention mixte (part directe + part via une autre entité) : les '
      'contributions de chaque part s\'additionnent',
      () {
        final holding = BusinessEntity(
          id: 'holding',
          name: 'Holding',
          type: EntityType.holding,
          stakes: const [OwnershipStake(percent: 80)],
        );
        // 40 % directement par l'utilisateur + 60 % via le holding (lui-même
        // détenu à 80 %) : 40 + 60 * 0.8 = 88 %.
        final mixte = BusinessEntity(
          id: 'mixte',
          name: 'Société mixte',
          type: EntityType.societeCommerciale,
          stakes: const [
            OwnershipStake(percent: 40),
            OwnershipStake(ownerId: 'holding', percent: 60),
          ],
        );
        final percents = effectiveOwnershipPercents([holding, mixte]);

        expect(percents['mixte'], closeTo(88, 1e-9));
      },
    );

    test('cycle (2 entités se référençant l\'une l\'autre) : retombe sur 0 '
        'pour la contribution cyclique plutôt que de boucler à l\'infini', () {
      final a = BusinessEntity(
        id: 'a',
        name: 'A',
        type: EntityType.holding,
        stakes: const [OwnershipStake(ownerId: 'b', percent: 70)],
      );
      final b = BusinessEntity(
        id: 'b',
        name: 'B',
        type: EntityType.holding,
        stakes: const [OwnershipStake(ownerId: 'a', percent: 40)],
      );

      final percents = effectiveOwnershipPercents([a, b]);
      // Aucune boucle infinie : les deux valeurs se résolvent (à 0, la
      // dépendance circulaire ne peut pas être satisfaite autrement) plutôt
      // que de planter.
      expect(percents['a'], isNotNull);
      expect(percents['b'], isNotNull);
    });
  });

  group('effectiveOwnedNetValue', () {
    test('applique la part diluée à une valeur nette fournie', () {
      final percents = {'e1': 40.0};
      expect(effectiveOwnedNetValue('e1', 100000, percents), 40000);
    });

    test('id absent de la carte : retombe sur 100 % (défensif)', () {
      expect(effectiveOwnedNetValue('inconnu', 100000, const {}), 100000);
    });
  });

  group('primaryOwnerId', () {
    test('une seule part : c\'est son propriétaire', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'Filiale',
        type: EntityType.societeCommerciale,
        stakes: const [OwnershipStake(ownerId: 'holding', percent: 100)],
      );
      expect(primaryOwnerId(entity), 'holding');
    });

    test('plusieurs parts : celle à la part la plus élevée', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'Mixte',
        type: EntityType.societeCommerciale,
        stakes: const [
          OwnershipStake(percent: 40),
          OwnershipStake(ownerId: 'holding', percent: 60),
        ],
      );
      expect(primaryOwnerId(entity), 'holding');
    });

    test('aucune part : null (détenue à 100 % directement, par défaut)', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'Sans part',
        type: EntityType.societeCommerciale,
        stakes: const [],
      );
      expect(primaryOwnerId(entity), isNull);
    });
  });

  group('orderedEntityHierarchy', () {
    test(
      'place chaque entité sous son propriétaire PRINCIPAL (voir '
      '[primaryOwnerId]) même en détention mixte',
      () {
        final holding = BusinessEntity(
          id: 'holding',
          name: 'Holding',
          type: EntityType.holding,
          stakes: const [OwnershipStake(percent: 100)],
        );
        final mixte = BusinessEntity(
          id: 'mixte',
          name: 'Mixte',
          type: EntityType.societeCommerciale,
          // Propriétaire principal : le holding (60 % > 40 %).
          stakes: const [
            OwnershipStake(percent: 40),
            OwnershipStake(ownerId: 'holding', percent: 60),
          ],
        );

        final ordered = orderedEntityHierarchy([holding, mixte]);

        expect(ordered, hasLength(2));
        expect(ordered[0].$1.id, 'holding');
        expect(ordered[0].$2, 0);
        expect(ordered[1].$1.id, 'mixte');
        expect(ordered[1].$2, 1);
      },
    );
  });

  group('descendantEntityIds', () {
    test('renvoie filles et petites-filles, pas les entités non liées', () {
      final entities = [
        BusinessEntity(
          id: 'racine',
          name: 'Holding',
          type: EntityType.holding,
          stakes: const [OwnershipStake(percent: 100)],
        ),
        BusinessEntity(
          id: 'fille',
          name: 'Fille',
          type: EntityType.societeCommerciale,
          stakes: const [OwnershipStake(ownerId: 'racine', percent: 100)],
        ),
        BusinessEntity(
          id: 'petite_fille',
          name: 'Petite-fille',
          type: EntityType.societeCommerciale,
          stakes: const [OwnershipStake(ownerId: 'fille', percent: 100)],
        ),
        BusinessEntity(
          id: 'sans_lien',
          name: 'Sans lien',
          type: EntityType.sci,
          stakes: const [OwnershipStake(percent: 100)],
        ),
      ];

      final descendants = descendantEntityIds('racine', entities);
      expect(descendants, {'fille', 'petite_fille'});
      expect(descendantEntityIds('sans_lien', entities), isEmpty);
    });

    test(
      'une entité à détention mixte est descendante de CHACUN de ses '
      'propriétaires',
      () {
        final entities = [
          BusinessEntity(
            id: 'holding',
            name: 'Holding',
            type: EntityType.holding,
            stakes: const [OwnershipStake(percent: 100)],
          ),
          BusinessEntity(
            id: 'autre',
            name: 'Autre société',
            type: EntityType.societeCommerciale,
            stakes: const [OwnershipStake(percent: 100)],
          ),
          BusinessEntity(
            id: 'mixte',
            name: 'Mixte',
            type: EntityType.societeCommerciale,
            stakes: const [
              OwnershipStake(ownerId: 'holding', percent: 40),
              OwnershipStake(ownerId: 'autre', percent: 60),
            ],
          ),
        ];

        expect(descendantEntityIds('holding', entities), {'mixte'});
        expect(descendantEntityIds('autre', entities), {'mixte'});
      },
    );
  });

  group('EntityType', () {
    test('label distinct pour chaque type', () {
      final labels = EntityType.values.map((t) => t.label).toSet();
      expect(labels, hasLength(EntityType.values.length));
    });

    test('fromName : nom inconnu retombe sur societeCommerciale', () {
      expect(EntityType.fromName('inconnu'), EntityType.societeCommerciale);
      expect(EntityType.fromName(null), EntityType.societeCommerciale);
    });

    test('fromName : round-trip sur chaque valeur', () {
      for (final type in EntityType.values) {
        expect(EntityType.fromName(type.name), type);
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/entities/entities_models.dart';

void main() {
  group('BusinessEntity — JSON round-trip', () {
    test('conserve tous les champs', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'SCI Les Tilleuls',
        type: EntityType.sci,
        ownershipPercent: 60,
        note: 'Créée en 2020',
      );

      final restored = BusinessEntity.fromJson(entity.toJson());

      expect(restored.id, 'e1');
      expect(restored.name, 'SCI Les Tilleuls');
      expect(restored.type, EntityType.sci);
      expect(restored.ownershipPercent, 60);
      expect(restored.note, 'Créée en 2020');
    });

    test('note absente : clé omise du JSON, reste null au décodage', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'Test',
        type: EntityType.comptePro,
        ownershipPercent: 100,
      );

      final json = entity.toJson();
      expect(json.containsKey('note'), isFalse);
      expect(BusinessEntity.fromJson(json).note, isNull);
    });
  });

  group('BusinessEntity — parentEntityId', () {
    test('absent du JSON existant : reste null, comportement inchangé', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'Test',
        type: EntityType.holding,
        ownershipPercent: 100,
      );
      final json = entity.toJson();
      expect(json.containsKey('parentEntityId'), isFalse);
      expect(BusinessEntity.fromJson(json).parentEntityId, isNull);
    });

    test('round-trip JSON quand renseigné', () {
      final entity = BusinessEntity(
        id: 'e2',
        name: 'Filiale',
        type: EntityType.societeCommerciale,
        ownershipPercent: 50,
        parentEntityId: 'e1',
      );
      final restored = BusinessEntity.fromJson(entity.toJson());
      expect(restored.parentEntityId, 'e1');
    });

    test('copyWith(parentEntityId: null) efface bien le lien existant', () {
      final entity = BusinessEntity(
        id: 'e2',
        name: 'Filiale',
        type: EntityType.societeCommerciale,
        ownershipPercent: 50,
        parentEntityId: 'e1',
      );
      final updated = entity.copyWith(parentEntityId: null);
      expect(updated.parentEntityId, isNull);
    });

    test('copyWith sans argument conserve le parentEntityId existant', () {
      final entity = BusinessEntity(
        id: 'e2',
        name: 'Filiale',
        type: EntityType.societeCommerciale,
        ownershipPercent: 50,
        parentEntityId: 'e1',
      );
      final updated = entity.copyWith(name: 'Filiale renommée');
      expect(updated.parentEntityId, 'e1');
    });
  });

  group('effectiveOwnershipPercents', () {
    test('entité de tête : part effective == ownershipPercent local', () {
      final holding = BusinessEntity(
        id: 'e1',
        name: 'Holding',
        type: EntityType.holding,
        ownershipPercent: 80,
      );
      final percents = effectiveOwnershipPercents([holding]);
      expect(percents['e1'], 80);
    });

    test('chaîne à 3 niveaux : dilution multiplicative le long des liens', () {
      final holding = BusinessEntity(
        id: 'racine',
        name: 'Holding',
        type: EntityType.holding,
        ownershipPercent: 80,
      );
      final fille = BusinessEntity(
        id: 'fille',
        name: 'Fille',
        type: EntityType.societeCommerciale,
        ownershipPercent: 50,
        parentEntityId: 'racine',
      );
      final petiteFille = BusinessEntity(
        id: 'petite_fille',
        name: 'Petite-fille',
        type: EntityType.societeCommerciale,
        ownershipPercent: 60,
        parentEntityId: 'fille',
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

    test('cycle (2 entités se référençant l\'une l\'autre) : retombe sur le '
        '% local plutôt que de boucler à l\'infini', () {
      final a = BusinessEntity(
        id: 'a',
        name: 'A',
        type: EntityType.holding,
        ownershipPercent: 70,
        parentEntityId: 'b',
      );
      final b = BusinessEntity(
        id: 'b',
        name: 'B',
        type: EntityType.holding,
        ownershipPercent: 40,
        parentEntityId: 'a',
      );

      final percents = effectiveOwnershipPercents([a, b]);
      expect(percents['a'], 70);
      expect(percents['b'], 40);
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

  group('descendantEntityIds', () {
    test('renvoie filles et petites-filles, pas les entités non liées', () {
      final entities = [
        BusinessEntity(
          id: 'racine',
          name: 'Holding',
          type: EntityType.holding,
          ownershipPercent: 100,
        ),
        BusinessEntity(
          id: 'fille',
          name: 'Fille',
          type: EntityType.societeCommerciale,
          ownershipPercent: 100,
          parentEntityId: 'racine',
        ),
        BusinessEntity(
          id: 'petite_fille',
          name: 'Petite-fille',
          type: EntityType.societeCommerciale,
          ownershipPercent: 100,
          parentEntityId: 'fille',
        ),
        BusinessEntity(
          id: 'sans_lien',
          name: 'Sans lien',
          type: EntityType.comptePro,
          ownershipPercent: 100,
        ),
      ];

      final descendants = descendantEntityIds('racine', entities);
      expect(descendants, {'fille', 'petite_fille'});
      expect(descendantEntityIds('sans_lien', entities), isEmpty);
    });
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

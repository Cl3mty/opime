import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/entities/entities_models.dart';

void main() {
  group('EntityLine', () {
    test('toJson/fromJson round-trip', () {
      final line = EntityLine(id: 'l1', label: 'Trésorerie', amount: 1234.5);
      final restored = EntityLine.fromJson(line.toJson());

      expect(restored.id, 'l1');
      expect(restored.label, 'Trésorerie');
      expect(restored.amount, 1234.5);
    });

    test('copyWith ne change que le champ demandé', () {
      final line = EntityLine(id: 'l1', label: 'Trésorerie', amount: 100);
      final updated = line.copyWith(amount: 200);

      expect(updated.id, 'l1');
      expect(updated.label, 'Trésorerie');
      expect(updated.amount, 200);
    });
  });

  group('BusinessEntity — netValue/ownedNetValue', () {
    BusinessEntity build({
      double ownershipPercent = 100,
      List<EntityLine> assets = const [],
      List<EntityLine> liabilities = const [],
    }) => BusinessEntity(
      id: 'e1',
      name: 'Test',
      type: EntityType.holding,
      ownershipPercent: ownershipPercent,
      assets: assets,
      liabilities: liabilities,
    );

    test('cas standard : actifs - passifs, pondéré par le % détenu', () {
      final entity = build(
        ownershipPercent: 60,
        assets: [const EntityLine(id: 'a', label: 'Immeuble', amount: 200000)],
        liabilities: [const EntityLine(id: 'l', label: 'Emprunt', amount: 50000)],
      );

      expect(entity.grossAssets, 200000);
      expect(entity.grossLiabilities, 50000);
      expect(entity.netValue, 150000);
      expect(entity.ownedNetValue, 90000);
    });

    test('100% détenu : ownedNetValue == netValue', () {
      final entity = build(
        ownershipPercent: 100,
        assets: [const EntityLine(id: 'a', label: 'Trésorerie', amount: 10000)],
      );

      expect(entity.ownedNetValue, entity.netValue);
      expect(entity.ownedNetValue, 10000);
    });

    test('sans aucune ligne : valeur nette nulle', () {
      final entity = build();
      expect(entity.netValue, 0);
      expect(entity.ownedNetValue, 0);
    });

    test('passifs > actifs : valeur nette négative', () {
      final entity = build(
        ownershipPercent: 50,
        assets: [const EntityLine(id: 'a', label: 'Trésorerie', amount: 10000)],
        liabilities: [const EntityLine(id: 'l', label: 'Emprunt', amount: 30000)],
      );

      expect(entity.netValue, -20000);
      expect(entity.ownedNetValue, -10000);
    });
  });

  group('BusinessEntity — JSON round-trip', () {
    test('conserve tous les champs, y compris les lignes', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'SCI Les Tilleuls',
        type: EntityType.sci,
        ownershipPercent: 60,
        assets: [const EntityLine(id: 'a', label: 'Immeuble', amount: 200000)],
        liabilities: [const EntityLine(id: 'l', label: 'Emprunt', amount: 50000)],
        note: 'Créée en 2020',
      );

      final restored = BusinessEntity.fromJson(entity.toJson());

      expect(restored.id, 'e1');
      expect(restored.name, 'SCI Les Tilleuls');
      expect(restored.type, EntityType.sci);
      expect(restored.ownershipPercent, 60);
      expect(restored.assets.single.label, 'Immeuble');
      expect(restored.liabilities.single.label, 'Emprunt');
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

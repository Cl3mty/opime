import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/entities/entities_models.dart';
import 'package:opime/features/entities/entities_patrimoine_adapter.dart';

void main() {
  group('buildEntitiesCategory', () {
    test('une ligne par entité, valeur = ownedNetValue (jamais netValue '
        'brut)', () {
      final holding = BusinessEntity(
        id: 'e1',
        name: 'Holding Petiot',
        type: EntityType.holding,
        ownershipPercent: 100,
        assets: const [EntityLine(id: 'a1', label: 'Trésorerie', amount: 50000)],
      );
      final sci = BusinessEntity(
        id: 'e2',
        name: 'SCI Les Tilleuls',
        type: EntityType.sci,
        ownershipPercent: 60,
        assets: const [
          EntityLine(id: 'a2', label: 'Immeuble', amount: 300000),
        ],
        liabilities: const [
          EntityLine(id: 'l1', label: 'Emprunt', amount: 100000),
        ],
      );
      // SCI : netValue = 300000 - 100000 = 200000, ownedNetValue = 60 %.
      final category = buildEntitiesCategory([holding, sci]);

      expect(category.id, kEntitiesCategoryId);
      expect(category.accounts, hasLength(2));

      final holdingLine = category.accounts.firstWhere((a) => a.id == 'e1');
      expect(holdingLine.valeur, 50000);
      expect(holdingLine.name, 'Holding Petiot');
      expect(holdingLine.subtitle, EntityType.holding.label);

      final sciLine = category.accounts.firstWhere((a) => a.id == 'e2');
      expect(sciLine.valeur, closeTo(120000, 1e-9)); // 200000 * 60 %
    });

    test('montantPatrimoine = somme des ownedNetValue, sans passifs miroir '
        '(déjà nettés)', () {
      final entities = [
        BusinessEntity(
          id: 'e1',
          name: 'A',
          type: EntityType.societeCommerciale,
          ownershipPercent: 100,
          assets: const [EntityLine(id: 'a1', label: 'Actif', amount: 10000)],
        ),
        BusinessEntity(
          id: 'e2',
          name: 'B',
          type: EntityType.comptePro,
          ownershipPercent: 50,
          assets: const [EntityLine(id: 'a2', label: 'Actif', amount: 20000)],
        ),
      ];
      final category = buildEntitiesCategory(entities);

      // 10000 (100 %) + 20000 * 50 % = 10000 + 10000 = 20000.
      expect(category.montantPatrimoine, closeTo(20000, 1e-9));
      expect(category.montant, closeTo(20000, 1e-9));
    });

    test('liste vide : catégorie vide, montant nul', () {
      final category = buildEntitiesCategory(const []);
      expect(category.accounts, isEmpty);
      expect(category.montantPatrimoine, 0);
    });

    test('aucune ligne n\'a de PRU/quantité ni d\'historique de période — '
        'pas de données pour ça', () {
      final entity = BusinessEntity(
        id: 'e1',
        name: 'A',
        type: EntityType.holding,
        ownershipPercent: 100,
        assets: const [EntityLine(id: 'a1', label: 'Actif', amount: 10000)],
      );
      final line = buildEntitiesCategory([entity]).accounts.single;

      expect(line.pru, isNull);
      expect(line.quantite, isNull);
      expect(line.periodChangeFor, isNull);
      expect(line.periodPnlFor, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/entities/entities_models.dart';
import 'package:opime/features/entities/entities_patrimoine_adapter.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';

void main() {
  InvestmentAccount accountWithValue(
    String entityId,
    double value, {
    String? id,
  }) => InvestmentAccount(
    id: id,
    assetClass: AssetClass.epargne,
    name: 'Compte',
    investments: [
      Investment(
        isin: 'FR0000000000',
        label: 'Position',
        // Pas de `lastPrice` : `displayValue` retombe sur `investedAmount`
        // (quantité × prix unitaire de cet unique achat), plus simple à
        // maîtriser dans un test qu'une valorisation de marché avec FX.
        transactions: [
          Transaction(date: DateTime(2024, 1, 1), isBuy: true, quantity: 1, unitPrice: value),
        ],
      ),
    ],
    entityId: entityId,
  );

  group('entityNetValue', () {
    test('somme les comptes, retranche les passifs, filtrés par entityId', () {
      final accounts = [
        accountWithValue('e1', 50000, id: 'a1'),
        accountWithValue('e2', 10000, id: 'a2'), // autre entité, ignoré
      ];
      final liabilities = [
        Liability(
          type: LiabilityType.creditAutre,
          name: 'Dette',
          montantEmprunte: 20000,
          tauxInteret: 0,
          nbrEcheances: 1,
          dateDebut: DateTime(2024, 1, 1),
          entityId: 'e1',
        ),
      ];

      expect(
        entityNetValue('e1', accounts, liabilities),
        closeTo(50000 - liabilities.first.remainingBalance, 1e-6),
      );
    });

    test('aucun compte/passif pour cette entité : 0', () {
      expect(entityNetValue('inconnu', const [], const []), 0);
    });
  });

  group('buildEntitiesCategory', () {
    test('une ligne par entité, valeur = part diluée de entityNetValue', () {
      final holding = BusinessEntity(
        id: 'e1',
        name: 'Holding Petiot',
        type: EntityType.holding,
        ownershipPercent: 100,
      );
      final sci = BusinessEntity(
        id: 'e2',
        name: 'SCI Les Tilleuls',
        type: EntityType.sci,
        ownershipPercent: 60,
      );
      final accounts = [
        accountWithValue('e1', 50000, id: 'a1'),
        accountWithValue('e2', 200000, id: 'a2'),
      ];
      final category = buildEntitiesCategory([holding, sci], accounts, const []);

      expect(category.id, kEntitiesCategoryId);
      expect(category.accounts, hasLength(2));

      final holdingLine = category.accounts.firstWhere((a) => a.id == 'e1');
      expect(holdingLine.valeur, 50000);
      expect(holdingLine.name, 'Holding Petiot');
      expect(holdingLine.subtitle, EntityType.holding.label);

      final sciLine = category.accounts.firstWhere((a) => a.id == 'e2');
      expect(sciLine.valeur, closeTo(120000, 1e-6)); // 200000 * 60 %
    });

    test('filiale liée à un holding : valorisée à la part diluée jusqu\'à '
        'l\'utilisateur, pas juste son % de lien local', () {
      final holding = BusinessEntity(
        id: 'holding',
        name: 'Holding',
        type: EntityType.holding,
        ownershipPercent: 80, // 80 % détenu par l'utilisateur.
      );
      final filiale = BusinessEntity(
        id: 'filiale',
        name: 'Filiale',
        type: EntityType.societeCommerciale,
        ownershipPercent: 50, // 50 % détenu par le holding.
        parentEntityId: 'holding',
      );
      final accounts = [
        accountWithValue('holding', 50000, id: 'a1'),
        accountWithValue('filiale', 100000, id: 'a2'),
      ];
      final category = buildEntitiesCategory([holding, filiale], accounts, const []);

      final holdingLine = category.accounts.firstWhere((a) => a.id == 'holding');
      expect(holdingLine.valeur, closeTo(40000, 1e-6)); // 50000 * 80 %

      final filialeLine = category.accounts.firstWhere((a) => a.id == 'filiale');
      // Part réellement diluée : 100000 * 80 % * 50 % = 40000 — PAS
      // 100000 * 50 % = 50000 (ce que donnerait le seul % de lien local).
      expect(filialeLine.valeur, closeTo(40000, 1e-6));
    });

    test('liste vide : catégorie vide, montant nul', () {
      final category = buildEntitiesCategory(const [], const [], const []);
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
      );
      final accounts = [accountWithValue('e1', 10000, id: 'a1')];
      final line = buildEntitiesCategory([entity], accounts, const []).accounts.single;

      expect(line.pru, isNull);
      expect(line.quantite, isNull);
      expect(line.periodChangeFor, isNull);
      expect(line.periodPnlFor, isNull);
    });
  });
}

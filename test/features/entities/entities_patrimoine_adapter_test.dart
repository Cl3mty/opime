import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/entities/entities_models.dart';
import 'package:opime/features/entities/entities_patrimoine_adapter.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/yahoo_finance_client.dart'
    show PricePoint;
import 'package:opime/features/liabilities/liabilities_models.dart';

const _noPriceHistories = <String, List<PricePoint>>{};
const _vaultPath = '/vault';

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

  group('buildEntityDashboardSections', () {
    test(
      'une section par entité, dans l\'ordre hiérarchique, avec sa propre '
      'valeur nette et sa part diluée',
      () {
        final holding = BusinessEntity(
          id: 'e1',
          name: 'Holding Petiot',
          type: EntityType.holding,
          stakes: const [OwnershipStake(percent: 100)],
        );
        final sci = BusinessEntity(
          id: 'e2',
          name: 'SCI Les Tilleuls',
          type: EntityType.sci,
          stakes: const [OwnershipStake(percent: 60)],
        );
        final accounts = [
          accountWithValue('e1', 50000, id: 'a1'),
          accountWithValue('e2', 200000, id: 'a2'),
        ];
        final sections = buildEntityDashboardSections(
          [holding, sci],
          accounts,
          const [],
          _noPriceHistories,
          _vaultPath,
        );

        expect(sections, hasLength(2));

        final holdingSection = sections.firstWhere(
          (s) => s.entity.id == 'e1',
        );
        expect(holdingSection.netValue, 50000);
        expect(holdingSection.effectivePercent, 100);
        expect(holdingSection.entity.name, 'Holding Petiot');
        expect(holdingSection.entitiesById, hasLength(2));

        final sciSection = sections.firstWhere((s) => s.entity.id == 'e2');
        expect(sciSection.netValue, 200000);
        expect(sciSection.effectivePercent, 60);
      },
    );

    test(
      'filiale liée à un holding : effectivePercent reflète la dilution '
      'jusqu\'à l\'utilisateur, netValue reste sa propre valeur non diluée',
      () {
        final holding = BusinessEntity(
          id: 'holding',
          name: 'Holding',
          type: EntityType.holding,
          // 80 % détenu par l'utilisateur.
          stakes: const [OwnershipStake(percent: 80)],
        );
        final filiale = BusinessEntity(
          id: 'filiale',
          name: 'Filiale',
          type: EntityType.societeCommerciale,
          // 50 % détenu par le holding.
          stakes: const [OwnershipStake(ownerId: 'holding', percent: 50)],
        );
        final accounts = [
          accountWithValue('holding', 50000, id: 'a1'),
          accountWithValue('filiale', 100000, id: 'a2'),
        ];
        final sections = buildEntityDashboardSections(
          [holding, filiale],
          accounts,
          const [],
          _noPriceHistories,
          _vaultPath,
        );

        final filialeSection = sections.firstWhere(
          (s) => s.entity.id == 'filiale',
        );
        expect(filialeSection.netValue, 100000); // sa propre valeur, non diluée.
        // Part réellement diluée : 80 % * 50 % = 40 % — PAS 50 % (le seul %
        // de lien local vers le holding).
        expect(filialeSection.effectivePercent, closeTo(40, 1e-6));
        expect(filialeSection.entitiesById['holding']?.name, 'Holding');
      },
    );

    test('liste vide : aucune section', () {
      expect(
        buildEntityDashboardSections(
          const [],
          const [],
          const [],
          _noPriceHistories,
          _vaultPath,
        ),
        isEmpty,
      );
    });

    test(
      'avoirs/dettes d\'une section ne portent que les comptes/passifs de '
      'CETTE entité, pas ceux d\'une autre',
      () {
        final e1 = BusinessEntity(
          id: 'e1',
          name: 'A',
          type: EntityType.holding,
          stakes: const [OwnershipStake(percent: 100)],
        );
        final e2 = BusinessEntity(
          id: 'e2',
          name: 'B',
          type: EntityType.sci,
          stakes: const [OwnershipStake(percent: 100)],
        );
        final accounts = [
          accountWithValue('e1', 10000, id: 'a1'),
          accountWithValue('e2', 20000, id: 'a2'),
        ];
        final sections = buildEntityDashboardSections(
          [e1, e2],
          accounts,
          const [],
          _noPriceHistories,
          _vaultPath,
        );

        final e1Section = sections.firstWhere((s) => s.entity.id == 'e1');
        final allAccountIds = [
          for (final category in e1Section.avoirsByAccount)
            for (final account in category.accounts) account.id,
        ];
        expect(allAccountIds, ['a1']);
      },
    );
  });
}

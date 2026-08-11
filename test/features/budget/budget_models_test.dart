import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/budget/budget_models.dart';

void main() {
  group('BudgetItem', () {
    test('round-trip JSON', () {
      final item = BudgetItem(id: 'abc', name: 'Salaire', amount: 2500.5);
      final restored = BudgetItem.fromJson(item.toJson());
      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.amount, item.amount);
    });

    test(
      'fromJson applique des valeurs par défaut sur des champs manquants',
      () {
        final item = BudgetItem.fromJson({'id': 'x'});
        expect(item.name, '');
        expect(item.amount, 0);
      },
    );

    test('copyWith ne modifie pas l\'id', () {
      final item = BudgetItem(id: 'abc', name: 'Loyer', amount: 800);
      final updated = item.copyWith(amount: 900);
      expect(updated.id, 'abc');
      expect(updated.name, 'Loyer');
      expect(updated.amount, 900);
    });
  });

  group('BudgetCategory', () {
    test('round-trip JSON avec plusieurs items', () {
      final category = BudgetCategory(
        name: 'Logement',
        items: [
          BudgetItem(id: '1', name: 'Loyer', amount: 800),
          BudgetItem(id: '2', name: 'Charges', amount: 150),
        ],
      );
      final restored = BudgetCategory.fromJson(category.toJson());
      expect(restored.name, 'Logement');
      expect(restored.items.length, 2);
      expect(restored.items[0].amount, 800);
      expect(restored.items[1].amount, 150);
    });

    test('un id est généré automatiquement si absent', () {
      final category = BudgetCategory(name: 'Transport', items: const []);
      expect(category.id, isNotEmpty);
    });
  });

  group('BudgetData — totaux', () {
    BudgetData buildSample() => BudgetData(
      revenues: [
        BudgetItem(id: 'r1', name: 'Salaire', amount: 3000),
        BudgetItem(id: 'r2', name: 'Primes', amount: 500),
      ],
      expenseCategories: [
        BudgetCategory(
          name: 'Logement',
          items: [BudgetItem(id: 'e1', name: 'Loyer', amount: 1000)],
        ),
        BudgetCategory(
          name: 'Nourriture',
          items: [BudgetItem(id: 'e2', name: 'Courses', amount: 400)],
        ),
      ],
      investmentCategories: [
        BudgetCategory(
          name: 'Bourse',
          items: [BudgetItem(id: 'i1', name: 'ETF', amount: 500)],
        ),
      ],
    );

    test('totalRevenues additionne tous les revenus', () {
      expect(buildSample().totalRevenues, 3500);
    });

    test(
      'totalExpenses additionne tous les items de toutes les catégories',
      () {
        expect(buildSample().totalExpenses, 1400);
      },
    );

    test('totalInvestments additionne les investissements', () {
      expect(buildSample().totalInvestments, 500);
    });

    test('balance = revenus - dépenses - investissements', () {
      expect(buildSample().balance, 3500 - 1400 - 500);
    });

    test('savingsRate = investissements / revenus * 100', () {
      expect(buildSample().savingsRate, closeTo(500 / 3500 * 100, 0.001));
    });

    test('possibleSavingsRate = (revenus - dépenses) / revenus * 100', () {
      expect(
        buildSample().possibleSavingsRate,
        closeTo((3500 - 1400) / 3500 * 100, 0.001),
      );
    });

    test(
      'taux à 0 quand il n\'y a aucun revenu (pas de division par zéro)',
      () {
        final empty = BudgetData.empty();
        expect(empty.savingsRate, 0);
        expect(empty.possibleSavingsRate, 0);
        expect(empty.balance, 0);
      },
    );

    test('round-trip JSON complet préserve les totaux', () {
      final sample = buildSample();
      final restored = BudgetData.fromJson(sample.toJson());
      expect(restored.totalRevenues, sample.totalRevenues);
      expect(restored.totalExpenses, sample.totalExpenses);
      expect(restored.totalInvestments, sample.totalInvestments);
    });
  });

  group('BudgetSnapshot', () {
    test('displayName utilise le nom si présent, sinon une date formatée', () {
      final named = BudgetSnapshot(
        id: '1',
        name: 'Mon budget',
        savedAt: DateTime(2026, 1, 1),
        data: BudgetData.empty(),
      );
      expect(named.displayName, 'Mon budget');

      final unnamed = BudgetSnapshot(
        id: '2',
        savedAt: DateTime(2026, 3, 15),
        data: BudgetData.empty(),
      );
      expect(unnamed.displayName, 'Budget du 15/03/2026');
    });

    test('round-trip JSON', () {
      final snapshot = BudgetSnapshot(
        id: 'snap-1',
        name: 'Test',
        savedAt: DateTime.utc(2026, 6, 1),
        data: BudgetData.empty(),
      );
      final restored = BudgetSnapshot.fromJson(snapshot.toJson());
      expect(restored.id, 'snap-1');
      expect(restored.name, 'Test');
      expect(restored.savedAt, snapshot.savedAt);
    });
  });
}

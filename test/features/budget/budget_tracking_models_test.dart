import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/budget/budget_tracking_models.dart';

void main() {
  group('TrackingItem', () {
    test('round-trip JSON', () {
      final item = TrackingItem(
        id: 'x1',
        name: 'Loyer',
        budget: 800,
        realite: 820,
        checked: true,
        category: 'Logement',
      );
      final restored = TrackingItem.fromJson(item.toJson());
      expect(restored.id, 'x1');
      expect(restored.name, 'Loyer');
      expect(restored.budget, 800);
      expect(restored.realite, 820);
      expect(restored.checked, true);
      expect(restored.category, 'Logement');
    });

    test('un id est généré automatiquement si non fourni', () {
      final item = TrackingItem(name: 'Test', budget: 0, realite: 0);
      expect(item.id, isNotEmpty);
    });

    test('copyWith met à jour uniquement les champs fournis', () {
      final item = TrackingItem(
        id: 'x1',
        name: 'Loyer',
        budget: 800,
        realite: 800,
      );
      final updated = item.copyWith(realite: 850, checked: true);
      expect(updated.id, 'x1');
      expect(updated.name, 'Loyer');
      expect(updated.budget, 800);
      expect(updated.realite, 850);
      expect(updated.checked, true);
    });
  });

  group('BudgetTrackingMonth — totaux', () {
    BudgetTrackingMonth buildSample() => BudgetTrackingMonth(
      month: 6,
      year: 2026,
      revenues: [TrackingItem(name: 'Salaire', budget: 3000, realite: 3100)],
      factures: [TrackingItem(name: 'Loyer', budget: 800, realite: 800)],
      depenses: [TrackingItem(name: 'Courses', budget: 400, realite: 450)],
      investEpargnes: [TrackingItem(name: 'ETF', budget: 500, realite: 500)],
      projets: [TrackingItem(name: 'Vacances', budget: 200, realite: 0)],
      dettes: [TrackingItem(name: 'Crédit', budget: 100, realite: 100)],
    );

    test('totaux budget par section', () {
      final month = buildSample();
      expect(month.totalRevenuesBudget, 3000);
      expect(month.totalFacturesBudget, 800);
      expect(month.totalDepensesBudget, 400);
      expect(month.totalInvestBudget, 500);
      expect(month.totalProjetsBudget, 200);
      expect(month.totalDettesBudget, 100);
    });

    test('totaux réalité par section', () {
      final month = buildSample();
      expect(month.totalRevenuesRealite, 3100);
      expect(month.totalFacturesRealite, 800);
      expect(month.totalDepensesRealite, 450);
      expect(month.totalInvestRealite, 500);
      expect(month.totalProjetsRealite, 0);
      expect(month.totalDettesRealite, 100);
    });

    test('restantBudget = revenus - toutes les autres sections (budget)', () {
      final month = buildSample();
      expect(month.restantBudget, 3000 - 800 - 400 - 500 - 200 - 100);
    });

    test('restantRealite = revenus - toutes les autres sections (réalité)', () {
      final month = buildSample();
      expect(month.restantRealite, 3100 - 800 - 450 - 500 - 0 - 100);
    });

    test('BudgetTrackingMonth.empty a des totaux nuls', () {
      final empty = BudgetTrackingMonth.empty(1, 2026);
      expect(empty.month, 1);
      expect(empty.year, 2026);
      expect(empty.restantBudget, 0);
      expect(empty.restantRealite, 0);
    });

    test('round-trip JSON préserve mois/année et totaux', () {
      final month = buildSample();
      final restored = BudgetTrackingMonth.fromJson(month.toJson());
      expect(restored.month, 6);
      expect(restored.year, 2026);
      expect(restored.restantBudget, month.restantBudget);
      expect(restored.restantRealite, month.restantRealite);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/budget/budget_recurring_templates_models.dart';

void main() {
  group('RecurringTemplate', () {
    test('round-trip JSON', () {
      final original = RecurringTemplate(
        name: 'Loyer',
        amount: 900,
        category: 'Logement',
        section: BudgetSection.facture,
      );
      final restored = RecurringTemplate.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, 'Loyer');
      expect(restored.amount, 900);
      expect(restored.category, 'Logement');
      expect(restored.section, BudgetSection.facture);
    });

    test('un id est généré automatiquement si non fourni', () {
      final a = RecurringTemplate(
        name: 'A',
        amount: 1,
        section: BudgetSection.depense,
      );
      final b = RecurringTemplate(
        name: 'A',
        amount: 1,
        section: BudgetSection.depense,
      );
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id));
    });

    test('category vide par défaut (non catégorisé)', () {
      final template = RecurringTemplate(
        name: 'A',
        amount: 1,
        section: BudgetSection.depense,
      );
      expect(template.category, '');
    });

    test('copyWith met à jour uniquement les champs fournis', () {
      final original = RecurringTemplate(
        name: 'Loyer',
        amount: 900,
        section: BudgetSection.facture,
      );
      final updated = original.copyWith(amount: 950);
      expect(updated.id, original.id);
      expect(updated.name, 'Loyer');
      expect(updated.amount, 950);
      expect(updated.section, BudgetSection.facture);
    });

    test(
      'section inconnue au décodage (fichier corrompu/futur) retombe sur '
      'depense plutôt que de planter',
      () {
        final restored = RecurringTemplate.fromJson({
          'id': 'x',
          'name': 'A',
          'amount': 1,
          'category': '',
          'section': 'section-inexistante',
        });
        expect(restored.section, BudgetSection.depense);
      },
    );
  });
}

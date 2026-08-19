import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/budget/budget_models.dart';
import 'package:opime/features/budget/budget_sankey.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  var nextId = 0;
  BudgetItem revenue(String name, double amount) =>
      BudgetItem(id: 'item_${nextId++}', name: name, amount: amount);

  Future<void> pump(WidgetTester tester, BudgetData data) => tester.pumpWidget(
    ShadcnApp(
      home: Scaffold(
        child: SizedBox(width: 800, child: BudgetSankeyChart(data: data)),
      ),
    ),
  );

  testWidgets(
    'un seul revenu : graphique inchangé, sans planter',
    (tester) async {
      await pump(
        tester,
        BudgetData(
          revenues: [revenue('Salaire', 3000)],
          expenseCategories: [
            BudgetCategory(name: 'Logement', items: [revenue('Loyer', 1000)]),
          ],
          investmentCategories: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    },
  );

  testWidgets(
    'plusieurs revenus : chacun devient une branche distincte fusionnant '
    'dans le nœud "Revenus", sans planter',
    (tester) async {
      await pump(
        tester,
        BudgetData(
          revenues: [
            revenue('Salaire', 3000),
            revenue('Freelance', 800),
            revenue('Loyers perçus', 500),
          ],
          expenseCategories: [
            BudgetCategory(name: 'Logement', items: [revenue('Loyer', 1000)]),
          ],
          investmentCategories: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    },
  );

  testWidgets(
    'revenu seul sans dépense ni investissement encore saisi : le nœud '
    '"Revenus" (plus de nœud "Disponible" séparé) reste dimensionné sur '
    'le vrai montant plutôt que de s\'effondrer à hauteur nulle faute de '
    'lien sortant',
    (tester) async {
      await pump(
        tester,
        BudgetData(
          revenues: [revenue('Salaire', 3000)],
          expenseCategories: const [],
          investmentCategories: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    },
  );

  testWidgets(
    'un revenu à 0 € parmi plusieurs est ignoré (pas de branche vide)',
    (tester) async {
      await pump(
        tester,
        BudgetData(
          revenues: [
            revenue('Salaire', 3000),
            revenue('Freelance', 0),
            revenue('Loyers perçus', 500),
          ],
          expenseCategories: const [],
          investmentCategories: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}

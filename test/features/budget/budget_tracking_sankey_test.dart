import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/budget/budget_tracking_models.dart';
import 'package:opime/features/budget/budget_tracking_sankey.dart';
import 'package:opime/features/budget/sankey_diagram.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  TrackingItem item(
    String name,
    double realite, {
    double budget = 0,
    String category = '',
  }) => TrackingItem(
    name: name,
    budget: budget,
    realite: realite,
    category: category,
  );

  Future<void> pump(WidgetTester tester, BudgetTrackingMonth data) =>
      tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: SizedBox(
              width: 900,
              child: BudgetTrackingSankeyChart(data: data),
            ),
          ),
        ),
      );

  testWidgets(
    'un revenu et une facture catégorisée : sans exception',
    (tester) async {
      await pump(
        tester,
        BudgetTrackingMonth(
          month: 1,
          year: 2026,
          revenues: [item('Salaire', 3000)],
          factures: [item('Loyer', 1000, category: 'Logement')],
          depenses: const [],
          investEpargnes: const [],
          projets: const [],
          dettes: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    },
  );

  testWidgets(
    'plusieurs revenus fusionnent dans "Revenus" (même principe que '
    'BudgetSankeyChart), sans exception',
    (tester) async {
      await pump(
        tester,
        BudgetTrackingMonth(
          month: 1,
          year: 2026,
          revenues: [item('Salaire', 3000), item('Freelance', 500)],
          factures: [item('Loyer', 1000)],
          depenses: const [],
          investEpargnes: const [],
          projets: const [],
          dettes: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'les 6 catégories de Suivi peuplées en même temps (Factures/Dépenses '
    'catégorisées, Invest/Épargne, Projets, Dettes à plat) : sans '
    'exception',
    (tester) async {
      await pump(
        tester,
        BudgetTrackingMonth(
          month: 1,
          year: 2026,
          revenues: [item('Salaire', 3000)],
          factures: [
            item('Loyer', 800, category: 'Logement'),
            item('Électricité', 100, category: 'Logement'),
          ],
          depenses: [item('Courses', 300, category: 'Nourriture')],
          investEpargnes: [item('PEA', 200)],
          projets: [item('Voyage', 150)],
          dettes: [item('Crédit auto', 250)],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'un poste sans catégorie renseignée tombe dans "Sans catégorie", sans '
    'exception',
    (tester) async {
      await pump(
        tester,
        BudgetTrackingMonth(
          month: 1,
          year: 2026,
          revenues: [item('Salaire', 3000)],
          factures: [item('Abonnement', 50)],
          depenses: const [],
          investEpargnes: const [],
          projets: const [],
          dettes: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'aucune donnée Réalité : affiche un message plutôt qu\'un graphique '
    'vide cassé',
    (tester) async {
      await pump(tester, BudgetTrackingMonth.empty(1, 2026));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Renseigne des montants dans les colonnes Réalité pour voir le '
          'flux de ce mois.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'des montants Budget seuls (sans Réalité) ne suffisent pas à afficher '
    'un flux — Suivi se base sur ce qui a réellement eu lieu',
    (tester) async {
      await pump(
        tester,
        BudgetTrackingMonth(
          month: 1,
          year: 2026,
          revenues: [item('Salaire', 0, budget: 3000)],
          factures: [item('Loyer', 0, budget: 1000)],
          depenses: const [],
          investEpargnes: const [],
          projets: const [],
          dettes: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Renseigne des montants dans les colonnes Réalité pour voir le '
          'flux de ce mois.',
        ),
        findsOneWidget,
      );
    },
  );

  SankeyNode revenusNodeOf(WidgetTester tester) {
    final diagram = tester.widget<SankeyDiagram>(find.byType(SankeyDiagram));
    return diagram.nodes.firstWhere((n) => n.label == 'Revenus');
  }

  testWidgets(
    'dépenses (Réalité) supérieures aux revenus (budget du mois en '
    'déficit) : le nœud "Revenus" annonce le vrai montant des revenus, '
    'pas celui, plus grand et trompeur, des sorties',
    (tester) async {
      await pump(
        tester,
        BudgetTrackingMonth(
          month: 1,
          year: 2026,
          revenues: [item('Salaire', 3000)],
          factures: [item('Loyer', 2000, category: 'Logement')],
          depenses: [item('Courses', 2500, category: 'Nourriture')],
          investEpargnes: const [],
          projets: const [],
          dettes: const [],
        ),
      );
      await tester.pumpAndSettle();

      final revenus = revenusNodeOf(tester);
      // Hauteur assez grande pour les sorties (2000 + 2500 = 4500)...
      expect(revenus.value, 4500);
      // ... mais libellé sur le vrai montant des revenus, déficit à part.
      expect(revenus.displayValue, 3000);
      expect(revenus.deficit, 1500);
    },
  );

  testWidgets(
    'sorties inférieures ou égales aux revenus : aucun déficit annoncé',
    (tester) async {
      await pump(
        tester,
        BudgetTrackingMonth(
          month: 1,
          year: 2026,
          revenues: [item('Salaire', 3000)],
          factures: [item('Loyer', 1000, category: 'Logement')],
          depenses: const [],
          investEpargnes: const [],
          projets: const [],
          dettes: const [],
        ),
      );
      await tester.pumpAndSettle();

      final revenus = revenusNodeOf(tester);
      expect(revenus.value, 3000);
      expect(revenus.displayValue, 3000);
      expect(revenus.deficit, 0);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/widgets/positions_table.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    InvestmentAccount account, {
    ValueChanged<Investment>? onTap,
  }) {
    return tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: PositionsTable(
            account: account,
            hidden: false,
            onTap: onTap ?? (_) {},
          ),
        ),
      ),
    );
  }

  InvestmentAccount buildAccount(List<Investment> investments) =>
      InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO',
        investments: investments,
      );

  testWidgets(
    'une position soldée (quantité nulle) apparaît sous "Anciennes '
    'positions", séparée des positions ouvertes',
    (tester) async {
      final open = Investment(
        isin: 'FR0000131104',
        label: 'TotalEnergies',
        transactions: [
          Transaction(
            date: DateTime(2024, 1, 1),
            isBuy: true,
            quantity: 10,
            unitPrice: 50,
          ),
        ],
      );
      final closed = Investment(
        isin: 'FR0000120271',
        label: 'Air Liquide',
        transactions: [
          Transaction(
            date: DateTime(2023, 1, 1),
            isBuy: true,
            quantity: 5,
            unitPrice: 100,
          ),
          Transaction(
            date: DateTime(2024, 6, 1),
            isBuy: false,
            quantity: 5,
            unitPrice: 120,
          ),
        ],
      );
      await pump(tester, buildAccount([open, closed]));

      expect(find.text('Anciennes positions'), findsOneWidget);
      expect(find.text('TotalEnergies'), findsOneWidget);
      expect(find.text('Air Liquide'), findsOneWidget);

      // "Air Liquide" (soldée) doit apparaître APRÈS "Anciennes positions"
      // dans l'arbre, "TotalEnergies" (ouverte) avant.
      final headerY = tester.getTopLeft(find.text('Anciennes positions')).dy;
      final openY = tester.getTopLeft(find.text('TotalEnergies')).dy;
      final closedY = tester.getTopLeft(find.text('Air Liquide')).dy;
      expect(openY, lessThan(headerY));
      expect(closedY, greaterThan(headerY));
    },
  );

  testWidgets(
    'sans aucune position soldée, pas de section "Anciennes positions"',
    (tester) async {
      final open = Investment(
        isin: 'FR0000131104',
        label: 'TotalEnergies',
        transactions: [
          Transaction(
            date: DateTime(2024, 1, 1),
            isBuy: true,
            quantity: 10,
            unitPrice: 50,
          ),
        ],
      );
      await pump(tester, buildAccount([open]));

      expect(find.text('Anciennes positions'), findsNothing);
      expect(find.text('TotalEnergies'), findsOneWidget);
    },
  );

  testWidgets(
    'cliquer une ancienne position déclenche bien onTap avec cette position',
    (tester) async {
      final closed = Investment(
        isin: 'FR0000120271',
        label: 'Air Liquide',
        transactions: [
          Transaction(
            date: DateTime(2023, 1, 1),
            isBuy: true,
            quantity: 5,
            unitPrice: 100,
          ),
          Transaction(
            date: DateTime(2024, 6, 1),
            isBuy: false,
            quantity: 5,
            unitPrice: 120,
          ),
        ],
      );
      Investment? tapped;
      await pump(
        tester,
        buildAccount([closed]),
        onTap: (i) => tapped = i,
      );

      await tester.tap(find.text('Air Liquide'));
      await tester.pump();

      expect(tapped?.id, closed.id);
    },
  );
}

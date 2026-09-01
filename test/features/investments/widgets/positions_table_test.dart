import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/leveraged_position.dart';
import 'package:opime/features/investments/widgets/positions_table.dart';
import 'package:opime/features/investments/yahoo_finance_client.dart'
    show PricePoint;
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    InvestmentAccount account, {
    ValueChanged<Investment>? onTap,
    DashboardPeriod period = DashboardPeriod.all,
    Map<String, List<PricePoint>> priceHistories = const {},
  }) {
    return tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: PositionsTable(
            account: account,
            hidden: false,
            onTap: onTap ?? (_) {},
            vaultPath: '/tmp/unused-in-this-test',
            onChanged: () async {},
            period: period,
            priceHistories: priceHistories,
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

  group('positions à effet de levier (régression : section de l\'onglet '
      'Positions, plus un onglet séparé)', () {
    testWidgets(
      'un compte Actions & Fonds/Crypto affiche la section même sans '
      'position à effet de levier — état vide + bouton "Ajouter"',
      (tester) async {
        await pump(tester, buildAccount(const []));

        expect(find.text('Positions à effet de levier'), findsOneWidget);
        expect(
          find.text('Aucune position à effet de levier pour l\'instant.'),
          findsOneWidget,
        );
        expect(find.text('Ajouter une position'), findsOneWidget);
      },
    );

    testWidgets(
      'une position ouverte apparaît dans un tableau (marché, taille, '
      'entrée, cours, marge, PnL), une position fermée sous "Positions '
      'fermées"',
      (tester) async {
        final open = LeveragedPosition(
          market: 'BTC',
          side: PositionSide.long,
          leverage: 2,
          size: 0.1,
          entryPrice: 60000,
          markPrice: 66000,
          openedAt: DateTime(2026, 1, 1),
        );
        final closed = LeveragedPosition(
          market: 'ETH',
          side: PositionSide.short,
          leverage: 3,
          size: 1,
          entryPrice: 3000,
          openedAt: DateTime(2025, 1, 1),
          closedAt: DateTime(2025, 6, 1),
          closePrice: 2700,
        );
        final account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO',
          investments: const [],
          leveragedPositions: [open, closed],
        );
        await pump(tester, account);

        expect(find.text('BTC'), findsOneWidget);
        expect(find.text('Long 2x'), findsOneWidget);
        expect(find.text('Positions fermées'), findsOneWidget);
        expect(find.text('ETH'), findsOneWidget);
        expect(find.text('Fermée'), findsOneWidget);
      },
    );

    testWidgets(
      'un compte épargne (aucun trading sur marge) n\'affiche pas la '
      'section du tout',
      (tester) async {
        final account = InvestmentAccount(
          assetClass: AssetClass.epargne,
          envelope: AccountEnvelope.livretA,
          name: 'Livret A',
          bankName: 'Boursorama',
          investments: const [],
        );
        await pump(tester, account);

        expect(find.text('Positions à effet de levier'), findsNothing);
      },
    );
  });

  testWidgets(
    'le tableau des positions spot affiche une colonne "Évolution" en plus '
    'de "+/- value"',
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

      expect(find.text('Évolution'), findsOneWidget);
      expect(find.text('+/- value'), findsOneWidget);
    },
  );
}

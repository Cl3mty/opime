import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/real_estate/real_estate_profitability_section.dart';
import 'package:opime/features/investments/real_estate/rent_models.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';
import 'package:opime/features/liabilities/liabilities_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_real_estate_profitability_test_',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Investment property({
    List<RentPeriod> rentPeriods = const [],
    List<WorkItem> workItems = const [],
    double buyAmount = 200000,
  }) => Investment(
    id: 'immobilier-abc',
    isin: 'immobilier-abc',
    label: 'Appartement Lyon 6e',
    realEstateType: RealEstateType.locationLongueDureeNue,
    transactions: [
      Transaction(date: DateTime(2020, 1, 1), isBuy: true, quantity: 1, unitPrice: buyAmount),
    ],
    rentPeriods: rentPeriods,
    workItems: workItems,
  );

  RentPeriod paidPeriod(DateTime month, double amount) => RentPeriod(
    periodStart: DateTime(month.year, month.month, 1),
    periodEnd: DateTime(month.year, month.month + 1, 0),
    amountDue: amount,
    amountPaid: amount,
    paidAt: DateTime(month.year, month.month, 5),
  );

  Future<void> pump(
    WidgetTester tester,
    Investment investment,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: RealEstateProfitabilitySection(
              vaultPath: tempDir.path,
              investment: investment,
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sans aucun loyer suivi, invite à en ajouter plutôt que d\'afficher '
    'une rentabilité à partir de rien',
    (tester) async {
      await pump(tester, property());
      expect(
        find.textContaining('Ajoutez des loyers'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'sans prêt lié : cash-flow calculé achat comptant, autofinancé dès '
    'que le loyer est positif',
    (tester) async {
      final now = DateTime.now();
      final investment = property(
        rentPeriods: [paidPeriod(now, 800)],
      );
      await pump(tester, investment);

      expect(find.textContaining('Cash-flow mensuel'), findsOneWidget);
      expect(find.text('Autofinancé'), findsOneWidget);
      expect(find.textContaining('Sans prêt lié'), findsOneWidget);
      // Revenu locatif annuel = 800 (un seul mois dans les 12 derniers,
      // annualisé via un loyer mensuel moyen puis × 12 : 800/1 mois moyen
      // × 12 donnerait 9600 si on avait 1 mois de recul — mais un seul
      // point de données réel produit 800 € de revenu annuel, la moyenne
      // mensuelle 800/12 rejouée × 12 redonne exactement 800.
      expect(find.textContaining('800'), findsWidgets);
    },
  );

  testWidgets(
    'avec un prêt lié : la mensualité de crédit est déduite et affichée',
    (tester) async {
      final now = DateTime.now();
      final investment = property(rentPeriods: [paidPeriod(now, 1200)]);
      final liability = Liability(
        type: LiabilityType.pretImmobilier,
        name: 'Prêt appart',
        montantEmprunte: 180000,
        tauxInteret: 3.5,
        nbrEcheances: 240,
        dateDebut: DateTime(2020, 1, 1),
        linkedInvestmentId: investment.id,
      );
      await tester.runAsync(
        () => LiabilitiesRepository(tempDir.path).saveLiability(liability),
      );

      await pump(tester, investment);

      expect(find.textContaining('Mensualité de crédit déduite'), findsOneWidget);
      expect(find.textContaining('Sans prêt lié'), findsNothing);
    },
  );

  testWidgets(
    'les travaux suivis s\'ajoutent au coût total du projet, mentionnés '
    'explicitement',
    (tester) async {
      final now = DateTime.now();
      final investment = property(
        rentPeriods: [paidPeriod(now, 800)],
        workItems: [
          WorkItem(label: 'Peinture', amount: 5000, date: DateTime(2024, 1, 1)),
        ],
      );
      await pump(tester, investment);

      expect(find.textContaining('5 000'), findsWidgets);
      expect(find.textContaining('de travaux'), findsOneWidget);
    },
  );
}

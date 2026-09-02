import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/features/dashboard/dashboard_screen.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart' show DashboardPeriod;
import 'package:opime/features/dashboard/widgets/category_breakdown_card.dart';
import 'package:opime/features/dashboard/widgets/net_worth_chart.dart' show PeriodTabs;
import 'package:opime/features/dashboard/onboarding_highlight_controller.dart'
    show OnboardingHighlightController;
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/patrimoine_refresh_controller.dart';
import 'package:opime/features/investments/price_sync_status_controller.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';
import 'package:opime/features/liabilities/liabilities_repository.dart';
import 'package:opime/features/simulations/loan_calculator.dart' show LoanType;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// `DashboardScreen`/`_RealDashboard` fait bien de la vraie E/S disque dans
/// `initState` (`InvestmentsRepository.listAll`, `LiabilitiesRepository
/// .listAll`, `loadAllPriceHistories`) — même motif déjà éprouvé pour
/// `AnalysesScreen` (`test/features/analyses/analyses_screen_test.dart`,
/// repris ici à l'identique) : `tester.runAsync` pour driver ces vraies E/S,
/// `pumpWidget` restant dans la MÊME zone `runAsync` que la boucle de
/// sondage qui l'attend (sinon la continuation reste suspendue
/// indéfiniment dans la zone fake-async du test, piège documenté ailleurs
/// dans cette suite — voir `real_estate_loan_link_test.dart`).
///
/// `_load()` déclenche aussi, sans l'attendre, une vraie synchronisation
/// réseau des cours (`_refreshFromNetwork`) pour tout investissement dont
/// `isPriceFresh` est faux — les fixtures ci-dessous donnent donc
/// systématiquement `lastPriceDate: DateTime.now()` aux positions cotées
/// pour l'éviter (contrairement à `analyses_screen_test.dart`, qui ne s'en
/// soucie pas), plutôt que de dépendre d'un vrai appel réseau (lent,
/// silencieusement avalé en cas d'échec, mais inutile ici).
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_dashboard_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ShadcnApp(
      home: Scaffold(
        child: DashboardScreen(
          vaultPath: tempDir.path,
          amountVisibility: AmountVisibilityController(),
          refreshSignal: PatrimoineRefreshController(),
          priceSyncStatus: PriceSyncStatusController(),
          onboardingHighlight: OnboardingHighlightController(),
        ),
      ),
    ),
  );

  /// Pompe l'écran puis sonde jusqu'à disparition du spinner de chargement
  /// plein cadre (`_loading` devenu `false`) — même zone `runAsync` que le
  /// pompage, voir la doc de tête.
  Future<void> pumpAndWaitForLoad(WidgetTester tester) async {
    await tester.runAsync(() async {
      await pump(tester);
      for (var i = 0; i < 40; i++) {
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'vault vide (aucun compte ni passif) : écran d\'accueil affiché, pas '
    'les cartes habituelles',
    (tester) async {
      await pumpAndWaitForLoad(tester);

      expect(find.text('Ton tableau de bord est vide'), findsOneWidget);
      expect(find.byType(CategoryBreakdownCard), findsNothing);
    },
  );

  testWidgets(
    'vault peuplé (un compte Actions & Fonds) : la carte "Actifs" affiche '
    'le nom du compte, avec un montant total non nul',
    (tester) async {
      await tester.runAsync(() async {
        final account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO Bourso',
          bankName: 'Bourso',
          investments: [
            Investment(
              isin: 'US0378331005',
              label: 'Apple',
              symbol: 'AAPL',
              lastPrice: 120,
              lastPriceDate: DateTime.now(),
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 10),
                  isBuy: true,
                  quantity: 10,
                  unitPrice: 100,
                ),
              ],
            ),
          ],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await pumpAndWaitForLoad(tester);

      expect(find.text('Ton tableau de bord est vide'), findsNothing);
      // "Actifs" apparaît aussi comme bascule sur la carte Allocation : on
      // vérifie précisément la carte `CategoryBreakdownCard` de ce titre,
      // pas seulement le texte "Actifs" (ambigu).
      expect(
        tester
            .widgetList<CategoryBreakdownCard>(
              find.byType(CategoryBreakdownCard),
            )
            .map((c) => c.title),
        containsAll(['Actifs']),
      );
      expect(find.text('CTO Bourso'), findsOneWidget);
      // 10 actions à 120 € : 1 200 €.
      expect(find.textContaining('1 200'), findsWidgets);
    },
  );

  testWidgets(
    'un passif enregistré : la carte "Passifs" affiche son nom',
    (tester) async {
      await tester.runAsync(() async {
        final liability = Liability(
          type: LiabilityType.pretImmobilier,
          name: 'Prêt appart',
          montantEmprunte: 200000,
          tauxInteret: 3.5,
          nbrEcheances: 240,
          dateDebut: DateTime(2024, 1, 1),
          loanType: LoanType.amortissable,
        );
        await LiabilitiesRepository(tempDir.path).saveLiability(liability);
      });

      await pumpAndWaitForLoad(tester);

      expect(
        tester
            .widgetList<CategoryBreakdownCard>(
              find.byType(CategoryBreakdownCard),
            )
            .map((c) => c.title),
        containsAll(['Passifs']),
      );
      expect(find.text('Prêt appart'), findsOneWidget);
    },
  );

  testWidgets(
    'au moins une position détenue : "Mes meilleures performances" '
    'affiche son libellé',
    (tester) async {
      await tester.runAsync(() async {
        final account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO Bourso',
          bankName: 'Bourso',
          investments: [
            Investment(
              isin: 'US0378331005',
              label: 'Apple',
              symbol: 'AAPL',
              lastPrice: 120,
              lastPriceDate: DateTime.now(),
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 10),
                  isBuy: true,
                  quantity: 10,
                  unitPrice: 100,
                ),
              ],
            ),
          ],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await pumpAndWaitForLoad(tester);

      expect(find.text('Mes meilleures performances'), findsOneWidget);
      expect(find.text('Apple'), findsWidgets);
    },
  );

  testWidgets(
    'régression : un seul PeriodTabs pilote toute la page — le taper met '
    'à jour la période effectivement passée aux cartes Actifs/Passifs '
    '(pas de sélecteur indépendant réapparu, ex. sur "Mes meilleures '
    'performances")',
    (tester) async {
      await tester.runAsync(() async {
        final account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO Bourso',
          bankName: 'Bourso',
          investments: [
            Investment(
              isin: 'US0378331005',
              label: 'Apple',
              symbol: 'AAPL',
              lastPrice: 120,
              lastPriceDate: DateTime.now(),
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 10),
                  isBuy: true,
                  quantity: 10,
                  unitPrice: 100,
                ),
              ],
            ),
          ],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await pumpAndWaitForLoad(tester);

      expect(find.byType(PeriodTabs), findsOneWidget);
      final cardsBefore = tester
          .widgetList<CategoryBreakdownCard>(find.byType(CategoryBreakdownCard))
          .map((c) => c.period)
          .toSet();
      expect(cardsBefore, {DashboardPeriod.all});

      await tester.tap(find.text('1M'));
      await tester.pump();

      final cardsAfter = tester
          .widgetList<CategoryBreakdownCard>(find.byType(CategoryBreakdownCard))
          .map((c) => c.period)
          .toSet();
      expect(cardsAfter, {DashboardPeriod.month1});
    },
  );
}

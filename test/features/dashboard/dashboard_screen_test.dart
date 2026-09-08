import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/features/dashboard/dashboard_screen.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart' show DashboardPeriod;
import 'package:opime/features/dashboard/widgets/category_breakdown_card.dart';
import 'package:opime/features/dashboard/widgets/net_worth_chart.dart' show PeriodTabs;
import 'package:opime/features/dashboard/onboarding_highlight_controller.dart'
    show OnboardingHighlightController;
import 'package:opime/features/entities/entities_models.dart';
import 'package:opime/features/entities/entities_repository.dart';
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
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      home: Scaffold(
        child: DashboardScreen(
          vaultPath: tempDir.path,
          amountVisibility: AmountVisibilityController(),
          refreshSignal: PatrimoineRefreshController(),
          priceSyncStatus: PriceSyncStatusController(),
          onboardingHighlight: OnboardingHighlightController(),
          profileName: 'Moi',
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
    'vault peuplé (un compte Actions & Fonds) : la carte "Placements" affiche '
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
      // "Placements" apparaît aussi comme bascule sur la carte Allocation : on
      // vérifie précisément la carte `CategoryBreakdownCard` de ce titre,
      // pas seulement le texte "Placements" (ambigu).
      expect(
        tester
            .widgetList<CategoryBreakdownCard>(
              find.byType(CategoryBreakdownCard),
            )
            .map((c) => c.title),
        containsAll(['Placements']),
      );
      expect(find.text('CTO Bourso'), findsOneWidget);
      // 10 actions à 120 € : 1 200 €.
      expect(find.textContaining('1 200'), findsWidgets);
    },
  );

  testWidgets(
    'un passif enregistré : la carte "Dettes" affiche son nom',
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
        containsAll(['Dettes']),
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

  group('Entités professionnelles (voir entities_patrimoine_adapter.dart)', () {
    testWidgets(
      'une entité avec un compte rattaché : sa valeur nette détenue '
      'apparaît sur la carte "Placements" — aucune distinction personnel/'
      'professionnel de coffre-fort n\'existe, n\'importe lequel peut avoir '
      'des entités',
      (tester) async {
        await tester.runAsync(() async {
          await EntityRepository(tempDir.path).saveEntity(
            const BusinessEntity(
              id: 'e1',
              name: 'SCI Les Tilleuls',
              type: EntityType.sci,
              stakes: [OwnershipStake(percent: 100)],
            ),
          );
          await InvestmentsRepository(tempDir.path).saveAccount(
            InvestmentAccount(
              assetClass: AssetClass.immobilier,
              name: 'Immeuble',
              investments: [
                Investment(
                  isin: 'FR0000000000',
                  label: 'Immeuble',
                  transactions: [
                    Transaction(
                      date: DateTime(2024, 1, 1),
                      isBuy: true,
                      quantity: 1,
                      unitPrice: 150000,
                    ),
                  ],
                ),
              ],
              entityId: 'e1',
            ),
          );
        });

        await pumpAndWaitForLoad(tester);

        expect(find.text('SCI Les Tilleuls'), findsOneWidget);
        expect(find.textContaining('150 000'), findsWidgets);
      },
    );

    testWidgets(
      'régression : cliquer une catégorie de la carte Dettes d\'une entité '
      'ouvre son détail (EntityDetailScreen), pas la page de catégorie '
      'personnelle habituelle — qui ne connaît pas les passifs d\'une '
      'entité et semblerait vide à tort',
      (tester) async {
        await tester.runAsync(() async {
          await EntityRepository(tempDir.path).saveEntity(
            const BusinessEntity(
              id: 'e1',
              name: 'SCI Les Tilleuls',
              type: EntityType.sci,
              stakes: [OwnershipStake(percent: 100)],
            ),
          );
          await LiabilitiesRepository(tempDir.path).saveLiability(
            Liability(
              type: LiabilityType.creditAutre,
              name: 'Prêt travaux SCI',
              montantEmprunte: 30000,
              tauxInteret: 2,
              nbrEcheances: 60,
              dateDebut: DateTime(2024, 1, 1),
              loanType: LoanType.amortissable,
              entityId: 'e1',
            ),
          );
        });

        await pumpAndWaitForLoad(tester);

        await tester.ensureVisible(find.text(LiabilityType.creditAutre.label));
        await tester.tap(find.text(LiabilityType.creditAutre.label));
        // `EntityDetailScreen._load()` fait de vraies E/S disque — même
        // motif `runAsync` que `pumpAndWaitForLoad`, voir sa doc de tête.
        await tester.runAsync(() async {
          for (var i = 0; i < 20; i++) {
            if (find.text('Prêt travaux SCI').evaluate().isNotEmpty) return;
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
          }
        });

        // Le détail de l'entité affiche bien sa carte Dettes (voir
        // `entity_detail_screen.dart`) — pas une page personnelle vide.
        // "Dettes" seul est ambigu (aussi une bascule de la carte
        // Allocation juste au-dessus) : on vérifie précisément la carte
        // `CategoryBreakdownCard` de ce titre. Pas de carte "Placements" ici :
        // cette entité n'a aucun compte (voir `CategoryBreakdownCard`, qui
        // masque tout — y compris son titre — sans catégorie peuplée).
        expect(
          tester
              .widgetList<CategoryBreakdownCard>(
                find.byType(CategoryBreakdownCard),
              )
              .map((c) => c.title),
          containsAll(['Dettes']),
        );
        expect(find.text('Prêt travaux SCI'), findsOneWidget);
      },
    );
  });
}

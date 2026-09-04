import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/features/analyses/analyses_screen.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_analyses_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Survole [finder] (un seul widget attendu) et laisse la bulle
  /// `Tooltip` (shadcn_flutter) le temps de s'afficher — sondage par
  /// petits pas plutôt qu'un seul grand saut de durée, plus robuste face
  /// aux animations internes du package (voir `asset_table_header_cell_test
  /// .dart`, même motif).
  Future<void> hoverOver(WidgetTester tester, Finder finder) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(finder));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      
      home: Scaffold(
        child: AnalysesScreen(
          vaultPath: tempDir.path,
          amountVisibility: AmountVisibilityController(),
        ),
      ),
    ),
  );

  /// Bascule sur l'onglet [label] (Performance/Risque/Composition/Structure
  /// financière) — l'écran s'ouvre toujours sur "Performance" (voir
  /// `AnalysesScreen`'s `_tabIndex`), donc chaque test qui vise une autre
  /// section doit d'abord y naviguer explicitement plutôt que compter sur
  /// tout être présent en une seule page défilante (ancien comportement).
  Future<void> selectTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'la plus-value latente globale (déplacée depuis la carte "Patrimoine" '
    'du Dashboard) apparaît en haut de la section Performance',
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
              lastPrice: 120,
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 1),
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

      await tester.runAsync(() async {
        await pump(tester);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      expect(find.text('Plus-value latente'), findsOneWidget);
      // 10 actions à 120 € pour un coût d'acquisition de 1000 € : +200 €
      // (+20 %) — `formatEuros` arrondit à l'euro, `displayPercent` garde
      // 2 décimales avec un point (voir `core/money_format.dart`).
      expect(find.textContaining('+200 €'), findsOneWidget);
      expect(find.textContaining('+20.00 %'), findsOneWidget);
    },
  );

  testWidgets(
    'survoler l\'icône info à côté de "Plus-value latente" affiche son '
    'explication — une des 5 cartes qui n\'avaient encore aucune bulle',
    (tester) async {
      await tester.runAsync(() async {
        await pump(tester);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      final titleRow = find
          .ancestor(of: find.text('Plus-value latente'), matching: find.byType(Row))
          .first;
      await hoverOver(
        tester,
        find.descendant(of: titleRow, matching: find.byIcon(LucideIcons.info)),
      );

      expect(
        find.textContaining('Ce que la vente immédiate de tout le '
            'patrimoine rapporterait'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Diversification sectorielle et géographique : le donut/la carte et '
    'leur liste affichent chaque secteur/pays classé, y compris "Non '
    'classé" pour l\'investissement non renseigné',
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
              lastPrice: 120,
              sector: Sector.technologie,
              countryCode: 'US',
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 1),
                  isBuy: true,
                  quantity: 10,
                  unitPrice: 100,
                ),
              ],
            ),
            Investment(
              isin: 'FR0000120271',
              label: 'Total',
              lastPrice: 50,
              sector: Sector.energie,
              countryCode: 'FR',
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 1),
                  isBuy: true,
                  quantity: 10,
                  unitPrice: 40,
                ),
              ],
            ),
            Investment(
              isin: 'IE00B4L5Y983',
              label: 'ETF non classé',
              lastPrice: 30,
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 1),
                  isBuy: true,
                  quantity: 10,
                  unitPrice: 25,
                ),
              ],
            ),
          ],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.runAsync(() async {
        await pump(tester);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      await selectTab(tester, 'Composition');

      expect(find.text('Diversification sectorielle'), findsOneWidget);
      expect(find.text('Technologie'), findsOneWidget);
      expect(find.text('Énergie'), findsOneWidget);
      expect(find.text('Non classé'), findsWidgets);

      expect(find.text('Diversification géographique'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
      expect(find.text('États-Unis'), findsOneWidget);
    },
  );

  testWidgets(
    'survoler "Technologie" (carte sectorielle) affiche la liste des '
    'investissements du secteur (Apple), et survoler "France" (carte '
    'géographique) affiche ceux du pays (TotalEnergies)',
    (tester) async {
      // Fenêtre agrandie : depuis le passage à des onglets, l'onglet
      // Composition ne contient plus que 3 cartes (plus la page entière) —
      // mais survoler "Technologie" ajoute quand même un panneau sous la
      // carte sectorielle, poussant la carte géographique (donc "France")
      // plus bas que le viewport 800x600 par défaut.
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
              lastPrice: 120,
              sector: Sector.technologie,
              countryCode: 'US',
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 1),
                  isBuy: true,
                  quantity: 10,
                  unitPrice: 100,
                ),
              ],
            ),
            Investment(
              isin: 'FR0000120271',
              label: 'TotalEnergies',
              lastPrice: 50,
              sector: Sector.energie,
              countryCode: 'FR',
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 1),
                  isBuy: true,
                  quantity: 10,
                  unitPrice: 40,
                ),
              ],
            ),
          ],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.runAsync(() async {
        await pump(tester);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      await selectTab(tester, 'Composition');

      // Rien avant survol : ni "Apple" ni "TotalEnergies" ne sont affichés
      // par défaut, aucune sélection n'est encore active.
      expect(find.text('Apple'), findsNothing);
      expect(find.text('TotalEnergies'), findsNothing);

      // Un seul pointeur souris réutilisé pour les deux survols successifs
      // (contrairement à `hoverOver`, qui en crée un par appel — en créer
      // un second sans avoir retiré le premier viole l'invariant du
      // `MouseTracker` de Flutter).
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.text('Technologie')));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      // La liste ne montre que les investissements du secteur survolé.
      expect(find.text('TotalEnergies'), findsNothing);

      // Repasse par un point neutre avant le second survol : un saut
      // direct d'une région survolée à une autre, plus loin sur une carte
      // différente après un changement de mise en page (le panneau "Apple"
      // qui vient d'apparaître déplace tout ce qui suit), ne redéclenche
      // pas toujours proprement `onExit` sur la région quittée.
      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.text('France')));
      await tester.pumpAndSettle();
      expect(find.text('TotalEnergies'), findsOneWidget);
    },
  );

  testWidgets(
    'survoler "Technologie" n\'affiche que les positions à valeur actuelle '
    'non nulle : une position entièrement soldée du même secteur est '
    'ignorée',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
              lastPrice: 120,
              sector: Sector.technologie,
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 1),
                  isBuy: true,
                  quantity: 10,
                  unitPrice: 100,
                ),
              ],
            ),
            // Entièrement soldée (achat puis revente de la même quantité) :
            // même secteur, mais displayValue == 0 — ne doit apparaître ni
            // dans le camembert ni dans la liste au survol.
            Investment(
              isin: 'US67066G1040',
              label: 'Nvidia',
              lastPrice: 900,
              sector: Sector.technologie,
              transactions: [
                Transaction(
                  date: DateTime.utc(2023, 1, 1),
                  isBuy: true,
                  quantity: 5,
                  unitPrice: 200,
                ),
                Transaction(
                  date: DateTime.utc(2024, 6, 1),
                  isBuy: false,
                  quantity: 5,
                  unitPrice: 800,
                ),
              ],
            ),
          ],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.runAsync(() async {
        await pump(tester);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      await selectTab(tester, 'Composition');

      await hoverOver(tester, find.text('Technologie'));

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Nvidia'), findsNothing);
    },
  );

  testWidgets(
    'cliquer "Technologie" épingle la sélection : elle reste affichée une '
    'fois la souris repartie, jusqu\'à cliquer de nouveau dessus',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
              lastPrice: 120,
              sector: Sector.technologie,
              transactions: [
                Transaction(
                  date: DateTime.utc(2024, 1, 1),
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

      await tester.runAsync(() async {
        await pump(tester);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      await selectTab(tester, 'Composition');

      await tester.tap(find.text('Technologie'));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);

      // La souris "repart" en survolant un point neutre de l'écran.
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      await gesture.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();

      // Toujours affiché : la sélection cliquée reste épinglée.
      expect(find.text('Apple'), findsOneWidget);

      // Cliquer de nouveau dessus désépingle.
      await tester.tap(find.text('Technologie'));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
    },
  );

  testWidgets(
    'survoler le libellé "Levier" (carte Endettement et levier) affiche '
    'son explication',
    (tester) async {
      // Fenêtre élargie : les 4 onglets ("Structure financière" compris)
      // dépassent la largeur 800 par défaut.
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await pump(tester);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      await selectTab(tester, 'Structure financière');

      await hoverOver(tester, find.text('Levier'));

      expect(
        find.textContaining('Actifs totaux rapportés au patrimoine net'),
        findsOneWidget,
      );
    },
  );

  group('onglets (Performance/Risque/Composition/Structure financière)', () {
    testWidgets(
      'ouvre par défaut sur "Performance" : ses cartes sont visibles, '
      'celles de Risque/Composition/Structure financière ne le sont pas',
      (tester) async {
        await tester.runAsync(() async {
          await pump(tester);
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
          }
        });
        await tester.pumpAndSettle();

        expect(find.text('Plus-value latente'), findsOneWidget);
        expect(find.text('Risque et rendement'), findsNothing);
        expect(find.text('Style de gestion'), findsNothing);
        expect(find.text('Endettement et levier'), findsNothing);
      },
    );

    testWidgets(
      'cliquer "Risque" affiche ses cartes et masque celles de '
      'Performance — le sélecteur de période reste visible (pertinent '
      'pour les deux)',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.runAsync(() async {
          await pump(tester);
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
          }
        });
        await tester.pumpAndSettle();
        await selectTab(tester, 'Risque');

        expect(find.text('Plus-value latente'), findsNothing);
        expect(find.text('Risque et rendement'), findsOneWidget);
        expect(find.text('Corrélation entre catégories'), findsOneWidget);
        // Sélecteur de période (labels de DashboardPeriod) toujours affiché.
        expect(find.text('1A'), findsOneWidget);
      },
    );

    testWidgets(
      'sur "Structure financière" (instantané, pas de notion de période), '
      'le sélecteur de période est masqué',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.runAsync(() async {
          await pump(tester);
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
          }
        });
        await tester.pumpAndSettle();
        await selectTab(tester, 'Structure financière');

        expect(find.text('1A'), findsNothing);
        expect(find.text('Levier'), findsOneWidget);
      },
    );
  });
}

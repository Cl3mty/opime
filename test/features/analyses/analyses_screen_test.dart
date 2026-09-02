import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
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
      home: Scaffold(
        child: AnalysesScreen(
          vaultPath: tempDir.path,
          amountVisibility: AmountVisibilityController(),
        ),
      ),
    ),
  );

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
    'survoler le libellé "Levier" (carte Endettement et levier) affiche '
    'son explication',
    (tester) async {
      // Fenêtre agrandie : la carte "Endettement et levier" est la
      // dernière de la page, hors du viewport 800x600 par défaut.
      tester.view.physicalSize = const Size(1200, 3000);
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

      await hoverOver(tester, find.text('Levier'));

      expect(
        find.textContaining('Actifs totaux rapportés au patrimoine net'),
        findsOneWidget,
      );
    },
  );
}

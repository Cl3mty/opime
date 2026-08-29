import 'dart:io';

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
}

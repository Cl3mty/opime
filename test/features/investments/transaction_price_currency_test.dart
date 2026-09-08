import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/currency_data.dart'
    show kKnownStablecoins;
import 'package:opime/features/investments/transaction_price_currency.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;
  late TransactionPriceCurrencyController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_txn_price_currency_test_',
    );
    controller = TransactionPriceCurrencyController(vaultPath: tempDir.path);
  });

  tearDown(() async {
    controller.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  // La popup du `Select` sous-jacent (shadcn_flutter) s'ouvre dans un
  // overlay dont l'animation ne se prête pas à une interaction fiable en
  // test — on vérifie directement le paramètre reçu par
  // [TransactionPriceCurrencySelect] plutôt que de piloter la popup.
  testWidgets(
    'extraOptions (stablecoins pour une transaction crypto) est bien reçu '
    'par le sélecteur, vide par défaut sinon',
    (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: TransactionPriceCurrencySelect(
              controller: controller,
              extraOptions: kKnownStablecoins,
            ),
          ),
        ),
      );
      final widget = tester.widget<TransactionPriceCurrencySelect>(
        find.byType(TransactionPriceCurrencySelect),
      );
      expect(widget.extraOptions, kKnownStablecoins);

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: TransactionPriceCurrencySelect(controller: controller),
          ),
        ),
      );
      final defaultWidget = tester.widget<TransactionPriceCurrencySelect>(
        find.byType(TransactionPriceCurrencySelect),
      );
      expect(defaultWidget.extraOptions, isEmpty);
    },
  );

  group('fxPairFor (régression : le taux d\'un stablecoin retombait '
      'silencieusement sur la saisie manuelle, la paire fiat classique '
      'n\'existant pas pour lui sur Yahoo Finance)', () {
    test('une devise fiat classique utilise la paire `<CODE>EUR=X`', () {
      expect(fxPairFor('USD'), 'USDEUR=X');
      expect(fxPairFor('gbp'), 'GBPEUR=X');
    });

    test(
      'un stablecoin utilise la paire crypto `<CODE>-EUR`, pas `<CODE>EUR=X` '
      '(qui n\'existe pas sur Yahoo Finance pour un stablecoin)',
      () {
        expect(fxPairFor('USDC'), 'USDC-EUR');
        expect(fxPairFor('usdt'), 'USDT-EUR');
      },
    );
  });
}

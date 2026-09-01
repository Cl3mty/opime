import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/core/simulations/simulation_state_repository.dart';
import 'package:opime/features/simulations/simulations_taxation_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  group('Widget — l\'onglet actif persisté est restauré au chargement', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_taxation_screen_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: TaxationSimulationScreen(
              vaultPath: tempDir.path,
              amountVisibility: AmountVisibilityController(),
            ),
          ),
        ),
      );
      // `_loadState()` (lecture disque réelle) est déclenché depuis
      // `initState`, sans être attendu par l'appelant — repomper jusqu'à ce
      // que l'onglet chargé soit effectivement reflété.
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
    }

    testWidgets('sans état sauvegardé, l\'onglet IR (0) est actif par défaut', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(tester.widget<TabList>(find.byType(TabList)).index, 0);
    });

    testWidgets(
      'un onglet IFI (1) déjà sauvegardé sur ce vault est restauré au '
      'chargement, plutôt que de retomber sur IR par défaut',
      (tester) async {
        await tester.runAsync(
          () => SimulationStateRepository(
            tempDir.path,
          ).write('taxation', {'tabIndex': 1}),
        );

        await pumpScreen(tester);

        expect(tester.widget<TabList>(find.byType(TabList)).index, 1);
      },
    );
  });

  group('computeIR (impôt sur le revenu, quotient familial)', () {
    test('barème par part : limites et taux officiels', () {
      expect(irLimits, [11294.0, 28797.0, 82341.0, 177106.0]);
      expect(irRates, [0.0, 11.0, 30.0, 41.0, 45.0]);
    });

    test('revenu net imposable de 150 000 €, 1 part', () {
      final result = computeIR(netImposable: 150000, nbrParts: 1);

      expect(result.quotient, 150000);
      expect(result.tmi, 41);
      // 17 503*11% + 53 544*30% + 67 659*41% = 1 925.33 + 16 063.2 + 27 740.19
      expect(result.total, closeTo(45728.72, 0.02));
    });

    test('le quotient familial réduit le taux marginal par part', () {
      final oneShare = computeIR(netImposable: 150000, nbrParts: 1);
      final threeShares = computeIR(netImposable: 150000, nbrParts: 3);

      expect(threeShares.quotient, closeTo(50000, 0.01));
      expect(threeShares.tmi, lessThan(oneShare.tmi));
      // Même revenu, mais fiscalité totale plus faible grâce au quotient.
      expect(threeShares.total, lessThan(oneShare.total));
    });

    test('nombre de parts inférieur à 1 est ramené à 1', () {
      final zeroShares = computeIR(netImposable: 50000, nbrParts: 0);
      final oneShare = computeIR(netImposable: 50000, nbrParts: 1);
      expect(zeroShares.total, oneShare.total);
    });

    test('revenu sous le premier seuil : aucun impôt', () {
      final result = computeIR(netImposable: 10000, nbrParts: 1);
      expect(result.total, 0);
      expect(result.tmi, 0);
    });
  });

  group('computeIFI (impôt sur la fortune immobilière)', () {
    test('barème : seuils et taux officiels', () {
      expect(ifiLimits, [
        800000.0,
        1300000.0,
        2570000.0,
        5000000.0,
        10000000.0,
      ]);
      expect(ifiRates, [0.0, 0.5, 0.7, 1.0, 1.25, 1.5]);
    });

    test('patrimoine net de 2 000 000 €', () {
      final result = computeIFI(2000000);

      expect(result.tauxMax, closeTo(0.7, 0.001));
      // 500 000 * 0.5% + 700 000 * 0.7% = 2 500 + 4 900
      expect(result.total, closeTo(7400, 0.01));
    });

    test('sous le seuil de 1 300 000 € : exonération totale', () {
      final result = computeIFI(1000000);
      expect(result.total, 0);
      expect(result.tauxMax, 0);
    });

    test('exactement à 1 300 000 € : encore exonéré (seuil "supérieur à")', () {
      final result = computeIFI(1300000);
      expect(result.total, 0);
    });

    test('juste au-dessus de 1 300 000 € : redevient imposable', () {
      final result = computeIFI(1300001);
      expect(result.total, greaterThan(0));
    });

    test('patrimoine nul ou négatif ne génère aucun impôt', () {
      expect(computeIFI(0).total, 0);
      expect(computeIFI(-100).total, 0);
    });
  });
}

import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/core/simulations/simulation_state_repository.dart';
import 'package:opime/features/simulations/simulations_real_estate_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// [RealEstateSimulationScreen] regroupe Estimation/Scoring/Prêt sous un
/// seul `TabList` interne (voir sa doc de tête) — ces tests couvrent
/// uniquement la persistance de l'onglet actif (clé `'immobilier'` via
/// [SimulationStateRepository]), sur le même principe que les autres
/// écrans de simulation (`simulations_taxation_screen_test.dart`,
/// `simulations_wealth_screen_test.dart`,
/// `simulations_transmission_screen_test.dart`) : seule la logique de
/// calcul pure (real_estate_profitability_calculator_test.dart,
/// real_estate_scoring_calculator_test.dart...) était testée jusque-là.
void main() {
  group('Widget — l\'onglet actif persisté est restauré au chargement', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_real_estate_screen_',
      );
      // L'onglet "Estimation" embarque une carte (flutter_map), qui essaie
      // d'initialiser un cache de tuiles via `path_provider` — un plugin
      // sans implémentation mockée par défaut sous `flutter_test`. Sans ce
      // stub minimal, atteindre cet onglet (y compris celui sélectionné
      // par défaut) lève `MissingPluginException`.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path,
          );
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: RealEstateSimulationScreen(
              vaultPath: tempDir.path,
              amountVisibility: AmountVisibilityController(),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
    }

    testWidgets(
      'sans état sauvegardé, l\'onglet Estimation (0) est actif par défaut',
      (tester) async {
        await pumpScreen(tester);
        expect(tester.widget<TabList>(find.byType(TabList)).index, 0);
      },
    );

    testWidgets(
      'un onglet Prêt (2) déjà sauvegardé sur ce vault est restauré au '
      'chargement',
      (tester) async {
        await tester.runAsync(
          () => SimulationStateRepository(
            tempDir.path,
          ).write('immobilier', {'tabIndex': 2}),
        );

        await pumpScreen(tester);

        expect(tester.widget<TabList>(find.byType(TabList)).index, 2);
      },
    );
  });
}

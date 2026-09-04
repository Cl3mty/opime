import 'dart:io';
import 'dart:math';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/core/simulations/simulation_state_repository.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/simulations/simulations_wealth_screen.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  group('Widget — l\'onglet actif persisté est restauré au chargement', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('opime_wealth_screen_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr'), Locale('en')],
          localizationsDelegates: [
            shadcnLocalizationsFrDelegate,
            ...AppLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            child: WealthSimulationScreen(
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
      'sans état sauvegardé, l\'onglet Intérêts composés (0) est actif par '
      'défaut',
      (tester) async {
        await pumpScreen(tester);
        expect(tester.widget<TabList>(find.byType(TabList)).index, 0);
      },
    );

    testWidgets(
      'un onglet Monte-Carlo (1) déjà sauvegardé sur ce vault est restauré '
      'au chargement',
      (tester) async {
        await tester.runAsync(
          () => SimulationStateRepository(
            tempDir.path,
          ).write('wealth', {'tabIndex': 1}),
        );

        await pumpScreen(tester);

        expect(tester.widget<TabList>(find.byType(TabList)).index, 1);
      },
    );
  });

  group('monthlyRateFromAnnualPct', () {
    test('rendement nul -> taux mensuel nul', () {
      expect(monthlyRateFromAnnualPct(0), 0);
    });

    test('composé sur 12 mois redonne le taux annuel', () {
      final monthly = monthlyRateFromAnnualPct(8);
      final annualFromMonthly = pow(1 + monthly, 12) - 1;
      expect(annualFromMonthly, closeTo(0.08, 1e-9));
    });
  });

  group('gaussianSample', () {
    test(
      'moyenne et écart-type empiriques proches des paramètres sur un grand échantillon',
      () {
        final rng = Random(42);
        const mean = 8.0;
        const stddev = 15.0;
        const n = 20000;

        final samples = List.generate(
          n,
          (_) => gaussianSample(rng, mean, stddev),
        );
        final empiricalMean = samples.reduce((a, b) => a + b) / n;
        final variance =
            samples
                .map((v) => (v - empiricalMean) * (v - empiricalMean))
                .reduce((a, b) => a + b) /
            n;
        final empiricalStddev = sqrt(variance);

        expect(empiricalMean, closeTo(mean, 0.5));
        expect(empiricalStddev, closeTo(stddev, 0.5));
      },
    );
  });

  group('computeWealthProjection (déterministe, intérêts composés)', () {
    test(
      'sans versement ni rendement, la valeur future égale le patrimoine initial',
      () {
        final result = computeWealthProjection(
          patrimoineActuel: 100000,
          repartitionInitialeBourse: 50,
          investissementsMensuels: 0,
          repartitionInvestBourse: 50,
          nombreAnnees: 10,
          rendementBourse: 0,
          rendementAutre: 0,
          impositionBourse: 0,
          impositionAutre: 0,
          tauxRetrait: 4,
          tauxInflation: 0,
        );

        expect(result.valeurFuture, closeTo(100000, 0.01));
        expect(result.plusValue, closeTo(0, 0.01));
      },
    );

    test(
      'sans rendement, la valeur future égale patrimoine initial + versements cumulés',
      () {
        final result = computeWealthProjection(
          patrimoineActuel: 50000,
          repartitionInitialeBourse: 100,
          investissementsMensuels: 500,
          repartitionInvestBourse: 100,
          nombreAnnees: 5,
          rendementBourse: 0,
          rendementAutre: 0,
          impositionBourse: 0,
          impositionAutre: 0,
          tauxRetrait: 4,
          tauxInflation: 0,
        );

        expect(result.valeurFuture, closeTo(50000 + 500 * 60, 0.01));
      },
    );

    test(
      'croissance composée cohérente avec un taux annuel de 5% sur 10 ans',
      () {
        final result = computeWealthProjection(
          patrimoineActuel: 100000,
          repartitionInitialeBourse: 100,
          investissementsMensuels: 0,
          repartitionInvestBourse: 100,
          nombreAnnees: 10,
          rendementBourse: 5,
          rendementAutre: 0,
          impositionBourse: 0,
          impositionAutre: 0,
          tauxRetrait: 4,
          tauxInflation: 0,
        );

        final expected = 100000 * pow(1.05, 10);
        expect(result.valeurFuture, closeTo(expected, 1));
      },
    );

    test(
      'sans inflation, la valeur "pouvoir d\'achat actuel" égale la valeur nette nominale',
      () {
        final result = computeWealthProjection(
          patrimoineActuel: 100000,
          repartitionInitialeBourse: 100,
          investissementsMensuels: 200,
          repartitionInvestBourse: 100,
          nombreAnnees: 15,
          rendementBourse: 6,
          rendementAutre: 0,
          impositionBourse: 18.6,
          impositionAutre: 0,
          tauxRetrait: 4,
          tauxInflation: 0,
        );

        expect(result.valeurNetteReelle, closeTo(result.valeurNette, 0.01));
        expect(result.revenuMensuelReel, closeTo(result.revenuMensuel, 0.01));
      },
    );

    test(
      'avec de l\'inflation, la valeur réelle est actualisée à la baisse (régression : champ auparavant ignoré)',
      () {
        final result = computeWealthProjection(
          patrimoineActuel: 100000,
          repartitionInitialeBourse: 100,
          investissementsMensuels: 200,
          repartitionInvestBourse: 100,
          nombreAnnees: 20,
          rendementBourse: 7,
          rendementAutre: 0,
          impositionBourse: 18.6,
          impositionAutre: 0,
          tauxRetrait: 4,
          tauxInflation: 3,
        );

        expect(result.valeurNetteReelle, lessThan(result.valeurNette));
        final expectedFactor = pow(1.03, 20);
        expect(
          result.valeurNetteReelle,
          closeTo(result.valeurNette / expectedFactor, 0.01),
        );
      },
    );
  });

  group('computeMonteCarloProjection', () {
    test(
      'sans volatilité, converge vers la projection déterministe équivalente',
      () {
        final mc = computeMonteCarloProjection(
          patrimoineActuel: 100000,
          repartitionInitialeBourse: 100,
          investissementsMensuels: 300,
          repartitionInvestBourse: 100,
          nombreAnnees: 10,
          rendementBourse: 5,
          ecartTypeBourse: 0,
          rendementAutre: 0,
          ecartTypeAutre: 0,
          impositionBourse: 0,
          impositionAutre: 0,
          tauxRetrait: 4,
          nombreSimulations: 50,
        );

        final deterministic = computeWealthProjection(
          patrimoineActuel: 100000,
          repartitionInitialeBourse: 100,
          investissementsMensuels: 300,
          repartitionInvestBourse: 100,
          nombreAnnees: 10,
          rendementBourse: 5,
          rendementAutre: 0,
          impositionBourse: 0,
          impositionAutre: 0,
          tauxRetrait: 4,
          tauxInflation: 0,
        );

        expect(mc.valeurNetteP10, closeTo(mc.valeurNetteP90, 0.01));
        expect(mc.valeurFutureMediane, closeTo(deterministic.valeurFuture, 1));
      },
    );

    test('avec volatilité, les percentiles sont correctement ordonnés', () {
      final mc = computeMonteCarloProjection(
        patrimoineActuel: 100000,
        repartitionInitialeBourse: 60,
        investissementsMensuels: 400,
        repartitionInvestBourse: 60,
        nombreAnnees: 20,
        rendementBourse: 8,
        ecartTypeBourse: 15,
        rendementAutre: 4,
        ecartTypeAutre: 3,
        impositionBourse: 18.6,
        impositionAutre: 31.4,
        tauxRetrait: 4,
        nombreSimulations: 400,
        random: Random(7),
      );

      expect(mc.valeurNetteP10, lessThanOrEqualTo(mc.valeurNetteMediane));
      expect(mc.valeurNetteMediane, lessThanOrEqualTo(mc.valeurNetteP90));
      for (final point in mc.points) {
        expect(point.p10, lessThanOrEqualTo(point.p50));
        expect(point.p50, lessThanOrEqualTo(point.p90));
      }
    });

    test(
      'la graine par défaut est fixe : deux appels identiques donnent le même résultat',
      () {
        MCResult params() => computeMonteCarloProjection(
          patrimoineActuel: 80000,
          repartitionInitialeBourse: 70,
          investissementsMensuels: 250,
          repartitionInvestBourse: 70,
          nombreAnnees: 12,
          rendementBourse: 7,
          ecartTypeBourse: 12,
          rendementAutre: 3,
          ecartTypeAutre: 2,
          impositionBourse: 18.6,
          impositionAutre: 31.4,
          tauxRetrait: 4,
          nombreSimulations: 100,
        );

        final first = params();
        final second = params();
        expect(first.valeurNetteMediane, second.valeurNetteMediane);
        expect(first.valeurNetteP10, second.valeurNetteP10);
        expect(first.valeurNetteP90, second.valeurNetteP90);
      },
    );
  });
}

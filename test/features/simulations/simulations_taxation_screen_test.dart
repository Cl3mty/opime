import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/core/simulations/simulation_state_repository.dart';
import 'package:opime/features/investments/investments_models.dart';
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
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      
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

    testWidgets(
      'un onglet PFU (2) déjà sauvegardé sur ce vault est restauré au '
      'chargement, plutôt que de retomber sur IR par défaut',
      (tester) async {
        await tester.runAsync(
          () => SimulationStateRepository(
            tempDir.path,
          ).write('taxation', {'tabIndex': 2}),
        );

        await pumpScreen(tester);

        expect(tester.widget<TabList>(find.byType(TabList)).index, 2);
      },
    );
  });

  group('computePFU (retrait PEA / Assurance-Vie)', () {
    // Référence fixe pour les tests : le 1er janvier 2024.
    final reference = DateTime(2024, 1, 1);

    PFUResult peaUnder5yrs() => computePFU(
          withdrawalAmount: 10000,
          investedAmount: 8000,
          currentValue: 12000,
          openingDate: reference.subtract(const Duration(days: 365 * 3)),
          envelope: AccountEnvelope.pea,
          referenceDate: reference,
        );

    PFUResult peaOver5yrs() => computePFU(
          withdrawalAmount: 10000,
          investedAmount: 8000,
          currentValue: 12000,
          openingDate: reference.subtract(const Duration(days: 365 * 6)),
          envelope: AccountEnvelope.pea,
          referenceDate: reference,
        );

    PFUResult avUnder8yrs() => computePFU(
          withdrawalAmount: 10000,
          investedAmount: 8000,
          currentValue: 12000,
          openingDate: reference.subtract(const Duration(days: 365 * 3)),
          envelope: AccountEnvelope.assuranceVie,
          referenceDate: reference,
        );

    PFUResult avOver8yrs() => computePFU(
          withdrawalAmount: 10000,
          investedAmount: 8000,
          currentValue: 12000,
          openingDate: reference.subtract(const Duration(days: 365 * 10)),
          envelope: AccountEnvelope.assuranceVie,
          referenceDate: reference,
        );

    test('PEA avant 5 ans : PFU sur la part proportionnelle du gain', () {
      final result = peaUnder5yrs();
      // Gain latent = 12 000 − 8 000 = 4 000 €.
      // Retrait 10 000 / valeur 12 000 → proportion 5/6 du gain = 3 333,33 €.
      expect(result.gain, closeTo(4000, 0.01));
      expect(result.gainImposable, closeTo(3333.33, 0.01));
      expect(result.isExempt, isFalse);
      // IR 12.8% + PS 18.6% sur 3 333,33 €.
      expect(result.pfuIr, closeTo(426.67, 0.01));
      expect(result.pfuPs, closeTo(620.0, 0.01));
      expect(result.pfuTotal, closeTo(1046.67, 0.01));
      // Net reçu = 10 000 − 1 046,67.
      expect(result.netAfterPfu, closeTo(8953.33, 0.01));
      // Pas de comparaison barème pour le PEA.
      expect(result.baremeTotal, isNull);
    });

    test('PEA après 5 ans : exonération totale', () {
      final result = peaOver5yrs();
      expect(result.isExempt, isTrue);
      expect(result.gainImposable, 0);
      expect(result.pfuIr, 0);
      expect(result.pfuPs, 0);
      expect(result.pfuTotal, 0);
      expect(result.netAfterPfu, 10000);
    });

    test('Assurance-Vie avant 8 ans : abattement de 4 600 €', () {
      final result = avUnder8yrs();
      final gainImposable = 3333.33 - 4600.0;
      expect(result.gainImposable, closeTo(max(0, gainImposable), 0.01));
      // Le gain proportionnel est inférieur à l'abattement → aucun impôt.
      expect(result.gainImposable, 0);
      expect(result.pfuTotal, 0);
      expect(result.netAfterPfu, 10000);
      // La comparaison barème est fournie.
      expect(result.baremeTotal, isNotNull);
    });

    test('Assurance-Vie après 8 ans : abattement de 9 200 €', () {
      final result = avOver8yrs();
      expect(result.gainImposable, 0);
      expect(result.pfuTotal, 0);
    });

    test('Assurance-Vie : un gain supérieur à l\'abattement est imposé', () {
      final result = computePFU(
        withdrawalAmount: 20000,
        investedAmount: 8000,
        currentValue: 30000,
        openingDate: reference.subtract(const Duration(days: 365 * 3)),
        envelope: AccountEnvelope.assuranceVie,
        referenceDate: reference,
      );
      // Gain latent = 22 000 €. Retrait 20 000 / 30 000 → 2/3 → 14 666,67 €.
      final gainRetrait = 22000.0 * (20000.0 / 30000.0);
      expect(result.gainImposable, closeTo(gainRetrait - 4600.0, 0.01));
      // PFU total sur le gain imposable.
      expect(
        result.pfuTotal,
        closeTo((gainRetrait - 4600.0) * 0.314, 0.2),
      );
    });

    test('gain nul ou négatif : aucun impôt, même en deçà de 5 ans', () {
      final result = computePFU(
        withdrawalAmount: 5000,
        investedAmount: 10000,
        currentValue: 10000,
        openingDate: reference.subtract(const Duration(days: 365 * 2)),
        envelope: AccountEnvelope.pea,
        referenceDate: reference,
      );
      expect(result.gain, 0);
      expect(result.gainImposable, 0);
      expect(result.pfuTotal, 0);
      expect(result.netAfterPfu, 5000);
    });

    test('retrait proportionnel : moitié du retrait quand la valeur est '
        'égale au gain', () {
      // Valeur = investi + gain, retrait = 50% de la valeur.
      final result = computePFU(
        withdrawalAmount: 10000,
        investedAmount: 0,
        currentValue: 20000,
        openingDate: reference.subtract(const Duration(days: 365 * 2)),
        envelope: AccountEnvelope.pea,
        referenceDate: reference,
      );
      // Tout est gain : retrait 10 000 / 20 000 = 50% de la valeur → le
      // gain réalisé est proportionnel : 20 000 * 0.5 = 10 000 €.
      expect(result.gain, closeTo(20000, 0.01));
      expect(result.gainImposable, closeTo(10000, 0.01));
    });

    test('taux PFU personnalisés (Réglages) sont respectés', () {
      final defaultResult = peaUnder5yrs();
      final customResult = computePFU(
        withdrawalAmount: 10000,
        investedAmount: 8000,
        currentValue: 12000,
        openingDate: reference.subtract(const Duration(days: 365 * 3)),
        envelope: AccountEnvelope.pea,
        pfuIrRate: 15.0,
        pfuPsRate: 20.0,
        referenceDate: reference,
      );
      // 3 333,33 € * (15% + 20%) = 1 166,67 € > 1 046,67 € par défaut.
      expect(customResult.pfuTotal, greaterThan(defaultResult.pfuTotal));
    });

    test('comparaison barème AV : le PFU et le barème progressif sont '
        'calculés sur le même gain imposable', () {
      // Gain imposable suffisant pour être imposable (au-delà de l'abattement
      // de 4 600 €).
      final result = computePFU(
        withdrawalAmount: 20000,
        investedAmount: 8000,
        currentValue: 30000,
        openingDate: reference.subtract(const Duration(days: 365 * 3)),
        envelope: AccountEnvelope.assuranceVie,
        referenceDate: reference,
      );
      final gainImposable = 22000.0 * (20000.0 / 30000.0) - 4600.0;

      // IR barème progressif sur le gain imposable.
      final ir = computeIR(
        netImposable: gainImposable,
        nbrParts: 1,
      );
      expect(result.baremeIr, closeTo(ir.total, 0.01));
      // PS identiques au PFU (même taux).
      expect(result.baremePs, closeTo(gainImposable * 0.186, 0.01));
      expect(result.baremeTotal, closeTo(ir.total + gainImposable * 0.186, 0.01));
      expect(result.netAfterBareme, closeTo(20000 - result.baremeTotal!, 0.01));
    });
  });

  group('computePFURente (rente programmée assurance-vie)', () {
    // Référence fixe pour les tests : le 1er janvier 2024.
    final reference = DateTime(2024, 1, 1);

    test('part du gain constante : proportionnelle au couple '
        'valeur/investi', () {
      final result = computePFURente(
        monthlyWithdrawal: 500,
        capitalInvested: 100000,
        capitalValue: 150000,
        openingDate: reference.subtract(const Duration(days: 365 * 10)),
        startDate: reference,
        durationYears: 10,
      );
      // 50 000 € de gain sur 150 000 € → un tiers de chaque retrait.
      expect(result.gainShare, closeTo(1 / 3, 0.001));
      // 10 années simulées : le capital (150 000 €) suffit pour les 10 ans
      // demandés à 500 €/mois.
      expect(result.years.length, 10);
      expect(result.capitalExhausted, isFalse);
      expect(result.totalWithdrawn, closeTo(500 * 12 * 10, 0.01));
      // Chaque année : gain 2 000 €, abattement 9 200 € (contrat ≥ 8 ans) →
      // aucun impôt.
      for (final y in result.years) {
        expect(y.abattement, 9200);
        expect(y.gain, closeTo(2000, 0.01));
        expect(y.taxableGain, 0);
        expect(y.pfuTotal, 0);
        expect(y.netAfterPfu, closeTo(y.withdrawal, 0.01));
      }
      expect(result.totalPfu, 0);
      expect(result.effectiveRate, 0);
    });

    test('abattement annuel : 4 600 € puis 9 200 € à 8 ans d\'ancienneté', () {
      final result = computePFURente(
        monthlyWithdrawal: 2000,
        capitalInvested: 100000,
        capitalValue: 150000,
        openingDate: reference.subtract(const Duration(days: 365 * 5)),
        startDate: reference,
        durationYears: 10,
      );
      // Gain part = 1/3 → gain annuel = 24 000 × 1/3 = 8 000 €.
      // Années 1 à 4 : ancienneté < 8 ans → abattement 4 600 €.
      // Année 5 (ancienneté ≥ 8 ans) : abattement 9 200 €.
      expect(result.years.length, greaterThanOrEqualTo(5));
      expect(result.years[0].abattement, 4600);
      expect(result.years[1].abattement, 4600);
      expect(result.years[2].abattement, 4600);
      expect(result.years[3].abattement, 4600);
      for (var i = 0; i < 4; i++) {
        expect(result.years[i].gain, closeTo(8000, 0.01));
        expect(result.years[i].taxableGain, closeTo(8000 - 4600, 0.01));
      }
      expect(result.years[4].abattement, 9200);
      expect(result.years[4].taxableGain, 0);
    });

    test('contrat de 8 ans et plus : abattement de 9 200 € chaque année', () {
      final result = computePFURente(
        monthlyWithdrawal: 2000,
        capitalInvested: 100000,
        capitalValue: 150000,
        openingDate: reference.subtract(const Duration(days: 365 * 10)),
        startDate: reference,
        durationYears: 3,
      );
      for (final y in result.years) {
        expect(y.abattement, 9200);
        // Gain annuel 8 000 € < abattement → aucune imposition.
        expect(y.taxableGain, 0);
        expect(y.pfuTotal, 0);
      }
      expect(result.totalPfu, 0);
    });

    test('imposition PFU au-delà de l\'abattement, tenant compte de '
        'l\'épuisement du capital', () {
      final result = computePFURente(
        monthlyWithdrawal: 6000,
        capitalInvested: 50000,
        capitalValue: 200000,
        openingDate: reference.subtract(const Duration(days: 365 * 10)),
        startDate: reference,
        durationYears: 10,
      );
      // Gain part = 75 % → gain annuel = 72 000 × 0,75 = 54 000 €.
      // Taxable = 54 000 − 9 200 = 44 800 €.
      expect(result.gainShare, closeTo(0.75, 0.001));
      expect(result.years.every((y) => y.abattement == 9200), isTrue);
      final year = result.years.first;
      expect(year.gain, closeTo(54000, 0.01));
      expect(year.taxableGain, closeTo(44800, 0.01));
      expect(year.pfuIr, closeTo(44800 * 0.128, 0.01));
      expect(year.pfuPs, closeTo(44800 * 0.186, 0.01));
      expect(year.pfuTotal, closeTo(44800 * 0.314, 0.01));
      expect(year.netAfterPfu, closeTo(72000 - 44800 * 0.314, 0.01));
      // Le capital (200 000 €) est épuisé après 2 années de 72 000 € :
      // la durée demandée (10 ans) est tronquée.
      expect(result.years.length, 2);
      expect(result.capitalExhausted, isTrue);
      expect(result.totalWithdrawn, closeTo(144000, 0.01));
      expect(result.totalPfu, closeTo(44800 * 0.314 * 2, 0.01));
      expect(result.totalNet, closeTo(result.totalWithdrawn - result.totalPfu, 0.01));
      expect(result.effectiveRate, closeTo(44800 * 0.314 / 72000 * 100, 0.01));
    });

    test('le rendement annuel du capital restant prolonge la rente', () {
      PFURenteResult run(double performance) => computePFURente(
            monthlyWithdrawal: 1000,
            capitalInvested: 30000,
            capitalValue: 60000,
            openingDate: reference.subtract(const Duration(days: 365 * 7)),
            startDate: reference,
            durationYears: 10,
            annualPerformance: performance,
          );

      final withoutPerf = run(0);
      final withPerf = run(5);
      // Sans rendement : 60 000 / 12 000 = 5 ans (dernière année épuisée).
      expect(withoutPerf.years.length, lessThan(10));
      // Avec 5 % de rendement, les retraits sont en partie compensés par la
      // croissance du capital restant : la rente dure plus longtemps.
      expect(withPerf.years.length, greaterThan(withoutPerf.years.length));
      expect(withPerf.totalWithdrawn, greaterThan(withoutPerf.totalWithdrawn));
      expect(withPerf.capitalExhausted, isTrue);
    });

    test('rente trop élevée pour le capital : aucune année simulée', () {
      final result = computePFURente(
        monthlyWithdrawal: 1000,
        capitalInvested: 10000,
        capitalValue: 10000,
        openingDate: reference.subtract(const Duration(days: 365 * 2)),
        startDate: reference,
        durationYears: 10,
      );
      expect(result.years, isEmpty);
      expect(result.capitalExhausted, isTrue);
      expect(result.totalWithdrawn, 0);
      expect(result.totalPfu, 0);
      expect(result.effectiveRate, 0);
    });

    test('part du gain bornée entre 0 et 1', () {
      // Tout est gain.
      final allGain = computePFURente(
        monthlyWithdrawal: 100,
        capitalInvested: 0,
        capitalValue: 200000,
        openingDate: reference.subtract(const Duration(days: 365 * 10)),
        startDate: reference,
        durationYears: 1,
      );
      expect(allGain.gainShare, 1);
      // Valeur sous le montant investi : pas de gain.
      final noGain = computePFURente(
        monthlyWithdrawal: 100,
        capitalInvested: 150000,
        capitalValue: 100000,
        openingDate: reference.subtract(const Duration(days: 365 * 10)),
        startDate: reference,
        durationYears: 1,
      );
      expect(noGain.gainShare, 0);
    });

    test('taux PFU personnalisés (Réglages) sont respectés', () {
      final result = computePFURente(
        monthlyWithdrawal: 6000,
        capitalInvested: 50000,
        capitalValue: 200000,
        openingDate: reference.subtract(const Duration(days: 365 * 10)),
        startDate: reference,
        durationYears: 10,
        pfuIrRate: 15.0,
        pfuPsRate: 20.0,
      );
      final year = result.years.first;
      expect(year.pfuIr, closeTo(44800 * 0.15, 0.01));
      expect(year.pfuPs, closeTo(44800 * 0.20, 0.01));
    });
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

  group(
    'override des paramètres fiscaux (Réglages → Paramètres fiscaux)',
    () {
      test(
        'computeIR sans override reproduit le barème par défaut '
        '(non-régression : les paramètres optionnels ne changent rien tant '
        'qu\'on ne les fournit pas)',
        () {
          final withDefaults = computeIR(netImposable: 150000, nbrParts: 1);
          final explicit = computeIR(
            netImposable: 150000,
            nbrParts: 1,
            limits: irLimits,
            rates: irRates,
          );
          expect(withDefaults.total, explicit.total);
        },
      );

      test(
        'computeIR avec un barème personnalisé (ex : seuils relevés par '
        'l\'État) donne un résultat différent du barème par défaut',
        () {
          final withDefaultBareme = computeIR(
            netImposable: 50000,
            nbrParts: 1,
          );
          // Premier seuil doublé : le même revenu tombe dans une tranche
          // inférieure, donc paie moins d'impôt.
          final withHigherThreshold = computeIR(
            netImposable: 50000,
            nbrParts: 1,
            limits: [22588.0, 28797.0, 82341.0, 177106.0],
            rates: irRates,
          );
          expect(
            withHigherThreshold.total,
            lessThan(withDefaultBareme.total),
          );
        },
      );

      test(
        'computeIFI avec un seuil d\'imposition personnalisé change '
        'l\'exonération (ex : seuil abaissé par l\'État)',
        () {
          // 1 000 000 € : exonéré au seuil par défaut (1 300 000 €).
          expect(computeIFI(1000000).total, 0);
          final withLowerSeuil = computeIFI(1000000, seuilImposition: 500000);
          expect(withLowerSeuil.total, greaterThan(0));
        },
      );

      test(
        'computeIFI avec des taux personnalisés change le montant dû',
        () {
          final withDefaultRates = computeIFI(2000000);
          final withHigherRates = computeIFI(
            2000000,
            limits: ifiLimits,
            rates: [0.0, 1.0, 1.4, 2.0, 2.5, 3.0], // taux doublés
          );
          expect(withHigherRates.total, greaterThan(withDefaultRates.total));
        },
      );
    },
  );
}

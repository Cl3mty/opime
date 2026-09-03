import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/core/simulations/simulation_state_repository.dart';
import 'package:opime/features/simulations/simulations_transmission_screen.dart';
import 'package:opime/features/simulations/tax_parameters.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  group('Widget — l\'onglet actif persisté est restauré au chargement', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_transmission_screen_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: TransmissionSimulationScreen(
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
      'sans état sauvegardé, l\'onglet Démembrement (0) est actif par '
      'défaut',
      (tester) async {
        await pumpScreen(tester);
        expect(tester.widget<TabList>(find.byType(TabList)).index, 0);
      },
    );

    testWidgets(
      'un onglet Héritage (2) déjà sauvegardé sur ce vault est restauré au '
      'chargement',
      (tester) async {
        await tester.runAsync(
          () => SimulationStateRepository(
            tempDir.path,
          ).write('transmission', {'tabIndex': 2}),
        );

        await pumpScreen(tester);

        expect(tester.widget<TabList>(find.byType(TabList)).index, 2);
      },
    );
  });

  group('computeRights (barème progressif par tranches)', () {
    test('taxable nul ou négatif ne génère aucun droit', () {
      expect(directLineRights(0), 0);
      expect(directLineRights(-100), 0);
    });

    test('barème ligne directe (article 777 CGI) : taxable de 100 000 €', () {
      // 8 072 * 5% + 4 037 * 10% + 3 823 * 15% + 84 068 * 20%
      expect(directLineRights(100000), closeTo(18194.35, 0.01));
    });

    test(
      'barème ligne directe : taxable dans la première tranche uniquement',
      () {
        expect(directLineRights(8072), closeTo(403.6, 0.01));
      },
    );

    test('barème ligne directe est croissant avec le taxable', () {
      expect(directLineRights(50000), greaterThan(directLineRights(10000)));
      expect(directLineRights(2000000), greaterThan(directLineRights(1000000)));
    });

    test(
      'barème conjoint/PACS : 2e tranche correcte (8 072 à 15 932 €, pas 15 109 €)',
      () {
        // Régression : la 2e tranche du barème conjoint était plafonnée à 15 109 €
        // au lieu de 15 932 € (seuil officiel, identique à la ligne directe à ce niveau).
        // Pour un taxable de 20 000 € :
        // 8 072 * 5% + 7 860 * 10% + 4 068 * 15% = 403.6 + 786.0 + 610.2 = 1 799.8
        expect(spouseRights(20000), closeTo(1799.8, 0.01));
      },
    );

    test(
      'barème conjoint/PACS diffère du barème ligne directe entre 15 932 € et 31 865 €',
      () {
        // Dans cette fourchette, le taux ligne directe est déjà à 20% alors que
        // le taux conjoint est encore à 15% : les deux barèmes doivent diverger.
        expect(
          spouseRights(25000),
          isNot(closeTo(directLineRights(25000), 0.01)),
        );
      },
    );
  });

  group('abattementFor', () {
    test('abattements légaux par lien de parenté', () {
      expect(abattementFor(DonationRelation.enfant), 100000);
      expect(abattementFor(DonationRelation.petitEnfant), 31865);
      expect(abattementFor(DonationRelation.conjoint), 80724);
    });
  });

  group('nueProprietePct (barème article 669 CGI)', () {
    test('bornes officielles par tranche d\'âge', () {
      expect(nueProprietePct(18), 10);
      expect(nueProprietePct(20), 10);
      expect(nueProprietePct(21), 20);
      expect(nueProprietePct(30), 20);
      expect(nueProprietePct(31), 30);
      expect(nueProprietePct(50), 40);
      expect(nueProprietePct(62), 60);
      expect(nueProprietePct(80), 70);
      expect(nueProprietePct(90), 80);
      expect(nueProprietePct(91), 90);
      expect(nueProprietePct(110), 90);
    });
  });

  group('computeDemembrement', () {
    test('valeur 1M€, usufruitier 62 ans, 2 enfants, abattement 100k', () {
      final result = computeDemembrement(
        valeurPleinePropriete: 1000000,
        ageUsufruitier: 62,
        nombreEnfants: 2,
        abattementParEnfant: 100000,
      );

      expect(result.nueProprietePct, 60);
      expect(result.usufruitPct, 40);
      expect(result.valeurNuePropriete, closeTo(600000, 0.01));
      // Détail : voir computeRights, taxable/enfant = 200 000 € puis 400 000 €.
      expect(result.droitsTotauxNue, closeTo(76388.7, 0.02));
      expect(result.droitsTotauxPleine, closeTo(156388.7, 0.02));
      expect(result.economiePotentielle, closeTo(80000, 0.02));
    });

    test(
      'le démembrement ne coûte jamais plus cher que la pleine propriété',
      () {
        for (final age in [18, 25, 45, 65, 85, 105]) {
          final result = computeDemembrement(
            valeurPleinePropriete: 750000,
            ageUsufruitier: age,
            nombreEnfants: 3,
            abattementParEnfant: 100000,
          );
          expect(
            result.droitsTotauxNue,
            lessThanOrEqualTo(result.droitsTotauxPleine),
          );
          expect(result.economiePotentielle, greaterThanOrEqualTo(0));
        }
      },
    );
  });

  group('computeDonation', () {
    test('donation à des enfants, répartie également', () {
      final result = computeDonation(
        montantDonation: 400000,
        nombreDonataires: 2,
        relation: DonationRelation.enfant,
      );

      expect(result.abattementParDonataire, 100000);
      expect(result.montantParDonataire, 200000);
      expect(result.taxableParDonataire, 100000);
      expect(result.droitsParDonataire, closeTo(18194.35, 0.01));
      expect(result.droitsTotaux, closeTo(36388.7, 0.02));
      expect(result.tauxEffectif, closeTo(9.0972, 0.01));
    });

    test(
      'donation au conjoint utilise le barème spécifique (régression 15 932 €)',
      () {
        final result = computeDonation(
          montantDonation: 100724,
          nombreDonataires: 1,
          relation: DonationRelation.conjoint,
        );

        expect(result.abattementParDonataire, 80724);
        expect(result.taxableParDonataire, closeTo(20000, 0.01));
        expect(result.droitsParDonataire, closeTo(1799.8, 0.01));
      },
    );

    test(
      'donation entièrement couverte par l\'abattement ne génère aucun droit',
      () {
        final result = computeDonation(
          montantDonation: 150000,
          nombreDonataires: 2,
          relation: DonationRelation.enfant,
        );
        expect(result.taxableParDonataire, 0);
        expect(result.droitsTotaux, 0);
        expect(result.tauxEffectif, 0);
      },
    );
  });

  group('computeInheritance', () {
    test('avec conjoint survivant exonéré sur sa part', () {
      final result = computeInheritance(
        actifNetSuccessoral: 1200000,
        conjointSurvivant: true,
        partConjointPct: 25,
        nombreEnfants: 2,
        abattementParEnfant: 100000,
      );

      expect(result.partConjointExoneree, 300000);
      expect(result.masseTaxableEnfants, 900000);
      expect(result.partParEnfant, 450000);
      expect(result.taxableParEnfant, 350000);
      expect(result.droitsParEnfant, closeTo(68194.35, 0.02));
      expect(result.droitsTotauxEnfants, closeTo(136388.7, 0.02));
      expect(result.netParEnfant, closeTo(381805.65, 0.02));
    });

    test('sans conjoint survivant, toute la masse revient aux enfants', () {
      final result = computeInheritance(
        actifNetSuccessoral: 1200000,
        conjointSurvivant: false,
        partConjointPct: 25,
        nombreEnfants: 2,
        abattementParEnfant: 100000,
      );

      expect(result.partConjointExoneree, 0);
      expect(result.masseTaxableEnfants, 1200000);
    });
  });

  group(
    'override des paramètres fiscaux (Réglages → Paramètres fiscaux)',
    () {
      test(
        'directLineRights/spouseRights sans override reproduisent le '
        'barème par défaut',
        () {
          expect(
            directLineRights(100000),
            directLineRights(100000, brackets: defaultDirectLineBrackets),
          );
          expect(
            spouseRights(100000),
            spouseRights(100000, brackets: defaultSpouseBrackets),
          );
        },
      );

      test(
        'directLineRights avec un barème personnalisé (taux relevés par '
        'l\'État) donne un résultat différent du barème par défaut',
        () {
          const higherRates = [
            TaxBracket(8072, 0.10),
            TaxBracket(12109, 0.10),
            TaxBracket(15932, 0.15),
            TaxBracket(552324, 0.20),
            TaxBracket(902838, 0.30),
            TaxBracket(1805677, 0.40),
            TaxBracket(double.infinity, 0.45),
          ];
          final withDefault = directLineRights(100000);
          final withHigherRates = directLineRights(100000, brackets: higherRates);
          expect(withHigherRates, greaterThan(withDefault));
        },
      );

      test(
        'abattementFor avec des abattements personnalisés (relevés par '
        'l\'État) retourne la valeur personnalisée, pas la valeur légale '
        'par défaut',
        () {
          expect(
            abattementFor(DonationRelation.enfant, enfant: 150000),
            150000,
          );
          expect(
            abattementFor(DonationRelation.petitEnfant, petitEnfant: 40000),
            40000,
          );
          expect(
            abattementFor(DonationRelation.conjoint, conjoint: 90000),
            90000,
          );
          // Les autres relations restent inchangées par un override ciblé.
          expect(abattementFor(DonationRelation.enfant, conjoint: 90000), 100000);
        },
      );

      test(
        'nueProprietePct avec un barème personnalisé donne un résultat '
        'différent du barème par défaut',
        () {
          const custom = [UsufruitBracket(30, 50), UsufruitBracket(null, 90)];
          // 25 ans : tranche "≤30" dans les deux barèmes, mais un
          // pourcentage différent (20 % par défaut, 50 % personnalisé).
          expect(nueProprietePct(25), 20);
          expect(nueProprietePct(25, brackets: custom), 50);
        },
      );

      test(
        'computeDemembrement avec des paramètres personnalisés utilise '
        'bien le barème usufruit ET le barème ligne directe personnalisés',
        () {
          final withDefaults = computeDemembrement(
            valeurPleinePropriete: 1000000,
            ageUsufruitier: 62,
            nombreEnfants: 2,
            abattementParEnfant: 100000,
          );
          final customParams = TaxParameters.defaults.copyWith(
            demembrementBrackets: const [
              UsufruitBracket(50, 10),
              UsufruitBracket(70, 20),
              UsufruitBracket(null, 90),
            ],
          );
          final withCustom = computeDemembrement(
            valeurPleinePropriete: 1000000,
            ageUsufruitier: 62,
            nombreEnfants: 2,
            abattementParEnfant: 100000,
            params: customParams,
          );
          // 62 ans : 60 % de nue-propriété par défaut, 20 % avec le
          // barème personnalisé (tranche ≤70 → 20 %).
          expect(withDefaults.nueProprietePct, 60);
          expect(withCustom.nueProprietePct, 20);
        },
      );

      test(
        'computeDonation avec un abattement personnalisé change le '
        'montant taxable',
        () {
          final withDefaults = computeDonation(
            montantDonation: 400000,
            nombreDonataires: 2,
            relation: DonationRelation.enfant,
          );
          final withCustom = computeDonation(
            montantDonation: 400000,
            nombreDonataires: 2,
            relation: DonationRelation.enfant,
            params: TaxParameters.defaults.copyWith(abattementEnfant: 150000),
          );
          expect(withCustom.abattementParDonataire, 150000);
          expect(withCustom.taxableParDonataire, lessThan(withDefaults.taxableParDonataire));
        },
      );

      test(
        'computeInheritance avec un barème ligne directe personnalisé '
        'change les droits calculés',
        () {
          final withDefaults = computeInheritance(
            actifNetSuccessoral: 1200000,
            conjointSurvivant: true,
            partConjointPct: 25,
            nombreEnfants: 2,
            abattementParEnfant: 100000,
          );
          const higherRates = [
            TaxBracket(8072, 0.20),
            TaxBracket(12109, 0.10),
            TaxBracket(15932, 0.15),
            TaxBracket(552324, 0.20),
            TaxBracket(902838, 0.30),
            TaxBracket(1805677, 0.40),
            TaxBracket(double.infinity, 0.45),
          ];
          final withCustom = computeInheritance(
            actifNetSuccessoral: 1200000,
            conjointSurvivant: true,
            partConjointPct: 25,
            nombreEnfants: 2,
            abattementParEnfant: 100000,
            params: TaxParameters.defaults.copyWith(
              directLineBrackets: higherRates,
            ),
          );
          expect(withCustom.droitsParEnfant, greaterThan(withDefaults.droitsParEnfant));
        },
      );
    },
  );
}

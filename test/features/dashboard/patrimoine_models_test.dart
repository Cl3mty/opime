import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, Color;

void main() {
  PatrimoineAccount account({
    required double valeur,
    required double plusValueAbs,
    bool excludedFromPatrimoine = false,
  }) => PatrimoineAccount(
    name: 'Compte',
    valeur: valeur,
    plusValueAbs: plusValueAbs,
    plusValuePercent: null,
    excludedFromPatrimoine: excludedFromPatrimoine,
  );

  PatrimoineCategory category(List<PatrimoineAccount> accounts) =>
      PatrimoineCategory(
        id: 'actifs_actions_fonds',
        label: 'Actions & Fonds',
        icon: LucideIcons.trendingUp,
        color: const Color(0xFF000000),
        tier: AllocationTier.fondation,
        description: '',
        accounts: accounts,
      );

  group(
    'plusValueAbsPatrimoine (plus-value latente globale du graphique '
    'principal)',
    () {
      test(
        'somme la plus-value de tous les comptes non exclus, comme '
        'montantPatrimoine pour le montant',
        () {
          final c = category([
            account(valeur: 1000, plusValueAbs: 100),
            account(valeur: 500, plusValueAbs: -20),
          ]);
          expect(c.plusValueAbsPatrimoine, 80);
        },
      );

      test(
        'ignore la plus-value d\'un compte exclu du patrimoine, exactement '
        'comme montantPatrimoine ignore son montant',
        () {
          final c = category([
            account(valeur: 1000, plusValueAbs: 100),
            account(
              valeur: 5000,
              plusValueAbs: 900,
              excludedFromPatrimoine: true,
            ),
          ]);
          expect(c.montantPatrimoine, 1000);
          expect(c.plusValueAbsPatrimoine, 100);
          // plusValueAbs (non filtré) continue, lui, de tout compter — les
          // deux agrégats coexistent pour des usages différents.
          expect(c.plusValueAbs, 1000);
        },
      );

      test('0 sans aucun compte', () {
        expect(category(const []).plusValueAbsPatrimoine, 0);
      });
    },
  );

  group(
    'periodChangeFor/periodPnlFor (agrégat "Évolution"/"+/- value" pour une '
    'période sélectionnée)',
    () {
      PatrimoineAccount accountWithPeriod({
        required double valeur,
        required double changeEuros,
        required double pnlEuros,
      }) => PatrimoineAccount(
        name: 'Compte',
        valeur: valeur,
        plusValueAbs: null,
        plusValuePercent: null,
        periodChangeFor: (_) => (euros: changeEuros, percent: null),
        periodPnlFor: (_) => (euros: pnlEuros, percent: null),
      );

      test(
        'somme les euros de chaque ligne, recalcule le pourcentage depuis '
        'la valorisation de départ déduite de montant (même astuce de '
        'soustraction que plusValuePercent)',
        () {
          final c = category([
            accountWithPeriod(valeur: 1000, changeEuros: 100, pnlEuros: 80),
            accountWithPeriod(valeur: 500, changeEuros: -20, pnlEuros: -10),
          ]);

          final change = c.periodChangeFor(DashboardPeriod.all)!;
          expect(change.euros, 80);
          // montant = 1500, valorisation de départ = 1500 − 80 = 1420.
          expect(change.percent, closeTo(80 / 1420 * 100, 1e-9));

          final pnl = c.periodPnlFor(DashboardPeriod.all)!;
          expect(pnl.euros, 70);
        },
      );

      test(
        '`null` quand aucune ligne de la catégorie n\'a de closure — ex. '
        'periodPnlFor sur une catégorie de passifs, où cette notion n\'a '
        'pas de sens (voir PatrimoineAccount.periodPnlFor)',
        () {
          final passifLine = PatrimoineAccount(
            name: 'Prêt',
            valeur: 5000,
            plusValueAbs: -1000,
            plusValuePercent: -20,
            periodChangeFor: (_) => (euros: -100, percent: -2),
            // periodPnlFor volontairement absent, comme un vrai passif.
          );
          final c = category([passifLine]);

          expect(c.periodChangeFor(DashboardPeriod.all), isNotNull);
          expect(c.periodPnlFor(DashboardPeriod.all), isNull);
        },
      );

      test('`null` sans aucun compte', () {
        expect(category(const []).periodChangeFor(DashboardPeriod.all), isNull);
        expect(category(const []).periodPnlFor(DashboardPeriod.all), isNull);
      });
    },
  );

  group(
    'showsPnlColumn (masque entièrement la colonne "+/- value" pour un '
    'passif, plutôt qu\'un « — » systématique)',
    () {
      test('vrai pour une catégorie d\'actif réelle', () {
        expect(category(const []).showsPnlColumn, isTrue);
      });

      test('faux pour une catégorie de passif', () {
        final liabilities = PatrimoineCategory(
          id: 'passifs_prets_immobiliers',
          label: 'Prêts immobiliers',
          icon: LucideIcons.house,
          color: const Color(0xFF000000),
          tier: AllocationTier.croissance,
          description: '',
          accounts: const [],
        );
        expect(liabilities.showsPnlColumn, isFalse);
      });
    },
  );
}

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
}

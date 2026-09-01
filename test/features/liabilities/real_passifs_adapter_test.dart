import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';
import 'package:opime/features/liabilities/real_passifs_adapter.dart';
import 'package:opime/features/simulations/loan_calculator.dart';

void main() {
  group('totalBalanceOnGrid (capital restant dû échantillonné)', () {
    test('un point situé après le changement de mois calendaire mais avant '
        "l'anniversaire mensuel du prêt ne compte pas un mois de plus", () {
      // Prêt débuté le 15 : le 20 janvier suivant (5 jours plus tard,
      // mais dans le mois calendaire suivant) doit toujours refléter le
      // capital initial, pas déjà le solde après le premier paiement.
      final liability = Liability(
        type: LiabilityType.creditAutre,
        name: 'Test',
        montantEmprunte: 12000,
        tauxInteret: 3,
        nbrEcheances: 12,
        dateDebut: DateTime(2024, 1, 15),
        loanType: LoanType.amortissable,
      );

      final grid = [
        DateTime(2024, 1, 15), // jour du déblocage
        DateTime(2024, 1, 20), // même mois : toujours le capital initial
        DateTime(2024, 2, 10), // mois suivant, mais avant le 15 : idem
        DateTime(2024, 2, 15), // anniversaire exact : 1 mois écoulé
      ];

      final points = totalBalanceOnGrid([liability], grid);

      expect(points[0].value, liability.montantEmprunte);
      expect(points[1].value, liability.montantEmprunte);
      expect(
        points[2].value,
        liability.montantEmprunte,
        reason:
            'le 10 février, moins d\'un mois complet ne s\'est écoulé '
            'depuis le 15 janvier',
      );
      expect(points[3].value, liability.amortissement[0].capitalRestantDu);
    });
  });

  group('remainingBalanceHistoryFor / perLiabilityHistoryOnGrid : grille de '
      'dates jusqu\'à l\'échéance', () {
    Liability loan({required int nbrEcheances, DateTime? dateDebut}) => Liability(
      type: LiabilityType.creditAutre,
      name: 'Test',
      montantEmprunte: 12000,
      tauxInteret: 3,
      nbrEcheances: nbrEcheances,
      dateDebut: dateDebut ?? DateTime(2024, 1, 15),
      loanType: LoanType.amortissable,
    );

    test(
      'le dernier point tombe exactement à l\'échéance, capital restant dû '
      'à 0 € (régression : la grille s\'arrêtait jusqu\'à ~1/30e de la '
      'durée du prêt avant l\'échéance réelle, jamais 0 €)',
      () {
        final liability = loan(nbrEcheances: 12);
        final points = remainingBalanceHistoryFor([liability]);
        final expectedEnd = DateTime.utc(2025, 1, 15);

        expect(points.last.date, expectedEnd);
        expect(points.last.value, closeTo(0, 1e-6));
      },
    );

    test(
      'même régression sur un prêt long (20 ans) : le pas de la grille '
      '(~1/30e de la durée) est alors de plusieurs mois, l\'écart entre '
      'l\'ancien dernier point et la vraie échéance était le plus visible',
      () {
        final liability = loan(nbrEcheances: 240);
        final points = remainingBalanceHistoryFor([liability]);
        final expectedEnd = DateTime.utc(2044, 1, 15);

        expect(points.last.date, expectedEnd);
        expect(points.last.value, closeTo(0, 1e-6));
      },
    );

    test(
      'perLiabilityHistoryOnGrid : periodStart postérieur au début du prêt '
      'avance le premier point sans jamais raccourcir la projection '
      'jusqu\'à l\'échéance',
      () {
        final liability = loan(nbrEcheances: 240);
        final periodStart = DateTime.utc(2040, 1, 1);
        final history = perLiabilityHistoryOnGrid(
          [liability],
          periodStart: periodStart,
        )[liability.id]!;

        expect(history.first.date, periodStart);
        expect(history.last.date, DateTime.utc(2044, 1, 15));
        expect(history.last.value, closeTo(0, 1e-6));
      },
    );

    test(
      'perLiabilityHistoryOnGrid : periodStart antérieur au début du prêt '
      'n\'a aucun effet (la grille ne remonte jamais avant le déblocage)',
      () {
        final liability = loan(nbrEcheances: 12);
        final withEarlyPeriodStart = perLiabilityHistoryOnGrid(
          [liability],
          periodStart: DateTime.utc(2000, 1, 1),
        )[liability.id]!;
        final withoutPeriodStart = perLiabilityHistoryOnGrid(
          [liability],
        )[liability.id]!;

        expect(withEarlyPeriodStart.first.date, withoutPeriodStart.first.date);
        expect(withEarlyPeriodStart.first.date, DateTime.utc(2024, 1, 15));
      },
    );

    test(
      'la grille a une granularité mensuelle (un point par échéance), pas '
      'un échantillonnage grossier sur ~30 points quelle que soit la durée '
      '— nécessaire pour lire le capital restant dû mois par mois au '
      'survol du graphique',
      () {
        final liability = loan(nbrEcheances: 12);
        final points = remainingBalanceHistoryFor([liability]);

        // Un point de départ (déblocage) + un par échéance mensuelle.
        expect(points.length, 13);
        for (var i = 1; i < points.length; i++) {
          final previous = points[i - 1].date;
          final expected = DateTime.utc(
            previous.year,
            previous.month + 1,
            previous.day,
          );
          expect(
            points[i].date,
            expected,
            reason: 'le point $i devrait être exactement un mois après le '
                'point ${i - 1}',
          );
        }
      },
    );

    test(
      'même granularité mensuelle sur un prêt long (20 ans, 240 '
      'échéances) : l\'ancien pas grossier (~1/30e de la durée) aurait '
      'produit environ 30 points au lieu de 241',
      () {
        final liability = loan(nbrEcheances: 240);
        final points = remainingBalanceHistoryFor([liability]);
        expect(points.length, 241);
      },
    );
  });

  group('periodChangeFor (colonne "Évolution" pour un passif)', () {
    test(
      'sur la période "Tout", reflète le capital déjà remboursé depuis le '
      'déblocage — négatif (la dette a baissé), jusqu\'à -montantEmprunte '
      'une fois le prêt totalement soldé',
      () {
        // Prêt de 12 mensualités débuté en 2015 : totalement amorti bien
        // avant aujourd'hui, quelle que soit la date réelle d'exécution du
        // test — un scénario déterministe sans dépendre de `DateTime.now()`
        // au moment précis de la run (même principe que les tests
        // `_positionReturnForPeriod`/`periodReturnFor` côté actifs, dont
        // l'historique de cours tient flat après le dernier point connu).
        final liability = Liability(
          type: LiabilityType.creditAutre,
          name: 'Test',
          montantEmprunte: 12000,
          tauxInteret: 3,
          nbrEcheances: 12,
          dateDebut: DateTime(2015, 1, 15),
          loanType: LoanType.amortissable,
        );

        final change = periodChangeFor([liability], DashboardPeriod.all);

        expect(change.euros, closeTo(-12000, 1e-6));
        expect(change.percent, closeTo(-100, 1e-6));
      },
    );

    test(
      'sans aucun remboursement (prêt débuté aujourd\'hui), le delta est nul',
      () {
        final liability = Liability(
          type: LiabilityType.creditAutre,
          name: 'Test',
          montantEmprunte: 12000,
          tauxInteret: 3,
          nbrEcheances: 12,
          dateDebut: DateTime.now(),
          loanType: LoanType.amortissable,
        );

        final change = periodChangeFor([liability], DashboardPeriod.all);

        expect(change.euros, closeTo(0, 1e-6));
      },
    );
  });

  test(
    'buildRealPassifCategories : la feuille d\'un passif porte '
    'periodChangeFor mais pas periodPnlFor — la notion de performance hors '
    'flux n\'a pas de sens pour une dette',
    () {
      final liability = Liability(
        type: LiabilityType.creditAutre,
        name: 'Test',
        montantEmprunte: 12000,
        tauxInteret: 3,
        nbrEcheances: 12,
        dateDebut: DateTime(2015, 1, 15),
        loanType: LoanType.amortissable,
      );
      final leaf = buildRealPassifCategories([liability]).single.accounts.single;

      expect(leaf.periodChangeFor, isNotNull);
      expect(
        leaf.periodChangeFor!(DashboardPeriod.all).euros,
        closeTo(-12000, 1e-6),
      );
      expect(leaf.periodPnlFor, isNull);
    },
  );
}

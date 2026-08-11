import 'package:flutter_test/flutter_test.dart';
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
}

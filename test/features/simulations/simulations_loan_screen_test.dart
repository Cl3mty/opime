import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/features/simulations/simulations_loan_screen.dart';

void main() {
  group('simulateLoan — prêt amortissable classique', () {
    test('la mensualité suit la formule standard M = C·i / (1 - (1+i)^-n)', () {
      const montant = 100000.0;
      const tauxInteret = 3.5;
      const dureeAnnees = 20;
      final i = tauxInteret / 100 / 12;
      final n = dureeAnnees * 12;
      final expectedCapitalPlusInterest = montant * i / (1 - pow(1 + i, -n));

      final result = simulateLoan(
        montantEmprunte: montant,
        dureeAnnees: dureeAnnees,
        tauxInteret: tauxInteret,
        tauxAssurance: 0,
        fraisDossier: 0,
        fraisGarantie: 0,
        type: LoanType.amortissable,
        differeActif: false,
        dureeDiffereMois: 1,
        typeDiffere: DeferType.partielle,
      );

      expect(result.mensualite, closeTo(expectedCapitalPlusInterest, 0.01));
    });

    test('le capital est intégralement remboursé sur la durée du prêt', () {
      final result = simulateLoan(
        montantEmprunte: 200000,
        dureeAnnees: 15,
        tauxInteret: 2.8,
        tauxAssurance: 0.2,
        fraisDossier: 500,
        fraisGarantie: 900,
        type: LoanType.amortissable,
        differeActif: false,
        dureeDiffereMois: 1,
        typeDiffere: DeferType.partielle,
      );

      final capitalRembourse = result.years.fold<double>(0, (s, y) => s + y.capital * 12);
      expect(capitalRembourse, closeTo(200000, 1));
    });

    test('le coût total avec frais additionne bien les frais de dossier et de garantie', () {
      final result = simulateLoan(
        montantEmprunte: 100000,
        dureeAnnees: 20,
        tauxInteret: 3.5,
        tauxAssurance: 0.15,
        fraisDossier: 800,
        fraisGarantie: 1200,
        type: LoanType.amortissable,
        differeActif: false,
        dureeDiffereMois: 1,
        typeDiffere: DeferType.partielle,
      );

      expect(result.coutTotalAvecFrais, closeTo(result.coutTotalCredit + 2000, 0.01));
      expect(result.capitalRembourseInFine, isNull);
      expect(result.mensualiteDifferee, isNull);
    });
  });

  group('simulateLoan — prêt in fine', () {
    test('les intérêts sont constants et le capital est remboursé en une fois', () {
      final result = simulateLoan(
        montantEmprunte: 150000,
        dureeAnnees: 10,
        tauxInteret: 4.0,
        tauxAssurance: 0.1,
        fraisDossier: 0,
        fraisGarantie: 0,
        type: LoanType.inFine,
        differeActif: false,
        dureeDiffereMois: 1,
        typeDiffere: DeferType.partielle,
      );

      expect(result.capitalRembourseInFine, 150000);
      // Intérêts calculés sur le capital initial en permanence : constants d'une année à l'autre.
      expect(result.years.first.interest, closeTo(result.years.last.interest, 0.01));
      final expectedMonthlyInterest = 150000 * (4.0 / 100 / 12);
      expect(result.years.first.interest, closeTo(expectedMonthlyInterest, 0.01));
      // Le capital n'apparaît (en moyenne annuelle) que sur la dernière année.
      expect(result.years.first.capital, 0);
      expect(result.years.last.capital, closeTo(150000 / 12, 0.01));
    });
  });

  group('simulateLoan — différé de remboursement', () {
    test('franchise partielle : seuls les intérêts sont payés, le capital ne bouge pas', () {
      final result = simulateLoan(
        montantEmprunte: 100000,
        dureeAnnees: 20,
        tauxInteret: 3.5,
        tauxAssurance: 0.15,
        fraisDossier: 0,
        fraisGarantie: 0,
        type: LoanType.amortissable,
        differeActif: true,
        dureeDiffereMois: 12,
        typeDiffere: DeferType.partielle,
      );

      final expectedInterest = 100000 * (3.5 / 100 / 12);
      final expectedInsurance = 100000 * (0.15 / 100 / 12);
      expect(result.mensualiteDifferee, closeTo(expectedInterest + expectedInsurance, 0.01));
    });

    test('franchise totale : rien n\'est décaissé hors assurance (intérêts capitalisés)', () {
      final result = simulateLoan(
        montantEmprunte: 100000,
        dureeAnnees: 20,
        tauxInteret: 3.5,
        tauxAssurance: 0.15,
        fraisDossier: 0,
        fraisGarantie: 0,
        type: LoanType.amortissable,
        differeActif: true,
        dureeDiffereMois: 12,
        typeDiffere: DeferType.totale,
      );

      final expectedInsurance = 100000 * (0.15 / 100 / 12);
      // Régression : la mensualité affichée pendant un différé total ne doit
      // pas inclure les intérêts (capitalisés, donc non payés), seulement
      // l'assurance qui reste due.
      expect(result.mensualiteDifferee, closeTo(expectedInsurance, 0.001));
    });

    test('franchise totale : le capital restant dû augmente avec les intérêts capitalisés', () {
      final withoutDefer = simulateLoan(
        montantEmprunte: 100000,
        dureeAnnees: 20,
        tauxInteret: 3.5,
        tauxAssurance: 0,
        fraisDossier: 0,
        fraisGarantie: 0,
        type: LoanType.amortissable,
        differeActif: false,
        dureeDiffereMois: 1,
        typeDiffere: DeferType.totale,
      );
      final withTotalDefer = simulateLoan(
        montantEmprunte: 100000,
        dureeAnnees: 20,
        tauxInteret: 3.5,
        tauxAssurance: 0,
        fraisDossier: 0,
        fraisGarantie: 0,
        type: LoanType.amortissable,
        differeActif: true,
        dureeDiffereMois: 12,
        typeDiffere: DeferType.totale,
      );

      // Les intérêts capitalisés pendant le différé alourdissent le coût total du crédit.
      expect(withTotalDefer.coutTotalCredit, greaterThan(withoutDefer.coutTotalCredit));
    });
  });
}

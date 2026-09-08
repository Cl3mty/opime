import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/simulations/loan_calculator.dart';
import 'package:opime/features/simulations/real_estate_profitability_calculator.dart';
import 'package:opime/features/simulations/real_estate_rental_models.dart';

void main() {
  RentalUnit longTermUnit(double monthlyRent) => RentalUnit(
    label: 'Appartement',
    strategy: RentalStrategy.longTerm(monthlyRent: monthlyRent),
  );

  test('achat comptant (sans prêt) : mensualité nulle', () {
    final result = simulateRealEstateProfitability(
      prixAchat: 200000,
      fraisNotairePercent: 7.5,
      travaux: 10000,
      apport: 210000,
      units: [longTermUnit(900)],
      chargesAnnuelles: 1200,
      loan: null,
    );

    expect(result.mensualiteCredit, 0);
    expect(result.revenuLocatifAnnuelBrut, 10800);
    expect(result.revenuLocatifAnnuelNet, 10800 - 1200);
    expect(result.coutTotalProjet, 200000 * 1.075 + 10000);
    expect(result.cashFlowMensuel, closeTo((10800 - 1200) / 12, 0.01));
    expect(result.autofinance, isTrue);
  });

  test('agrège plusieurs unités (découpage en plusieurs biens)', () {
    final units = [
      longTermUnit(900),
      RentalUnit(
        label: 'Studio annexe',
        strategy: RentalStrategy.shortTerm(nightlyRate: 60, occupancyRatePercent: 50),
      ),
    ];
    final result = simulateRealEstateProfitability(
      prixAchat: 300000,
      fraisNotairePercent: 7.5,
      travaux: 0,
      apport: 300000,
      units: units,
      chargesAnnuelles: 0,
      loan: null,
    );

    final expectedBrut = 900 * 12 + 60 * 365 * 0.5;
    expect(result.revenuLocatifAnnuelBrut, closeTo(expectedBrut, 0.01));
  });

  test('avec un prêt lié : la mensualité réduit le cash-flow', () {
    final coutTotalProjet = 200000 * 1.075 + 0;
    final montantEmprunte = coutTotalProjet - 20000; // apport 20000
    final loan = simulateLoan(
      montantEmprunte: montantEmprunte,
      dureeAnnees: 20,
      tauxInteret: 3.5,
      assuranceMensuelle: 20,
      fraisDossier: 0,
      fraisGarantie: 0,
      type: LoanType.amortissable,
      differeActif: false,
      dureeDiffereMois: 0,
      typeDiffere: DeferType.partielle,
    );

    final result = simulateRealEstateProfitability(
      prixAchat: 200000,
      fraisNotairePercent: 7.5,
      travaux: 0,
      apport: 20000,
      units: [longTermUnit(900)],
      chargesAnnuelles: 1200,
      loan: loan,
    );

    expect(result.mensualiteCredit, loan.mensualite);
    expect(
      result.cashFlowMensuel,
      closeTo((10800 - 1200) / 12 - loan.mensualite, 0.01),
    );
  });

  test('frontière autofinance : cash-flow négatif => false', () {
    final loan = simulateLoan(
      montantEmprunte: 250000,
      dureeAnnees: 15,
      tauxInteret: 4,
      assuranceMensuelle: 30,
      fraisDossier: 0,
      fraisGarantie: 0,
      type: LoanType.amortissable,
      differeActif: false,
      dureeDiffereMois: 0,
      typeDiffere: DeferType.partielle,
    );

    final result = simulateRealEstateProfitability(
      prixAchat: 250000,
      fraisNotairePercent: 7.5,
      travaux: 0,
      apport: 0,
      units: [longTermUnit(700)],
      chargesAnnuelles: 1000,
      loan: loan,
    );

    expect(result.cashFlowMensuel, lessThan(0));
    expect(result.autofinance, isFalse);
  });

  test('rendements bruts/nets calculés sur le coût total du projet', () {
    final result = simulateRealEstateProfitability(
      prixAchat: 100000,
      fraisNotairePercent: 0,
      travaux: 0,
      apport: 100000,
      units: [longTermUnit(1000)],
      chargesAnnuelles: 2000,
      loan: null,
    );

    expect(result.rendementBrutPercent, closeTo(12000 / 100000 * 100, 0.01));
    expect(result.rendementNetPercent, closeTo(10000 / 100000 * 100, 0.01));
  });
}

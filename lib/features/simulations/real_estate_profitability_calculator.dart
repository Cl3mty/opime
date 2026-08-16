import 'loan_calculator.dart' show LoanResult;
import 'real_estate_rental_models.dart' show RentalUnit;

/// Résultat d'une simulation de rentabilité immobilière — voir
/// [simulateRealEstateProfitability].
class RealEstateProfitabilityResult {
  final double revenuLocatifAnnuelBrut;
  final double revenuLocatifAnnuelNet;
  final double coutTotalProjet;
  final double mensualiteCredit;
  final double cashFlowMensuel;
  final double rendementBrutPercent;
  final double rendementNetPercent;
  final bool autofinance;

  const RealEstateProfitabilityResult({
    required this.revenuLocatifAnnuelBrut,
    required this.revenuLocatifAnnuelNet,
    required this.coutTotalProjet,
    required this.mensualiteCredit,
    required this.cashFlowMensuel,
    required this.rendementBrutPercent,
    required this.rendementNetPercent,
    required this.autofinance,
  });
}

/// Simule la rentabilité globale d'un projet immobilier locatif : agrège le
/// revenu de toutes les [units] (voir `real_estate_rental_models.dart`,
/// couvre nativement le découpage en plusieurs unités, le mix saisonnier et
/// la colocation), déduit les charges annuelles, et calcule le cash-flow
/// mensuel une fois la mensualité de crédit soustraite. [loan] est le
/// résultat d'un appel indépendant à `loan_calculator.dart`'s
/// `simulateLoan`/`simulateLoanByMonths` fait par l'appelant (montant
/// emprunté = [coutTotalProjet] moins l'apport, jamais recalculé ici) —
/// `null` pour un achat comptant, sans crédit.
RealEstateProfitabilityResult simulateRealEstateProfitability({
  required double prixAchat,
  required double fraisNotairePercent,
  required double travaux,
  required double apport,
  required List<RentalUnit> units,
  required double chargesAnnuelles,
  LoanResult? loan,
}) {
  final coutTotalProjet =
      prixAchat * (1 + fraisNotairePercent / 100) + travaux;
  final revenuBrut = units.fold(0.0, (sum, unit) => sum + unit.annualGrossRevenue);
  final revenuNet = revenuBrut - chargesAnnuelles;
  final mensualiteCredit = loan?.mensualite ?? 0;
  final cashFlowMensuel = revenuNet / 12 - mensualiteCredit;

  return RealEstateProfitabilityResult(
    revenuLocatifAnnuelBrut: revenuBrut,
    revenuLocatifAnnuelNet: revenuNet,
    coutTotalProjet: coutTotalProjet,
    mensualiteCredit: mensualiteCredit,
    cashFlowMensuel: cashFlowMensuel,
    rendementBrutPercent: coutTotalProjet == 0 ? 0 : revenuBrut / coutTotalProjet * 100,
    rendementNetPercent: coutTotalProjet == 0 ? 0 : revenuNet / coutTotalProjet * 100,
    autofinance: cashFlowMensuel >= 0,
  );
}

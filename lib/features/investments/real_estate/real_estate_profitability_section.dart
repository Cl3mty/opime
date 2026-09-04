import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../../core/money_format.dart';
import '../../../core/ui/frosted_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../liabilities/liabilities_models.dart';
import '../../liabilities/liabilities_repository.dart';
import '../../simulations/loan_calculator.dart';
import '../../simulations/real_estate_profitability_calculator.dart';
import '../../simulations/real_estate_rental_models.dart';
import '../investments_models.dart';
import 'rent_models.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Onglet "Rentabilité" d'un bien immobilier — réutilise le calculateur pur
/// `simulateRealEstateProfitability` (`real_estate_profitability_calculator
/// .dart`), déjà utilisé par le simulateur autonome (`real_estate_estimation
/// _screen.dart`), mais alimenté ici par les vraies données du bien plutôt
/// qu'une saisie manuelle :
/// - Revenu locatif : somme des [RentPeriod.amountDue] des 12 derniers
///   mois, annualisée via un [RentalUnit] synthétique (voir
///   [RentalStrategy.longTerm]) pour réutiliser le calculateur tel quel
///   sans le modifier.
/// - Coût total du projet : [Investment.investedAmount] (déjà le montant
///   total payé, frais compris — pas de notion de frais de notaire séparée
///   trackée ici) + somme des [WorkItem.amount].
/// - Prêt : reconstruit un [LoanResult] complet à partir du [Liability] lié
///   (voir `RealEstateLoanLinkSection`) en rejouant [simulateLoanByMonths]
///   avec ses propres paramètres stockés — même calcul que celui qui a
///   produit son propre `Liability.amortissement`, donc cohérent avec sa
///   mensualité affichée ailleurs dans l'app.
///
/// Affichage volontairement différent du simulateur autonome (cartes
/// compactes, même style que les onglets Loyers/Travaux) plutôt qu'une
/// réutilisation littérale de sa mise en page, qui est un détail
/// d'implémentation privé de son écran — voir le plan.
///
/// Limitation connue : pas de suivi des charges annuelles récurrentes
/// (taxe foncière, assurance, gestion...) sur [Investment] aujourd'hui —
/// `chargesAnnuelles` vaut 0, le rendement "net" est donc identique au
/// "brut" tant que ce suivi n'existe pas.
class RealEstateProfitabilitySection extends StatefulWidget {
  final String vaultPath;
  final Investment investment;

  const RealEstateProfitabilitySection({
    super.key,
    required this.vaultPath,
    required this.investment,
  });

  @override
  State<RealEstateProfitabilitySection> createState() =>
      _RealEstateProfitabilitySectionState();
}

class _RealEstateProfitabilitySectionState
    extends State<RealEstateProfitabilitySection> {
  bool _loading = true;
  Liability? _linkedLiability;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await LiabilitiesRepository(widget.vaultPath).listAll();
    if (!mounted) return;
    Liability? linked;
    for (final liability in all) {
      if (liability.linkedInvestmentId == widget.investment.id) {
        linked = liability;
        break;
      }
    }
    setState(() {
      _linkedLiability = linked;
      _loading = false;
    });
  }

  double get _annualRent {
    final now = DateTime.now();
    final cutoff = DateTime(now.year - 1, now.month, now.day);
    return widget.investment.rentPeriods.fold(
      0.0,
      (sum, p) => p.periodStart.isAfter(cutoff) ? sum + p.amountDue : sum,
    );
  }

  double get _totalWorkItems =>
      widget.investment.workItems.fold(0.0, (sum, w) => sum + w.amount);

  LoanResult? get _loanResult {
    final liability = _linkedLiability;
    if (liability == null) return null;
    return simulateLoanByMonths(
      montantEmprunte: liability.montantEmprunte,
      totalMonths: liability.nbrEcheances + liability.dureeDiffereMois,
      tauxInteret: liability.tauxInteret,
      assuranceMensuelle: liability.assuranceMensuelle,
      fraisDossier: liability.fraisDossier,
      fraisGarantie: liability.fraisGarantie,
      type: liability.loanType,
      differeActif: liability.differeActif,
      dureeDiffereMois: liability.dureeDiffereMois,
      typeDiffere: liability.typeDiffere,
    );
  }

  RealEstateProfitabilityResult _simulate() => simulateRealEstateProfitability(
    prixAchat: widget.investment.investedAmount,
    fraisNotairePercent: 0,
    travaux: _totalWorkItems,
    apport: 0,
    units: [
      RentalUnit(
        label: 'Loyers perçus',
        strategy: RentalStrategy.longTerm(monthlyRent: _annualRent / 12),
      ),
    ],
    chargesAnnuelles: 0,
    loan: _loanResult,
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    if (widget.investment.rentPeriods.isEmpty) {
      return shadcn.Text(
        l10n.real_estate_profitability_no_rent_hint,
      ).muted().small();
    }
    final result = _simulate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            shadcn.Text(
              l10n.real_estate_monthly_cashflow_label(
                displaySignedEuros(result.cashFlowMensuel, false),
              ),
              style: TextStyle(
                color: result.autofinance ? _green : _red,
                fontWeight: FontWeight.w600,
              ),
            ).medium(),
            const SizedBox(width: 8),
            OutlineBadge(
              child: shadcn.Text(
                result.autofinance
                    ? l10n.real_estate_self_financed
                    : l10n.real_estate_not_self_financed,
              ).xSmall(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        shadcn.Text(
          _linkedLiability == null
              ? l10n.real_estate_cashflow_no_loan_note
              : l10n.real_estate_cashflow_with_loan_note(
                  displayEuros(result.mensualiteCredit, false),
                ),
        ).muted().xSmall(),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              label: l10n.real_estate_gross_yield_label,
              value: displayPercent(result.rendementBrutPercent),
            ),
            _StatCard(
              label: l10n.real_estate_net_yield_label,
              value: displayPercent(result.rendementNetPercent),
            ),
            _StatCard(
              label: l10n.real_estate_annual_rental_income_label,
              value: displayEuros(result.revenuLocatifAnnuelBrut, false),
            ),
            _StatCard(
              label: l10n.real_estate_total_project_cost_label,
              value: displayEuros(result.coutTotalProjet, false),
            ),
          ],
        ),
        if (widget.investment.workItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          shadcn.Text(
            l10n.real_estate_work_items_included_note(
              displayEuros(_totalWorkItems, false),
            ),
          ).muted().xSmall(),
        ],
        const SizedBox(height: 8),
        shadcn.Text(
          l10n.real_estate_annual_charges_not_tracked_note,
        ).muted().xSmall(),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            shadcn.Text(label).muted().xSmall(),
            shadcn.Text(value).medium(),
          ],
        ),
      ),
    );
  }
}

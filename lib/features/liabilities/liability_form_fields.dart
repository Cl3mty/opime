import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/ui/opime_date_picker.dart';
import '../../core/ui/toggle_button_style.dart';
import '../../l10n/app_localizations.dart';
import '../simulations/loan_calculator.dart';

/// Champs communs aux 3 formulaires de création/édition d'un passif réel
/// (`real_passif_detail_screen.dart`, `liability_detail_view.dart`,
/// `investments/complete_patrimoine_dialog.dart`) — factorisé pour que les
/// trois restent alignés plutôt que de dupliquer ces champs (et le risque
/// d'en oublier un lors d'une future évolution).
///
/// Le prix total et l'apport sont saisis séparément : le capital
/// effectivement emprunté (`Liability.montantEmprunte`) est calculé par
/// l'appelant comme `prix - apport` avant de construire le [Liability].
class LiabilityFormFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController prixController;
  final TextEditingController apportController;
  final TextEditingController tauxController;
  final TextEditingController assuranceMensuelleController;
  final TextEditingController nbrEcheancesController;
  final TextEditingController dureeDiffereController;
  final DateTime? dateDebut;
  final LoanType loanType;
  final bool differeActif;
  final DeferType typeDiffere;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<LoanType> onLoanTypeChanged;
  final ValueChanged<bool> onDiffereActifChanged;
  final ValueChanged<DeferType> onTypeDiffereChanged;

  const LiabilityFormFields({
    super.key,
    required this.nameController,
    required this.prixController,
    required this.apportController,
    required this.tauxController,
    required this.assuranceMensuelleController,
    required this.nbrEcheancesController,
    required this.dureeDiffereController,
    required this.dateDebut,
    required this.loanType,
    required this.differeActif,
    required this.typeDiffere,
    required this.onDateChanged,
    required this.onLoanTypeChanged,
    required this.onDiffereActifChanged,
    required this.onTypeDiffereChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          placeholder: shadcn.Text(l10n.liabilities_name_hint),
          autofocus: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: prixController,
                placeholder: shadcn.Text(l10n.liabilities_price_total_label),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: apportController,
                placeholder: shadcn.Text(l10n.liabilities_down_payment_hint),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: tauxController,
                placeholder: shadcn.Text(l10n.liabilities_interest_rate_label),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: assuranceMensuelleController,
                placeholder: shadcn.Text(
                  l10n.liabilities_monthly_insurance_label,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nbrEcheancesController,
          placeholder: shadcn.Text(l10n.liabilities_installments_count_label),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: shadcn.Text(l10n.liabilities_deferred_loan_label).medium(),
            ),
            Switch(value: differeActif, onChanged: onDiffereActifChanged),
          ],
        ),
        // Le nombre de mois et le mode de franchise n'ont de sens que si le
        // différé est actif — masqués plutôt qu'affichés en permanence avec
        // une valeur à 0, pour ne pas laisser croire qu'un différé de 0 mois
        // est une option distincte de "pas de différé du tout".
        if (differeActif) ...[
          const SizedBox(height: 8),
          TextField(
            controller: dureeDiffereController,
            placeholder: shadcn.Text(l10n.liabilities_deferral_duration_label),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: shadcn.Text(l10n.liabilities_deferral_type_label)
                    .muted()
                    .small(),
              ),
              // Libellés courts ("Partielle"/"Totale", pas "Franchise
              // partielle"/"Franchise totale") : le contexte est déjà donné
              // par le libellé de la ligne, et les deux boutons pleine
              // longueur débordaient de la largeur étroite du dialogue de
              // création (régression détectée par les tests d'intégration).
              ButtonGroup(
                children: [
                  SelectedButton(
                    value: typeDiffere == DeferType.partielle,
                    selectedStyle: const ButtonStyle.primary(),
                    style: toggleUnselectedStyle(context),
                    onChanged: (_) =>
                        onTypeDiffereChanged(DeferType.partielle),
                    child: shadcn.Text(l10n.liabilities_deferral_partial),
                  ),
                  SelectedButton(
                    value: typeDiffere == DeferType.totale,
                    selectedStyle: const ButtonStyle.primary(),
                    style: toggleUnselectedStyle(context),
                    onChanged: (_) => onTypeDiffereChanged(DeferType.totale),
                    child: shadcn.Text(l10n.liabilities_deferral_total),
                  ),
                ],
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ButtonGroup(
              children: [
                SelectedButton(
                  value: loanType == LoanType.amortissable,
                  selectedStyle: const ButtonStyle.primary(),
                  style: toggleUnselectedStyle(context),
                  onChanged: (_) => onLoanTypeChanged(LoanType.amortissable),
                  child: shadcn.Text(l10n.liabilities_loan_type_amortizing),
                ),
                SelectedButton(
                  value: loanType == LoanType.inFine,
                  selectedStyle: const ButtonStyle.primary(),
                  style: toggleUnselectedStyle(context),
                  onChanged: (_) => onLoanTypeChanged(LoanType.inFine),
                  child: shadcn.Text(l10n.liabilities_loan_type_in_fine),
                ),
              ],
            ),
            OpimeDatePicker(
              value: dateDebut,
              onChanged: onDateChanged,
              placeholder: shadcn.Text(l10n.liabilities_start_date_label),
            ),
          ],
        ),
      ],
    );
  }
}

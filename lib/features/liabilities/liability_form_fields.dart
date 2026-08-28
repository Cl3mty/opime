import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/ui/opime_date_picker.dart';
import '../../core/ui/toggle_button_style.dart';
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
  final DeferType typeDiffere;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<LoanType> onLoanTypeChanged;
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
    required this.typeDiffere,
    required this.onDateChanged,
    required this.onLoanTypeChanged,
    required this.onTypeDiffereChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          placeholder: const shadcn.Text('Nom (ex: Prêt résidence principale)'),
          autofocus: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: prixController,
                placeholder: const shadcn.Text('Prix total (€)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: apportController,
                placeholder: const shadcn.Text('Apport (€, 0 si aucun)'),
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
                placeholder: const shadcn.Text('Taux d\'intérêt (%)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: assuranceMensuelleController,
                placeholder: const shadcn.Text('Assurance mensuelle (€)'),
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
                controller: nbrEcheancesController,
                placeholder: const shadcn.Text('Nombre d\'échéances (mois)'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: dureeDiffereController,
                placeholder: const shadcn.Text('Différé (mois, 0 si aucun)'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
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
                  child: const shadcn.Text('Amortissable'),
                ),
                SelectedButton(
                  value: loanType == LoanType.inFine,
                  selectedStyle: const ButtonStyle.primary(),
                  style: toggleUnselectedStyle(context),
                  onChanged: (_) => onLoanTypeChanged(LoanType.inFine),
                  child: const shadcn.Text('In fine'),
                ),
              ],
            ),
            ButtonGroup(
              children: [
                SelectedButton(
                  value: typeDiffere == DeferType.partielle,
                  selectedStyle: const ButtonStyle.primary(),
                  style: toggleUnselectedStyle(context),
                  onChanged: (_) => onTypeDiffereChanged(DeferType.partielle),
                  child: const shadcn.Text('Franchise partielle'),
                ),
                SelectedButton(
                  value: typeDiffere == DeferType.totale,
                  selectedStyle: const ButtonStyle.primary(),
                  style: toggleUnselectedStyle(context),
                  onChanged: (_) => onTypeDiffereChanged(DeferType.totale),
                  child: const shadcn.Text('Franchise totale'),
                ),
              ],
            ),
            OpimeDatePicker(
              value: dateDebut,
              onChanged: onDateChanged,
              placeholder: const shadcn.Text('Date de début'),
            ),
          ],
        ),
      ],
    );
  }
}

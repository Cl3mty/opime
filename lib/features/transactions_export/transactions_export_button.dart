import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../core/profiles/profile_controller.dart';
import '../navigation/top_bar_actions.dart';
import 'transactions_export_dialog.dart';

/// Bouton "Exporter les transactions (JSON/CSV)" de la TopBar — ouvre
/// [showTransactionsExportDialog]. Distinct de [PatrimoineExportButton]
/// (`patrimoine_export_button.dart`) : le premier exporte un instantané des
/// positions en PDF, celui-ci l'historique complet des transactions en
/// JSON/CSV — deux imports/usages différents (rapport lisible vs donnée
/// réutilisable), deux boutons plutôt qu'un menu qui les mélangerait.
class TransactionsExportButton extends StatelessWidget {
  final ProfileController profileController;

  const TransactionsExportButton({
    super.key,
    required this.profileController,
  });

  @override
  Widget build(BuildContext context) => TopBarIconButton(
    // Une feuille de calcul plutôt qu'un simple tableau générique
    // (`LucideIcons.table`, ambigu avec d'autres vues "tableau" de l'app) :
    // évoque directement un export de données tabulaires (CSV/JSON), sans
    // confusion possible avec le PDF (icône flèche de téléchargement du
    // bouton voisin).
    icon: LucideIcons.fileSpreadsheet,
    tooltip: 'Exporter les transactions (JSON/CSV)',
    onPressed: () => showTransactionsExportDialog(
      context,
      vaultPath: profileController.activeDataPath,
    ),
  );
}

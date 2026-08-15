import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../core/profiles/profile_controller.dart';
import '../navigation/top_bar_actions.dart';
import 'patrimoine_export_dialog.dart';

/// Bouton "Télécharger mon patrimoine (PDF)" de la TopBar — ouvre
/// [showPatrimoineExportDialog]. Même structure que les autres boutons de la
/// barre (`NewsButton`, `AmountVisibilityToggleButton`).
class PatrimoineExportButton extends StatelessWidget {
  final ProfileController profileController;

  const PatrimoineExportButton({super.key, required this.profileController});

  @override
  Widget build(BuildContext context) => TopBarIconButton(
    icon: LucideIcons.arrowDownToLine,
    tooltip: 'Télécharger mon patrimoine (PDF)',
    onPressed: () => showPatrimoineExportDialog(
      context,
      vaultPath: profileController.activeDataPath,
      profileName: profileController.active?.name ?? '',
    ),
  );
}

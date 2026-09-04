import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/profiles/profile_controller.dart';
import '../../l10n/app_localizations.dart';
import '../patrimoine_export/patrimoine_export_dialog.dart';
import '../transactions_export/transactions_export_dialog.dart';

/// Bouton unique de la TopBar regroupant les deux exports (PDF du
/// patrimoine, CSV/JSON des transactions) derrière un menu déroulant — les
/// raccourcis ⌘P/⌘E (`lib/core/shortcuts/app_shortcuts.dart`) restent des
/// accès directs à chacun des deux dialogues, indépendants de ce bouton (voir
/// `main.dart`'s `_buildShortcuts`).
class PatrimoineExportMenuButton extends StatelessWidget {
  final ProfileController profileController;

  const PatrimoineExportMenuButton({
    super.key,
    required this.profileController,
  });

  void _openMenu(BuildContext anchorContext) {
    final l10n = AppLocalizations.of(anchorContext);
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260),
        child: DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.arrowDownToLine, size: 14),
              child: shadcn.Text(l10n.navigation_export_download_patrimoine_pdf),
              onPressed: (_) => showPatrimoineExportDialog(
                anchorContext,
                vaultPath: profileController.activeDataPath,
                profileName: profileController.active?.name ?? '',
              ),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.fileSpreadsheet, size: 14),
              child: shadcn.Text(l10n.navigation_export_transactions_csv_json),
              onPressed: (_) => showTransactionsExportDialog(
                anchorContext,
                vaultPath: profileController.activeDataPath,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // ignore: implicit_call_tearoffs
      tooltip: TooltipContainer(
        child: shadcn.Text(AppLocalizations.of(context).navigation_export_tooltip),
      ),
      child: Builder(
        builder: (context) => IconButton.ghost(
          icon: const Icon(LucideIcons.arrowDownToLine),
          onPressed: () => _openMenu(context),
        ),
      ),
    );
  }
}

import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/notifications/notifications_settings_controller.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/profiles/profile_controller.dart';
import '../../l10n/app_localizations.dart';
import '../dashboard/onboarding_highlight_controller.dart';
import '../investments/current_account_focus_controller.dart';
import '../investments/patrimoine_refresh_controller.dart';
import '../investments/price_sync_status_controller.dart';
import '../notifications/news_button.dart';
import '../notifications/notifications_controller.dart';
import '../search/global_search_bar.dart';
import 'nav_models.dart';
import 'patrimoine_export_menu_button.dart';
import 'top_bar_actions.dart';

/// Barre persistante au-dessus du contenu de la page en mise en page
/// "large" (sidebar, desktop ou tablette) : titre de la page courante,
/// recherche globale, bascule de confidentialité des montants, et ajout
/// rapide.
///
/// En mode mobile (bottom nav), ces actions sont directement intégrées à
/// l'AppBar par [AppShell] : pas de barre séparée, pour économiser la
/// place verticale.
class TopBar extends StatelessWidget {
  final AmountVisibilityController amountVisibility;
  final ProfileController profileController;
  final PatrimoineRefreshController patrimoineRefreshController;
  final CurrentAccountFocusController currentAccountFocus;
  final OnboardingHighlightController onboardingHighlight;
  final PriceSyncStatusController priceSyncStatus;
  final NotificationsSettingsController notificationsSettings;
  final NotificationsController notificationsController;
  final String currentPageKey;
  final ValueChanged<String> onSelect;

  const TopBar({
    super.key,
    required this.amountVisibility,
    required this.profileController,
    required this.patrimoineRefreshController,
    required this.currentAccountFocus,
    required this.onboardingHighlight,
    required this.priceSyncStatus,
    required this.notificationsSettings,
    required this.notificationsController,
    required this.currentPageKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        // Semi-transparent : le halo/dégradé de AppBackground (qui
        // enveloppe la TopBar) doit rester visible en transparence.
        color: theme.colorScheme.card.withValues(alpha: 0.82),
        border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        children: [
          // Fil d'Ariane de la page sélectionnée : pour un sous-menu (ex :
          // « Simulation > Transmission »), le parent précède la page ; une
          // page de premier niveau n'affiche que son libellé.
          _buildBreadcrumb(context, theme),
          const SizedBox(width: 16),
          // Reconstruit l'index de recherche quand le profil actif change :
          // le patrimoine réel indexé dépend de ProfileController.activeDataPath.
          Expanded(
            child: GlobalSearchBar(
              key: ValueKey(profileController.activeDataPath),
              vaultPath: profileController.activeDataPath,
              onSelect: onSelect,
            ),
          ),
          const SizedBox(width: 8),
          AmountVisibilityToggleButton(amountVisibility: amountVisibility),
          const SizedBox(width: 4),
          NewsButton(
            settings: notificationsSettings,
            controller: notificationsController,
            vaultPath: profileController.activeDataPath,
          ),
          const SizedBox(width: 4),
          PatrimoineExportMenuButton(profileController: profileController),
          const SizedBox(width: 4),
          AddMenuButton(
            profileController: profileController,
            patrimoineRefreshController: patrimoineRefreshController,
            currentAccountFocus: currentAccountFocus,
            onboardingHighlight: onboardingHighlight,
            priceSyncStatus: priceSyncStatus,
            currentPageKey: currentPageKey,
          ),
        ],
      ),
    );
  }

  /// Fil d'Ariane de la page courante : chaque segment du parcours sauf le
  /// dernier est grisé et précédé d'une chevron (« Simulation › Transmission »).
  Widget _buildBreadcrumb(BuildContext context, ThemeData theme) {
    final crumbs = navLocalizedBreadcrumb(
      AppLocalizations.of(context),
      currentPageKey,
    );
    final lastIndex = crumbs.length - 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < crumbs.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronRight,
              size: 12,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(width: 6),
          ],
          shadcn.Text(
            crumbs[i],
            style: i == lastIndex
                ? null
                : TextStyle(color: theme.colorScheme.mutedForeground),
          ).medium.small,
        ],
      ],
    );
  }
}

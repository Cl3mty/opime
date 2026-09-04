import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import '../../core/notifications/notifications_settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../navigation/top_bar_actions.dart' show TopBarIconButton;
import 'news_panel.dart';
import 'notifications_controller.dart';

/// Bouton "Actualités" de la top bar — masqué si la fonctionnalité est
/// désactivée dans les Réglages (aucun appel réseau n'est alors effectué
/// pour elle, voir [NotificationsController]/`CoinGeckoClient`). Affiche
/// une pastille (même style que le badge non-lu de l'Assistant, voir
/// `app_sidebar.dart`) tant que [NotificationsController.unreadCount] est
/// supérieur à zéro.
class NewsButton extends StatelessWidget {
  final NotificationsSettingsController settings;
  final NotificationsController controller;
  final String vaultPath;

  const NewsButton({
    super.key,
    required this.settings,
    required this.controller,
    required this.vaultPath,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        if (!settings.enabled) return const SizedBox.shrink();
        return ValueListenableBuilder<int>(
          valueListenable: controller.unreadCount,
          builder: (context, unread, _) {
            final theme = Theme.of(context);
            return Builder(
              builder: (barContext) => Stack(
                clipBehavior: Clip.none,
                children: [
                  TopBarIconButton(
                    icon: LucideIcons.bell,
                    tooltip: AppLocalizations.of(context).notifications_title,
                    onPressed: () => openNewsPanel(
                      barContext,
                      controller: controller,
                      settings: settings,
                      vaultPath: vaultPath,
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

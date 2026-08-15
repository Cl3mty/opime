import 'dart:async' show unawaited;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:url_launcher/url_launcher.dart';
import '../../core/notifications/notifications_settings_controller.dart';
import 'notification_models.dart';
import 'notifications_controller.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Ouvre le panneau d'actualités/alertes, ancré sur [anchorContext] — même
/// pattern que `openAccountSwitcherMenu`
/// (`features/navigation/account_switcher_menu.dart`) : `showDropdown` avec
/// un builder personnalisé.
///
/// Marque immédiatement la consultation comme "vue" (efface la pastille) et
/// lance un rafraîchissement en tâche de fond — "vu" signifie "panneau
/// ouvert", pas "chaque élément lu individuellement" (voir
/// `NotificationsController.markAllSeen`).
void openNewsPanel(
  BuildContext anchorContext, {
  required NotificationsController controller,
  required NotificationsSettingsController settings,
  required String vaultPath,
  AlignmentGeometry anchorAlignment = AlignmentDirectional.topEnd,
  AlignmentGeometry alignment = AlignmentDirectional.bottomEnd,
  Offset offset = const Offset(0, -8),
}) {
  final now = DateTime.now();
  controller.markAllSeen(now);
  unawaited(settings.markSeen(now));
  unawaited(controller.refresh(vaultPath, lastSeen: now));

  showDropdown(
    context: anchorContext,
    anchorAlignment: anchorAlignment,
    alignment: alignment,
    offset: offset,
    builder: (context) => _NotificationsPanel(controller: controller),
  );
}

/// Clé stable d'un élément, pour le suivi des "X" fermés localement (voir
/// [_NotificationsPanelState._dismissedKeys]) — CoinGecko ne fournissant
/// aucun identifiant d'évènement, l'horodatage du calcul en tient lieu pour
/// une alerte crypto.
String _itemKey(NotificationItem item) {
  if (item is NewsArticleItem) return 'news:${item.uuid}';
  final alert = item as CryptoAlertItem;
  return 'crypto:${alert.coinId}:${alert.observedAt.millisecondsSinceEpoch}';
}

/// Contenu du panneau — état local pour les fermetures individuelles ("X"
/// sur chaque carte), qui n'existent que pour la durée d'ouverture du
/// panneau : rien n'est persisté, un prochain rafraîchissement peut faire
/// réapparaître un élément toujours présent côté source (voir
/// `NotificationsController.refresh`).
class _NotificationsPanel extends StatefulWidget {
  final NotificationsController controller;

  const _NotificationsPanel({required this.controller});

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel> {
  final Set<String> _dismissedKeys = {};

  void _dismiss(NotificationItem item) {
    setState(() => _dismissedKeys.add(_itemKey(item)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final items = widget.controller.items
            .where((item) => !_dismissedKeys.contains(_itemKey(item)))
            .toList();
        return SizedBox(
          width: 380,
          height: 480,
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: shadcn.Text('Actualités').semiBold().large(),
                ),
                Expanded(
                  child: widget.controller.loading && items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                      ? Center(
                          child: shadcn.Text(
                            'Aucune actualité pour le moment.',
                          ).muted(),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) => _NotificationCard(
                            item: items[index],
                            onDismiss: () => _dismiss(items[index]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Une carte de notification : contenu (titre tronqué + sous-titre discret)
/// à gauche, avatar coloré à droite, bouton de fermeture flottant en haut à
/// droite — inspiré du panneau de notifications de Finary. Le contenu et le
/// bouton de fermeture sont deux enfants distincts d'un même `Stack` (pas
/// l'un imbriqué dans l'autre) pour que le clic sur l'un n'interfère jamais
/// avec l'autre.
class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onDismiss;

  const _NotificationCard({required this.item, required this.onDismiss});

  bool get _isNews => item is NewsArticleItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MouseRegion(
            cursor: _isNews
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: _isNews
                  ? () => launchUrl(
                      Uri.parse((item as NewsArticleItem).link),
                      mode: LaunchMode.externalApplication,
                    )
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _content(theme)),
                  const SizedBox(width: 10),
                  _avatar(theme),
                ],
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: _DismissButton(onPressed: onDismiss),
          ),
        ],
      ),
    );
  }

  Widget _content(ThemeData theme) {
    if (item is NewsArticleItem) {
      final news = item as NewsArticleItem;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          shadcn.Text(
            news.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ).semiBold().small(),
          const SizedBox(height: 4),
          shadcn.Text(
            '${news.publisher} · ${_relativeTime(news.publishedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ).muted().xSmall(),
        ],
      );
    }
    final alert = item as CryptoAlertItem;
    final change = alert.changePercent24h ?? alert.changePercent7d ?? 0;
    final up = change >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        shadcn.Text(
          '${alert.symbol} ${up ? '+' : ''}${change.toStringAsFixed(1)} % sur 24h',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ).semiBold().small(),
        const SizedBox(height: 4),
        shadcn.Text(
          '${alert.name} · ${alert.currentPrice.toStringAsFixed(2)} €',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ).muted().xSmall(),
      ],
    );
  }

  Widget _avatar(ThemeData theme) {
    if (item is NewsArticleItem) {
      return _AvatarBox(
        background: theme.colorScheme.border.withValues(alpha: 0.5),
        icon: LucideIcons.newspaper,
        iconColor: theme.colorScheme.mutedForeground,
      );
    }
    final alert = item as CryptoAlertItem;
    final change = alert.changePercent24h ?? alert.changePercent7d ?? 0;
    final up = change >= 0;
    final accent = up ? _green : _red;
    return _AvatarBox(
      background: accent.withValues(alpha: 0.15),
      icon: up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
      iconColor: accent,
    );
  }
}

/// Vignette carrée arrondie à droite d'une carte — icône seule (pas de logo
/// de source, contrairement à Finary : ce code n'a pas de banque de logos
/// pour des tickers/éditeurs arbitraires), teintée pour distinguer d'un
/// coup d'œil une actualité (neutre) d'une alerte crypto (verte/rouge selon
/// le sens de la variation).
class _AvatarBox extends StatelessWidget {
  final Color background;
  final IconData icon;
  final Color iconColor;

  const _AvatarBox({
    required this.background,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}

class _DismissButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DismissButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.card,
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Icon(
          LucideIcons.x,
          size: 12,
          color: theme.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

/// Temps relatif court ("à l'instant" / "il y a Xh" / "il y a Xj") pour
/// l'horodatage d'un article — pas d'utilitaire équivalent ailleurs dans ce
/// code, écrit ici plutôt qu'extrait vu son unique site d'usage.
String _relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'à l\'instant';
  if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
  return 'il y a ${diff.inDays} j';
}

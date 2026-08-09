import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/profiles/profile_controller.dart';

Widget _profileAvatar(BuildContext context, String initials, double size) {
  final bg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.18);
  final fg = Theme.of(context).colorScheme.primary;
  return SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: shadcn.Text(
          initials,
          style: TextStyle(
            color: fg,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

/// Ouvre le menu de bascule de compte + accès Comptes/Réglages, ancré sur
/// [anchorContext]. Partagé entre la sidebar desktop ([AppSidebar]) et
/// l'icône compte de l'AppBar en navigation mobile, pour ne pas dupliquer
/// cette logique dans les deux endroits.
void openAccountSwitcherMenu(
  BuildContext anchorContext, {
  required ProfileController profileController,
  required ValueChanged<String> onSelect,
  AlignmentGeometry anchorAlignment = AlignmentDirectional.topEnd,
  AlignmentGeometry alignment = AlignmentDirectional.bottomEnd,
  Offset offset = const Offset(0, -8),
}) {
  showDropdown(
    context: anchorContext,
    anchorAlignment: anchorAlignment,
    alignment: alignment,
    offset: offset,
    builder: (context) {
      return AnimatedBuilder(
        animation: profileController,
        builder: (context, _) {
          final profiles = profileController.profiles;
          final activeId = profileController.active?.id;
          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
            child: DropdownMenu(
              children: [
                for (final profile in profiles)
                  MenuButton(
                    leading: _profileAvatar(context, profile.initials, 24),
                    trailing: profile.id == activeId
                        ? const Icon(LucideIcons.check, size: 16)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        shadcn.Text(profile.name),
                        if (profile.relationship.isNotEmpty)
                          shadcn.Text(profile.relationship).muted.xSmall,
                      ],
                    ),
                    onPressed: (ctx) {
                      profileController.switchTo(profile.id);
                      final toastContext =
                          Navigator.maybeOf(
                            anchorContext,
                            rootNavigator: true,
                          )?.context ??
                          anchorContext;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!toastContext.mounted) return;
                        showToast(
                          context: toastContext,
                          location: ToastLocation.bottomRight,
                          builder: (context, overlay) => SurfaceCard(
                            child: Basic(
                              title: shadcn.Text(
                                'Profil actif: ${profile.name}',
                              ),
                              subtitle: shadcn.Text(
                                profile.relationship.isNotEmpty
                                    ? profile.relationship
                                    : 'Compte activé',
                              ),
                            ),
                          ),
                        );
                      });
                    },
                  ),
                const MenuDivider(),
                MenuButton(
                  leading: const Icon(LucideIcons.userPlus),
                  child: const shadcn.Text('Gérer les comptes'),
                  onPressed: (ctx) => onSelect('account_management'),
                ),
                MenuButton(
                  leading: const Icon(LucideIcons.settings),
                  child: const shadcn.Text('Paramètres'),
                  onPressed: (ctx) => onSelect('settings'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

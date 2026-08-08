import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/profiles/profile_controller.dart';
import '../../core/profiles/sidebar_prefs_controller.dart';
import 'nav_models.dart';

class AppSidebar extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<String> onSelect;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ProfileController profileController;
  final SidebarPrefsController sidebarPrefsController;

  const AppSidebar({
    super.key,
    required this.selectedKey,
    required this.onSelect,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.profileController,
    required this.sidebarPrefsController,
  });

  Widget _profileAvatar(BuildContext context, String initials, double size) {
    final bg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.18);
    final fg = Theme.of(context).colorScheme.primary;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
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

  Widget _withTooltip(String label, Widget child) {
    if (!collapsed) return child;
    return Tooltip(
      // ignore: implicit_call_tearoffs
      tooltip: TooltipContainer(child: shadcn.Text(label)),
      child: child,
    );
  }

  Widget _buildItem(NavItem item) {
    return _withTooltip(
      item.label,
      NavigationItem(
        label: shadcn.Text(item.label),
        selectedStyle: const ButtonStyle.primaryIcon(),
        selected: selectedKey == item.key,
        onChanged: (isSelected) {
          if (isSelected) onSelect(item.key);
        },
        child: Icon(item.icon),
      ),
    );
  }

  Widget _buildGroup(NavGroup group, Set<String> hiddenKeys) {
    return NavigationGroup(
      labelAlignment: Alignment.centerLeft,
      label: shadcn.Text(group.label).semiBold.muted.xSmall,
      children: [
        for (final item in group.items)
          if (item.children.isEmpty)
            _buildItem(item)
          else
            _buildParentWithFilteredChildren(item, hiddenKeys),
      ],
    );
  }

  /// Filtre les sous-items (postes Actifs/Passifs) selon les préférences du
  /// compte actif. Si tout est masqué, le parent disparaît aussi.
  Widget _buildParentWithFilteredChildren(NavItem item, Set<String> hiddenKeys) {
    final visibleChildren = item.children.where((c) => !hiddenKeys.contains(c.key)).toList();
    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    return _withTooltip(
      item.label,
      NavigationCollapsible(
        leading: Icon(item.icon),
        label: shadcn.Text(item.label),
        children: [for (final child in visibleChildren) _buildItem(child)],
      ),
    );
  }

  void _openAccountSwitcher(BuildContext anchorContext) {
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.bottomEnd,
      offset: const Offset(0, -8),
      builder: (context) {
        return AnimatedBuilder(
          animation: profileController,
          builder: (context, _) {
            final profiles = profileController.profiles;
            final activeId = profileController.active?.id;
            return ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
              child: DropdownMenu(children: [
                for (final profile in profiles)
                  MenuButton(
                    leading: _profileAvatar(context, profile.initials, 24),
                    trailing: profile.id == activeId ? const Icon(LucideIcons.check, size: 16) : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        shadcn.Text(profile.name),
                        if (profile.relationship.isNotEmpty) shadcn.Text(profile.relationship).muted.xSmall,
                      ],
                    ),
                    onPressed: (ctx) {
                      profileController.switchTo(profile.id);
                      final toastContext =
                          Navigator.maybeOf(anchorContext, rootNavigator: true)?.context ?? anchorContext;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!toastContext.mounted) return;
                        showToast(
                          context: toastContext,
                          location: ToastLocation.bottomRight,
                          builder: (context, overlay) => SurfaceCard(
                            child: Basic(
                              title: shadcn.Text('Profil actif: ${profile.name}'),
                              subtitle: shadcn.Text(
                                profile.relationship.isNotEmpty ? profile.relationship : 'Compte activé',
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
              ]),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([profileController, sidebarPrefsController]),
      builder: (context, _) {
        final active = profileController.active;
        final hiddenKeys = active != null ? sidebarPrefsController.hiddenKeysFor(active.id) : <String>{};
        if (active != null) {
          sidebarPrefsController.loadFor(active.id);
        }

        return NavigationRail(
          backgroundColor: theme.colorScheme.card,
          labelType: NavigationLabelType.expanded,
          labelPosition: NavigationLabelPosition.end,
          alignment: NavigationRailAlignment.start,
          expandedSize: 260,
          expanded: !collapsed,
          header: [
            _withTooltip(
              collapsed ? 'Étendre' : 'Réduire',
              NavigationSlot(
                leading: SizedBox(
                width: 35,
                height: 35,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
                title: const shadcn.Text('Freenary').medium.small,
                trailing: Icon(
                  collapsed ? LucideIcons.panelLeftOpen : LucideIcons.panelLeftClose,
                ).iconSmall,
                onPressed: onToggleCollapse,
              ),
            ),
          ],
          footer: [
            _withTooltip(
              active != null ? '${active.name} — changer de compte' : 'Comptes',
              Builder(
                builder: (slotContext) => NavigationSlot(
                  leading: _profileAvatar(slotContext, active?.initials ?? '?', 32),
                  title: shadcn.Text(active?.name ?? 'Compte').medium.small,
                  subtitle: shadcn.Text(
                    active?.relationship.isNotEmpty == true ? active!.relationship : 'Compte',
                  ).xSmall.normal,
                  trailing: const Icon(LucideIcons.chevronsUpDown).iconSmall,
                  onPressed: () => _openAccountSwitcher(slotContext),
                ),
              ),
            ),
          ],
          children: [
            _buildGroup(patrimoineGroup, hiddenKeys),
            const NavigationDivider(),
            _buildGroup(academieGroup, hiddenKeys),
            const NavigationDivider(),
            _buildGroup(outilsGroup, hiddenKeys),
          ],
        );
      },
    );
  }
}
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/platform_info.dart';
import '../../core/profiles/profile_controller.dart';
import '../../core/profiles/sidebar_prefs_controller.dart';
import 'account_switcher_menu.dart';
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

  void _openAccountSwitcher(BuildContext anchorContext) {
    openAccountSwitcherMenu(
      anchorContext,
      profileController: profileController,
      onSelect: onSelect,
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
  Widget _buildParentWithFilteredChildren(
    NavItem item,
    Set<String> hiddenKeys,
  ) {
    final visibleChildren = item.children
        .where((c) => !hiddenKeys.contains(c.key))
        .toList();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([profileController, sidebarPrefsController]),
      builder: (context, _) {
        final active = profileController.active;
        final hiddenKeys = active != null
            ? sidebarPrefsController.hiddenKeysFor(active.id)
            : <String>{};
        if (active != null) {
          sidebarPrefsController.loadFor(active.id);
        }

        return NavigationRail(
          // Semi-transparent : le halo/dégradé de AppBackground (qui
          // enveloppe la sidebar) doit rester visible en transparence.
          backgroundColor: theme.colorScheme.card.withValues(alpha: 0.82),
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
                  collapsed
                      ? LucideIcons.panelLeftOpen
                      : LucideIcons.panelLeftClose,
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
                  leading: _profileAvatar(
                    slotContext,
                    active?.initials ?? '?',
                    32,
                  ),
                  title: shadcn.Text(active?.name ?? 'Compte').medium.small,
                  subtitle: shadcn.Text(
                    active?.relationship.isNotEmpty == true
                        ? active!.relationship
                        : 'Compte',
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
            // L'Assistant est réservé au desktop, y compris sur tablette
            // (où la largeur d'écran déclenche par ailleurs cette même
            // sidebar) : toolsTabItems l'exclut déjà pour la navigation
            // mobile, on le réutilise ici plutôt que dupliquer le filtre.
            _buildGroup(
              isDesktopPlatform
                  ? outilsGroup
                  : NavGroup(label: outilsGroup.label, items: toolsTabItems),
              hiddenKeys,
            ),
          ],
        );
      },
    );
  }
}

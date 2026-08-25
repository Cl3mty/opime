import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/platform_info.dart';
import '../../core/profiles/profile_controller.dart';
import '../../core/profiles/sidebar_prefs_controller.dart';
import '../../core/storage/vault_folder_service.dart';
import 'account_switcher_menu.dart';
import 'nav_models.dart';

class AppSidebar extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<String> onSelect;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ProfileController profileController;
  final SidebarPrefsController sidebarPrefsController;
  final VaultFolderService vaultFolderService;
  final Future<void> Function(String path) onVaultActivated;
  final VoidCallback onNoVaultSelected;

  /// L'assistant est-il activé dans les Réglages ? Si non, son item est
  /// retiré du groupe Outils sur desktop.
  final bool assistantEnabled;

  /// Nombre de réponses de l'assistant générées pendant qu'on était ailleurs
  /// (« non lues »), affiché en badge sur l'item Assistant. `ValueListenable`
  /// pour ne re-rendre la sidebar que quand le compteur bouge (une fois par
  /// réponse, pas à chaque token du streaming).
  final ValueListenable<int>? assistantUnread;

  const AppSidebar({
    super.key,
    required this.selectedKey,
    required this.onSelect,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.profileController,
    required this.sidebarPrefsController,
    required this.assistantEnabled,
    this.assistantUnread,
    required this.vaultFolderService,
    required this.onVaultActivated,
    required this.onNoVaultSelected,
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
      vaultFolderService: vaultFolderService,
      onVaultActivated: onVaultActivated,
      onNoVaultSelected: onNoVaultSelected,
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

  Widget _buildItem(BuildContext context, NavItem item) {
    final theme = Theme.of(context);
    final label = shadcn.Text(item.label);
    // Badge « réponses non lues » sur l'item Assistant : une pastille
    // numérique dans la version étendue, une simple pastille pleine dans la
    // version réduite (le libellé n'y est pas affiché, l'icône non plus si
    // on ne l'habillait pas).
    final unread =
        item.key == 'assistant' ? (assistantUnread?.value ?? 0) : 0;
    final icon = unread > 0
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(item.icon),
              Positioned(
                right: -7,
                top: -6,
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
          )
        : Icon(item.icon);

    return _withTooltip(
      item.label,
      NavigationItem(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: label),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: shadcn.Text('$unread').small,
              ),
            ],
          ],
        ),
        selectedStyle: const ButtonStyle.primaryIcon(),
        selected: selectedKey == item.key,
        onChanged: (isSelected) {
          if (isSelected) onSelect(item.key);
        },
        child: icon,
      ),
    );
  }

  Widget _buildGroup(BuildContext context, NavGroup group, Set<String> hiddenKeys) {
    return NavigationGroup(
      labelAlignment: Alignment.centerLeft,
      label: shadcn.Text(group.label).semiBold.muted.xSmall,
      children: [
        for (final item in group.items)
          if (item.children.isEmpty)
            _buildItem(context, item)
          else
            _buildParentWithFilteredChildren(context, item, hiddenKeys),
      ],
    );
  }

  /// Filtre les sous-items (postes Actifs/Passifs) selon les préférences du
  /// compte actif. Si tout est masqué, le parent disparaît aussi.
  Widget _buildParentWithFilteredChildren(
    BuildContext context,
    NavItem item,
    Set<String> hiddenKeys,
  ) {
    final visibleChildren = item.children
        .where((c) => !hiddenKeys.contains(c.key))
        .toList();
    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    // Sidebar réduite : NavigationCollapsible masque entièrement ses
    // enfants dans ce mode (pas de simple repli visuel), donc les
    // sous-pages (ex : Budget > Suivi) seraient introuvables sans déplier
    // toute la sidebar. On ouvre à la place un petit menu flottant listant
    // les sous-items, accessible en un clic sur l'icône du parent.
    if (collapsed) {
      return _buildCollapsedParentFlyout(context, item, visibleChildren);
    }

    return _withTooltip(
      item.label,
      NavigationCollapsible(
        leading: Icon(item.icon),
        label: shadcn.Text(item.label),
        children: [for (final child in visibleChildren) _buildItem(context, child)],
      ),
    );
  }

  void _openChildrenFlyout(
    BuildContext anchorContext,
    List<NavItem> children,
  ) {
    showOverlay(
      anchorContext,
      PopoverConfiguration(
        alignment: Alignment.topLeft,
        anchorAlignment: Alignment.topRight,
        offset: const Offset(8, 0),
        widthConstraint: PopoverConstraint.flexible,
        builder: (popoverContext) => SurfaceCard(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final child in children)
                Tooltip(
                  // ignore: implicit_call_tearoffs
                  tooltip: TooltipContainer(child: shadcn.Text(child.label)),
                  child: IconButton(
                    key: ValueKey('nav_flyout_item_${child.key}'),
                    icon: Icon(child.icon),
                    variance: selectedKey == child.key
                        ? ButtonVariance.secondary
                        : ButtonVariance.ghost,
                    onPressed: () {
                      // Différée à la frame suivante plutôt qu'immédiate :
                      // retirer ce popover de l'arbre pendant le traitement
                      // du clic (sous le curseur à cet instant) fait
                      // planter `MouseTracker`
                      // ("!_debugDuringDeviceUpdate").
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (popoverContext.mounted) {
                          closeOverlay(popoverContext);
                        }
                      });
                      onSelect(child.key);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      adaptive: false,
    );
  }

  Widget _buildCollapsedParentFlyout(
    BuildContext context,
    NavItem item,
    List<NavItem> visibleChildren,
  ) {
    final isChildSelected = visibleChildren.any((c) => c.key == selectedKey);
    return _withTooltip(
      item.label,
      Builder(
        key: ValueKey('nav_parent_flyout_trigger_${item.key}'),
        builder: (anchorContext) => NavigationItem(
          selected: isChildSelected,
          selectedStyle: const ButtonStyle.primaryIcon(),
          // Toujours ouvrir le menu au clic, que le parent soit déjà "actif"
          // (un de ses enfants sélectionné) ou non : ce parent n'a pas de
          // page propre, seul le menu importe.
          onChanged: (_) => _openChildrenFlyout(anchorContext, visibleChildren),
          child: Icon(item.icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        profileController,
        sidebarPrefsController,
        if (assistantUnread != null) assistantUnread,
      ]),
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
                title: const shadcn.Text('Opime').medium.small,
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
                builder: (slotContext) {
                  final slot = NavigationSlot(
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
                  );
                  // Réduite, la sidebar ne montre plus que l'avatar (titre/
                  // sous-titre/trailing repliés à largeur nulle) — mais
                  // `NavigationSlot` ne centre pas son contenu pour autant
                  // (son propre paramètre `alignment` n'a aucun effet, voir
                  // `Button._buildAligned` dans shadcn_flutter : il ignore
                  // l'alignement du bouton englobant et ne s'applique que si
                  // `NavigationSlot` le passait lui-même, ce qu'il ne fait
                  // pas). Sans ce `Center`, l'avatar reste collé au bord
                  // gauche au lieu d'être aligné avec les icônes de
                  // navigation au-dessus.
                  return collapsed ? Center(child: slot) : slot;
                },
              ),
            ),
          ],
          children: [
            _buildGroup(context, patrimoineGroup, hiddenKeys),
            const NavigationDivider(),
            _buildGroup(context, academieGroup, hiddenKeys),
            const NavigationDivider(),
            // L'Assistant est réservé au desktop, y compris sur tablette
            // (où la largeur d'écran déclenche par ailleurs cette même
            // sidebar) : toolsTabItems l'exclut déjà pour la navigation
            // mobile. Sur desktop, il n'apparaît que si l'assistant est
            // activé dans les Réglages (assistantEnabled).
            _buildGroup(
              context,
              isDesktopPlatform
                  ? NavGroup(
                      label: outilsGroup.label,
                      items: [
                        for (final item in outilsGroup.items)
                          if (assistantEnabled || item.key != 'assistant') item,
                      ],
                    )
                  : NavGroup(label: outilsGroup.label, items: toolsTabItems),
              hiddenKeys,
            ),
          ],
        );
      },
    );
  }
}


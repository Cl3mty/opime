import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/profiles/profile_controller.dart';
import '../../core/storage/vault_folder_service.dart';

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

void _showAccountToast(
  BuildContext anchorContext,
  String title,
  String subtitle,
) {
  // Contrairement à la bascule de profil (synchrone), basculer/ajouter un
  // vault passe par un `await` — le temps qu'il se résolve, `anchorContext`
  // (la sidebar/l'icône ayant ouvert ce menu) peut avoir été démonté par le
  // rechargement complet de l'appli que `onVaultActivated` déclenche.
  if (!anchorContext.mounted) return;
  final toastContext =
      Navigator.maybeOf(anchorContext, rootNavigator: true)?.context ??
      anchorContext;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!toastContext.mounted) return;
    showToast(
      context: toastContext,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: shadcn.Text(title),
          subtitle: shadcn.Text(subtitle),
        ),
      ),
    );
  });
}

/// Ouvre le menu de bascule de compte + accès Comptes/Réglages/Vaults,
/// ancré sur [anchorContext]. Partagé entre la sidebar desktop
/// ([AppSidebar]) et l'icône compte de l'AppBar en navigation mobile, pour
/// ne pas dupliquer cette logique dans les deux endroits.
void openAccountSwitcherMenu(
  BuildContext anchorContext, {
  required ProfileController profileController,
  required ValueChanged<String> onSelect,
  required VaultFolderService vaultFolderService,
  required Future<void> Function(String path) onVaultActivated,
  required VoidCallback onNoVaultSelected,
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
      return _AccountSwitcherContent(
        anchorContext: anchorContext,
        profileController: profileController,
        onSelect: onSelect,
        vaultFolderService: vaultFolderService,
        onVaultActivated: onVaultActivated,
        onNoVaultSelected: onNoVaultSelected,
      );
    },
  );
}

class _AccountSwitcherContent extends StatefulWidget {
  final BuildContext anchorContext;
  final ProfileController profileController;
  final ValueChanged<String> onSelect;
  final VaultFolderService vaultFolderService;
  final Future<void> Function(String path) onVaultActivated;
  final VoidCallback onNoVaultSelected;

  const _AccountSwitcherContent({
    required this.anchorContext,
    required this.profileController,
    required this.onSelect,
    required this.vaultFolderService,
    required this.onVaultActivated,
    required this.onNoVaultSelected,
  });

  @override
  State<_AccountSwitcherContent> createState() =>
      _AccountSwitcherContentState();
}

class _AccountSwitcherContentState extends State<_AccountSwitcherContent> {
  List<SavedVault> _vaults = const [];
  String? _activeVaultId;

  @override
  void initState() {
    super.initState();
    _loadVaults();
  }

  Future<void> _loadVaults() async {
    final vaults = await widget.vaultFolderService.listVaults();
    final activeVault = await widget.vaultFolderService.getActiveVault();
    if (!mounted) return;
    setState(() {
      _vaults = vaults;
      _activeVaultId = activeVault?.id;
    });
  }

  /// Basculer de vault dispose puis recrée le `ProfileController` que ce
  /// menu écoute (`AnimatedBuilder` dans [build]) — contrairement à un
  /// changement de profil, un simple champ interne au même controller.
  /// Le menu doit donc se refermer (pas via `autoClose`, ces boutons n'en
  /// sont pas) pour ne jamais retenter de notifier/écouter un controller
  /// déjà disposé. Fermeture différée à la frame suivante plutôt
  /// qu'immédiate dans le handler de tap : la retirer de l'arbre pendant
  /// le traitement du pointer par Flutter (elle est là, sous le curseur,
  /// à l'instant du clic) fait planter `MouseTracker`
  /// ("!_debugDuringDeviceUpdate").
  Future<void> _switchVault(BuildContext menuContext, SavedVault vault) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (menuContext.mounted) closeOverlay(menuContext);
    });
    try {
      final activeVault = await widget.vaultFolderService.setActiveVault(
        vault.id,
      );
      if (activeVault == null) {
        widget.onNoVaultSelected();
      } else {
        await widget.onVaultActivated(activeVault.vaultPath);
        _showAccountToast(
          widget.anchorContext,
          'Coffre-fort actif : ${activeVault.name}',
          'Basculé depuis le sélecteur de compte',
        );
      }
    } catch (e) {
      _showAccountToast(
        widget.anchorContext,
        'Impossible d\'activer ce coffre-fort',
        '$e',
      );
    }
  }

  /// Flèches gauche/droite pour parcourir les coffres-forts enregistrés,
  /// au-dessus de la liste des profils — pas de liste des coffres-forts par
  /// nom ici, elle reste dans Réglages (`SettingsScreen`/`_VaultCard`) pour
  /// une gestion complète (renommer/oublier/ajouter).
  ///
  /// Toujours présente dans `DropdownMenu.children` (même pendant le
  /// chargement, flèches simplement désactivées) plutôt qu'insérée après
  /// coup : `MenuGroup`/`SubFocusScope` (shadcn_flutter) gère mal un
  /// changement de forme de sa liste d'enfants pendant qu'un item a le
  /// focus — un `setState` déclenché pendant le démontage d'un item
  /// redistribuant le focus plante ("widget tree was locked").
  Widget _buildVaultSwitcherRow(BuildContext context) {
    final index = _vaults.indexWhere((v) => v.id == _activeVaultId);
    final activeName = index != -1 ? _vaults[index].name : null;
    SavedVault? previous;
    SavedVault? next;
    if (_vaults.length > 1 && index != -1) {
      previous = _vaults[(index - 1) % _vaults.length];
      next = _vaults[(index + 1) % _vaults.length];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Tooltip(
            // ignore: implicit_call_tearoffs
            tooltip: TooltipContainer(
              child: shadcn.Text(
                previous != null
                    ? 'Coffre-fort précédent : ${previous.name}'
                    : 'Coffre-fort précédent',
              ),
            ),
            child: IconButton.ghost(
              icon: const Icon(LucideIcons.chevronLeft, size: 16),
              onPressed: previous == null
                  ? null
                  : () => _switchVault(context, previous!),
            ),
          ),
          Expanded(
            child: Center(
              child: shadcn.Text(activeName ?? 'Coffre-fort').medium.small,
            ),
          ),
          Tooltip(
            // ignore: implicit_call_tearoffs
            tooltip: TooltipContainer(
              child: shadcn.Text(
                next != null
                    ? 'Coffre-fort suivant : ${next.name}'
                    : 'Coffre-fort suivant',
              ),
            ),
            child: IconButton.ghost(
              icon: const Icon(LucideIcons.chevronRight, size: 16),
              onPressed: next == null ? null : () => _switchVault(context, next!),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.profileController,
      builder: (context, _) {
        final profiles = widget.profileController.profiles;
        final activeProfileId = widget.profileController.active?.id;
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
          child: DropdownMenu(
            children: [
              _MenuRow(child: _buildVaultSwitcherRow(context)),
              const MenuDivider(),
              for (final profile in profiles)
                MenuButton(
                  leading: _profileAvatar(context, profile.initials, 24),
                  trailing: profile.id == activeProfileId
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
                    widget.profileController.switchTo(profile.id);
                    _showAccountToast(
                      widget.anchorContext,
                      'Profil actif: ${profile.name}',
                      profile.relationship.isNotEmpty
                          ? profile.relationship
                          : 'Compte activé',
                    );
                  },
                ),
              const MenuDivider(),
              // Un seul point d'entrée « Paramètres » : la gestion des
              // comptes (créer/éditer/basculer un profil) vit désormais
              // dans cette même page, à côté de celle des vaults (voir
              // `settings_screen.dart`'s `_ProfilesCard`/`_VaultCard`).
              MenuButton(
                leading: const Icon(LucideIcons.settings),
                child: const shadcn.Text('Paramètres'),
                onPressed: (ctx) => widget.onSelect('settings'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fait passer un widget quelconque (ici la ligne flèches/nom de vault, pas
/// sélectionnable/fermante comme un [MenuButton]) pour un [MenuItem] —
/// requis par [DropdownMenu.children], qui ne type que des `MenuItem`.
class _MenuRow extends StatelessWidget implements MenuItem {
  final Widget child;

  const _MenuRow({required this.child});

  @override
  bool get hasLeading => false;

  @override
  OverlayController? get overlayController => null;

  @override
  Widget build(BuildContext context) => child;
}

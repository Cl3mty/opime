import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme_controller.dart';
import '../../core/storage/vault_folder_service.dart';
import '../../core/updates/update_checker.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/profiles/profile_controller.dart';
import '../../core/profiles/sidebar_prefs_controller.dart';
import 'sidebar_visibility_card.dart';

class SettingsScreen extends StatelessWidget {
  final VaultFolderService vaultFolderService;
  final Future<void> Function(String path) onVaultActivated;
  final VoidCallback onNoVaultSelected;
  final ThemeController themeController;
  final ProfileController profileController;
  final SidebarPrefsController sidebarPrefsController;
  final String githubOwner;
  final String githubRepo;

  const SettingsScreen({
    super.key,
    required this.vaultFolderService,
    required this.onVaultActivated,
    required this.onNoVaultSelected,
    required this.themeController,
    required this.profileController,
    required this.sidebarPrefsController,
    required this.githubOwner,
    required this.githubRepo,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      // Toute la largeur disponible, comme les autres pages : plus de
      // ConstrainedBox(maxWidth) qui cantonnait les cartes à une colonne
      // centrale étroite.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Réglages').large().medium(),
          const SizedBox(height: 24),
          _ThemeCard(themeController: themeController),
          const SizedBox(height: 16),
          _VersionCard(githubOwner: githubOwner, githubRepo: githubRepo),
          const SizedBox(height: 16),
          SidebarVisibilityCard(
            profileController: profileController,
            sidebarPrefsController: sidebarPrefsController,
          ),
          const SizedBox(height: 16),
          _VaultCard(
            vaultFolderService: vaultFolderService,
            onVaultActivated: onVaultActivated,
            onNoVaultSelected: onNoVaultSelected,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _VersionCard extends StatefulWidget {
  final String githubOwner;
  final String githubRepo;

  const _VersionCard({required this.githubOwner, required this.githubRepo});

  @override
  State<_VersionCard> createState() => _VersionCardState();
}

class _VersionCardState extends State<_VersionCard> {
  bool _loading = true;
  String? _error;
  String _currentVersion = '-';
  String? _latestVersion;
  UpdateInfo? _update;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final checker = UpdateChecker(
        githubOwner: widget.githubOwner,
        githubRepo: widget.githubRepo,
      );
      final result = await checker.checkForUpdateDetailed();
      if (!mounted) return;
      setState(() {
        _currentVersion = result.currentVersion;
        _latestVersion = result.latestVersion;
        _update = result.update;
        _error = result.errorMessage;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadAndInstall() async {
    if (_update == null) return;
    final uri = Uri.parse(_update!.downloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openReleaseNotes() async {
    if (_update == null || _update!.releaseNotesUrl.isEmpty) return;
    final uri = Uri.parse(_update!.releaseNotesUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.mutedForeground;

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version et mises à jour').large().medium(),
            const SizedBox(height: 8),
            Text('Version installée : $_currentVersion').muted(),
            const SizedBox(height: 12),
            if (_loading)
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  const Text('Vérification des releases GitHub...').muted(),
                ],
              )
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.destructive,
                ),
              )
            else if (_update != null) ...[
              Text(
                'Nouvelle version détectée : ${_update!.latestVersion}',
                style: TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  PrimaryButton(
                    onPressed: _downloadAndInstall,
                    leading: const Icon(LucideIcons.download),
                    child: const Text('Télécharger et installer'),
                  ),
                  const SizedBox(width: 8),
                  OutlineButton(
                    onPressed: _openReleaseNotes,
                    leading: const Icon(LucideIcons.externalLink),
                    child: const Text('Voir la release'),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  Icon(LucideIcons.circleCheckBig, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    _latestVersion == null
                        ? 'Version distante inconnue.'
                        : 'Vous êtes à jour (latest: $_latestVersion).',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemeController themeController;
  const _ThemeCard({required this.themeController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final mode = themeController.mode;
        return FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Apparence').large().medium(),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Les 3 boutons icône+texte ne tiennent pas côte à côte
                    // en dessous de ce seuil (ex: "Système" tronqué) :
                    // ButtonGroup passe alors en colonne pleine largeur.
                    final narrow = constraints.maxWidth < 360;
                    return ButtonGroup(
                      direction: narrow ? Axis.vertical : Axis.horizontal,
                      expands: narrow,
                      children: [
                        SelectedButton(
                          value: mode == ThemeMode.light,
                          // Le style "selected" par défaut (secondary) est
                          // presque blanc en thème clair — quasi invisible
                          // sur le fond de carte, lui aussi clair. primary()
                          // garantit un contraste net dans les deux thèmes.
                          selectedStyle: const ButtonStyle.primary(),
                          onChanged: (_) =>
                              themeController.setMode(ThemeMode.light),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.sun),
                              SizedBox(width: 8),
                              Text('Clair'),
                            ],
                          ),
                        ),
                        SelectedButton(
                          value: mode == ThemeMode.dark,
                          selectedStyle: const ButtonStyle.primary(),
                          onChanged: (_) =>
                              themeController.setMode(ThemeMode.dark),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.moon),
                              SizedBox(width: 8),
                              Text('Sombre'),
                            ],
                          ),
                        ),
                        SelectedButton(
                          value: mode == ThemeMode.system,
                          selectedStyle: const ButtonStyle.primary(),
                          onChanged: (_) =>
                              themeController.setMode(ThemeMode.system),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.monitor),
                              SizedBox(width: 8),
                              Text('Système'),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VaultCard extends StatefulWidget {
  final VaultFolderService vaultFolderService;
  final Future<void> Function(String path) onVaultActivated;
  final VoidCallback onNoVaultSelected;

  const _VaultCard({
    required this.vaultFolderService,
    required this.onVaultActivated,
    required this.onNoVaultSelected,
  });

  @override
  State<_VaultCard> createState() => _VaultCardState();
}

class _VaultCardState extends State<_VaultCard> {
  final _editNameController = TextEditingController();

  List<SavedVault> _vaults = const [];
  String? _activeVaultId;
  String? _editingId;
  bool _loading = true;
  String? _error;
  final Set<String> _pathVisibleIds = {};

  @override
  void initState() {
    super.initState();
    _loadVaults();
  }

  @override
  void dispose() {
    _editNameController.dispose();
    super.dispose();
  }

  Future<void> _loadVaults() async {
    final vaults = await widget.vaultFolderService.listVaults();
    final activeVault = await widget.vaultFolderService.getActiveVault();
    if (!mounted) return;
    setState(() {
      _vaults = vaults;
      _activeVaultId = activeVault?.id;
      _loading = false;
    });
  }

  Future<void> _addVault() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vault = await widget.vaultFolderService.pickAndRememberVault(
        dialogTitle: 'Choisis ou crée un vault Freenary',
      );
      if (vault != null) {
        await widget.onVaultActivated(vault.vaultPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Impossible d\'ajouter un vault : $e');
      }
    } finally {
      await _loadVaults();
    }
  }

  void _startEdit(SavedVault vault) {
    _editNameController.text = vault.name;
    setState(() => _editingId = vault.id);
  }

  Future<void> _commitEdit(String id) async {
    final name = _editNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    await widget.vaultFolderService.renameVault(id, name);
    if (!mounted) return;
    setState(() => _editingId = null);
    await _loadVaults();
  }

  Future<void> _switchTo(SavedVault vault) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activeVault = await widget.vaultFolderService.setActiveVault(
        vault.id,
      );
      if (activeVault == null) {
        widget.onNoVaultSelected();
      } else {
        await widget.onVaultActivated(activeVault.vaultPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Impossible d\'activer ce vault : $e');
      }
    } finally {
      await _loadVaults();
    }
  }

  Future<void> _forgetVault(SavedVault vault) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final nextVault = await widget.vaultFolderService.forgetVault(vault.id);
      if (nextVault == null) {
        widget.onNoVaultSelected();
      } else {
        await widget.onVaultActivated(nextVault.vaultPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Impossible d\'oublier ce vault : $e');
      }
    } finally {
      await _loadVaults();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeId = _activeVaultId;
    final theme = Theme.of(context);

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vaults').large().medium(),
            const SizedBox(height: 8),
            const Text(
              'Ajoute plusieurs vaults, donne-leur un nom, bascule entre eux et oublie-les sans toucher aux données sur disque.',
            ).muted().small(),
            const SizedBox(height: 16),
            if (_loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              for (final vault in _vaults) ...[
                if (_editingId == vault.id)
                  _buildEditRow(vault)
                else
                  _buildVaultRow(
                    vault,
                    isActive: vault.id == activeId,
                    theme: theme,
                  ),
                const Divider(),
              ],
              OutlineButton(
                onPressed: _addVault,
                leading: const Icon(LucideIcons.folderPlus),
                child: const Text('Ajouter un vault'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.destructive,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVaultRow(
    SavedVault vault, {
    required bool isActive,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Peu de place sur mobile pour un chemin de fichier complet :
          // il est masqué par défaut et révélé à la demande via l'icône info.
          final narrow = constraints.maxWidth < 500;
          final pathVisible = !narrow || _pathVisibleIds.contains(vault.id);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(LucideIcons.database, size: 16),
                        const SizedBox(width: 8),
                        Flexible(child: Text(vault.name).medium()),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('Actif').small(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (narrow)
                    IconButton.ghost(
                      icon: const Icon(LucideIcons.info, size: 16),
                      onPressed: () => setState(() {
                        if (!_pathVisibleIds.add(vault.id)) {
                          _pathVisibleIds.remove(vault.id);
                        }
                      }),
                    ),
                  if (!isActive)
                    OutlineButton(
                      onPressed: () => _switchTo(vault),
                      child: const Text('Basculer'),
                    ),
                  IconButton.ghost(
                    icon: const Icon(LucideIcons.pencil, size: 16),
                    onPressed: () => _startEdit(vault),
                  ),
                  IconButton.ghost(
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    onPressed: () => _forgetVault(vault),
                  ),
                ],
              ),
              if (pathVisible) ...[
                const SizedBox(height: 6),
                Text(
                  vault.vaultPath,
                  style: const TextStyle(fontFamily: 'monospace'),
                ).muted().small(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditRow(SavedVault vault) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _editNameController,
              placeholder: const Text('Nom du vault'),
              autofocus: true,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.ghost(
            icon: const Icon(LucideIcons.check, size: 16),
            onPressed: () => _commitEdit(vault.id),
          ),
          IconButton.ghost(
            icon: const Icon(LucideIcons.x, size: 16),
            onPressed: () => setState(() => _editingId = null),
          ),
        ],
      ),
    );
  }
}

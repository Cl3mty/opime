import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme_controller.dart';
import '../../core/assistant/assistant_config_controller.dart';
import '../../core/notifications/notifications_settings_controller.dart';
import '../../core/profiles/profile_controller.dart';
import '../../core/profiles/profile_models.dart';
import '../../core/shortcuts/app_shortcuts.dart';
import '../../core/shortcuts/keyboard_shortcuts_controller.dart';
import '../../core/storage/vault_encryption_metadata.dart';
import '../../core/storage/vault_encryption_repository.dart';
import '../../core/storage/vault_folder_service.dart';
import '../../core/ui/toggle_button_style.dart';
import '../../core/updates/update_checker.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/responsive.dart';
import 'vault_encryption_dialogs.dart';

class SettingsScreen extends StatelessWidget {
  final VaultFolderService vaultFolderService;
  final Future<void> Function(String path) onVaultActivated;
  final VoidCallback onNoVaultSelected;
  final ThemeController themeController;
  final AssistantConfigController assistantConfigController;
  final NotificationsSettingsController notificationsSettingsController;
  final KeyboardShortcutsController keyboardShortcutsController;
  final ProfileController profileController;
  final String vaultPath;

  /// Appelé après une activation/désactivation réussie du chiffrement (ou
  /// une régénération de clé de récupération) — recharge le profil actif
  /// pour que les repositories déjà construits (qui ont capturé
  /// `VaultSession.current` une fois pour toutes à leur construction, voir
  /// `vault_file_storage.dart`) soient reconstruits avec la nouvelle
  /// session.
  final VoidCallback onVaultEncryptionChanged;
  final String githubOwner;
  final String githubRepo;

  const SettingsScreen({
    super.key,
    required this.vaultFolderService,
    required this.onVaultActivated,
    required this.onNoVaultSelected,
    required this.themeController,
    required this.assistantConfigController,
    required this.notificationsSettingsController,
    required this.keyboardShortcutsController,
    required this.profileController,
    required this.vaultPath,
    required this.onVaultEncryptionChanged,
    required this.githubOwner,
    required this.githubRepo,
  });

  @override
  Widget build(BuildContext context) {
    // L'Assistant IA n'a pas d'onglet en version mobile (voir
    // nav_models.dart) et les raccourcis clavier supposent un clavier
    // physique : les deux cartes n'ont pas d'équivalent utile en dessous du
    // seuil desktop, donc on les masque plutôt que d'afficher des réglages
    // sans effet.
    final isWide = isWideLayout(context);
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
          if (isWide) ...[
            _AssistantCard(configController: assistantConfigController),
            const SizedBox(height: 16),
          ],
          _NotificationsCard(configController: notificationsSettingsController),
          const SizedBox(height: 16),
          if (isWide) ...[
            _ShortcutsCard(configController: keyboardShortcutsController),
            const SizedBox(height: 16),
          ],
          _EncryptionCard(
            vaultPath: vaultPath,
            onChanged: onVaultEncryptionChanged,
          ),
          const SizedBox(height: 16),
          _VersionCard(githubOwner: githubOwner, githubRepo: githubRepo),
          const SizedBox(height: 16),
          _VaultCard(
            vaultFolderService: vaultFolderService,
            onVaultActivated: onVaultActivated,
            onNoVaultSelected: onNoVaultSelected,
          ),
          const SizedBox(height: 16),
          _ProfilesCard(profileController: profileController),
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
  bool _hasError = false;
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
      _hasError = false;
    });
    try {
      final checker = UpdateChecker(
        githubOwner: widget.githubOwner,
        githubRepo: widget.githubRepo,
      );
      final result = await checker.checkForUpdateDetailed();
      if (!mounted) return;
      // L'utilisateur n'a rien à faire de ces détails techniques (code HTTP,
      // exception réseau...) : l'UI reste sur un message générique, le
      // détail complet part uniquement dans le terminal pour le diagnostic.
      if (result.errorMessage != null) {
        // ignore: avoid_print
        print('Vérification de mise à jour échouée : ${result.errorMessage}');
      }
      setState(() {
        _currentVersion = result.currentVersion;
        _latestVersion = result.latestVersion;
        _update = result.update;
        _hasError = result.errorMessage != null;
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
            else if (_hasError)
              Text(
                'Impossible de vérifier les mises à jour pour le moment.',
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
                          style: toggleUnselectedStyle(context),
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
                          style: toggleUnselectedStyle(context),
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
                          style: toggleUnselectedStyle(context),
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

class _AssistantCard extends StatefulWidget {
  final AssistantConfigController configController;

  const _AssistantCard({required this.configController});

  @override
  State<_AssistantCard> createState() => _AssistantCardState();
}

class _AssistantCardState extends State<_AssistantCard> {
  final _baseUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = widget.configController.baseUrl;
    widget.configController.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    widget.configController.removeListener(_onConfigChanged);
    _baseUrlController.dispose();
    super.dispose();
  }

  void _onConfigChanged() {
    // Synchronise le champ d'adresse si une autre source (écran assistant,
    // restauration...) a changé la base URL sans passer par cette carte.
    final baseUrl = widget.configController.baseUrl;
    if (baseUrl != _baseUrlController.text) {
      _baseUrlController.text = baseUrl;
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _resetBaseUrl() async {
    await widget.configController.setBaseUrl(
      AssistantConfigController.defaultBaseUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.configController,
      builder: (context, _) {
        final enabled = widget.configController.enabled;
        return FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.bot,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Assistant IA').large().medium()),
                    Switch(
                      value: enabled,
                      onChanged: (value) =>
                          widget.configController.setEnabled(value),
                    ),
                  ],
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Dialogue avec un modèle Ollama local (gemma, llama...) : '
                    'analyses du patrimoine, explications pédagogiques, '
                    'questions sur tes simulations et ta stratégie. Tout reste '
                    'sur ta machine — aucune donnée n\'est envoyée en ligne. '
                    'Ollama doit tourner en arrière-plan (« ollama serve ») et '
                    'les modèles s\'installent avec « ollama pull <modèle> ».',
                  ).muted().small(),
                  const SizedBox(height: 16),
                  _buildBaseUrlField(),
                  const SizedBox(height: 12),
                  _buildContextCheckbox(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBaseUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Adresse du serveur Ollama').medium()),
            Tooltip(
              // ignore: implicit_call_tearoffs
              tooltip: TooltipContainer(
                child: Text('Rétablir l\'adresse par défaut'),
              ),
              child: IconButton.ghost(
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                onPressed: _resetBaseUrl,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _baseUrlController,
          onChanged: (value) => widget.configController.setBaseUrl(value),
          placeholder: const Text('http://localhost:11434'),
        ),
      ],
    );
  }

  Widget _buildContextCheckbox() {
    return Checkbox(
      state: widget.configController.includePatrimoine
          ? CheckboxState.checked
          : CheckboxState.unchecked,
      onChanged: (state) => widget.configController.setIncludePatrimoine(
        state == CheckboxState.checked,
      ),
      trailing: const Text(
        'Inclure une synthèse de mon patrimoine dans le contexte du modèle',
      ).small(),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  final NotificationsSettingsController configController;

  const _NotificationsCard({required this.configController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: configController,
      builder: (context, _) {
        final enabled = configController.enabled;
        return FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.bell,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Actualités').large().medium()),
                    Switch(
                      value: enabled,
                      onChanged: (value) => configController.setEnabled(value),
                    ),
                  ],
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Actualités Yahoo Finance pour tes actions/ETF détenus, '
                    'et alertes de variation de prix (CoinGecko) pour tes '
                    'cryptomonnaies détenues. Aucune requête réseau n\'est '
                    'effectuée si désactivé.',
                  ).muted().small(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShortcutsCard extends StatelessWidget {
  final KeyboardShortcutsController configController;

  const _ShortcutsCard({required this.configController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: configController,
      builder: (context, _) {
        final enabled = configController.enabled;
        return FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.keyboard,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Raccourcis clavier').large().medium(),
                    ),
                    Switch(
                      value: enabled,
                      onChanged: (value) => configController.setEnabled(value),
                    ),
                  ],
                ),
                if (enabled) ...[
                  const SizedBox(height: 12),
                  for (final action in AppShortcutAction.values) ...[
                    if (action != AppShortcutAction.values.first)
                      const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text(action.label).small()),
                        _KeycapBadge(label: action.displayLabel),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bulle façon "touche" affichant une combinaison de raccourci (ex : "⌘B").
class _KeycapBadge extends StatelessWidget {
  final String label;

  const _KeycapBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ).xSmall(),
    );
  }
}

class _EncryptionCard extends StatefulWidget {
  final String vaultPath;
  final VoidCallback onChanged;

  const _EncryptionCard({required this.vaultPath, required this.onChanged});

  @override
  State<_EncryptionCard> createState() => _EncryptionCardState();
}

class _EncryptionCardState extends State<_EncryptionCard> {
  VaultEncryptionMetadata? _metadata;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final metadata = await VaultEncryptionRepository(widget.vaultPath).load();
    if (!mounted) return;
    setState(() {
      _metadata = metadata;
      _loading = false;
    });
  }

  Future<void> _enable() async {
    final activated = await showEnableEncryptionDialog(
      context,
      vaultPath: widget.vaultPath,
    );
    if (!activated) return;
    await _load();
    widget.onChanged();
  }

  Future<void> _disable() async {
    final metadata = _metadata;
    if (metadata == null) return;
    final deactivated = await showDisableEncryptionDialog(
      context,
      vaultPath: widget.vaultPath,
      metadata: metadata,
    );
    if (!deactivated) return;
    await _load();
    widget.onChanged();
  }

  Future<void> _regenerateRecoveryKey() async {
    final metadata = _metadata;
    if (metadata == null) return;
    await showRegenerateRecoveryKeyDialog(
      context,
      vaultPath: widget.vaultPath,
      metadata: metadata,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const FrostedCard(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final enabled = _metadata?.enabled ?? false;
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.shieldCheck,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Chiffrement du vault').large().medium()),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              enabled
                  ? 'Les données privées de ce vault (comptes, budget, '
                        'passifs, projets, notes de stratégie, simulations) '
                        'sont chiffrées. Le mot de passe est redemandé à '
                        'chaque lancement de l\'app.'
                  : 'Chiffre les données privées de ce vault avec un mot de '
                        'passe que tu définis. Les caches publics (cours de '
                        'marché, données immobilières, loyers...) restent '
                        'toujours en clair.',
            ).muted().small(),
            const SizedBox(height: 12),
            if (enabled)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlineButton(
                    onPressed: _regenerateRecoveryKey,
                    leading: const Icon(LucideIcons.keyRound),
                    child: const Text(
                      'Générer une nouvelle clé de récupération',
                    ),
                  ),
                  DestructiveButton(
                    onPressed: _disable,
                    leading: const Icon(LucideIcons.lockOpen),
                    child: const Text('Désactiver le chiffrement'),
                  ),
                ],
              )
            else
              PrimaryButton(
                onPressed: _enable,
                leading: const Icon(LucideIcons.lock),
                child: const Text('Activer le chiffrement'),
              ),
          ],
        ),
      ),
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
        dialogTitle: 'Choisis ou crée un vault Opime',
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

/// Gestion des profils du vault actif (créer, renommer, supprimer, basculer)
/// — anciennement une page à part ("Gérer les comptes"), fusionnée ici avec
/// les Réglages pour que la gestion des vaults ([_VaultCard]) et celle des
/// profils vivent sur la même page.
class _ProfilesCard extends StatefulWidget {
  final ProfileController profileController;

  const _ProfilesCard({required this.profileController});

  @override
  State<_ProfilesCard> createState() => _ProfilesCardState();
}

class _ProfilesCardState extends State<_ProfilesCard> {
  String? _editingId;
  final _editNameController = TextEditingController();
  final _editRelationshipController = TextEditingController();

  bool _creating = false;
  final _newNameController = TextEditingController();
  final _newRelationshipController = TextEditingController();

  @override
  void dispose() {
    _editNameController.dispose();
    _editRelationshipController.dispose();
    _newNameController.dispose();
    _newRelationshipController.dispose();
    super.dispose();
  }

  void _startEdit(Profile profile) {
    _editNameController.text = profile.name;
    _editRelationshipController.text = profile.relationship;
    setState(() => _editingId = profile.id);
  }

  Future<void> _commitEdit(String id) async {
    final name = _editNameController.text.trim();
    if (name.isEmpty) return;
    await widget.profileController.renameProfile(
      id,
      name: name,
      relationship: _editRelationshipController.text.trim(),
    );
    setState(() => _editingId = null);
  }

  Future<void> _commitCreate() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;
    await widget.profileController.createProfile(
      name: name,
      relationship: _newRelationshipController.text.trim(),
    );
    _newNameController.clear();
    _newRelationshipController.clear();
    setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.profileController,
      builder: (context, _) {
        final profiles = widget.profileController.profiles;
        final activeId = widget.profileController.active?.id;

        return FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Comptes').large().medium(),
                const SizedBox(height: 8),
                const Text(
                  'Sépare le patrimoine, le budget et les notes de stratégie '
                  'de chaque personne du vault actif.',
                ).muted().small(),
                const SizedBox(height: 16),
                for (final profile in profiles) ...[
                  if (_editingId == profile.id)
                    _buildEditRow(profile)
                  else
                    _buildProfileRow(profile, isActive: profile.id == activeId),
                  const Divider(),
                ],
                const SizedBox(height: 8),
                if (_creating) _buildCreateForm() else _buildAddButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(Profile profile, {required bool isActive}) {
    final theme = Theme.of(context);

    final identity = Row(
      children: [
        Avatar(size: 36, initials: profile.initials),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      profile.name,
                      overflow: TextOverflow.ellipsis,
                    ).medium(),
                  ),
                  if (profile.isMaster) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Principal').small(),
                    ),
                  ],
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.check,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              if (profile.relationship.isNotEmpty)
                Text(profile.relationship).muted().small(),
            ],
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isActive)
          OutlineButton(
            onPressed: () => widget.profileController.switchTo(profile.id),
            child: const Text('Basculer'),
          ),
        IconButton.ghost(
          icon: const Icon(LucideIcons.pencil, size: 16),
          onPressed: () => _startEdit(profile),
        ),
        if (!profile.isMaster)
          IconButton.ghost(
            icon: const Icon(LucideIcons.trash2, size: 16),
            onPressed: () => widget.profileController.deleteProfile(profile.id),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En dessous de ce seuil, le nom + les 3 actions (Basculer, crayon,
          // poubelle) ne tiennent plus sur une seule ligne sans se chevaucher :
          // les actions passent sur leur propre ligne, alignées à droite.
          final narrow = constraints.maxWidth < 420;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditRow(Profile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _editNameController,
              placeholder: const Text('Nom'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _editRelationshipController,
              placeholder: const Text('Lien de parenté'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.ghost(
            icon: const Icon(LucideIcons.check, size: 16),
            onPressed: () => _commitEdit(profile.id),
          ),
          IconButton.ghost(
            icon: const Icon(LucideIcons.x, size: 16),
            onPressed: () => setState(() => _editingId = null),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newNameController,
                placeholder: const Text('Nom (ex: Camille)'),
                autofocus: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _newRelationshipController,
                placeholder: const Text('Lien de parenté (ex: Épouse)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            PrimaryButton(
              onPressed: _commitCreate,
              child: const Text('Créer le compte'),
            ),
            const SizedBox(width: 8),
            OutlineButton(
              onPressed: () => setState(() => _creating = false),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => setState(() => _creating = true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.userPlus,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Ajouter un compte',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

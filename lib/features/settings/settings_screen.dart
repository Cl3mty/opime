import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme_controller.dart';
import '../../app/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../core/assistant/assistant_config_controller.dart';
import '../../core/assistant/llm_provider.dart';
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
import '../../core/ui/vault_kind_selector.dart';
import '../navigation/navigation_scope.dart';
import 'vault_encryption_dialogs.dart';

class SettingsScreen extends StatelessWidget {
  final VaultFolderService vaultFolderService;
  final Future<void> Function(String path) onVaultActivated;
  final VoidCallback onNoVaultSelected;
  final ThemeController themeController;
  final LocaleController localeController;
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
    required this.localeController,
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
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      // Toute la largeur disponible, comme les autres pages : plus de
      // ConstrainedBox(maxWidth) qui cantonnait les cartes à une colonne
      // centrale étroite.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.nav_settings).large().medium(),
          const SizedBox(height: 24),
          _ThemeCard(themeController: themeController),
          const SizedBox(height: 16),
          _LanguageCard(localeController: localeController),
          const SizedBox(height: 16),
          if (isWide) ...[
            AssistantSettingsCard(configController: assistantConfigController),
            const SizedBox(height: 16),
          ],
          _NotificationsCard(configController: notificationsSettingsController),
          const SizedBox(height: 16),
          if (isWide) ...[
            _ShortcutsCard(configController: keyboardShortcutsController),
            const SizedBox(height: 16),
          ],
          _TaxParametersCard(vaultPath: profileController.activeDataPath),
          const SizedBox(height: 16),
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
    final l10n = AppLocalizations.of(context);

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settings_version_updates).large().medium(),
            const SizedBox(height: 8),
            Text(l10n.settings_version_installed(_currentVersion)).muted(),
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
                  Text(l10n.settings_checking_releases).muted(),
                ],
              )
            else if (_hasError)
              Text(
                l10n.settings_update_check_failed,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.destructive,
                ),
              )
            else if (_update != null) ...[
              Text(
                l10n.settings_new_version(_update!.latestVersion),
                style: TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  PrimaryButton(
                    onPressed: _downloadAndInstall,
                    leading: const Icon(LucideIcons.download),
                    child: Text(l10n.settings_download_install),
                  ),
                  const SizedBox(width: 8),
                  OutlineButton(
                    onPressed: _openReleaseNotes,
                    leading: const Icon(LucideIcons.externalLink),
                    child: Text(l10n.settings_view_release),
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
                        ? l10n.settings_remote_version_unknown
                        : l10n.settings_up_to_date(_latestVersion!),
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
        final l10n = AppLocalizations.of(context);
        final mode = themeController.mode;
        return FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.settings_appearance).large().medium(),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.sun),
                              const SizedBox(width: 8),
                              Text(l10n.settings_light),
                            ],
                          ),
                        ),
                        SelectedButton(
                          value: mode == ThemeMode.dark,
                          selectedStyle: const ButtonStyle.primary(),
                          style: toggleUnselectedStyle(context),
                          onChanged: (_) =>
                              themeController.setMode(ThemeMode.dark),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.moon),
                              const SizedBox(width: 8),
                              Text(l10n.settings_dark),
                            ],
                          ),
                        ),
                        SelectedButton(
                          value: mode == ThemeMode.system,
                          selectedStyle: const ButtonStyle.primary(),
                          style: toggleUnselectedStyle(context),
                          onChanged: (_) =>
                              themeController.setMode(ThemeMode.system),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.monitor),
                              const SizedBox(width: 8),
                              Text(l10n.settings_system),
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

/// Carte Réglages de la langue d'affichage (Système / Français / Anglais),
/// pilotée par [LocaleController] — même motif que [_ThemeCard] : une
/// `AnimatedBuilder` autour du controller, avec un `ButtonGroup` à trois
/// choix persistant via `shared_preferences`.
class _LanguageCard extends StatelessWidget {
  final LocaleController localeController;

  const _LanguageCard({required this.localeController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: localeController,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final locale = localeController.locale;
        return FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.settings_language).large().medium(),
                const SizedBox(height: 4),
                Text(l10n.settings_language_description).muted().small(),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 360;
                    return ButtonGroup(
                      direction: narrow ? Axis.vertical : Axis.horizontal,
                      expands: narrow,
                      children: [
                        SelectedButton(
                          value: locale == AppLocale.system,
                          selectedStyle: const ButtonStyle.primary(),
                          style: toggleUnselectedStyle(context),
                          onChanged: (_) =>
                              localeController.setLocale(AppLocale.system),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.monitor),
                              SizedBox(width: 8),
                              Text('Système'),
                            ],
                          ),
                        ),
                        SelectedButton(
                          value: locale == AppLocale.french,
                          selectedStyle: const ButtonStyle.primary(),
                          style: toggleUnselectedStyle(context),
                          onChanged: (_) =>
                              localeController.setLocale(AppLocale.french),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.languages),
                              SizedBox(width: 8),
                              Text('Français'),
                            ],
                          ),
                        ),
                        SelectedButton(
                          value: locale == AppLocale.english,
                          selectedStyle: const ButtonStyle.primary(),
                          style: toggleUnselectedStyle(context),
                          onChanged: (_) =>
                              localeController.setLocale(AppLocale.english),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.globe),
                              SizedBox(width: 8),
                              Text('English'),
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

/// Carte Réglages de l'assistant IA (activation, fournisseur, clé API ou
/// adresse Ollama). Publique (contrairement aux autres cartes de cet écran)
/// pour rester testable indépendamment du reste de [SettingsScreen] —
/// certaines de ses cartes voisines (ex : `_VersionCard`) font de vrais
/// appels réseau en `initState`, peu désirable dans un test ciblant
/// uniquement la logique fournisseur/clé API de celle-ci.
class AssistantSettingsCard extends StatefulWidget {
  final AssistantConfigController configController;

  const AssistantSettingsCard({super.key, required this.configController});

  @override
  State<AssistantSettingsCard> createState() => _AssistantSettingsCardState();
}

class _AssistantSettingsCardState extends State<AssistantSettingsCard> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = widget.configController.baseUrl;
    _apiKeyController.text = _currentApiKey;
    widget.configController.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    widget.configController.removeListener(_onConfigChanged);
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  String get _currentApiKey =>
      widget.configController.apiKeyFor(widget.configController.provider) ??
      '';

  void _onConfigChanged() {
    // Synchronise le champ d'adresse si une autre source (écran assistant,
    // restauration...) a changé la base URL sans passer par cette carte.
    final baseUrl = widget.configController.baseUrl;
    if (baseUrl != _baseUrlController.text) {
      _baseUrlController.text = baseUrl;
    }
    // Idem pour la clé API — resynchronisée aussi quand l'utilisateur
    // bascule de fournisseur, puisque chacun a la sienne.
    final apiKey = _currentApiKey;
    if (apiKey != _apiKeyController.text) {
      _apiKeyController.text = apiKey;
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
        final provider = widget.configController.provider;
        final l10n = AppLocalizations.of(context);
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
                    Expanded(child: Text(l10n.settings_assistant).large().medium()),
                    Switch(
                      value: enabled,
                      onChanged: (value) =>
                          widget.configController.setEnabled(value),
                    ),
                  ],
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  Text(_descriptionFor(context, provider)).muted().small(),
                  const SizedBox(height: 16),
                  _buildProviderSelector(context, provider),
                  const SizedBox(height: 12),
                  if (provider == LlmProvider.ollama)
                    _buildBaseUrlField(context)
                  else
                    _buildApiKeyField(context, provider),
                  if (provider.isCloud) ...[
                    const SizedBox(height: 12),
                    _buildCloudWarning(context, provider),
                  ],
                  const SizedBox(height: 12),
                  _buildContextCheckbox(context),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _descriptionFor(BuildContext context, LlmProvider provider) {
    final l10n = AppLocalizations.of(context);
    if (provider == LlmProvider.ollama) {
      return l10n.settings_ollama_description;
    }
    return l10n.settings_cloud_description(provider.label);
  }

  Widget _buildProviderSelector(BuildContext context, LlmProvider provider) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settings_provider).medium(),
        const SizedBox(height: 6),
        Select<LlmProvider>(
          value: provider,
          onChanged: (value) {
            if (value != null) widget.configController.setProvider(value);
          },
          itemBuilder: (context, value) => Text(value.label),
          popup: (context) => SelectPopup(
            items: SelectItemList(
              children: [
                for (final p in LlmProvider.values)
                  SelectItemButton(value: p, child: Text(p.label)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBaseUrlField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.settings_ollama_address).medium()),
            Tooltip(
              // ignore: implicit_call_tearoffs
              tooltip: TooltipContainer(
                child: Text(l10n.settings_ollama_reset_default),
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

  Widget _buildApiKeyField(BuildContext context, LlmProvider provider) {
    final l10n = AppLocalizations.of(context);
    final error = widget.configController.apiKeyError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settings_api_key(provider.label)).medium(),
        const SizedBox(height: 6),
        TextField(
          key: ValueKey(provider),
          controller: _apiKeyController,
          obscureText: true,
          features: const [InputFeature.passwordToggle()],
          placeholder: Text(l10n.settings_api_key_placeholder),
          onChanged: (value) =>
              widget.configController.setApiKeyFor(provider, value),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.triangleAlert,
                size: 14,
                color: Theme.of(context).colorScheme.destructive,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(error).small()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCloudWarning(BuildContext context, LlmProvider provider) {
    final theme = Theme.of(context);
    final includesPatrimoine = widget.configController.includePatrimoine;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: 16,
            color: theme.colorScheme.destructive,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.settings_cloud_warning(
                provider.label,
                includesPatrimoine
                    ? l10n.settings_cloud_include_patrimoine
                    : '',
              ),
            ).small(),
          ),
        ],
      ),
    );
  }

  Widget _buildContextCheckbox(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Checkbox(
      state: widget.configController.includePatrimoine
          ? CheckboxState.checked
          : CheckboxState.unchecked,
      onChanged: (state) => widget.configController.setIncludePatrimoine(
        state == CheckboxState.checked,
      ),
      trailing: Text(l10n.settings_include_patrimoine_context).small(),
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
        final l10n = AppLocalizations.of(context);
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
                    Expanded(child: Text(l10n.settings_news).large().medium()),
                    Switch(
                      value: enabled,
                      onChanged: (value) => configController.setEnabled(value),
                    ),
                  ],
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  Text(l10n.settings_news_description).muted().small(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Carte d'entrée vers [TaxParametersScreen] (voir sa doc de classe) —
/// juste un bouton, la personnalisation elle-même se fait sur son propre
/// écran plutôt que dans cette carte, vu le nombre de valeurs concernées
/// (barèmes IR/IFI/démembrement/donation, une dizaine de tranches
/// chacune).
class _TaxParametersCard extends StatelessWidget {
  final String vaultPath;

  const _TaxParametersCard({required this.vaultPath});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              LucideIcons.scale,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settings_tax_parameters).large().medium(),
                  const SizedBox(height: 4),
                  Text(l10n.settings_tax_parameters_description).muted().small(),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlineButton(
              onPressed: () =>
                  NavigationScope.maybeOf(context)?.call('tax_parameters'),
              child: Text(l10n.common_edit),
            ),
          ],
        ),
      ),
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
        final l10n = AppLocalizations.of(context);
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
                      child: Text(l10n.settings_shortcuts).large().medium(),
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
    final l10n = AppLocalizations.of(context);
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
                Expanded(
                  child: Text(l10n.settings_encryption).large().medium(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              enabled
                  ? l10n.settings_encryption_enabled
                  : l10n.settings_encryption_disabled,
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
                    child: Text(l10n.settings_encryption_regenerate_key),
                  ),
                  DestructiveButton(
                    onPressed: _disable,
                    leading: const Icon(LucideIcons.lockOpen),
                    child: Text(l10n.settings_encryption_disable),
                  ),
                ],
              )
            else
              PrimaryButton(
                onPressed: _enable,
                leading: const Icon(LucideIcons.lock),
                child: Text(l10n.settings_encryption_enable),
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
    // Demandé avant d'ouvrir le sélecteur de dossier natif : ne s'applique
    // vraiment que si le dossier choisi correspond à un coffre-fort
    // réellement nouveau (voir `VaultFolderService.pickAndRememberVault`),
    // mais poser la question à ce moment reste la meilleure place pour ne
    // pas interrompre le flux une fois le dossier déjà choisi.
    // Uniquement la valeur destinée au dialogue natif est capturée ici,
    // avant tout `await`, pour éviter d'utiliser `context` après un trou
    // asynchrone (voir la remarque de `mounted` plus bas).
    final dialogTitle =
        AppLocalizations.of(context).settings_vault_pick_dialog_title;
    final kind = await showVaultKindDialog(context);
    if (kind == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vault = await widget.vaultFolderService.pickAndRememberVault(
        dialogTitle: dialogTitle,
        kind: kind,
      );
      if (vault != null) {
        await widget.onVaultActivated(vault.vaultPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).settings_vault_add_failed(e);
        });
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
        setState(() {
          _error = AppLocalizations.of(context).settings_vault_activate_failed(e);
        });
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
        setState(() {
          _error = AppLocalizations.of(context).settings_vault_forget_failed(e);
        });
      }
    } finally {
      await _loadVaults();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeId = _activeVaultId;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settings_vaults).large().medium(),
            const SizedBox(height: 8),
            Text(l10n.settings_vaults_description).muted().small(),
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
                child: Text(l10n.settings_add_vault),
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
                            child: Text(
                              AppLocalizations.of(context).common_active,
                            ).small(),
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
                      child: Text(
                        AppLocalizations.of(context).common_switch,
                      ),
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
              placeholder: Text(
                AppLocalizations.of(context).settings_vault_name_hint,
              ),
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
        final l10n = AppLocalizations.of(context);

        return FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.settings_comptes).large().medium(),
                const SizedBox(height: 8),
                Text(l10n.settings_comptes_description).muted().small(),
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
                      child: Text(
                        AppLocalizations.of(context).common_principal,
                      ).small(),
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
            child: Text(AppLocalizations.of(context).common_switch),
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _editNameController,
              placeholder: Text(l10n.settings_profile_name),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _editRelationshipController,
              placeholder: Text(l10n.settings_profile_relationship),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newNameController,
                placeholder: Text(l10n.settings_profile_name_hint),
                autofocus: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _newRelationshipController,
                placeholder: Text(l10n.settings_profile_relationship_hint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            PrimaryButton(
              onPressed: _commitCreate,
              child: Text(l10n.settings_create_account),
            ),
            const SizedBox(width: 8),
            OutlineButton(
              onPressed: () => setState(() => _creating = false),
              child: Text(l10n.common_cancel),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    final l10n = AppLocalizations.of(context);
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
            l10n.settings_add_account,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

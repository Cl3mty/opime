import 'dart:async' show unawaited;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/assistant/assistant_chat_controller.dart';
import 'core/assistant/assistant_config_controller.dart';
import 'core/notifications/notifications_settings_controller.dart';
import 'core/privacy/amount_visibility_controller.dart';
import 'core/shortcuts/keyboard_shortcuts_controller.dart';
import 'core/storage/vault_crypto.dart' show VaultCipher;
import 'core/storage/vault_encryption_metadata.dart';
import 'core/storage/vault_encryption_repository.dart';
import 'core/storage/vault_folder_service.dart';
import 'core/storage/vault_session.dart';
import 'core/profiles/profile_controller.dart';
import 'core/profiles/profile_repository.dart';
import 'core/profiles/sidebar_prefs_controller.dart';
import 'core/updates/update_banner.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/vault_recovery_screen.dart';
import 'features/onboarding/vault_unlock_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/account_management_screen.dart';
import 'features/assistant/assistant_screen.dart';
import 'app/theme_controller.dart';
import 'app/app_shell.dart';
import 'core/platform_info.dart';
import 'core/ui/load_error_view.dart';
import 'core/ui/mobile_orientation.dart';
import 'features/analyses/analyses_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/onboarding_highlight_controller.dart';
import 'features/projects/projects_screen.dart';
import 'features/investments/investments_models.dart' show AssetClass;
import 'features/investments/patrimoine_refresh_controller.dart';
import 'features/investments/price_sync_banner.dart';
import 'features/investments/price_sync_status_controller.dart';
import 'features/investments/real_category_detail_screen.dart';
import 'features/notifications/notifications_controller.dart';
import 'features/liabilities/liabilities_models.dart' show LiabilityType;
import 'features/liabilities/real_passif_detail_screen.dart';
import 'features/strategy/strategy_screen.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'features/budget/budget_screen.dart';
import 'features/simulations/simulations_taxation_screen.dart';
import 'features/simulations/simulations_wealth_screen.dart';
import 'features/simulations/simulations_real_estate_screen.dart';
import 'features/simulations/simulations_transmission_screen.dart';
import 'features/budget/budget_tracking_screen.dart';
import 'features/academy/envelope_sheet_screen.dart';
import 'features/academy/envelopes_data.dart';
import 'features/academy/investissement_card_screen.dart';
import 'features/academy/investissement_data.dart';
import 'features/academy/formation_track_screen.dart';
import 'features/academy/formation_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Verrouille l'app en mode portrait par défaut sur mobile ; seuls
  // certains écrans (ex : ventilation du budget) l'autorisent
  // temporairement via allowLandscapeOnMobile().
  lockPortraitOnMobile();

  // window_manager n'a pas d'implémentation mobile : il ne doit être
  // initialisé que sur les plateformes desktop qu'il supporte réellement.
  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1440, 900),
      minimumSize: Size(1024, 700),
      center: true,
      title: 'Opime',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const OpimeApp());
}

class OpimeApp extends StatefulWidget {
  const OpimeApp({super.key});

  @override
  State<OpimeApp> createState() => _OpimeAppState();
}

class _OpimeAppState extends State<OpimeApp> {
  static const _githubOwner = 'Cl3mty';
  static const _githubRepo = 'opime';

  final _themeController = ThemeController();
  final _amountVisibilityController = AmountVisibilityController();
  final _keyboardShortcutsController = KeyboardShortcutsController();
  final _assistantConfigController = AssistantConfigController();
  final _notificationsSettingsController = NotificationsSettingsController();
  final _notificationsController = NotificationsController();
  final _patrimoineRefreshController = PatrimoineRefreshController();
  final _priceSyncStatusController = PriceSyncStatusController();
  final _onboardingHighlightController = OnboardingHighlightController();
  final _vaultFolderService = VaultFolderService();

  bool _checkingVault = true;
  String? _vaultPath;
  ProfileController? _profileController;
  SidebarPrefsController? _sidebarPrefsController;
  Object? _profilesLoadError;

  /// Métadonnées de chiffrement du vault actif, non nulles dès que
  /// `.opime/vault_encryption.json` existe et `enabled == true` — voir
  /// [_initProfiles], qui bloque le chargement des profils tant que
  /// [_vaultLocked] est vrai (aucun repository ne peut rien lire sans la
  /// DEK déverrouillée, voir `VaultSession.current`).
  VaultEncryptionMetadata? _vaultEncryptionMetadata;
  bool _vaultLocked = false;

  /// Bascule vers l'écran de récupération (clé de récupération → nouveau
  /// mot de passe) depuis l'écran de déverrouillage classique.
  bool _showingVaultRecovery = false;

  /// Conversation avec l'assistant : vit ici (et non dans l'écran) pour
  /// que les réponses continuent en arrière-plan quand on navigue ailleurs.
  /// Recréé quand le contexte change (vault ou profil actif), ce qui coupe
  /// proprement les requêtes en cours — d'où le toast d'interruption.
  AssistantChatController? _assistantChatController;

  /// Clé de contexte du controller courant : `vaultPath|profileId`. Quand
  /// elle change, la conversation est remise à zéro (données d'un autre
  /// profil = autre conversation).
  String? _assistantChatScope;

  /// Clé de contexte du dernier rafraîchissement des notifications
  /// (`vaultPath|profileId`) — même rôle que [_assistantChatScope], pour ne
  /// relancer un rafraîchissement que quand le profil/vault a réellement
  /// changé.
  String? _notificationsScope;

  void _handleProfileControllerChanged() {
    _recreateAssistantChat();
    _refreshNotificationsIfNeeded();
    if (mounted) setState(() {});
  }

  /// Recharge les notifications (actualités/alertes) pour le profil actif
  /// si le contexte a changé, ou ne fait rien si la fonctionnalité est
  /// désactivée dans les Réglages — aucune requête réseau tant qu'elle ne
  /// l'est pas.
  void _refreshNotificationsIfNeeded() {
    if (!_notificationsSettingsController.enabled) return;
    final profile = _profileController;
    if (profile == null || profile.active == null) return;
    final scope = '$_vaultPath|${profile.active!.id}';
    if (scope == _notificationsScope) return;
    _notificationsScope = scope;
    unawaited(
      _notificationsController.refresh(
        profile.activeDataPath,
        lastSeen: _notificationsSettingsController.lastSeen,
      ),
    );
  }

  /// Activer la fonctionnalité depuis les Réglages doit peupler le badge
  /// sans attendre l'ouverture du panneau : réinitialise le contexte
  /// mémorisé pour forcer [_refreshNotificationsIfNeeded] à relancer un
  /// chargement dès la transition désactivé → activé.
  void _onNotificationsSettingsChanged() {
    if (_notificationsSettingsController.enabled) {
      _notificationsScope = null;
      _refreshNotificationsIfNeeded();
    }
  }

  /// (Re)crée le controller de chat quand le vault ou le profil actif a
  /// changé. L'ancien est disposé (requêtes annulées) et, si une réponse
  /// était en cours, un toast prévient l'utilisateur qu'elle a été coupée.
  void _recreateAssistantChat() {
    final profile = _profileController;
    if (profile == null || profile.active == null) return;
    final scope = '$_vaultPath|${profile.active!.id}';
    if (scope == _assistantChatScope) return;

    final old = _assistantChatController;
    final wasBusy = old?.busy ?? false;
    old?.dispose();
    _assistantChatScope = scope;
    _assistantChatController = AssistantChatController(
      config: _assistantConfigController,
      activeDataPath: () => profile.activeDataPath,
    );
    if (wasBusy && mounted) {
      // Le changement de contexte (vault/profil) coupe les réponses en
      // cours : on le signale plutôt que de laisser l'utilisateur croire
      // qu'elles arrivent encore.
      showToast(
        context: context,
        location: ToastLocation.bottomRight,
        builder: (context, overlay) => SurfaceCard(
          child: Basic(
            leading: const Icon(LucideIcons.circlePause, size: 18),
            title: const Text('Réponse interrompue'),
            subtitle: const Text(
              'Le profil ou le vault a changé pendant la génération.',
            ),
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _themeController.load();
    _themeController.addListener(() => setState(() {}));
    _amountVisibilityController.load();
    _keyboardShortcutsController.load();
    _assistantConfigController.load();
    _notificationsSettingsController.load();
    _notificationsSettingsController.addListener(
      _onNotificationsSettingsChanged,
    );
    _loadVault();
  }

  Future<void> _loadVault() async {
    final activeVault = await _vaultFolderService.getActiveVault();
    final path = activeVault?.vaultPath;
    setState(() {
      _vaultPath = path;
      _checkingVault = false;
    });
    if (path != null) await _initProfiles(path);
  }

  Future<void> _initProfiles(String vaultPath) async {
    // Vault chiffré et pas encore déverrouillé pour cette session : aucun
    // repository ne peut rien lire sans la DEK (voir `VaultSession.current`)
    // — on affiche l'écran de déverrouillage au lieu de continuer, voir
    // `_buildHome`. Après un déverrouillage réussi, `_onVaultUnlocked`
    // rappelle `_initProfiles` : `VaultSession.current` est alors posé, ce
    // garde-fou ne se redéclenche pas.
    if (VaultSession.current == null) {
      final metadata = await VaultEncryptionRepository(vaultPath).load();
      if (metadata != null && metadata.enabled) {
        if (!mounted) return;
        setState(() {
          _vaultPath = vaultPath;
          _vaultEncryptionMetadata = metadata;
          _vaultLocked = true;
          _profileController = null;
          _sidebarPrefsController = null;
          _profilesLoadError = null;
        });
        return;
      }
    }

    final oldController = _profileController;
    oldController?.removeListener(_handleProfileControllerChanged);
    oldController?.dispose();

    setState(() {
      _vaultPath = vaultPath;
      _profileController = null;
      _sidebarPrefsController = null;
      _profilesLoadError = null;
    });

    final controller = ProfileController(ProfileRepository(vaultPath));
    try {
      await controller.load();
    } catch (e) {
      // Un dossier Vault synchronisé (iCloud Drive...) pas encore
      // totalement téléchargé peut faire échouer la lecture des profils :
      // sans ce garde-fou, l'app restait bloquée sur un spinner infini (ou
      // plantait) au lieu de proposer de réessayer.
      controller.dispose();
      if (!mounted) return;
      setState(() => _profilesLoadError = e);
      return;
    }
    controller.addListener(_handleProfileControllerChanged);
    final sidebarPrefs = SidebarPrefsController(controller);
    if (!mounted) {
      controller.removeListener(_handleProfileControllerChanged);
      controller.dispose();
      return;
    }
    setState(() {
      _profileController = controller;
      _sidebarPrefsController = sidebarPrefs;
    });
    _recreateAssistantChat();
    _refreshNotificationsIfNeeded();
  }

  void _retryInitProfiles() {
    final path = _vaultPath;
    if (path != null) _initProfiles(path);
  }

  Future<void> _onVaultReady(String path) async {
    await _initProfiles(path);
  }

  /// Déverrouillage réussi (mot de passe ou récupération, voir
  /// [_onVaultRecovered]) : pose la clé pour le reste du process
  /// ([VaultSession.current], jamais persistée — voir sa documentation)
  /// puis relance le chargement des profils, cette fois avec la clé posée.
  void _onVaultUnlocked(VaultCipher cipher) {
    VaultSession.current = cipher;
    setState(() {
      _vaultLocked = false;
      _showingVaultRecovery = false;
    });
    final path = _vaultPath;
    if (path != null) _initProfiles(path);
  }

  /// Récupération par clé terminée (voir `VaultRecoveryScreen`) : persiste
  /// la nouvelle enveloppe mot de passe avant de déverrouiller la session,
  /// pour que le prochain lancement utilise directement le nouveau mot de
  /// passe (l'ancien ne fonctionne plus, voir
  /// `VaultEncryptionMetadata.rewrapPassword`).
  Future<void> _onVaultRecovered(
    VaultEncryptionMetadata updatedMetadata,
    VaultCipher cipher,
  ) async {
    final path = _vaultPath;
    if (path == null) return;
    await VaultEncryptionRepository(path).save(updatedMetadata);
    if (!mounted) return;
    setState(() => _vaultEncryptionMetadata = updatedMetadata);
    _onVaultUnlocked(cipher);
  }

  void _resetVault() {
    _profileController?.removeListener(_handleProfileControllerChanged);
    _profileController?.dispose();
    _assistantChatController?.dispose();
    _assistantChatController = null;
    _assistantChatScope = null;
    _notificationsScope = null;
    VaultSession.current = null;
    setState(() {
      _vaultPath = null;
      _profileController = null;
      _sidebarPrefsController = null;
      _vaultEncryptionMetadata = null;
      _vaultLocked = false;
      _showingVaultRecovery = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'Opime',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: LegacyColorSchemes.lightZinc().recolor(
          const Color(0xFFF4BE7E),
        ),
        radius: 0.6,
      ),
      darkTheme: ThemeData(
        colorScheme: LegacyColorSchemes.darkZinc().recolor(
          const Color(0xFFF4BE7E),
        ),
        radius: 0.6,
      ),
      themeMode: _themeController.mode,
      home: _buildHome(),
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
    );
  }

  Widget _buildHome() {
    if (_checkingVault) {
      return const Scaffold(child: Center(child: CircularProgressIndicator()));
    }
    if (_vaultPath == null) {
      return OnboardingScreen(
        vaultFolderService: _vaultFolderService,
        onVaultReady: _onVaultReady,
      );
    }
    if (_vaultLocked) {
      final metadata = _vaultEncryptionMetadata;
      if (metadata == null) {
        // Ne devrait jamais arriver (_vaultLocked implique metadata non
        // nulle, voir _initProfiles) — filet de sécurité plutôt qu'un
        // écran cassé.
        return const Scaffold(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (_showingVaultRecovery) {
        return VaultRecoveryScreen(
          metadata: metadata,
          onRecovered: _onVaultRecovered,
          onCancel: () => setState(() => _showingVaultRecovery = false),
        );
      }
      return VaultUnlockScreen(
        metadata: metadata,
        onUnlocked: _onVaultUnlocked,
        onForgotPassword: () => setState(() => _showingVaultRecovery = true),
      );
    }
    if (_profilesLoadError != null) {
      return Scaffold(
        child: LoadErrorView(
          message:
              'Impossible de charger les profils. Le dossier Vault est '
              'peut-être encore en cours de synchronisation.',
          onRetry: _retryInitProfiles,
        ),
      );
    }
    if (_profileController == null || _sidebarPrefsController == null) {
      return const Scaffold(child: Center(child: CircularProgressIndicator()));
    }
    return UpdateBanner(
      githubOwner: _githubOwner,
      githubRepo: _githubRepo,
      child: PriceSyncBanner(
        controller: _priceSyncStatusController,
        child: AppShell(
          themeController: _themeController,
          profileController: _profileController!,
          sidebarPrefsController: _sidebarPrefsController!,
          amountVisibilityController: _amountVisibilityController,
          keyboardShortcutsController: _keyboardShortcutsController,
          patrimoineRefreshController: _patrimoineRefreshController,
          onboardingHighlightController: _onboardingHighlightController,
          priceSyncStatusController: _priceSyncStatusController,
          assistantConfigController: _assistantConfigController,
          assistantChatController: _assistantChatController!,
          notificationsSettingsController: _notificationsSettingsController,
          notificationsController: _notificationsController,
          pages: {
            'dashboard': (_) => DashboardScreen(
              key: ValueKey(_profileController!.activeDataPath),
              vaultPath: _profileController!.activeDataPath,
              amountVisibility: _amountVisibilityController,
              refreshSignal: _patrimoineRefreshController,
              priceSyncStatus: _priceSyncStatusController,
              onboardingHighlight: _onboardingHighlightController,
            ),
            'analyses': (_) => AnalysesScreen(
              key: ValueKey(_profileController!.activeDataPath),
              vaultPath: _profileController!.activeDataPath,
              amountVisibility: _amountVisibilityController,
            ),
            'projets': (_) => ProjectsScreen(
              key: ValueKey(_profileController!.activeDataPath),
              vaultPath: _profileController!.activeDataPath,
            ),
            for (final assetClass in AssetClass.values)
              assetClass.categoryId: (_) => RealCategoryDetailScreen(
                key: ValueKey(
                  '${_profileController!.activeDataPath}_${assetClass.categoryId}',
                ),
                vaultPath: _profileController!.activeDataPath,
                categoryId: assetClass.categoryId,
                amountVisibility: _amountVisibilityController,
                patrimoineRefreshController: _patrimoineRefreshController,
              ),
            for (final liabilityType in LiabilityType.values)
              liabilityType.categoryId: (_) => RealPassifDetailScreen(
                key: ValueKey(
                  '${_profileController!.activeDataPath}_${liabilityType.categoryId}',
                ),
                vaultPath: _profileController!.activeDataPath,
                categoryId: liabilityType.categoryId,
                amountVisibility: _amountVisibilityController,
                patrimoineRefreshController: _patrimoineRefreshController,
              ),
            for (final envelope in envelopes)
              envelope.id: (_) => EnvelopeSheetScreen(
                key: ValueKey(
                  '${_profileController!.activeDataPath}_${envelope.id}',
                ),
                vaultPath: _profileController!.activeDataPath,
                envelope: envelope,
              ),
            for (final card in investissementCards)
              card.id: (_) => InvestissementCardScreen(
                key: ValueKey(
                  '${_profileController!.activeDataPath}_${card.id}',
                ),
                vaultPath: _profileController!.activeDataPath,
                card: card,
              ),
            for (final track in formationTracks)
              track.id: (_) => FormationTrackScreen(
                key: ValueKey(
                  '${_profileController!.activeDataPath}_${track.id}',
                ),
                vaultPath: _profileController!.activeDataPath,
                track: track,
              ),
            'strategie': (_) => StrategyScreen(
              key: ValueKey(_profileController!.activeDataPath),
              vaultPath: _profileController!.activeDataPath,
            ),
            'budget_ventilation': (_) => BudgetScreen(
              key: ValueKey(_profileController!.activeDataPath),
              vaultPath: _profileController!.activeDataPath,
              amountVisibility: _amountVisibilityController,
            ),
            'budget_suivi': (_) => BudgetTrackingScreen(
              key: ValueKey(_profileController!.activeDataPath),
              vaultPath: _profileController!.activeDataPath,
              amountVisibility: _amountVisibilityController,
            ),
            'simulation_taxation': (_) => TaxationSimulationScreen(
              key: ValueKey(_profileController!.activeDataPath),
              vaultPath: _profileController!.activeDataPath,
              amountVisibility: _amountVisibilityController,
            ),
            'simulation_patrimoine': (_) => WealthSimulationScreen(
              key: ValueKey(_profileController!.activeDataPath),
              vaultPath: _profileController!.activeDataPath,
              amountVisibility: _amountVisibilityController,
            ),
            'simulation_immobilier': (_) => RealEstateSimulationScreen(
              key: ValueKey(_profileController!.activeDataPath),
              vaultPath: _profileController!.activeDataPath,
              amountVisibility: _amountVisibilityController,
            ),
            'simulation_transmission': (_) => TransmissionSimulationScreen(
              key: ValueKey(_profileController!.activeDataPath),
              vaultPath: _profileController!.activeDataPath,
              amountVisibility: _amountVisibilityController,
            ),
            'assistant': (_) => AssistantScreen(
              key: ValueKey('assistant_${_profileController!.activeDataPath}'),
              configController: _assistantConfigController,
              chatController: _assistantChatController!,
            ),
            'account_management': (_) =>
                AccountManagementScreen(profileController: _profileController!),
            'settings': (_) => SettingsScreen(
              vaultFolderService: _vaultFolderService,
              onVaultActivated: _onVaultReady,
              onNoVaultSelected: _resetVault,
              themeController: _themeController,
              assistantConfigController: _assistantConfigController,
              notificationsSettingsController: _notificationsSettingsController,
              keyboardShortcutsController: _keyboardShortcutsController,
              vaultPath: _vaultPath!,
              onVaultEncryptionChanged: () => _initProfiles(_vaultPath!),
              githubOwner: _githubOwner,
              githubRepo: _githubRepo,
            ),
          },
        ),
      ),
    );
  }
}

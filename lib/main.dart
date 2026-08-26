import 'dart:async' show unawaited;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/assistant/assistant_chat_controller.dart';
import 'core/assistant/assistant_config_controller.dart';
import 'core/notifications/notifications_settings_controller.dart';
import 'core/privacy/amount_visibility_controller.dart';
import 'core/shortcuts/app_shortcuts.dart';
import 'core/shortcuts/keyboard_shortcuts_controller.dart';
import 'core/storage/vault_crypto.dart' show VaultCipher;
import 'core/storage/vault_encryption_metadata.dart';
import 'core/storage/vault_encryption_repository.dart';
import 'core/storage/vault_folder_service.dart';
import 'core/storage/vault_migration_marker.dart';
import 'core/storage/vault_session.dart';
import 'core/profiles/profile_controller.dart';
import 'core/profiles/profile_repository.dart';
import 'core/profiles/sidebar_prefs_controller.dart';
import 'core/updates/update_banner.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/vault_migration_interrupted_screen.dart';
import 'features/onboarding/vault_recovery_screen.dart';
import 'features/onboarding/vault_unlock_screen.dart';
import 'features/settings/settings_screen.dart';
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
import 'features/patrimoine_export/patrimoine_export_dialog.dart';
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

  /// Le `BuildContext` reçu par `ShadcnApp.builder` (voir [_buildShortcuts])
  /// est un ANCÊTRE du Navigator interne de l'app, pas un descendant — donc
  /// invalide pour `showDialog`/`Navigator.of` (l'appel échoue silencieusement
  /// avec "Navigator operation requested with a context that does not
  /// include a Navigator", visible seulement dans les logs). Cette clé donne
  /// accès, via `_navigatorKey.currentContext`, à un contexte réellement posé
  /// SOUS le Navigator, valide pour ces opérations.
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// `showDialog` empile une nouvelle route (avec sa propre pénombre) à
  /// chaque appel — sans ce garde, appuyer plusieurs fois sur ⌘P empilait
  /// autant de boîtes de dialogue transparentes les unes sur les autres, ce
  /// qui assombrissait progressivement l'écran au lieu de rouvrir/fermer un
  /// seul dialogue. Vrai pendant toute la durée de vie du dialogue (posé à
  /// l'ouverture, remis à `false` quand `showPatrimoineExportDialog` se
  /// termine, quelle que soit la façon dont il se ferme).
  bool _exportDialogOpen = false;

  /// État (replié/déplié) de la sidebar — remonté ici depuis `AppShell` pour
  /// que le raccourci clavier ⌘B, posé à la racine de l'app (voir
  /// `ShadcnApp`'s `builder` dans [build]), puisse le modifier. Un
  /// `CallbackShortcuts` posé plus bas dans l'arbre (à l'intérieur d'une
  /// route, comme c'était le cas avant dans `AppShell`) ne reçoit jamais les
  /// évènements clavier tant que le focus est ailleurs — typiquement dans
  /// une boîte de dialogue, elle-même une AUTRE route du même Navigator,
  /// donc pas un descendant du contenu de la route "accueil" : c'est ce qui
  /// rendait les raccourcis silencieusement inopérants dès qu'un dialogue
  /// était ouvert. Posés ici, en ancêtre du Navigator lui-même, ils restent
  /// actifs quel que soit ce qui a le focus.
  final _sidebarCollapsed = ValueNotifier<bool>(false);

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

  /// Vrai quand `VaultMigrationMarker` détecte qu'une opération activer/
  /// désactiver le chiffrement a été interrompue avant sa fin sur ce vault
  /// (voir `vault_migration_interrupted_screen.dart`) — bloque tout
  /// chargement de profil tant que l'utilisateur n'a pas explicitement
  /// choisi de continuer malgré l'avertissement.
  bool _vaultMigrationInterrupted = false;

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
    // Réévalue le `builder` de ShadcnApp (voir [build]) quand les Réglages
    // activent/désactivent les raccourcis clavier — sans ça, la nouvelle
    // valeur ne serait relue qu'au prochain rebuild déclenché par autre
    // chose.
    _keyboardShortcutsController.addListener(() => setState(() {}));
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
    // Priorité absolue sur tout le reste, chiffré ou non : une migration
    // interrompue peut avoir laissé des fichiers privés dans un état mixte
    // (voir `VaultMigrationMarker`) — mieux vaut bloquer explicitement que
    // de charger un vault potentiellement incohérent en silence.
    if (await VaultMigrationMarker.exists(vaultPath)) {
      if (!mounted) return;
      setState(() {
        _vaultPath = vaultPath;
        _vaultMigrationInterrupted = true;
        _profileController = null;
        _sidebarPrefsController = null;
        _profilesLoadError = null;
      });
      return;
    }

    // Changement de vault pendant qu'une clé d'un AUTRE vault était encore
    // posée (ex : "Changer de dossier de vault" depuis l'écran de
    // déverrouillage, ou changement de vault actif depuis les Réglages) :
    // sans cette invalidation, les repositories du nouveau vault
    // hériteraient de la clé de l'ancien via VaultSession.current, ce qui
    // chiffrerait/déchiffrerait ses fichiers avec la mauvaise clé.
    if (VaultSession.current != null && VaultSession.vaultPath != vaultPath) {
      VaultSession.current = null;
      VaultSession.vaultPath = null;
    }

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
          _vaultMigrationInterrupted = false;
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
      _vaultMigrationInterrupted = false;
      // Sans ça, changer de vault chiffré -> non chiffré (bouton "Changer
      // de dossier de vault" sur VaultUnlockScreen) laisse _vaultLocked à
      // true : _buildHome reste bloqué sur l'écran de déverrouillage de
      // l'ANCIEN vault alors que les profils du nouveau viennent de
      // charger normalement en dessous.
      _vaultLocked = false;
      _vaultEncryptionMetadata = null;
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

  /// L'utilisateur choisit d'ignorer l'avertissement de migration
  /// interrompue (voir [VaultMigrationInterruptedScreen]) : efface le
  /// marqueur puis relance le chargement normalement.
  Future<void> _continueDespiteInterruptedMigration() async {
    final path = _vaultPath;
    if (path == null) return;
    await VaultMigrationMarker.clear(path);
    setState(() => _vaultMigrationInterrupted = false);
    await _initProfiles(path);
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
    VaultSession.vaultPath = _vaultPath;
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
    VaultSession.vaultPath = null;
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
      navigatorKey: _navigatorKey,
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
      // Ancêtre du Navigator (donc de toute route, y compris une boîte de
      // dialogue) plutôt que posés à l'intérieur de la route "accueil" —
      // voir la documentation de [_sidebarCollapsed] pour pourquoi c'est le
      // seul endroit où ces raccourcis fonctionnent de façon fiable.
      builder: (context, child) => _buildShortcuts(context, child!),
    );
  }

  Widget _buildShortcuts(BuildContext context, Widget child) {
    if (!_keyboardShortcutsController.enabled) return child;
    return CallbackShortcuts(
      bindings: {
        AppShortcutAction.toggleSidebar.activator: () =>
            _sidebarCollapsed.value = !_sidebarCollapsed.value,
        AppShortcutAction.toggleAmountsHidden.activator: () =>
            _amountVisibilityController.toggle(),
        AppShortcutAction.exportPdf.activator: () {
          // `context` ici (celui du builder de ShadcnApp) est un ancêtre du
          // Navigator, pas un descendant : `showDialog` y échouerait
          // silencieusement. `_navigatorKey.currentContext` est le contexte
          // du Navigator lui-même, valide pour ouvrir une boîte de dialogue.
          final navigatorContext = _navigatorKey.currentContext;
          if (navigatorContext == null) return;
          // Rejouer ⌘P pendant que le dialogue est déjà ouvert le referme —
          // un vrai toggle, plutôt que d'empiler une boîte de dialogue de
          // plus à chaque pression.
          if (_exportDialogOpen) {
            Navigator.of(navigatorContext).pop();
            return;
          }
          final profileController = _profileController;
          if (profileController == null) {
            _showExportUnavailableToast(navigatorContext);
            return;
          }
          _exportDialogOpen = true;
          showPatrimoineExportDialog(
            navigatorContext,
            vaultPath: profileController.activeDataPath,
            profileName: profileController.active?.name ?? '',
          ).whenComplete(() => _exportDialogOpen = false);
        },
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  /// Explique pourquoi Cmd/Ctrl+P n'a rien fait plutôt que de rester
  /// silencieux — le raccourci ne peut pas ouvrir l'export tant qu'aucun
  /// profil n'est chargé (vault verrouillé, migration en attente, ou
  /// chargement/erreur en cours).
  void _showExportUnavailableToast(BuildContext context) {
    final String title;
    final String subtitle;
    if (_vaultLocked) {
      title = 'Vault verrouillé';
      subtitle = "Déverrouille ton vault avant d'exporter.";
    } else if (_vaultMigrationInterrupted) {
      title = 'Migration en attente';
      subtitle = "Termine la migration du vault avant d'exporter.";
    } else {
      title = 'Aucun profil chargé';
      subtitle = 'Réessaie une fois le vault chargé.';
    }
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(title: Text(title), subtitle: Text(subtitle)),
      ),
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
    if (_vaultMigrationInterrupted) {
      return VaultMigrationInterruptedScreen(
        vaultPath: _vaultPath!,
        onContinueAnyway: _continueDespiteInterruptedMigration,
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
        vaultFolderService: _vaultFolderService,
        onVaultActivated: _onVaultReady,
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
          patrimoineRefreshController: _patrimoineRefreshController,
          onboardingHighlightController: _onboardingHighlightController,
          priceSyncStatusController: _priceSyncStatusController,
          assistantConfigController: _assistantConfigController,
          assistantChatController: _assistantChatController!,
          notificationsSettingsController: _notificationsSettingsController,
          notificationsController: _notificationsController,
          sidebarCollapsed: _sidebarCollapsed,
          vaultFolderService: _vaultFolderService,
          onVaultActivated: _onVaultReady,
          onNoVaultSelected: _resetVault,
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
            'settings': (_) => SettingsScreen(
              vaultFolderService: _vaultFolderService,
              onVaultActivated: _onVaultReady,
              onNoVaultSelected: _resetVault,
              themeController: _themeController,
              assistantConfigController: _assistantConfigController,
              notificationsSettingsController: _notificationsSettingsController,
              keyboardShortcutsController: _keyboardShortcutsController,
              profileController: _profileController!,
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

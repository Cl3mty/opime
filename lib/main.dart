import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' as material;
import 'package:flutter_localizations/flutter_localizations.dart' as fl;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/notifications/notifications_settings_controller.dart';
import 'core/privacy/amount_visibility_controller.dart';
import 'core/shortcuts/app_shortcuts.dart';
import 'core/shortcuts/keyboard_shortcuts_controller.dart';
import 'core/ui/shadcn_localizations_fr.dart';
import 'core/storage/vault_crypto.dart' show VaultCipher;
import 'core/storage/vault_encryption_metadata.dart';
import 'core/storage/vault_fs.dart' show initVaultFs;
import 'core/storage/vault_encryption_repository.dart';
import 'core/storage/vault_folder_service.dart';
import 'core/storage/vault_migration_marker.dart';
import 'core/storage/vault_session.dart';
import 'core/profiles/profile_controller.dart';
import 'core/profiles/profile_repository.dart';
import 'core/profiles/sidebar_prefs_controller.dart';
import 'core/updates/update_banner.dart';
import 'features/onboarding/local_folder_reauth_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/vault_migration_interrupted_screen.dart';
import 'features/onboarding/vault_recovery_screen.dart';
import 'features/onboarding/vault_unlock_screen.dart';
import 'features/assistant/assistant_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/tax_parameters_screen.dart';
import 'app/theme_controller.dart';
import 'app/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'app/app_shell.dart';
import 'core/platform_info.dart';
import 'core/web_navigation.dart';
import 'core/ui/app_loading_screen.dart';
import 'core/ui/load_error_view.dart';
import 'core/ui/mobile_orientation.dart';
import 'features/analyses/analyses_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/entities/entities_screen.dart';
import 'features/landing/landing_screen.dart';
import 'features/dashboard/onboarding_highlight_controller.dart';
import 'features/projects/projects_screen.dart';
import 'features/investments/current_account_focus_controller.dart';
import 'features/investments/investment_reminder_banner.dart';
import 'features/investments/investments_models.dart' show AssetClass;
import 'features/investments/patrimoine_refresh_controller.dart';
import 'features/investments/price_sync_banner.dart';
import 'features/investments/price_sync_status_controller.dart';
import 'features/investments/real_category_detail_screen.dart';
import 'features/notifications/notifications_controller.dart';
import 'features/patrimoine_export/patrimoine_export_dialog.dart';
import 'features/transactions_export/transactions_export_dialog.dart';
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
import 'core/premium/locked_feature_screen.dart';

/// Chemin web dédié à l'app "nue", sans passer par la vitrine commerciale
/// (voir [LandingScreen]) — `opime.vercel.app/` (et tout autre chemin) sert
/// systématiquement la landing page, `opime.vercel.app/home` (ce chemin) va
/// directement à l'onboarding/l'app. Un simple chemin d'URL plutôt qu'un
/// vrai routeur : l'app n'a par ailleurs aucune route nommée (navigation
/// interne pilotée par état, voir `AppShell`) — [Uri.base] est donc relu à
/// chaque build de [_OpimeAppState._buildHome] plutôt que mémorisé une
/// seule fois, pour réagir à [replaceUrlPath] sans recharger la page.
const _homePath = '/home';

/// `true` si l'URL affichée est [_homePath] — voir [_homePath]. Sans objet
/// hors web (`Uri.base` y refléterait le répertoire de travail du
/// processus, pas une URL de navigateur).
bool _isOnHomePath() {
  final path = Uri.base.path;
  return path == _homePath || path.startsWith('$_homePath/');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise la couche de stockage : sur le web, ouvre la racine de la
  // zone de stockage privée (OPFS) du navigateur ; sur desktop, le système
  // de fichiers natif est utilisé tel quel.
  await initVaultFs();

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
  static const _githubRepo = 'opime-free';

  final _themeController = ThemeController();
  final _localeController = LocaleController();
  final _amountVisibilityController = AmountVisibilityController();
  final _keyboardShortcutsController = KeyboardShortcutsController();
  final _notificationsSettingsController = NotificationsSettingsController();
  final _notificationsController = NotificationsController();
  final _patrimoineRefreshController = PatrimoineRefreshController();
  final _currentAccountFocusController = CurrentAccountFocusController();
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

  /// Même garde que [_exportDialogOpen], pour ⌘E (export des transactions)
  /// — un dialogue distinct, donc son propre drapeau plutôt que de
  /// réutiliser celui du PDF (les deux peuvent en théorie être ouverts l'un
  /// après l'autre, jamais simultanément dans la pratique mais rien ne
  /// l'empêche techniquement).
  bool _transactionsExportDialogOpen = false;

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

  /// Nom du coffre-fort actif, résolu dans [_initProfiles] — utilisé
  /// uniquement par [LocalFolderReauthScreen] (voir
  /// [_webLocalFolderNeedsReauth]), à un moment où [_profileController]
  /// n'est pas encore chargé et ne peut donc pas fournir ce nom autrement.
  String? _activeVaultName;

  /// Id (`SavedVault.id`) du coffre-fort actif, résolu dans [_initProfiles]
  /// en même temps que [_activeVaultName] — sur le build web, [_vaultPath]
  /// seul ne suffit PAS à distinguer deux coffres-forts distincts (voir la
  /// doc de tête de `VaultSession.vaultId`) : cet id sert de complément
  /// fiable partout où il faut détecter un VRAI changement de coffre-fort
  /// (invalidation de [VaultSession], portée des notifications dans
  /// [_refreshNotificationsIfNeeded], et [_activeDataKey] pour les
  /// `ValueKey` des pages de [_buildHome]).
  String? _activeVaultId;

  /// Identifiant combiné coffre-fort + profil actif, unique même sur le
  /// build web (voir [_activeVaultId]) — à utiliser pour toute [ValueKey]
  /// devant forcer un remontage complet d'un écran au changement de vault
  /// OU de profil (voir [_buildHome]), plutôt que
  /// `_profileController!.activeDataPath` seul, qui ne varie pas d'un
  /// coffre-fort web à l'autre.
  String get _activeDataKey =>
      '$_activeVaultId|${_profileController!.activeDataPath}';

  /// Web uniquement : vrai quand le coffre-fort actif est un dossier local
  /// (voir `VaultStorage.webLocalFolder`) dont la permission navigateur a
  /// expiré — voir [VaultFolderService.activeVaultNeedsReauthorization].
  /// Bloque le chargement des profils comme [_vaultLocked], en attendant un
  /// geste explicite de l'utilisateur (voir [_buildHome]).
  bool _webLocalFolderNeedsReauth = false;
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

  /// Clé de contexte du dernier rafraîchissement des notifications
  /// (`vaultId|vaultPath|profileId`), pour ne relancer un rafraîchissement
  /// que quand le profil/vault a réellement changé.
  String? _notificationsScope;

  void _handleProfileControllerChanged() {
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
    final scope = '$_activeVaultId|$_vaultPath|${profile.active!.id}';
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

  @override
  void initState() {
    super.initState();
    _themeController.load();
    _themeController.addListener(() => setState(() {}));
    _localeController.load();
    _localeController.addListener(() => setState(() {}));
    _amountVisibilityController.load();
    _keyboardShortcutsController.load();
    // Réévalue le `builder` de ShadcnApp (voir [build]) quand les Réglages
    // activent/désactivent les raccourcis clavier — sans ça, la nouvelle
    // valeur ne serait relue qu'au prochain rebuild déclenché par autre
    // chose.
    _keyboardShortcutsController.addListener(() => setState(() {}));
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
    // Résolu séparément du reste de cette fonction (qui a plusieurs retours
    // anticipés selon l'état du vault — migration interrompue, verrouillé...)
    // : le nom du coffre-fort actif doit être à jour dans tous les cas, pas
    // seulement le chemin "chargement normal" tout en bas.
    final activeVault = await _vaultFolderService.getActiveVault();
    if (mounted && activeVault?.vaultPath == vaultPath) {
      setState(() {
        _activeVaultName = activeVault!.name;
        _activeVaultId = activeVault.id;
      });
    }

    // Web uniquement : un coffre-fort adossé à un dossier local (voir
    // `VaultStorage.webLocalFolder`) peut avoir perdu la permission du
    // navigateur (nouvelle session, rechargement de page...) — sans ce
    // garde-fou, les repositories du reste de cette fonction liraient/
    // écriraient silencieusement contre la mauvaise racine de stockage
    // (voir `VaultFolderService._resolveAccessibleVault`/`vault_fs_web
    // .dart`). Priorité sur la migration/le chiffrement ci-dessous : sans
    // accès au dossier, aucun des deux ne peut de toute façon être vérifié.
    if (kIsWeb && _vaultFolderService.activeVaultNeedsReauthorization) {
      if (!mounted) return;
      setState(() {
        _vaultPath = vaultPath;
        _webLocalFolderNeedsReauth = true;
        _profileController = null;
        _sidebarPrefsController = null;
        _profilesLoadError = null;
      });
      return;
    }

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
    // posée (ex : "Changer de dossier du coffre-fort" depuis l'écran de
    // déverrouillage, ou changement de vault actif depuis les Réglages) :
    // sans cette invalidation, les repositories du nouveau vault
    // hériteraient de la clé de l'ancien via VaultSession.current, ce qui
    // chiffrerait/déchiffrerait ses fichiers avec la mauvaise clé. Comparé
    // aussi par id (pas seulement par chemin) : sur le build web, deux
    // coffres-forts distincts peuvent partager le même [vaultPath] virtuel
    // (voir la doc de tête de `VaultSession.vaultId`), auquel cas la seule
    // comparaison de chemin ne détecterait pas le changement.
    if (VaultSession.current != null &&
        (VaultSession.vaultPath != vaultPath ||
            VaultSession.vaultId != _activeVaultId)) {
      VaultSession.current = null;
      VaultSession.vaultPath = null;
      VaultSession.vaultId = null;
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
      _webLocalFolderNeedsReauth = false;
    });

    final controller = ProfileController(ProfileRepository(vaultPath));
    try {
      await controller.load();
    } catch (e, st) {
      // Un dossier Vault synchronisé (iCloud Drive...) pas encore
      // totalement téléchargé peut faire échouer la lecture des profils :
      // sans ce garde-fou, l'app restait bloquée sur un spinner infini (ou
      // plantait) au lieu de proposer de réessayer.
      // `st` capturé pour le log des échecs de chargement de profil.
      debugPrint('[initProfiles] Échec du chargement des profils ($vaultPath) :');
      debugPrint('$e');
      debugPrint('$st');
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
    VaultSession.vaultId = _activeVaultId;
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
    _notificationsScope = null;
    VaultSession.current = null;
    VaultSession.vaultPath = null;
    VaultSession.vaultId = null;
    setState(() {
      _vaultPath = null;
      _activeVaultId = null;
      _profileController = null;
      _sidebarPrefsController = null;
      _vaultEncryptionMetadata = null;
      _vaultLocked = false;
      _webLocalFolderNeedsReauth = false;
      _showingVaultRecovery = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      colorScheme: LegacyColorSchemes.lightZinc().recolor(
        const Color(0xFFF4BE7E),
      ),
      radius: 0.6,
    );
    final darkTheme = ThemeData(
      colorScheme: LegacyColorSchemes.darkZinc().recolor(
        const Color(0xFFF4BE7E),
      ),
      radius: 0.6,
    );
    // Des widgets tiers non conscients de shadcn (ex. `flutter_quill`, dans
    // les notes) lisent le thème *Material* de Flutter (`material.Theme.of`)
    // plutôt que celui de shadcn. Sans `materialTheme` explicite ci-dessous,
    // `ShadcnApp` en construit un par défaut à partir de `theme` — TOUJOURS
    // le thème clair, jamais `darkTheme`, quel que soit le mode actif (voir
    // sa propre implémentation dans `shadcn_app.dart`) : ces widgets
    // recevaient donc des couleurs pensées pour un fond clair même en thème
    // sombre, d'où par exemple des titres invisibles dans les notes. On
    // calcule ici ce thème Material à partir du `ColorScheme` shadcn
    // réellement affiché (clair ou sombre selon `_themeController.mode` +
    // le thème système), pour qu'il reste toujours en phase avec l'apparence
    // effective de l'app.
    final effectiveBrightness = switch (_themeController.mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => material.MediaQuery.platformBrightnessOf(context),
    };
    // Langue effective : la langue choisie dans les Réglages, ou à défaut
    // (AppLocale.system) celle de l'appareil. Français par défaut si la
    // langue système n'est ni le français ni l'anglais.
    final effectiveLocale =
        _localeController.locale.locale ??
        (WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'en'
            ? const Locale('en')
            : const Locale('fr'));
    final activeTheme = effectiveBrightness == Brightness.dark
        ? darkTheme
        : lightTheme;
    final materialTheme = material.ThemeData.from(
      colorScheme: material.ColorScheme.fromSeed(
        seedColor: activeTheme.colorScheme.primary,
        brightness: effectiveBrightness,
        surface: activeTheme.colorScheme.background,
        primary: activeTheme.colorScheme.primary,
        secondary: activeTheme.colorScheme.secondary,
        error: activeTheme.colorScheme.destructive,
      ),
    );
    return ShadcnApp(
      navigatorKey: _navigatorKey,
      title: 'Opime',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeController.mode,
      materialTheme: materialTheme,
      home: _buildHome(),
      // La langue de l'app est pilotée par le réglage Langue (voir
      // LocaleController) et non plus câblée en dur au français : sans ça,
      // shadcn_flutter (boutons Annuler/Enregistrer de la boîte de dialogue
      // d'[OpimeDatePicker]...) resterait bloqué sur sa locale par défaut et
      // l'app sur le français, quel que soit le choix de l'utilisateur.
      locale: effectiveLocale,
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: [
        ...FlutterQuillLocalizations.localizationsDelegates,
        shadcnLocalizationsFrDelegate,
        // Nos traductions d'app (voir lib/l10n) — c'est le délégué qui
        // fournit `AppLocalizations.of(context)` partout dans l'UI.
        ...AppLocalizations.localizationsDelegates,
        // Sans ces trois-là, `ShadcnApp` retombe sur ses propres délégués
        // Material/Cupertino/Widgets internes (`m.DefaultMaterialLocalizations`...),
        // qui ne prennent en charge que l'anglais — Flutter avertirait alors
        // (et `flutter_test` lèverait une erreur) que la locale française
        // n'est pas prise en charge par tous les délégués déclarés.
        fl.GlobalMaterialLocalizations.delegate,
        fl.GlobalCupertinoLocalizations.delegate,
        fl.GlobalWidgetsLocalizations.delegate,
      ],
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
        AppShortcutAction.exportTransactions.activator: () {
          final navigatorContext = _navigatorKey.currentContext;
          if (navigatorContext == null) return;
          if (_transactionsExportDialogOpen) {
            Navigator.of(navigatorContext).pop();
            return;
          }
          final profileController = _profileController;
          if (profileController == null) {
            _showExportUnavailableToast(navigatorContext);
            return;
          }
          _transactionsExportDialogOpen = true;
          showTransactionsExportDialog(
            navigatorContext,
            vaultPath: profileController.activeDataPath,
          ).whenComplete(() => _transactionsExportDialogOpen = false);
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
    final l10n = AppLocalizations.of(context);
    final String title;
    final String subtitle;
    if (_vaultLocked) {
      title = l10n.shell_vault_locked;
      subtitle = l10n.shell_unlock_before_export;
    } else if (_vaultMigrationInterrupted) {
      title = l10n.shell_migration_pending;
      subtitle = l10n.shell_finish_migration_before_export;
    } else {
      title = l10n.shell_no_profile_loaded;
      subtitle = l10n.shell_retry_after_vault_loaded;
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
      // `Builder` plutôt que le `context` de `_OpimeAppState` directement :
      // ce dernier est au-dessus de `ShadcnApp` (donc de ses délégués de
      // localisation) dans l'arbre au moment où `_buildHome()` s'exécute —
      // `AppLocalizations.of(context)` y jetterait un null check operator
      // used on a null value (vu en vrai : écran rouge d'erreur qui flashe
      // au tout premier frame). `Builder` fournit un contexte résolu une
      // fois ce widget réellement monté SOUS `ShadcnApp`, où la
      // localisation est disponible.
      return Builder(
        builder: (context) => AppLoadingScreen(
          message: AppLocalizations.of(context).shell_loading_vault,
        ),
      );
    }
    // La vitrine commerciale n'a de sens que sur le web (un utilisateur qui
    // a déjà installé l'app desktop n'a pas besoin qu'on la lui présente).
    // Purement piloté par l'URL plutôt que par l'existence d'un coffre-fort
    // sur cet appareil : `/` (et tout chemin autre que `/home`) affiche
    // toujours la landing page, même pour un visiteur qui a déjà un vault —
    // sans quoi il n'y aurait aucun moyen d'y revenir une fois connecté.
    if (kIsWeb && !_isOnHomePath()) {
      return LandingScreen(
        onGetStarted: () {
          replaceUrlPath(_homePath);
          setState(() {});
        },
        themeController: _themeController,
      );
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
    if (_webLocalFolderNeedsReauth) {
      return LocalFolderReauthScreen(
        vaultName: _activeVaultName ?? '',
        onReauthorize: () async {
          final ok = await _vaultFolderService.reauthorizeActiveVault();
          if (ok) await _initProfiles(_vaultPath!);
          return ok;
        },
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
      // Voir le commentaire de la branche `_checkingVault` ci-dessus :
      // même raison pour ce `Builder`.
      return Builder(
        builder: (context) => Scaffold(
          child: LoadErrorView(
            message: AppLocalizations.of(context).shell_profiles_load_failed,
            onRetry: _retryInitProfiles,
          ),
        ),
      );
    }
    if (_profileController == null || _sidebarPrefsController == null) {
      return Builder(
        builder: (context) => AppLoadingScreen(
          message: AppLocalizations.of(context).shell_loading_data,
        ),
      );
    }
    return UpdateBanner(
      githubOwner: _githubOwner,
      githubRepo: _githubRepo,
      child: PriceSyncBanner(
        controller: _priceSyncStatusController,
        child: ReminderBanner(
          vaultPath: _profileController!.activeDataPath,
          refreshSignal: _patrimoineRefreshController,
          child: AppShell(
            themeController: _themeController,
            profileController: _profileController!,
            sidebarPrefsController: _sidebarPrefsController!,
            amountVisibilityController: _amountVisibilityController,
            patrimoineRefreshController: _patrimoineRefreshController,
            currentAccountFocusController: _currentAccountFocusController,
            onboardingHighlightController: _onboardingHighlightController,
            priceSyncStatusController: _priceSyncStatusController,
            notificationsSettingsController: _notificationsSettingsController,
            notificationsController: _notificationsController,
            sidebarCollapsed: _sidebarCollapsed,
            vaultFolderService: _vaultFolderService,
            onVaultActivated: _onVaultReady,
            onNoVaultSelected: _resetVault,
            pages: {
              'dashboard': (_) => DashboardScreen(
                key: ValueKey(_activeDataKey),
                vaultPath: _profileController!.activeDataPath,
                amountVisibility: _amountVisibilityController,
                refreshSignal: _patrimoineRefreshController,
                priceSyncStatus: _priceSyncStatusController,
                onboardingHighlight: _onboardingHighlightController,
                profileName: _profileController!.active?.name ?? '',
              ),
              // Analyses/Projets : réservés à Opime Premium dans cette
              // édition gratuite (voir `core/premium/premium_lock.dart`) —
              // leur vrai code ne vit pas dans ce dépôt public, seul un
              // aperçu illustratif (mockup, données factices) est construit
              // ici, lui-même figé derrière `LockedFeatureScreen`.
              'analyses': (context) => LockedFeatureScreen(
                title: 'Analyses',
                description:
                    'Graphiques de répartition et de performance avancés : '
                    'réservés à Opime Premium.',
                pageBuilder: (_) => const AnalysesScreen(),
              ),
              'projets': (context) => LockedFeatureScreen(
                title: 'Projets',
                description:
                    'Suivi d\'objectifs financiers chiffrés dans le temps : '
                    'réservé à Opime Premium.',
                pageBuilder: (_) => const ProjectsScreen(),
              ),
              // Entités : la gestion (création/édition/organigramme) ne vit
              // pas dans ce dépôt public — voir `core/premium/premium_lock
              // .dart`. Le modèle de données et la vue en lecture d'une
              // entité restent en revanche partagés avec le Dashboard
              // gratuit (aucune distinction personnel/professionnel de
              // coffre-fort n'existe à ce niveau, voir `entity_detail
              // _screen.dart`).
              'entites': (context) => LockedFeatureScreen(
                title: 'Entités',
                description:
                    'Gestion des holdings, sociétés commerciales et SCI '
                    '(comptes professionnels) : réservée à Opime Premium.',
                pageBuilder: (_) => const EntitiesScreen(),
              ),
              for (final assetClass in AssetClass.values)
                assetClass.categoryId: (_) => RealCategoryDetailScreen(
                  key: ValueKey('${_activeDataKey}_${assetClass.categoryId}'),
                  vaultPath: _profileController!.activeDataPath,
                  categoryId: assetClass.categoryId,
                  amountVisibility: _amountVisibilityController,
                  patrimoineRefreshController: _patrimoineRefreshController,
                  currentAccountFocus: _currentAccountFocusController,
                  profileName: _profileController!.active?.name ?? '',
                ),
              for (final liabilityType in LiabilityType.values)
                liabilityType.categoryId: (_) => RealPassifDetailScreen(
                  key: ValueKey('${_activeDataKey}_${liabilityType.categoryId}'),
                  vaultPath: _profileController!.activeDataPath,
                  categoryId: liabilityType.categoryId,
                  amountVisibility: _amountVisibilityController,
                  patrimoineRefreshController: _patrimoineRefreshController,
                ),
              for (final envelope in envelopes)
                envelope.id: (_) => EnvelopeSheetScreen(
                  key: ValueKey('${_activeDataKey}_${envelope.id}'),
                  vaultPath: _profileController!.activeDataPath,
                  envelope: envelope,
                ),
              for (final card in investissementCards)
                card.id: (_) => InvestissementCardScreen(
                  key: ValueKey('${_activeDataKey}_${card.id}'),
                  vaultPath: _profileController!.activeDataPath,
                  card: card,
                ),
              // Formation (Académie > Formation) : réservée à Opime Premium
              // — Fondamentaux et Enveloppes (au-dessus) restent gratuits.
              // Le vrai contenu des leçons ne vit pas dans ce dépôt public,
              // seul un aperçu illustratif (mockup) est construit ici.
              for (final track in formationTracks)
                track.id: (context) => LockedFeatureScreen(
                  title: track.title,
                  description:
                      'Ce parcours de formation est réservé à Opime Premium.',
                  pageBuilder: (_) => FormationTrackScreen(track: track),
                ),
              'strategie': (_) => StrategyScreen(
                key: ValueKey(_activeDataKey),
                vaultPath: _profileController!.activeDataPath,
              ),
              'budget_ventilation': (_) => BudgetScreen(
                key: ValueKey(_activeDataKey),
                vaultPath: _profileController!.activeDataPath,
                amountVisibility: _amountVisibilityController,
              ),
              'budget_suivi': (_) => BudgetTrackingScreen(
                key: ValueKey(_activeDataKey),
                vaultPath: _profileController!.activeDataPath,
                amountVisibility: _amountVisibilityController,
              ),
              'simulation_taxation': (_) => TaxationSimulationScreen(
                key: ValueKey(_activeDataKey),
                vaultPath: _profileController!.activeDataPath,
                amountVisibility: _amountVisibilityController,
              ),
              'simulation_patrimoine': (_) => WealthSimulationScreen(
                key: ValueKey(_activeDataKey),
                vaultPath: _profileController!.activeDataPath,
                amountVisibility: _amountVisibilityController,
              ),
              'simulation_immobilier': (_) => RealEstateSimulationScreen(
                key: ValueKey(_activeDataKey),
                vaultPath: _profileController!.activeDataPath,
                amountVisibility: _amountVisibilityController,
              ),
              'simulation_transmission': (_) => TransmissionSimulationScreen(
                key: ValueKey(_activeDataKey),
                vaultPath: _profileController!.activeDataPath,
                amountVisibility: _amountVisibilityController,
              ),
              // Assistant IA : le vrai client LLM/contexte financier ne vit
              // pas dans ce dépôt public — voir `core/premium/premium_lock
              // .dart`. Un aperçu illustratif (mockup) est construit ici.
              'assistant': (context) => LockedFeatureScreen(
                title: 'Assistant IA',
                description:
                    'L\'assistant conversationnel sur votre patrimoine est '
                    'réservé à Opime Premium.',
                pageBuilder: (_) => const AssistantScreen(),
              ),
              'settings': (_) => SettingsScreen(
                key: ValueKey(_activeDataKey),
                vaultFolderService: _vaultFolderService,
                onVaultActivated: _onVaultReady,
                onNoVaultSelected: _resetVault,
                themeController: _themeController,
                localeController: _localeController,
                notificationsSettingsController:
                    _notificationsSettingsController,
                keyboardShortcutsController: _keyboardShortcutsController,
                profileController: _profileController!,
                vaultPath: _vaultPath!,
                onVaultEncryptionChanged: () => _initProfiles(_vaultPath!),
                githubOwner: _githubOwner,
                githubRepo: _githubRepo,
              ),
              'tax_parameters': (_) => TaxParametersScreen(
                key: ValueKey(_activeDataKey),
                vaultPath: _profileController!.activeDataPath,
              ),
            },
          ),
        ),
      ),
    );
  }
}

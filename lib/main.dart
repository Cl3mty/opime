import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/privacy/amount_visibility_controller.dart';
import 'core/storage/vault_folder_service.dart';
import 'core/profiles/profile_controller.dart';
import 'core/profiles/profile_repository.dart';
import 'core/profiles/sidebar_prefs_controller.dart';
import 'core/updates/update_banner.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/account_management_screen.dart';
import 'app/theme_controller.dart';
import 'app/app_shell.dart';
import 'core/platform_info.dart';
import 'core/ui/load_error_view.dart';
import 'core/ui/mobile_orientation.dart';
import 'features/strategy/strategy_screen.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'features/budget/budget_screen.dart';
import 'features/simulations/simulations_taxation_screen.dart';
import 'features/simulations/simulations_wealth_screen.dart';
import 'features/simulations/simulations_loan_screen.dart';
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
      title: 'Freenary',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const FreenaryApp());
}

class FreenaryApp extends StatefulWidget {
  const FreenaryApp({super.key});

  @override
  State<FreenaryApp> createState() => _FreenaryAppState();
}

class _FreenaryAppState extends State<FreenaryApp> {
  static const _githubOwner = 'Cl3mty';
  static const _githubRepo = 'freenary';

  final _themeController = ThemeController();
  final _amountVisibilityController = AmountVisibilityController();
  final _vaultFolderService = VaultFolderService();

  bool _checkingVault = true;
  String? _vaultPath;
  ProfileController? _profileController;
  SidebarPrefsController? _sidebarPrefsController;
  Object? _profilesLoadError;

  void _handleProfileControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _themeController.load();
    _themeController.addListener(() => setState(() {}));
    _amountVisibilityController.load();
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
  }

  void _retryInitProfiles() {
    final path = _vaultPath;
    if (path != null) _initProfiles(path);
  }

  Future<void> _onVaultReady(String path) async {
    await _initProfiles(path);
  }

  void _resetVault() {
    _profileController?.removeListener(_handleProfileControllerChanged);
    _profileController?.dispose();
    setState(() {
      _vaultPath = null;
      _profileController = null;
      _sidebarPrefsController = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'Freenary',
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
      child: AppShell(
        themeController: _themeController,
        profileController: _profileController!,
        sidebarPrefsController: _sidebarPrefsController!,
        amountVisibilityController: _amountVisibilityController,
        pages: {
          'dashboard': (_) => const Center(child: Text('Tableau de bord')),
          'actifs_actions_fonds': (_) =>
              const Center(child: Text('Actions & Fonds')),
          'actifs_private_equity': (_) =>
              const Center(child: Text('Private Equity')),
          'actifs_immobilier': (_) => const Center(child: Text('Immobilier')),
          'actifs_crypto': (_) => const Center(child: Text('Crypto')),
          'actifs_metaux_precieux': (_) =>
              const Center(child: Text('Métaux précieux')),
          'actifs_epargne': (_) => const Center(child: Text('Épargne')),
          'actifs_autres': (_) => const Center(child: Text('Autres')),
          'passifs_emprunts': (_) => const Center(child: Text('Emprunts')),
          'passifs_prets_immobiliers': (_) =>
              const Center(child: Text('Prêts immobiliers')),
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
              key: ValueKey('${_profileController!.activeDataPath}_${card.id}'),
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
          'simulation_pret': (_) => LoanSimulationScreen(
            key: ValueKey(_profileController!.activeDataPath),
            vaultPath: _profileController!.activeDataPath,
            amountVisibility: _amountVisibilityController,
          ),
          'simulation_transmission': (_) => TransmissionSimulationScreen(
            key: ValueKey(_profileController!.activeDataPath),
            vaultPath: _profileController!.activeDataPath,
            amountVisibility: _amountVisibilityController,
          ),
          'assistant': (_) => const Center(child: Text('Assistant')),
          'account_management': (_) =>
              AccountManagementScreen(profileController: _profileController!),
          'settings': (_) => SettingsScreen(
            vaultFolderService: _vaultFolderService,
            onVaultActivated: _onVaultReady,
            onNoVaultSelected: _resetVault,
            themeController: _themeController,
            profileController: _profileController!,
            sidebarPrefsController: _sidebarPrefsController!,
            githubOwner: _githubOwner,
            githubRepo: _githubRepo,
          ),
        },
      ),
    );
  }
}

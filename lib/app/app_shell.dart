import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:opime/l10n/app_localizations.dart';
import '../core/notifications/notifications_settings_controller.dart';
import '../core/privacy/amount_visibility_controller.dart';
import '../core/profiles/profile_controller.dart';
import '../core/ui/app_background.dart';
import '../core/ui/responsive.dart';
import '../core/profiles/sidebar_prefs_controller.dart';
import '../core/storage/vault_folder_service.dart';
import '../features/navigation/account_switcher_menu.dart';
import '../features/navigation/app_sidebar.dart';
import '../features/navigation/mobile_nav_hub.dart';
import '../features/navigation/nav_models.dart';
import '../features/navigation/navigation_scope.dart';
import '../features/navigation/top_bar.dart';
import '../features/navigation/top_bar_actions.dart';
import '../features/dashboard/onboarding_highlight_controller.dart';
import '../features/investments/current_account_focus_controller.dart';
import '../features/investments/patrimoine_refresh_controller.dart';
import '../features/investments/price_sync_status_controller.dart';
import '../features/navigation/patrimoine_export_menu_button.dart';
import '../features/notifications/news_button.dart';
import '../features/notifications/notifications_controller.dart';
import 'theme_controller.dart';

/// Les 4 onglets de la barre de navigation mobile (en dessous de
/// [_breakpoint]), qui remplace la sidebar desktop. Pas d'onglet Assistant
/// en version mobile. `items` est vide pour Home, qui n'a pas de hub :
/// il renvoie directement au tableau de bord.
class _MobileTab {
  final String key;

  /// Résolu au moment de l'affichage plutôt qu'une simple `String` : les 4
  /// onglets sont déclarés une fois pour toute l'app (variable top-level),
  /// avant qu'un `BuildContext` (donc une locale) ne soit disponible.
  final String Function(AppLocalizations l10n) label;
  final IconData icon;
  final List<NavItem> Function() items;

  const _MobileTab(this.key, this.label, this.icon, this.items);
}

final _mobileTabs = [
  _MobileTab('home', (l10n) => l10n.nav_home, LucideIcons.house, () => const []),
  _MobileTab(
    'portfolio',
    (l10n) => l10n.nav_patrimoine,
    LucideIcons.walletMinimal,
    () => portfolioTabItems,
  ),
  _MobileTab(
    'tools',
    (l10n) => l10n.nav_tools,
    LucideIcons.wrench,
    () => toolsTabItems,
  ),
  _MobileTab(
    'learn',
    (l10n) => l10n.nav_academy,
    LucideIcons.graduationCap,
    () => academieGroup.items,
  ),
];

class AppShell extends StatefulWidget {
  final ThemeController themeController;
  final ProfileController profileController;
  final SidebarPrefsController sidebarPrefsController;
  final AmountVisibilityController amountVisibilityController;
  final PatrimoineRefreshController patrimoineRefreshController;
  final CurrentAccountFocusController currentAccountFocusController;
  final OnboardingHighlightController onboardingHighlightController;
  final PriceSyncStatusController priceSyncStatusController;
  final NotificationsSettingsController notificationsSettingsController;
  final NotificationsController notificationsController;
  final Map<String, WidgetBuilder> pages;

  /// Passés jusqu'au sélecteur de compte (bascule/ajout de vault, voir
  /// `account_switcher_menu.dart`) — la même paire de callbacks que
  /// `SettingsScreen`/`VaultUnlockScreen` pour recharger tout l'état de
  /// l'appli après un changement de vault.
  final VaultFolderService vaultFolderService;
  final Future<void> Function(String path) onVaultActivated;
  final VoidCallback onNoVaultSelected;

  /// État (replié/déplié) de la sidebar, remonté à `main.dart` pour que le
  /// raccourci clavier ⌘B puisse le basculer depuis la racine de l'app —
  /// voir sa documentation dans `main.dart` pour pourquoi les raccourcis ne
  /// peuvent plus vivre ici (`CallbackShortcuts` posé sur le contenu d'une
  /// route ne voit jamais les évènements clavier tant qu'une boîte de
  /// dialogue d'une AUTRE route a le focus — ce qui les rendait
  /// silencieusement inopérants dès qu'un dialogue était ouvert).
  final ValueNotifier<bool> sidebarCollapsed;

  const AppShell({
    super.key,
    required this.themeController,
    required this.profileController,
    required this.sidebarPrefsController,
    required this.amountVisibilityController,
    required this.patrimoineRefreshController,
    required this.currentAccountFocusController,
    required this.onboardingHighlightController,
    required this.priceSyncStatusController,
    required this.notificationsSettingsController,
    required this.notificationsController,
    required this.pages,
    required this.sidebarCollapsed,
    required this.vaultFolderService,
    required this.onVaultActivated,
    required this.onNoVaultSelected,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selectedKey = 'dashboard';
  int _dashboardEpoch = 0;

  /// Pile des pages visitées avant la page courante (desktop uniquement,
  /// voir [_select]) — alimente le chevron retour tout à gauche de la
  /// [TopBar] : contrairement au mobile (bottom nav, qui a sa propre pile
  /// hub/feuille via [_mobileBack]), la mise en page large n'avait jusqu'ici
  /// aucun moyen de revenir à la page précédente sans repasser par la
  /// sidebar.
  final List<String> _pageHistory = [];

  // --- État de la navigation mobile (bottom bar + hub de drill-down) ---
  String _mobileActiveTab = 'home';
  NavItem? _mobileDrillParent;
  bool _mobileShowingHub = false;

  void _select(String key) {
    // Utilisé pour des destinations hors des onglets mobiles (Comptes,
    // Réglages, via l'icône de l'AppBar) : doit toujours afficher la page
    // demandée, quel que soit l'onglet actif ou l'état du hub en cours.
    setState(() {
      // Un reclic sur la page déjà affichée (ex : re-sélectionner "Tableau
      // de bord" pour réinitialiser son drill-down local, voir
      // `_dashboardEpoch` juste en dessous) n'est pas une "vraie" navigation
      // vers une nouvelle page : ne pas l'empiler évite un chevron retour
      // qui ramènerait sur la page déjà affichée.
      if (key != _selectedKey) _pageHistory.add(_selectedKey);
      _selectedKey = key;
      _mobileShowingHub = false;
      // Incrémenté même si le Dashboard est déjà actif : une page qui gère
      // un drill-down local (voir NavigationScope.dashboardEpoch) s'en sert
      // pour revenir à sa racine sur un reclic de la sidebar.
      if (key == 'dashboard') _dashboardEpoch++;
    });
  }

  /// Retire la dernière page de [_pageHistory] et y revient — SANS empiler
  /// la page courante à son tour (contrairement à [_select]) : ce chevron
  /// est un "retour", pas juste un raccourci vers cette page, une seconde
  /// pression doit continuer à remonter la pile plutôt que faire l'aller-
  /// retour indéfiniment entre les deux mêmes pages.
  void _goBack() {
    if (_pageHistory.isEmpty) return;
    setState(() {
      _selectedKey = _pageHistory.removeLast();
      _mobileShowingHub = false;
      if (_selectedKey == 'dashboard') _dashboardEpoch++;
    });
  }

  @override
  void initState() {
    super.initState();
    widget.sidebarCollapsed.addListener(_onSidebarCollapsedChanged);
  }

  /// Le raccourci clavier ⌘B (posé à la racine de l'app, voir `main.dart`)
  /// modifie [AppShell.sidebarCollapsed] directement plutôt que par un
  /// `setState` local — ce listener répercute le changement sur ce widget.
  void _onSidebarCollapsedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.sidebarCollapsed.removeListener(_onSidebarCollapsedChanged);
    super.dispose();
  }

  _MobileTab get _currentMobileTab =>
      _mobileTabs.firstWhere((t) => t.key == _mobileActiveTab);

  void _selectMobileTab(String tabKey) {
    if (tabKey == 'home') {
      setState(() {
        _mobileActiveTab = tabKey;
        _mobileDrillParent = null;
        _mobileShowingHub = false;
        _selectedKey = 'dashboard';
      });
      return;
    }
    // Retour systématique à la racine de l'onglet : comportement standard
    // d'une tab bar mobile, y compris en retapant l'onglet déjà actif.
    setState(() {
      _mobileActiveTab = tabKey;
      _mobileDrillParent = null;
      _mobileShowingHub = true;
    });
  }

  void _mobileTapLeaf(NavItem item) {
    setState(() {
      _selectedKey = item.key;
      _mobileShowingHub = false;
    });
  }

  void _mobileTapParent(NavItem item) {
    setState(() => _mobileDrillParent = item);
  }

  void _mobileBack() {
    setState(() {
      if (!_mobileShowingHub) {
        if (_mobileActiveTab == 'home') {
          // Page hors-onglet ouverte depuis Home (ex: Comptes, Réglages) :
          // il n'y a pas de hub Home à afficher, on revient au tableau de
          // bord directement.
          _selectedKey = 'dashboard';
        } else {
          // Page feuille -> retour au hub d'où elle a été ouverte (celui
          // du parent si on avait "drillé", sinon la racine de l'onglet).
          _mobileShowingHub = true;
        }
      } else if (_mobileDrillParent != null) {
        _mobileDrillParent = null;
      }
    });
  }

  bool get _mobileCanGoBack {
    if (!_mobileShowingHub) return _selectedKey != 'dashboard';
    return _mobileDrillParent != null;
  }

  /// Titre affiché dans l'AppBar mobile — dépend de la locale (voir
  /// [_MobileTab.label]), donc reçoit un `BuildContext` plutôt que d'être un
  /// simple getter comme avant l'internationalisation de l'app.
  String _mobileTitleFor(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_mobileShowingHub) {
      return _mobileDrillParent != null
          ? navLocalizedLabel(l10n, _mobileDrillParent!.key,
              fallback: _mobileDrillParent!.label)
          : _currentMobileTab.label(l10n);
    }
    if (_selectedKey == 'dashboard') return l10n.appName;
    if (_selectedKey == 'settings') return l10n.nav_settings;
    for (final item in _currentMobileTab.items()) {
      if (item.key == _selectedKey) {
        return navLocalizedLabel(l10n, item.key, fallback: item.label);
      }
      for (final child in item.children) {
        if (child.key == _selectedKey) {
          return navLocalizedLabel(l10n, child.key, fallback: child.label);
        }
      }
    }
    return _currentMobileTab.label(l10n);
  }

  Widget _mobileContent(BuildContext context) {
    if (_mobileActiveTab == 'home' || !_mobileShowingHub) {
      final page =
          widget.pages[_selectedKey]?.call(context) ??
          Center(child: Text(AppLocalizations.of(context).common_page_not_found));
      return NavigationScope(
        onSelect: _select,
        dashboardEpoch: _dashboardEpoch,
        child: page,
      );
    }
    final items = _mobileDrillParent?.children ?? _currentMobileTab.items();
    return MobileNavHub(
      items: items,
      onTapLeaf: _mobileTapLeaf,
      onTapParent: _mobileTapParent,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sans ça, faire pivoter le téléphone bascule à tort vers la sidebar
    // desktop (donc vers l'Assistant, absent de la version mobile) — voir
    // le commentaire de isWideLayout() sur le choix de shortestSide.
    final isWide = isWideLayout(context);
    final l10n = AppLocalizations.of(context);

    if (isWide) {
      final page = NavigationScope(
        onSelect: _select,
        dashboardEpoch: _dashboardEpoch,
        child:
            widget.pages[_selectedKey]?.call(context) ??
            Center(child: Text(l10n.common_page_not_found)),
      );
      // AppBackground (halo/dégradé) habille uniquement la sidebar et la
      // TopBar — le contenu de page reste un aplat uni (theme.background),
      // pas de dégradé dessus. Leur propre fond est semi-transparent (voir
      // AppSidebar/TopBar) pour laisser le halo transparaître.
      final sidebar = AppBackground(
        child: AppSidebar(
          selectedKey: _selectedKey,
          onSelect: _select,
          collapsed: widget.sidebarCollapsed.value,
          onToggleCollapse: () =>
              widget.sidebarCollapsed.value = !widget.sidebarCollapsed.value,
          profileController: widget.profileController,
          sidebarPrefsController: widget.sidebarPrefsController,
          vaultFolderService: widget.vaultFolderService,
          onVaultActivated: widget.onVaultActivated,
          onNoVaultSelected: widget.onNoVaultSelected,
        ),
      );
      return Scaffold(
        // SafeArea : sans elle, la sidebar et la TopBar démarrent au tout
        // haut de l'écran physique et chevauchent la barre système
        // (batterie/heure) sur tablette. Sans effet sur desktop, où
        // MediaQuery.padding.top est toujours nul.
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              sidebar,
              Container(width: 1, color: Theme.of(context).colorScheme.border),
              Expanded(
                child: Column(
                  children: [
                    AppBackground(
                      child: TopBar(
                        amountVisibility: widget.amountVisibilityController,
                        profileController: widget.profileController,
                        patrimoineRefreshController:
                            widget.patrimoineRefreshController,
                        currentAccountFocus:
                            widget.currentAccountFocusController,
                        onboardingHighlight:
                            widget.onboardingHighlightController,
                        priceSyncStatus: widget.priceSyncStatusController,
                        notificationsSettings:
                            widget.notificationsSettingsController,
                        notificationsController: widget.notificationsController,
                        currentPageKey: _selectedKey,
                        onSelect: _select,
                        canGoBack: _pageHistory.isNotEmpty,
                        onBack: _goBack,
                      ),
                    ),
                    Expanded(child: page),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      headers: [
        AppBar(
          // FittedBox plutôt qu'un simple Text : un titre trop long
          // (ex. un nom de compte long) doit rétrécir pour tenir sur une
          // ligne au lieu de passer sur deux et pousser le contenu de
          // l'AppBar.
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_mobileTitleFor(context), maxLines: 1, softWrap: false),
          ),
          leading: [
            if (_mobileCanGoBack)
              IconButton.ghost(
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: _mobileBack,
              ),
          ],
          trailing: [
            AmountVisibilityToggleButton(
              amountVisibility: widget.amountVisibilityController,
            ),
            NewsButton(
              settings: widget.notificationsSettingsController,
              controller: widget.notificationsController,
              vaultPath: widget.profileController.activeDataPath,
            ),
            PatrimoineExportMenuButton(
              profileController: widget.profileController,
            ),
            AddMenuButton(
              profileController: widget.profileController,
              patrimoineRefreshController: widget.patrimoineRefreshController,
              currentAccountFocus: widget.currentAccountFocusController,
              onboardingHighlight: widget.onboardingHighlightController,
              priceSyncStatus: widget.priceSyncStatusController,
              compact: true,
              currentPageKey: _selectedKey,
            ),
            Builder(
              builder: (barContext) => IconButton.ghost(
                icon: const Icon(LucideIcons.userRound),
                onPressed: () => openAccountSwitcherMenu(
                  barContext,
                  profileController: widget.profileController,
                  onSelect: _select,
                  vaultFolderService: widget.vaultFolderService,
                  onVaultActivated: widget.onVaultActivated,
                  onNoVaultSelected: widget.onNoVaultSelected,
                ),
              ),
            ),
          ],
        ),
      ],
      footers: [
        NavigationBar(
          alignment: NavigationBarAlignment.spaceAround,
          children: [
            for (final tab in _mobileTabs)
              NavigationItem(
                label: Text(tab.label(l10n)),
                selectedStyle: const ButtonStyle.primaryIcon(),
                selected: _mobileActiveTab == tab.key,
                onChanged: (isSelected) {
                  if (isSelected) _selectMobileTab(tab.key);
                },
                child: Icon(tab.icon),
              ),
          ],
        ),
      ],
      // Contenu de page en aplat uni, comme en desktop : pas de dégradé
      // ici (réservé aux barres — AppBar/NavigationBar restent telles
      // quelles pour l'instant côté mobile).
      child: _mobileContent(context),
    );
  }
}

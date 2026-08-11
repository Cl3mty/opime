import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../core/privacy/amount_visibility_controller.dart';
import '../core/profiles/profile_controller.dart';
import '../core/ui/app_background.dart';
import '../core/profiles/sidebar_prefs_controller.dart';
import '../features/navigation/account_switcher_menu.dart';
import '../features/navigation/app_sidebar.dart';
import '../features/navigation/mobile_nav_hub.dart';
import '../features/navigation/nav_models.dart';
import '../features/navigation/navigation_scope.dart';
import '../features/navigation/top_bar.dart';
import '../features/navigation/top_bar_actions.dart';
import '../features/dashboard/onboarding_highlight_controller.dart';
import '../features/investments/patrimoine_refresh_controller.dart';
import 'theme_controller.dart';

const _breakpoint = 800.0;

/// Les 4 onglets de la barre de navigation mobile (en dessous de
/// [_breakpoint]), qui remplace la sidebar desktop. Pas d'onglet Assistant
/// en version mobile. `items` est vide pour Home, qui n'a pas de hub :
/// il renvoie directement au tableau de bord.
class _MobileTab {
  final String key;
  final String label;
  final IconData icon;
  final List<NavItem> Function() items;

  const _MobileTab(this.key, this.label, this.icon, this.items);
}

final _mobileTabs = [
  _MobileTab('home', 'Home', LucideIcons.house, () => const []),
  _MobileTab(
    'portfolio',
    'Portfolio',
    LucideIcons.walletMinimal,
    () => portfolioTabItems,
  ),
  _MobileTab('tools', 'Tools', LucideIcons.wrench, () => toolsTabItems),
  _MobileTab(
    'learn',
    'Learn',
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
  final OnboardingHighlightController onboardingHighlightController;
  final Map<String, WidgetBuilder> pages;

  const AppShell({
    super.key,
    required this.themeController,
    required this.profileController,
    required this.sidebarPrefsController,
    required this.amountVisibilityController,
    required this.patrimoineRefreshController,
    required this.onboardingHighlightController,
    required this.pages,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selectedKey = 'dashboard';
  bool _collapsed = false;
  int _dashboardEpoch = 0;

  // --- État de la navigation mobile (bottom bar + hub de drill-down) ---
  String _mobileActiveTab = 'home';
  NavItem? _mobileDrillParent;
  bool _mobileShowingHub = false;

  void _select(String key) {
    // Utilisé pour des destinations hors des onglets mobiles (Comptes,
    // Réglages, via l'icône de l'AppBar) : doit toujours afficher la page
    // demandée, quel que soit l'onglet actif ou l'état du hub en cours.
    setState(() {
      _selectedKey = key;
      _mobileShowingHub = false;
      // Incrémenté même si le Dashboard est déjà actif : une page qui gère
      // un drill-down local (voir NavigationScope.dashboardEpoch) s'en sert
      // pour revenir à sa racine sur un reclic de la sidebar.
      if (key == 'dashboard') _dashboardEpoch++;
    });
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

  String get _mobileTitle {
    if (_mobileShowingHub) {
      return _mobileDrillParent?.label ?? _currentMobileTab.label;
    }
    if (_selectedKey == 'dashboard') return 'Opime';
    if (_selectedKey == 'account_management') return 'Comptes';
    if (_selectedKey == 'settings') return 'Réglages';
    for (final item in _currentMobileTab.items()) {
      if (item.key == _selectedKey) return item.label;
      for (final child in item.children) {
        if (child.key == _selectedKey) return child.label;
      }
    }
    return _currentMobileTab.label;
  }

  Widget _mobileContent(BuildContext context) {
    if (_mobileActiveTab == 'home' || !_mobileShowingHub) {
      final page =
          widget.pages[_selectedKey]?.call(context) ??
          const Center(child: Text('Page introuvable'));
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
    // shortestSide (et non width) : reste stable quelle que soit
    // l'orientation d'un téléphone donné, contrairement à width qui
    // dépasse 800 en paysage sur un iPhone large. Sans ça, faire pivoter
    // le téléphone bascule à tort vers la sidebar desktop (donc vers
    // l'Assistant, absent de la version mobile). Une vraie tablette garde
    // un shortestSide >= 800 dans les deux orientations.
    final isWide = MediaQuery.of(context).size.shortestSide >= _breakpoint;

    if (isWide) {
      final page = NavigationScope(
        onSelect: _select,
        dashboardEpoch: _dashboardEpoch,
        child:
            widget.pages[_selectedKey]?.call(context) ??
            const Center(child: Text('Page introuvable')),
      );
      // AppBackground (halo/dégradé) habille uniquement la sidebar et la
      // TopBar — le contenu de page reste un aplat uni (theme.background),
      // pas de dégradé dessus. Leur propre fond est semi-transparent (voir
      // AppSidebar/TopBar) pour laisser le halo transparaître.
      final sidebar = AppBackground(
        child: AppSidebar(
          selectedKey: _selectedKey,
          onSelect: _select,
          collapsed: _collapsed,
          onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
          profileController: widget.profileController,
          sidebarPrefsController: widget.sidebarPrefsController,
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
                        onboardingHighlight:
                            widget.onboardingHighlightController,
                        currentPageKey: _selectedKey,
                        onSelect: _select,
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
          title: Text(_mobileTitle),
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
            AddMenuButton(
              profileController: widget.profileController,
              patrimoineRefreshController: widget.patrimoineRefreshController,
              onboardingHighlight: widget.onboardingHighlightController,
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
                label: Text(tab.label),
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

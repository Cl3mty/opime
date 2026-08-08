import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../core/privacy/amount_visibility_controller.dart';
import '../core/profiles/profile_controller.dart';
import '../core/profiles/sidebar_prefs_controller.dart';
import '../features/navigation/app_sidebar.dart';
import '../features/navigation/top_bar.dart';
import 'theme_controller.dart';

const _breakpoint = 800.0;

class AppShell extends StatefulWidget {
  final ThemeController themeController;
  final ProfileController profileController;
  final SidebarPrefsController sidebarPrefsController;
  final AmountVisibilityController amountVisibilityController;
  final Map<String, WidgetBuilder> pages;

  const AppShell({
    super.key,
    required this.themeController,
    required this.profileController,
    required this.sidebarPrefsController,
    required this.amountVisibilityController,
    required this.pages,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selectedKey = 'dashboard';
  bool _collapsed = false;

  void _select(String key) {
    setState(() => _selectedKey = key);
  }

  void _openMobileDrawer(BuildContext context) {
    openDrawerOverlay(
      context: context,
      position: OverlayPosition.left,
      builder: (drawerContext) => AppSidebar(
        selectedKey: _selectedKey,
        onSelect: (key) {
          closeDrawer(drawerContext);
          _select(key);
        },
        collapsed: false,
        onToggleCollapse: () {},
        profileController: widget.profileController,
        sidebarPrefsController: widget.sidebarPrefsController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _breakpoint;
    final page = widget.pages[_selectedKey]?.call(context) ??
        const Center(child: Text('Page introuvable'));

    if (isWide) {
      final sidebar = AppSidebar(
        selectedKey: _selectedKey,
        onSelect: _select,
        collapsed: _collapsed,
        onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
        profileController: widget.profileController,
        sidebarPrefsController: widget.sidebarPrefsController,
      );
      return Scaffold(
        child: Row(
          children: [
            sidebar,
            Container(width: 1, color: Theme.of(context).colorScheme.border),
            Expanded(
              child: Column(
                children: [
                  TopBar(
                    amountVisibility: widget.amountVisibilityController,
                    onSelect: _select,
                  ),
                  Expanded(child: page),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Freenary'),
          leading: [
            Builder(
              builder: (barContext) => GestureDetector(
                onTap: () => _openMobileDrawer(barContext),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(LucideIcons.menu),
                ),
              ),
            ),
          ],
        ),
      ],
      child: Column(
        children: [
          TopBar(
            amountVisibility: widget.amountVisibilityController,
            onSelect: _select,
            compact: true,
          ),
          Expanded(child: page),
        ],
      ),
    );
  }
}
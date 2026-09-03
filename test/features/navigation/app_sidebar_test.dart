import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/profiles/profile_controller.dart';
import 'package:opime/core/profiles/profile_repository.dart';
import 'package:opime/core/profiles/sidebar_prefs_controller.dart';
import 'package:opime/core/storage/vault_folder_service.dart';
import 'package:opime/features/navigation/app_sidebar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sidebar réduite : un item de premier niveau avec des enfants (ex :
/// « Budget » > Ventilation/Suivi) n'a pas de page propre — seuls ses
/// enfants sont navigables. `NavigationCollapsible` (shadcn_flutter)
/// masque entièrement ses enfants quand le rail est réduit, rendant ces
/// sous-pages inatteignables sans ré-étendre la sidebar. `AppSidebar`
/// ouvre à la place un petit menu flottant listant les enfants au clic
/// sur l'icône du parent — ces tests couvrent ce comportement.
void main() {
  late Directory tempDir;
  late ProfileController profileController;
  late SidebarPrefsController sidebarPrefsController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('opime_app_sidebar_');
    profileController = ProfileController(ProfileRepository(tempDir.path));
    await profileController.load();
    sidebarPrefsController = SidebarPrefsController(profileController);
  });

  tearDown(() async {
    profileController.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpSidebar(
    WidgetTester tester, {
    required bool collapsed,
    required ValueChanged<String> onSelect,
    String selectedKey = 'dashboard',
  }) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: AppSidebar(
            selectedKey: selectedKey,
            onSelect: onSelect,
            collapsed: collapsed,
            onToggleCollapse: () {},
            profileController: profileController,
            sidebarPrefsController: sidebarPrefsController,
            assistantEnabled: true,
            vaultFolderService: VaultFolderService(),
            onVaultActivated: (_) async {},
            onNoVaultSelected: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'sidebar étendue : les enfants de Budget sont visibles directement '
    '(comportement inchangé)',
    (tester) async {
      await pumpSidebar(tester, collapsed: false, onSelect: (_) {});

      expect(find.text('Ventilation'), findsOneWidget);
      expect(find.text('Suivi'), findsOneWidget);
    },
  );

  testWidgets(
    'sidebar réduite : les enfants de Budget ne sont plus rendus tant que '
    'le menu flottant du parent n\'a pas été ouvert',
    (tester) async {
      await pumpSidebar(tester, collapsed: true, onSelect: (_) {});

      expect(find.byKey(const ValueKey('nav_flyout_item_budget_suivi')), findsNothing);
      expect(
        find.byKey(const ValueKey('nav_parent_flyout_trigger_budget')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'sidebar réduite : cliquer l\'icône de Budget ouvre un menu listant ses '
    'enfants, et cliquer un enfant sélectionne sa page puis referme le menu',
    (tester) async {
      String? selected;
      await pumpSidebar(
        tester,
        collapsed: true,
        onSelect: (key) => selected = key,
      );

      await tester.tap(
        find.byKey(const ValueKey('nav_parent_flyout_trigger_budget')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final suiviButton = find.byKey(
        const ValueKey('nav_flyout_item_budget_suivi'),
      );
      expect(suiviButton, findsOneWidget);
      expect(
        find.byKey(const ValueKey('nav_flyout_item_budget_ventilation')),
        findsOneWidget,
      );

      await tester.tap(suiviButton);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(selected, 'budget_suivi');
      expect(
        find.byKey(const ValueKey('nav_flyout_item_budget_suivi')),
        findsNothing,
        reason: 'le menu doit se refermer après la sélection',
      );
    },
  );

  testWidgets(
    'sidebar réduite : le parent (ex. Budget) est mis en évidence quand un '
    'de ses enfants est la page actuellement sélectionnée',
    (tester) async {
      await pumpSidebar(
        tester,
        collapsed: true,
        onSelect: (_) {},
        selectedKey: 'budget_suivi',
      );

      final trigger = tester.widget<NavigationItem>(
        find.descendant(
          of: find.byKey(const ValueKey('nav_parent_flyout_trigger_budget')),
          matching: find.byType(NavigationItem),
        ),
      );
      expect(trigger.selected, isTrue);
    },
  );

  testWidgets(
    'le groupe "Entités" n\'a pas de nav dédiée — repliée dans le Dashboard '
    '(voir entities_patrimoine_adapter.dart), elle n\'apparaît plus jamais '
    'dans la sidebar',
    (tester) async {
      await pumpSidebar(tester, collapsed: false, onSelect: (_) {});
      expect(find.text('Entités'), findsNothing);
    },
  );
}

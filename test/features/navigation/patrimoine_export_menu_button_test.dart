import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/profiles/profile_controller.dart';
import 'package:opime/core/profiles/profile_repository.dart';
import 'package:opime/features/navigation/patrimoine_export_menu_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [PatrimoineExportMenuButton] remplace les deux anciens boutons séparés
/// (PDF / CSV-JSON) de la TopBar par un seul bouton à menu déroulant — voir
/// sa doc de tête. Ces tests couvrent uniquement l'ouverture du menu et ses
/// deux entrées ; la génération PDF/CSV/JSON elle-même reste couverte par
/// `patrimoine_export_data_test.dart`/`transactions_export_*_test.dart`, et
/// les raccourcis ⌘P/⌘E (indépendants de ce bouton) ne passent jamais par
/// lui.
void main() {
  late Directory profileDir;
  late ProfileController profileController;

  setUp(() async {
    profileDir = await Directory.systemTemp.createTemp(
      'opime_export_menu_profile_',
    );
    SharedPreferences.setMockInitialValues({});
    profileController = ProfileController(ProfileRepository(profileDir.path));
    await profileController.load();
  });

  tearDown(() async {
    profileController.dispose();
    if (await profileDir.exists()) await profileDir.delete(recursive: true);
  });

  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: Center(
            child: PatrimoineExportMenuButton(
              profileController: profileController,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('un seul bouton, ouvre un menu avec les deux exports', (
    tester,
  ) async {
    await pumpButton(tester);

    // Un seul déclencheur — plus deux boutons séparés côte à côte.
    expect(find.byIcon(LucideIcons.arrowDownToLine), findsOneWidget);
    expect(find.byIcon(LucideIcons.fileSpreadsheet), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.arrowDownToLine));
    await tester.pumpAndSettle();

    expect(
      find.text('Télécharger mon patrimoine (PDF)'),
      findsOneWidget,
    );
    expect(
      find.text('Exporter les transactions (JSON/CSV)'),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.fileSpreadsheet), findsOneWidget);
  });
}

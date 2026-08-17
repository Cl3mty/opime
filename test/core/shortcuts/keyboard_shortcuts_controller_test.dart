import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/shortcuts/keyboard_shortcuts_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('activé par défaut', () async {
    final controller = KeyboardShortcutsController();
    await controller.load();
    expect(controller.enabled, isTrue);
  });

  test('setEnabled met à jour l\'état, notifie et persiste', () async {
    final controller = KeyboardShortcutsController();
    var notified = false;
    controller.addListener(() => notified = true);

    await controller.setEnabled(false);

    expect(controller.enabled, isFalse);
    expect(notified, isTrue);

    final reloaded = KeyboardShortcutsController();
    await reloaded.load();
    expect(reloaded.enabled, isFalse);
  });
}

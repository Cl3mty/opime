import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/app/theme_controller.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('mode par défaut est ThemeMode.system', () {
    expect(ThemeController().mode, ThemeMode.system);
  });

  test('load() sans préférence sauvegardée conserve ThemeMode.system', () async {
    final controller = ThemeController();
    await controller.load();
    expect(controller.mode, ThemeMode.system);
  });

  test('setMode met à jour le mode et notifie les auditeurs', () async {
    final controller = ThemeController();
    var notified = false;
    controller.addListener(() => notified = true);

    await controller.setMode(ThemeMode.dark);

    expect(controller.mode, ThemeMode.dark);
    expect(notified, isTrue);
  });

  test('setMode persiste le choix pour un futur load()', () async {
    final first = ThemeController();
    await first.setMode(ThemeMode.light);

    final second = ThemeController();
    await second.load();
    expect(second.mode, ThemeMode.light);
  });

  test('toggleLightDark bascule entre clair et sombre', () async {
    final controller = ThemeController();
    await controller.setMode(ThemeMode.light);

    controller.toggleLightDark();
    expect(controller.mode, ThemeMode.dark);

    controller.toggleLightDark();
    expect(controller.mode, ThemeMode.light);
  });
}

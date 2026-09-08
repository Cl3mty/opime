import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/notifications/notifications_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('désactivé par défaut, aucune dernière consultation', () async {
    final controller = NotificationsSettingsController();
    await controller.load();
    expect(controller.enabled, isFalse);
    expect(controller.lastSeen, isNull);
  });

  test('setEnabled met à jour l\'état, notifie et persiste', () async {
    final controller = NotificationsSettingsController();
    var notified = false;
    controller.addListener(() => notified = true);

    await controller.setEnabled(true);

    expect(controller.enabled, isTrue);
    expect(notified, isTrue);

    final reloaded = NotificationsSettingsController();
    await reloaded.load();
    expect(reloaded.enabled, isTrue);
  });

  test('markSeen persiste le timestamp pour un futur load()', () async {
    final controller = NotificationsSettingsController();
    final when = DateTime.utc(2026, 8, 14, 12);
    await controller.markSeen(when);

    expect(controller.lastSeen, when);

    final reloaded = NotificationsSettingsController();
    await reloaded.load();
    expect(reloaded.lastSeen, when);
  });
}

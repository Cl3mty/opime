import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/profiles/profile_controller.dart';
import 'package:opime/core/profiles/profile_repository.dart';
import 'package:opime/core/profiles/sidebar_prefs_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ProfileController profileController;
  late SidebarPrefsController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('opime_sidebar_prefs_');
    profileController = ProfileController(ProfileRepository(tempDir.path));
    await profileController.load();
    controller = SidebarPrefsController(profileController);
  });

  tearDown(() async {
    profileController.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('hiddenKeysFor est vide avant tout chargement', () {
    expect(controller.hiddenKeysFor(profileController.active!.id), isEmpty);
  });

  test('loadFor sans préférence existante donne un ensemble vide', () async {
    await controller.loadFor(profileController.active!.id);
    expect(controller.hiddenKeysFor(profileController.active!.id), isEmpty);
  });

  test('setHidden(true) ajoute la clé, setHidden(false) la retire', () async {
    final profileId = profileController.active!.id;
    await controller.loadFor(profileId);

    await controller.setHidden(profileId, 'actifs_crypto', true);
    expect(controller.hiddenKeysFor(profileId), {'actifs_crypto'});

    await controller.setHidden(profileId, 'actifs_crypto', false);
    expect(controller.hiddenKeysFor(profileId), isEmpty);
  });

  test(
    'les préférences sont persistées sur disque et rechargées par une nouvelle instance',
    () async {
      final profileId = profileController.active!.id;
      await controller.loadFor(profileId);
      await controller.setHidden(profileId, 'passifs_emprunts', true);

      final reloaded = SidebarPrefsController(profileController);
      await reloaded.loadFor(profileId);
      expect(reloaded.hiddenKeysFor(profileId), {'passifs_emprunts'});
    },
  );

  test('notifie ses auditeurs lors d\'un changement', () async {
    final profileId = profileController.active!.id;
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.loadFor(profileId);
    await controller.setHidden(profileId, 'actifs_epargne', true);

    expect(notified, greaterThanOrEqualTo(2));
  });
}

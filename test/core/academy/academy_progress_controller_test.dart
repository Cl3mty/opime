import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/academy/academy_progress_controller.dart';
import 'package:opime/core/academy/academy_progress_repository.dart';

void main() {
  late Directory tempDir;
  late AcademyProgressController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_academy_controller_',
    );
    controller = AcademyProgressController(
      AcademyProgressRepository(tempDir.path),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('isCompleted est faux avant tout chargement', () {
    expect(controller.isCompleted('envelope_pea'), isFalse);
  });

  test(
    'load() sans progression sauvegardée ne marque rien comme acquis',
    () async {
      await controller.load();
      expect(controller.isCompleted('envelope_pea'), isFalse);
    },
  );

  test(
    'setCompleted(true) marque la notion comme acquise et notifie',
    () async {
      var notified = false;
      controller.addListener(() => notified = true);

      await controller.setCompleted('envelope_pea', true);

      expect(controller.isCompleted('envelope_pea'), isTrue);
      expect(notified, isTrue);
    },
  );

  test('setCompleted persiste pour un futur load()', () async {
    await controller.setCompleted('invest_risque', true);

    final reloaded = AcademyProgressController(
      AcademyProgressRepository(tempDir.path),
    );
    await reloaded.load();
    expect(reloaded.isCompleted('invest_risque'), isTrue);
  });

  test('toggle bascule l\'état d\'une notion', () async {
    await controller.toggle('envelope_pea');
    expect(controller.isCompleted('envelope_pea'), isTrue);

    await controller.toggle('envelope_pea');
    expect(controller.isCompleted('envelope_pea'), isFalse);
  });

  test('setCompleted avec la même valeur ne notifie pas inutilement', () async {
    await controller.setCompleted('envelope_pea', false);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setCompleted('envelope_pea', false);

    expect(notifications, 0);
  });

  test('completedCountAmong compte uniquement les ids fournis', () async {
    await controller.setCompleted('a', true);
    await controller.setCompleted('b', true);
    await controller.setCompleted('c', true);

    expect(controller.completedCountAmong(['a', 'b', 'z']), 2);
  });
}

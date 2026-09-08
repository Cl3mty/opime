import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('les montants sont visibles par défaut', () {
    expect(AmountVisibilityController().hidden, isFalse);
  });

  test(
    'load() sans préférence sauvegardée conserve la visibilité par défaut',
    () async {
      final controller = AmountVisibilityController();
      await controller.load();
      expect(controller.hidden, isFalse);
    },
  );

  test('setHidden met à jour l\'état et notifie les auditeurs', () async {
    final controller = AmountVisibilityController();
    var notified = false;
    controller.addListener(() => notified = true);

    await controller.setHidden(true);

    expect(controller.hidden, isTrue);
    expect(notified, isTrue);
  });

  test('setHidden persiste le choix pour un futur load()', () async {
    final first = AmountVisibilityController();
    await first.setHidden(true);

    final second = AmountVisibilityController();
    await second.load();
    expect(second.hidden, isTrue);
  });

  test('toggle bascule l\'état', () async {
    final controller = AmountVisibilityController();
    await controller.setHidden(false);

    controller.toggle();
    await Future<void>.delayed(Duration.zero);
    expect(controller.hidden, isTrue);

    controller.toggle();
    await Future<void>.delayed(Duration.zero);
    expect(controller.hidden, isFalse);
  });

  test('setHidden avec la même valeur ne notifie pas inutilement', () async {
    final controller = AmountVisibilityController();
    await controller.setHidden(false);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setHidden(false);

    expect(notifications, 0);
  });
}

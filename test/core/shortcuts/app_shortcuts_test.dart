import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/shortcuts/app_shortcuts.dart';

void main() {
  test('trois actions, une combinaison distincte chacune', () {
    expect(AppShortcutAction.values, hasLength(3));
    final keys = AppShortcutAction.values.map((a) => a.key).toSet();
    expect(keys, hasLength(3));
  });

  test('displayLabel contient la lettre de la touche', () {
    for (final action in AppShortcutAction.values) {
      expect(action.displayLabel, contains(action.key.keyLabel));
    }
  });

  test('activator retient la même touche que l\'action', () {
    for (final action in AppShortcutAction.values) {
      expect(action.activator.trigger, action.key);
    }
  });
}

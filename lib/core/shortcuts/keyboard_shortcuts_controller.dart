import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglage device-local activant/désactivant les raccourcis clavier globaux
/// de l'application (voir `app_shortcuts.dart`'s `AppShortcutAction` et
/// `app_shell.dart`'s `CallbackShortcuts`) — même pattern que
/// [NotificationsSettingsController] : un `ChangeNotifier` chargé au
/// démarrage et réécrit dans `shared_preferences` à chaque modification.
/// Activé par défaut.
class KeyboardShortcutsController extends ChangeNotifier {
  static const _enabledKey = 'keyboard_shortcuts_enabled';

  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }
}

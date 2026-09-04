import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Langue choisie par l'utilisateur dans les Réglages. `system` correspond au
/// réglage par défaut : l'app suit alors la langue de l'appareil (avec retombée
/// en français si elle n'est pas prise en charge).
enum AppLocale {
  system,
  french,
  english;

  /// Le `Locale` effectif à utiliser par l'app pour cet énuméré ; `null` pour
  /// `system` (l'app se tourne alors vers la locale de l'appareil via
  /// `WidgetsBinding.instance.platformDispatcher.locale`).
  Locale? get locale => switch (this) {
        AppLocale.system => null,
        AppLocale.french => const Locale('fr'),
        AppLocale.english => const Locale('en'),
      };
}

/// Contrôle la langue d'affichage de l'app. Même motif que [ThemeController] :
/// `ChangeNotifier` + persistance dans `shared_preferences`, injecté depuis
/// `main.dart` puis passé à `ShadcnApp` (via sa `locale`) et aux Réglages pour
/// le sélecteur de langue.
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'app_locale';

  AppLocale _locale = AppLocale.system;

  AppLocale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    _locale = switch (saved) {
      'french' => AppLocale.french,
      'english' => AppLocale.english,
      _ => AppLocale.system,
    };
    notifyListeners();
  }

  Future<void> setLocale(AppLocale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.name);
  }
}

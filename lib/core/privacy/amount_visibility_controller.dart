import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrôle l'affichage/masquage global des montants dans toute l'app
/// (bascule de la top bar). Persisté comme la préférence de thème, pour
/// que le choix survive au redémarrage.
class AmountVisibilityController extends ChangeNotifier {
  static const _prefsKey = 'amounts_hidden';
  bool _hidden = false;

  bool get hidden => _hidden;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _hidden = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  Future<void> setHidden(bool value) async {
    if (_hidden == value) return;
    _hidden = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  void toggle() => setHidden(!_hidden);
}

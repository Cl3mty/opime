import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglage device-local de la fonctionnalité "Actualités" (actualités
/// Yahoo Finance pour les actions/ETF détenus, alertes de variation de prix
/// CoinGecko pour les cryptos détenues) — même pattern que
/// [ThemeController]/[AssistantConfigController] : un `ChangeNotifier`
/// chargé au démarrage et ré-écrit dans `shared_preferences` à chaque
/// modification. Préférence device-local (comme le thème), pas une donnée
/// de domaine liée à un vault, donc pas de fichier JSON du vault ici.
class NotificationsSettingsController extends ChangeNotifier {
  static const _enabledKey = 'news_notifications_enabled';
  static const _lastSeenKey = 'news_notifications_last_seen';

  bool _enabled = false;
  DateTime? _lastSeen;

  /// La fonctionnalité est-elle activée (via les Réglages) ? Désactivée,
  /// aucun appel réseau n'est effectué pour cette fonctionnalité — voir
  /// `NewsButton`/`NotificationsController`.
  bool get enabled => _enabled;

  /// Dernière consultation du panneau — sert à calculer le nombre
  /// d'éléments non lus (voir `NotificationsController.unreadCount`).
  DateTime? get lastSeen => _lastSeen;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    final lastSeenMs = prefs.getInt(_lastSeenKey);
    // isUtc: true — encodé/décodé en instant absolu (millisecondsSinceEpoch),
    // reconstruire en heure locale produirait un DateTime représentant le
    // même instant mais jugé différent par `==` (qui distingue UTC/local).
    _lastSeen = lastSeenMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastSeenMs, isUtc: true)
        : null;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> markSeen(DateTime when) async {
    _lastSeen = when;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenKey, when.millisecondsSinceEpoch);
  }
}

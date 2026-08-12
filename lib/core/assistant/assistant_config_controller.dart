import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ollama_client.dart';

/// Configuration persistée de l'assistant IA (Ollama local), sur le même
/// pattern que [ThemeController] : un ChangeNotifier chargé au démarrage et
/// ré-écrit dans `shared_preferences` à chaque modification.
///
/// L'assistant n'envoie aucune donnée vers le cloud : il dialogue
/// exclusivement avec une instance Ollama locale (http://localhost:11434 par
/// défaut), adresse qui reste modifiable pour cibler une autre machine du
/// réseau ou un autre port.
class AssistantConfigController extends ChangeNotifier {
  static const _enabledKey = 'assistant_enabled';
  static const _baseUrlKey = 'assistant_base_url';
  static const _modelKey = 'assistant_model';
  static const _includePatrimoineKey = 'assistant_include_patrimoine';

  static const defaultBaseUrl = 'http://localhost:11434';

  bool _enabled = false;
  String _baseUrl = defaultBaseUrl;
  String? _model;
  bool _includePatrimoine = true;

  /// L'assistant est-il activé (via les Réglages) ?
  bool get enabled => _enabled;

  /// Racine de l'API Ollama (sans `/api/...`).
  String get baseUrl => _baseUrl;

  /// Modèle Ollama choisi (ex : `llama3.2:3b`), `null` tant qu'aucun n'a été
  /// sélectionné — l'écran d'assistant propose alors de choisir parmi ceux
  /// détectés sur l'instance.
  String? get model => _model;

  /// Faut-il inclure une synthèse du patrimoine du profil actif dans le
  /// contexte envoyé au modèle ? Toujours local, mais désactivable pour
  /// alléger le contexte (et donc limiter la consommation mémoire/tokens).
  bool get includePatrimoine => _includePatrimoine;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    // Une adresse corrompue (saisie partielle, copier-coller raté...) est
    // ramenée à la valeur par défaut : sans ça, l'assistant afficherait
    // « Adresse du serveur invalide » sans raison d'être récupérable.
    final stored = prefs.getString(_baseUrlKey)?.trim() ?? defaultBaseUrl;
    _baseUrl = stored.isEmpty || !OllamaClient.isValidBaseUrl(stored)
        ? defaultBaseUrl
        : stored;
    _model = prefs.getString(_modelKey);
    _includePatrimoine = prefs.getBool(_includePatrimoineKey) ?? true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> setBaseUrl(String value) async {
    final normalized = value.trim().isEmpty ? defaultBaseUrl : value.trim();
    _baseUrl = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, normalized);
  }

  Future<void> setModel(String? value) async {
    _model = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_modelKey);
    } else {
      await prefs.setString(_modelKey, value);
    }
  }

  Future<void> setIncludePatrimoine(bool value) async {
    _includePatrimoine = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_includePatrimoineKey, value);
  }
}

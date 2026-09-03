import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'llm_provider.dart';
import 'ollama_client.dart';

/// Configuration persistée de l'assistant IA, sur le même pattern que
/// [ThemeController] : un ChangeNotifier chargé au démarrage et ré-écrit à
/// chaque modification.
///
/// L'assistant peut dialoguer soit avec une instance Ollama locale
/// (aucune donnée envoyée en ligne), soit avec un fournisseur cloud
/// (OpenAI, Anthropic, Google) connecté via une clé API — voir
/// [LlmProvider.isCloud]. Dans ce second cas, les messages (et la synthèse
/// patrimoine si [includePatrimoine] est activée) quittent la machine et
/// sont traités par les serveurs de ce fournisseur ; les Réglages affichent
/// un avertissement explicite tant qu'un fournisseur cloud est actif.
class AssistantConfigController extends ChangeNotifier {
  static const _enabledKey = 'assistant_enabled';
  static const _providerKey = 'assistant_provider';
  static const _baseUrlKey = 'assistant_base_url';
  static const _includePatrimoineKey = 'assistant_include_patrimoine';

  /// Clé de modèle Ollama historique, conservée telle quelle (sans suffixe
  /// de fournisseur) pour ne pas faire perdre son choix à un utilisateur
  /// déjà configuré avant l'introduction des fournisseurs cloud.
  static const _ollamaModelKey = 'assistant_model';

  static String _modelKeyFor(LlmProvider provider) =>
      provider == LlmProvider.ollama
      ? _ollamaModelKey
      : 'assistant_model_${provider.name}';

  static String _apiKeyStorageKeyFor(LlmProvider provider) =>
      'llm_api_key_${provider.name}';

  static const defaultBaseUrl = 'http://localhost:11434';

  final FlutterSecureStorage _secureStorage;

  AssistantConfigController({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          // `useDataProtectionKeyChain: false` (le défaut du package est
          // `true`) : Opime tourne en sandbox App Sandbox
          // (`com.apple.security.app-sandbox`, voir les `.entitlements` du
          // Runner) mais sans identité de signature stable (build local
          // sans compte développeur Apple, `CODE_SIGN_IDENTITY = "-"`) —
          // le "Data Protection Keychain" moderne exige une entitlement
          // `keychain-access-groups` valide pour ça, absente ici, et
          // `SecItemAdd`/`SecItemUpdate` échouaient silencieusement
          // (`errSecMissingEntitlement`, -34018 : l'appel Dart n'était
          // jamais attendu par l'UI, voir [setApiKeyFor]). Repli sur
          // l'API Trousseau historique (pré-Catalina), qui n'a pas cette
          // exigence et fonctionne en sandbox sans identité de signature
          // particulière — cause racine du bug "la clé API n'est pas
          // sauvegardée de façon persistante" : elle semblait enregistrée
          // (cache mémoire mis à jour, champ toujours rempli pendant la
          // session) mais ne survivait jamais à un redémarrage de l'app.
          const FlutterSecureStorage(
            mOptions: MacOsOptions(useDataProtectionKeyChain: false),
          );

  bool _enabled = false;
  LlmProvider _provider = LlmProvider.ollama;
  String _baseUrl = defaultBaseUrl;
  bool _includePatrimoine = true;
  final Map<LlmProvider, String?> _models = {};
  final Map<LlmProvider, String?> _apiKeys = {};

  /// Message d'erreur si le dernier appel à [setApiKeyFor] n'a pas pu
  /// écrire/effacer la clé dans le stockage sécurisé (`null` sinon) — sans
  /// ça, un échec du Trousseau système passait inaperçu : le cache mémoire
  /// (donc [apiKeyFor] et le champ de saisie) restait à jour pendant la
  /// session, donnant l'illusion que la clé était enregistrée alors
  /// qu'elle ne survivrait pas à un redémarrage de l'app.
  String? _apiKeyError;
  String? get apiKeyError => _apiKeyError;

  /// L'assistant est-il activé (via les Réglages) ?
  bool get enabled => _enabled;

  /// Fournisseur de modèle actuellement sélectionné.
  LlmProvider get provider => _provider;

  /// Racine de l'API Ollama (sans `/api/...`) — non pertinent pour les
  /// fournisseurs cloud, qui ont une adresse fixe côté client.
  String get baseUrl => _baseUrl;

  /// Modèle choisi pour le fournisseur actuel (ex : `llama3.2:3b` pour
  /// Ollama, `gpt-4o` pour OpenAI), `null` tant qu'aucun n'a été
  /// sélectionné — l'écran d'assistant propose alors de choisir parmi ceux
  /// détectés.
  String? get model => _models[_provider];

  /// Clé API du fournisseur [provider] (`null` si non configurée), lue
  /// depuis le cache mémoire rempli par [load]. `null` pour [LlmProvider.ollama],
  /// qui n'utilise pas de clé API.
  String? apiKeyFor(LlmProvider provider) => _apiKeys[provider];

  /// Faut-il inclure une synthèse du patrimoine du profil actif dans le
  /// contexte envoyé au modèle ? Toujours lu localement, mais transmis au
  /// fournisseur actif si celui-ci est un service cloud.
  bool get includePatrimoine => _includePatrimoine;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _provider = LlmProvider.values.firstWhere(
      (p) => p.name == prefs.getString(_providerKey),
      orElse: () => LlmProvider.ollama,
    );
    // Une adresse corrompue (saisie partielle, copier-coller raté...) est
    // ramenée à la valeur par défaut : sans ça, l'assistant afficherait
    // « Adresse du serveur invalide » sans raison d'être récupérable.
    final storedBaseUrl = prefs.getString(_baseUrlKey)?.trim() ?? defaultBaseUrl;
    _baseUrl = storedBaseUrl.isEmpty || !OllamaClient.isValidBaseUrl(storedBaseUrl)
        ? defaultBaseUrl
        : storedBaseUrl;
    _includePatrimoine = prefs.getBool(_includePatrimoineKey) ?? true;

    for (final provider in LlmProvider.values) {
      _models[provider] = prefs.getString(_modelKeyFor(provider));
      if (provider.isCloud) {
        _apiKeys[provider] = await _secureStorage.read(
          key: _apiKeyStorageKeyFor(provider),
        );
      }
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> setProvider(LlmProvider value) async {
    _provider = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, value.name);
  }

  Future<void> setBaseUrl(String value) async {
    final normalized = value.trim().isEmpty ? defaultBaseUrl : value.trim();
    _baseUrl = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, normalized);
  }

  /// Change le modèle du fournisseur *actuellement sélectionné*
  /// ([provider]) — changer de fournisseur puis rappeler [setModel] affecte
  /// ce nouveau fournisseur, pas l'ancien.
  Future<void> setModel(String? value) async {
    _models[_provider] = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = _modelKeyFor(_provider);
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  /// Enregistre (ou efface, si `null`) la clé API du fournisseur cloud
  /// [provider] dans le stockage sécurisé du système (Trousseau macOS,
  /// Gestionnaire d'identification Windows, Secret Service Linux) — jamais
  /// en clair dans `shared_preferences`, contrairement au reste de cette
  /// configuration : une clé API est un secret facturable, pas une simple
  /// préférence d'affichage.
  Future<void> setApiKeyFor(LlmProvider provider, String? value) async {
    final trimmed = value?.trim();
    _apiKeys[provider] = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final key = _apiKeyStorageKeyFor(provider);
    try {
      if (_apiKeys[provider] == null) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: _apiKeys[provider]);
      }
      _apiKeyError = null;
    } catch (e) {
      // Le cache mémoire ci-dessus reste à jour (la clé continue de
      // fonctionner pour la session en cours), mais sans être persistée :
      // signalé via [apiKeyError] plutôt que laissé silencieux, pour que
      // l'utilisateur sache qu'elle ne survivra pas à un redémarrage.
      _apiKeyError =
          'Impossible d\'enregistrer la clé dans le Trousseau du système : $e';
    }
    notifyListeners();
  }

  Future<void> setIncludePatrimoine(bool value) async {
    _includePatrimoine = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_includePatrimoineKey, value);
  }
}

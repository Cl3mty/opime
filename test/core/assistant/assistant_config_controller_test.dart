import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opime/core/assistant/assistant_config_controller.dart';
import 'package:opime/core/assistant/llm_provider.dart';

void main() {
  late Map<String, String> secureStorageData;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorageData = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureStorageData,
    );
  });

  test('par défaut : fournisseur Ollama, aucune clé API', () async {
    final config = AssistantConfigController();
    await config.load();

    expect(config.provider, LlmProvider.ollama);
    expect(config.apiKeyFor(LlmProvider.openai), isNull);
    expect(config.apiKeyFor(LlmProvider.anthropic), isNull);
    expect(config.apiKeyFor(LlmProvider.google), isNull);
  });

  test('le fournisseur choisi survit à un rechargement', () async {
    final config = AssistantConfigController();
    await config.load();
    await config.setProvider(LlmProvider.anthropic);

    final reloaded = AssistantConfigController();
    await reloaded.load();

    expect(reloaded.provider, LlmProvider.anthropic);
  });

  test(
    'chaque fournisseur garde son propre modèle : changer de fournisseur '
    'ne fait pas perdre le choix fait sur un autre',
    () async {
      final config = AssistantConfigController();
      await config.load();

      await config.setProvider(LlmProvider.ollama);
      await config.setModel('llama3.2:3b');

      await config.setProvider(LlmProvider.openai);
      expect(config.model, isNull);
      await config.setModel('gpt-4o');

      await config.setProvider(LlmProvider.ollama);
      expect(config.model, 'llama3.2:3b');

      await config.setProvider(LlmProvider.openai);
      expect(config.model, 'gpt-4o');
    },
  );

  test(
    'le modèle Ollama choisi avant l\'introduction des fournisseurs cloud '
    'reste lisible (pas de migration nécessaire, même clé de préférences)',
    () async {
      SharedPreferences.setMockInitialValues({
        'assistant_model': 'llama3.2:3b',
      });
      final config = AssistantConfigController();
      await config.load();

      expect(config.provider, LlmProvider.ollama);
      expect(config.model, 'llama3.2:3b');
    },
  );

  test(
    'la clé API d\'un fournisseur cloud est écrite dans le stockage '
    'sécurisé, pas dans shared_preferences',
    () async {
      final config = AssistantConfigController();
      await config.load();

      await config.setApiKeyFor(LlmProvider.openai, 'sk-test-123');

      expect(config.apiKeyFor(LlmProvider.openai), 'sk-test-123');
      expect(secureStorageData['llm_api_key_openai'], 'sk-test-123');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.contains('sk-test-123')),
        isEmpty,
      );
    },
  );

  test('la clé API survit à un rechargement', () async {
    final config = AssistantConfigController();
    await config.load();
    await config.setApiKeyFor(LlmProvider.anthropic, 'sk-ant-abc');

    final reloaded = AssistantConfigController();
    await reloaded.load();

    expect(reloaded.apiKeyFor(LlmProvider.anthropic), 'sk-ant-abc');
  });

  test('effacer la clé API (valeur vide) la retire du stockage sécurisé', () async {
    final config = AssistantConfigController();
    await config.load();
    await config.setApiKeyFor(LlmProvider.google, 'goog-abc');
    expect(config.apiKeyFor(LlmProvider.google), isNotNull);

    await config.setApiKeyFor(LlmProvider.google, '');

    expect(config.apiKeyFor(LlmProvider.google), isNull);
    expect(secureStorageData.containsKey('llm_api_key_google'), isFalse);
  });

  test(
    'les clés des 3 fournisseurs cloud sont indépendantes entre elles',
    () async {
      final config = AssistantConfigController();
      await config.load();

      await config.setApiKeyFor(LlmProvider.openai, 'sk-openai');
      await config.setApiKeyFor(LlmProvider.anthropic, 'sk-anthropic');
      await config.setApiKeyFor(LlmProvider.google, 'sk-google');

      expect(config.apiKeyFor(LlmProvider.openai), 'sk-openai');
      expect(config.apiKeyFor(LlmProvider.anthropic), 'sk-anthropic');
      expect(config.apiKeyFor(LlmProvider.google), 'sk-google');
    },
  );
}

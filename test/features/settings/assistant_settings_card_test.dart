import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opime/core/assistant/assistant_config_controller.dart';
import 'package:opime/core/assistant/llm_provider.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/settings/settings_screen.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
  });

  Future<AssistantConfigController> enabledConfig() async {
    final config = AssistantConfigController();
    await config.load();
    await config.setEnabled(true);
    return config;
  }

  Future<void> pump(WidgetTester tester, AssistantConfigController config) {
    return tester.pumpWidget(
      ShadcnApp(
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          shadcnLocalizationsFrDelegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        home: Scaffold(
          child: AssistantSettingsCard(configController: config),
        ),
      ),
    );
  }

  testWidgets(
    'fournisseur Ollama (par défaut) : champ d\'adresse visible, pas de '
    'champ clé API ni de bandeau d\'avertissement',
    (tester) async {
      final config = await enabledConfig();
      await pump(tester, config);
      await tester.pump();

      expect(find.text('Adresse du serveur Ollama'), findsOneWidget);
      expect(find.textContaining('Clé API'), findsNothing);
      expect(
        find.textContaining('hors de ta machine'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'basculer sur OpenAI affiche le champ clé API et le bandeau '
    'd\'avertissement, masque le champ d\'adresse Ollama',
    (tester) async {
      final config = await enabledConfig();
      await pump(tester, config);
      await tester.pump();

      await tester.tap(find.text('Ollama (local)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OpenAI'));
      await tester.pumpAndSettle();

      expect(find.text('Adresse du serveur Ollama'), findsNothing);
      expect(find.text('Clé API OpenAI'), findsOneWidget);
      expect(find.textContaining('hors de ta machine'), findsOneWidget);
      expect(find.textContaining('OpenAI'), findsWidgets);
    },
  );

  testWidgets(
    'revenir sur Ollama depuis un fournisseur cloud masque à nouveau le '
    'champ clé API et le bandeau d\'avertissement',
    (tester) async {
      final config = await enabledConfig();
      await config.setProvider(LlmProvider.anthropic);
      await pump(tester, config);
      await tester.pump();
      expect(find.text('Clé API Anthropic (Claude)'), findsOneWidget);

      await tester.tap(find.text('Anthropic (Claude)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ollama (local)').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Clé API'), findsNothing);
      expect(find.textContaining('hors de ta machine'), findsNothing);
      expect(find.text('Adresse du serveur Ollama'), findsOneWidget);
    },
  );

  testWidgets(
    'saisir une clé API la persiste dans la config du fournisseur actif',
    (tester) async {
      final config = await enabledConfig();
      await config.setProvider(LlmProvider.google);
      await pump(tester, config);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'goog-secret-key');
      await tester.pump();

      expect(config.apiKeyFor(LlmProvider.google), 'goog-secret-key');
    },
  );
}

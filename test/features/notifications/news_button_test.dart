import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/notifications/notifications_settings_controller.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/notifications/news_button.dart';
import 'package:opime/features/notifications/notifications_controller.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('masqué quand la fonctionnalité est désactivée', (tester) async {
    final settings = NotificationsSettingsController();
    final controller = NotificationsController();

    await tester.pumpWidget(
      ShadcnApp(
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          shadcnLocalizationsFrDelegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        home: Scaffold(
          child: NewsButton(
            settings: settings,
            controller: controller,
            vaultPath: '/tmp/vault',
          ),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.bell), findsNothing);
  });

  testWidgets('affiche l\'icône quand la fonctionnalité est activée', (
    tester,
  ) async {
    final settings = NotificationsSettingsController();
    await settings.setEnabled(true);
    final controller = NotificationsController();

    await tester.pumpWidget(
      ShadcnApp(
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          shadcnLocalizationsFrDelegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        home: Scaffold(
          child: NewsButton(
            settings: settings,
            controller: controller,
            vaultPath: '/tmp/vault',
          ),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.bell), findsOneWidget);
  });
}

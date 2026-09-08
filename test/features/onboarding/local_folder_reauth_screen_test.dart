import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/onboarding/local_folder_reauth_screen.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Widget wrap(Widget child) => ShadcnApp(
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr'), Locale('en')],
    localizationsDelegates: [
      shadcnLocalizationsFrDelegate,
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: child,
  );

  testWidgets('affiche le nom du coffre-fort dans la description', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        LocalFolderReauthScreen(
          vaultName: 'Mon Drive',
          onReauthorize: () async => true,
        ),
      ),
    );

    expect(find.textContaining('Mon Drive'), findsOneWidget);
  });

  testWidgets(
    'un succès de onReauthorize ne laisse aucun message d\'échec affiché',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          LocalFolderReauthScreen(
            vaultName: 'Mon Drive',
            onReauthorize: () async => true,
          ),
        ),
      );

      await tester.tap(find.text("Redonner l'accès"));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "L'accès n'a pas été accordé. Réessaie, ou choisis le bon "
          'dossier si le navigateur te le demande.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets('un échec de onReauthorize affiche le message d\'erreur', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        LocalFolderReauthScreen(
          vaultName: 'Mon Drive',
          onReauthorize: () async => false,
        ),
      ),
    );

    await tester.tap(find.text("Redonner l'accès"));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "L'accès n'a pas été accordé. Réessaie, ou choisis le bon "
        'dossier si le navigateur te le demande.',
      ),
      findsOneWidget,
    );
  });
}

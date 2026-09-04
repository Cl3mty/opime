import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_folder_service.dart' show VaultKind;
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/core/ui/vault_kind_selector.dart';
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

  group('VaultKindSelector', () {
    testWidgets(
      'affiche les deux options, celle passée en value est sélectionnée',
      (tester) async {
        VaultKind selected = VaultKind.personal;
        await tester.pumpWidget(
          wrap(
            Scaffold(
              child: StatefulBuilder(
                builder: (context, setState) => VaultKindSelector(
                  value: selected,
                  onChanged: (k) => setState(() => selected = k),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Personnel'), findsOneWidget);
        expect(find.text('Professionnel'), findsOneWidget);

        await tester.tap(find.text('Professionnel'));
        await tester.pump();

        expect(selected, VaultKind.professional);
      },
    );
  });

  group('showVaultKindDialog', () {
    testWidgets(
      'renvoie null si annulé, sans changer la sélection par défaut',
      (tester) async {
        VaultKind? result;
        await tester.pumpWidget(
          wrap(
            Scaffold(
              child: Builder(
                builder: (context) => PrimaryButton(
                  onPressed: () async {
                    result = await showVaultKindDialog(context);
                  },
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();

        expect(result, isNull);
      },
    );

    testWidgets(
      'sélectionner Professionnel puis Continuer renvoie ce choix',
      (tester) async {
        VaultKind? result;
        await tester.pumpWidget(
          wrap(
            Scaffold(
              child: Builder(
                builder: (context) => PrimaryButton(
                  onPressed: () async {
                    result = await showVaultKindDialog(context);
                  },
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Professionnel'));
        await tester.pump();
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();

        expect(result, VaultKind.professional);
      },
    );
  });
}

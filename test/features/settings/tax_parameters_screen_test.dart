import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/settings/tax_parameters_screen.dart';
import 'package:opime/features/simulations/tax_parameters.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_tax_parameters_screen_test_',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ShadcnApp(
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            shadcnLocalizationsFrDelegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          home: Scaffold(
            child: TaxParametersScreen(vaultPath: tempDir.path),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'affiche les valeurs par défaut au premier chargement, sans bouton '
    'de réinitialisation visible (rien n\'a encore été modifié)',
    (tester) async {
      await pump(tester);

      expect(find.text('Paramètres fiscaux'), findsOneWidget);
      // Premier seuil IR par défaut.
      expect(find.text('11294'), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
    },
  );

  testWidgets(
    'modifier une valeur la persiste sur disque et fait apparaître son '
    'bouton de réinitialisation',
    (tester) async {
      await pump(tester);

      final field = find.widgetWithText(TextField, '11294');
      expect(field, findsOneWidget);

      // `enterText` déclenche `onChanged` → `_update`, qui écrit sur disque
      // sans être attendu par l'écran (voir `_update`) : une vraie E/S
      // asynchrone, qui doit donc rester dans la même zone `runAsync` que
      // l'interaction qui la déclenche, sinon sa continuation reste
      // suspendue indéfiniment dans la zone fake-async du test (même piège
      // que partout ailleurs dans cette suite pour de l'E/S réelle
      // déclenchée depuis un callback de widget).
      await tester.runAsync(() async {
        await tester.enterText(field, '12000');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('12000'), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);

      final saved = await tester.runAsync(
        () => loadTaxParameters(tempDir.path),
      );
      expect(saved!.irLimits[0], 12000);
    },
  );

  testWidgets(
    'le bouton de réinitialisation ramène la valeur modifiée à sa '
    'référence légale et la repersiste',
    (tester) async {
      // La carte Abattements/barèmes donation se trouve bas dans la page,
      // hors du viewport 800x600 par défaut.
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(
        () => saveTaxParameters(
          tempDir.path,
          TaxParameters.defaults.copyWith(abattementEnfant: 150000),
        ),
      );
      await pump(tester);

      expect(find.text('150000'), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byIcon(LucideIcons.rotateCcw));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('100000'), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);

      final saved = await tester.runAsync(
        () => loadTaxParameters(tempDir.path),
      );
      expect(saved!.abattementEnfant, 100000);
    },
  );

  testWidgets(
    'le taux d\'un barème donation/succession s\'affiche en pourcentage '
    'lisible (5, pas 0.05, le format de stockage interne de TaxBracket)',
    (tester) async {
      await pump(tester);

      // Première tranche du barème ligne directe : 8072 € à 5 %.
      expect(find.text('8072'), findsWidgets);
      expect(find.text('5'), findsWidgets);
    },
  );

  testWidgets(
    'PFU : part IR et part prélèvements sociaux sont deux champs '
    'indépendants, chacun avec son propre bouton de réinitialisation',
    (tester) async {
      // La carte PFU est la dernière de la page, hors du viewport 800x600
      // par défaut.
      tester.view.physicalSize = const Size(1200, 4600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pump(tester);

      expect(find.text('Part IR (%)'), findsOneWidget);
      expect(find.text('Part prélèvements sociaux (%)'), findsOneWidget);
      expect(find.widgetWithText(TextField, '12.8'), findsOneWidget);
      expect(find.widgetWithText(TextField, '18.6'), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);

      // Modifier seulement la part IR fait apparaître un seul bouton de
      // réinitialisation (celui de la part IR, pas celui des PS).
      await tester.runAsync(() async {
        await tester.enterText(find.widgetWithText(TextField, '12.8'), '13');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byIcon(LucideIcons.rotateCcw));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.widgetWithText(TextField, '12.8'), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);

      final saved = await tester.runAsync(
        () => loadTaxParameters(tempDir.path),
      );
      expect(saved!.pfuIrRate, 12.8);
      expect(saved.pfuPsRate, 18.6);
    },
  );
}

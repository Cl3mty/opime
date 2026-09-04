import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';
import 'package:opime/features/liabilities/liabilities_repository.dart';
import 'package:opime/features/liabilities/liability_detail_view.dart';
import 'package:opime/features/simulations/loan_calculator.dart' show DeferType;
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;
  late LiabilitiesRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_liability_detail_view_test_',
    );
    repo = LiabilitiesRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Liability liability({bool differeActif = false, int dureeDiffereMois = 0}) =>
      Liability(
        type: LiabilityType.pretImmobilier,
        name: 'Prêt appart',
        montantEmprunte: 200000,
        tauxInteret: 3.5,
        nbrEcheances: 240,
        dateDebut: DateTime(2024, 1, 1),
        differeActif: differeActif,
        dureeDiffereMois: dureeDiffereMois,
      );

  Future<void> pump(WidgetTester tester, Liability liability) => tester.pumpWidget(
    ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      
      home: Scaffold(
        child: LiabilityDetailView(
          vaultPath: tempDir.path,
          liability: liability,
          hidden: false,
          onBack: () {},
          onChanged: () {},
        ),
      ),
    ),
  );

  Future<void> startEdit(WidgetTester tester) async {
    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    // `pumpAndSettle`, pas un simple `pump()` : le menu déroulant ouvert
    // juste avant garde sinon sa superposition (barrière de fermeture
    // encore en cours d'animation) au-dessus du formulaire, qui intercepte
    // alors les taps suivants (ex : sur le `Switch`) avant qu'ils
    // n'atteignent le vrai widget.
    await tester.pumpAndSettle();
  }

  testWidgets(
    'un prêt sans différé : le switch est désactivé, ni le champ de durée '
    'ni le choix de franchise ne sont affichés',
    (tester) async {
      await pump(tester, liability());
      await startEdit(tester);

      expect(find.text('Prêt différé'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text('Durée du différé (mois)'), findsNothing);
      expect(find.text('Partielle'), findsNothing);
      expect(find.text('Totale'), findsNothing);
    },
  );

  testWidgets(
    'un prêt déjà différé : le switch est activé et les champs associés '
    'sont visibles dès l\'ouverture du formulaire',
    (tester) async {
      await pump(
        tester,
        liability(differeActif: true, dureeDiffereMois: 12),
      );
      await startEdit(tester);

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Durée du différé (mois)'), findsOneWidget);
      expect(find.text('Partielle'), findsOneWidget);
      expect(find.text('Totale'), findsOneWidget);
    },
  );

  testWidgets(
    'activer le switch fait apparaître la durée et le choix de franchise',
    (tester) async {
      await pump(tester, liability());
      await startEdit(tester);
      expect(find.text('Durée du différé (mois)'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(find.text('Durée du différé (mois)'), findsOneWidget);
      expect(find.text('Partielle'), findsOneWidget);
    },
  );

  testWidgets(
    'enregistrer avec le switch désactivé force dureeDiffereMois à 0, même '
    'si le champ masqué contient encore une ancienne valeur',
    (tester) async {
      await tester.runAsync(
        () => repo.saveLiability(
          liability(differeActif: true, dureeDiffereMois: 12),
        ),
      );
      final saved = (await tester.runAsync(() => repo.listAll()))!.single;
      await pump(tester, saved);
      await startEdit(tester);

      // Le switch est activé (le prêt l'était), le champ de durée porte
      // encore "12" — on le désactive sans y toucher.
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.text('Durée du différé (mois)'), findsNothing);

      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final updated = (await tester.runAsync(() => repo.listAll()))!.single;
      expect(updated.differeActif, isFalse);
      expect(updated.dureeDiffereMois, 0);
    },
  );

  testWidgets(
    'activer le switch puis saisir une durée persiste bien le différé',
    (tester) async {
      await tester.runAsync(() => repo.saveLiability(liability()));
      final saved = (await tester.runAsync(() => repo.listAll()))!.single;
      await pump(tester, saved);
      await startEdit(tester);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Durée du différé (mois)'),
        '24',
      );
      await tester.tap(find.text('Totale'));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final updated = (await tester.runAsync(() => repo.listAll()))!.single;
      expect(updated.differeActif, isTrue);
      expect(updated.dureeDiffereMois, 24);
      expect(updated.typeDiffere, DeferType.totale);
    },
  );
}

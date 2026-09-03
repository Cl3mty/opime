import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/entities/entities_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_entities_screen_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ShadcnApp(
      home: Scaffold(child: EntitiesScreen(vaultPath: tempDir.path)),
    ),
  );

  testWidgets(
    'coffre-fort sans entité : message vide, total à 0 €',
    (tester) async {
      await tester.runAsync(() async {
        await pump(tester);
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });

      expect(
        find.text('Aucune entité pour l\'instant — ajoute un holding, une '
            'société commerciale, une SCI ou un compte pro.'),
        findsOneWidget,
      );
      expect(find.text('0 €'), findsOneWidget);
    },
  );

  testWidgets(
    'créer une entité (60% détenu, 1 actif 200 000 €, 1 passif 50 000 €) '
    'affiche la valeur nette (150 000 €) et la valeur détenue (90 000 €)',
    (tester) async {
      await tester.runAsync(() async {
        await pump(tester);
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });

      await tester.tap(find.text('Ajouter une entité'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.enterText(
          find.widgetWithText(TextField, 'Nom (ex : Holding Dupont)'),
          'SCI Les Tilleuls',
        );
        await tester.enterText(
          find.widgetWithText(TextField, '% détenu'),
          '60',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      // Une ligne d'actif puis une ligne de passif.
      await tester.tap(find.byKey(const ValueKey('add_line_Actifs')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add_line_Passifs')));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.enterText(
          find.widgetWithText(TextField, 'Libellé').first,
          'Immeuble',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Montant (€)').first,
          '200000',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Libellé').last,
          'Emprunt',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Montant (€)').last,
          '50000',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 50));
        }
      });

      expect(find.text('SCI Les Tilleuls'), findsOneWidget);
      expect(find.textContaining('60 % détenu'), findsOneWidget);
      // Total détenu (en tête de page) et valeur détenue de l'entité :
      // même montant affiché à deux endroits.
      expect(find.text('90 000 €'), findsNWidgets(2));
      // Valeur nette de l'entité (avant pondération par le % détenu),
      // affichée en complément sur sa carte.
      expect(find.textContaining('150 000 €'), findsOneWidget);
    },
  );
}

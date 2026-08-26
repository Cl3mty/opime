import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/complete_patrimoine_dialog.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_complete_patrimoine_test_',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpDialog(WidgetTester tester, {required AssetClass initialAssetClass}) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: Builder(
            builder: (context) => GestureDetector(
              onTap: () => showCompletePatrimoineDialog(
                context,
                vaultPath: tempDir.path,
                onCompleted: () {},
                initialAssetClass: initialAssetClass,
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    // Le chargement initial (comptes existants, logos, catégories "Autres"
    // personnalisées) est asynchrone.
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if (find.text('Quel bien ?').evaluate().isNotEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
  }

  testWidgets(
    '"Autres" saute directement l\'étape "Quel établissement ?" (elle n\'a '
    'plus de notion d\'établissement financier), et utilise un vocabulaire '
    'adapté ("bien", pas "compte")',
    (tester) async {
      await pumpDialog(tester, initialAssetClass: AssetClass.autres);

      expect(find.text('Quel établissement ?'), findsNothing);
      expect(find.text('Quel compte ?'), findsNothing);
      expect(find.text('Quel bien ?'), findsOneWidget);
    },
  );

  testWidgets(
    'créer un bien "Autres" ne demande pas de banque/établissement, le nom '
    'est saisi librement',
    (tester) async {
      await pumpDialog(tester, initialAssetClass: AssetClass.autres);

      await tester.tap(find.text('Nouveau bien'));
      await tester.pump();

      // Pas de champ "Banque" pour Autres — un seul TextField visible,
      // celui du nom.
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Rolex Submariner');
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('Créer'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      final account = saved!.single;
      expect(account.assetClass, AssetClass.autres);
      expect(account.name, 'Rolex Submariner');
      expect(account.bankName, isNull);
    },
  );

  testWidgets(
    'ajouter une pièce à l\'intérieur du bien : pas d\'ISIN exigé, une '
    'référence est générée si laissée vide',
    (tester) async {
      await pumpDialog(tester, initialAssetClass: AssetClass.autres);

      await tester.tap(find.text('Nouveau bien'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Montres de collection');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Créer'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      // Étape suivante : "Quelle pièce ?", pas "Quel investissement ?".
      expect(find.text('Quel investissement ?'), findsNothing);
      expect(find.text('Quelle pièce ?'), findsOneWidget);

      await tester.tap(find.text('Nouvelle pièce'));
      await tester.pump();

      // Le nom précède la référence (facultative, pas "ISIN").
      expect(find.text('Nom (ex : Rolex Submariner)'), findsOneWidget);
      expect(
        find.text('Référence (optionnelle : numéro de série, référence...)'),
        findsOneWidget,
      );
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));
      // Nom saisi (premier champ), référence laissée vide (second champ).
      await tester.enterText(textFields.at(0), 'Rolex Submariner Date');
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('Ajouter la pièce'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      final investment = saved!.single.investments.single;
      expect(investment.label, 'Rolex Submariner Date');
      // Référence auto-générée, jamais vide (identité de l'investissement).
      expect(investment.isin, startsWith('autre-'));
    },
  );
}

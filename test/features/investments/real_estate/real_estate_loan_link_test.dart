import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/real_estate/real_estate_loan_link.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';
import 'package:opime/features/liabilities/liabilities_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;
  late LiabilitiesRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_real_estate_loan_link_test_',
    );
    repo = LiabilitiesRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, String investmentId) async {
    // `initState` déclenche un vrai chargement disque (`_load`) : comme
    // pour toute opération d'E/S réelle dans un test widget, `pumpWidget`
    // doit rester dans la même zone `runAsync` que ce chargement, sinon sa
    // continuation reste suspendue indéfiniment dans la zone fake-async
    // (même piège rencontré en écrivant les tests de
    // `investment_detail_screen_test.dart`'s onglet Loyers).
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: RealEstateLoanLinkSection(
              vaultPath: tempDir.path,
              investmentId: investmentId,
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pumpAndSettle();
  }

  Liability loan({String? linkedInvestmentId, String name = 'Prêt appart'}) =>
      Liability(
        type: LiabilityType.pretImmobilier,
        name: name,
        montantEmprunte: 200000,
        tauxInteret: 3.5,
        nbrEcheances: 240,
        dateDebut: DateTime(2024, 1, 1),
        linkedInvestmentId: linkedInvestmentId,
      );

  testWidgets(
    'sans aucun prêt immobilier disponible, affiche un message plutôt '
    'qu\'un bouton inerte',
    (tester) async {
      await pump(tester, 'immobilier-abc');
      expect(
        find.text('Aucun prêt immobilier disponible à lier.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'un prêt immobilier existant, pas encore lié, propose "Lier un prêt '
    'existant"',
    (tester) async {
      await tester.runAsync(() => repo.saveLiability(loan()));
      await pump(tester, 'immobilier-abc');
      expect(find.text('Lier un prêt existant'), findsOneWidget);
    },
  );

  testWidgets(
    'un prêt déjà lié à un AUTRE bien n\'apparaît pas comme candidat '
    '(régression potentielle : un prêt ne devrait financer qu\'un bien)',
    (tester) async {
      await tester.runAsync(
        () => repo.saveLiability(loan(linkedInvestmentId: 'immobilier-xyz')),
      );
      await pump(tester, 'immobilier-abc');
      expect(
        find.text('Aucun prêt immobilier disponible à lier.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'lier un prêt le persiste (linkedInvestmentId renseigné) et affiche '
    'son nom + capital restant dû',
    (tester) async {
      await tester.runAsync(() => repo.saveLiability(loan()));
      await pump(tester, 'immobilier-abc');

      await tester.tap(find.text('Lier un prêt existant'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Prêt appart'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(() => repo.listAll());
      expect(saved!.single.linkedInvestmentId, 'immobilier-abc');
    },
  );

  testWidgets(
    'délier un prêt déjà lié efface linkedInvestmentId',
    (tester) async {
      await tester.runAsync(
        () => repo.saveLiability(loan(linkedInvestmentId: 'immobilier-abc')),
      );
      await pump(tester, 'immobilier-abc');

      expect(find.textContaining('Prêt appart'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byIcon(LucideIcons.unlink));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(() => repo.listAll());
      expect(saved!.single.linkedInvestmentId, isNull);
    },
  );
}

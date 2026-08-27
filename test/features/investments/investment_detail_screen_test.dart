import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investment_detail_screen.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets(
    'modifier une position "Autres" et vider son identifiant saisi par '
    'erreur régénère un identifiant plutôt que de bloquer l\'enregistrement '
    '(régression : le champ vide était auparavant simplement rejeté)',
    (tester) async {
      final investment = Investment(
        isin: 'REF-123',
        label: 'Rolex Submariner',
        transactions: const [],
      );
      final account = InvestmentAccount(
        assetClass: AssetClass.autres,
        envelope: AccountEnvelope.montre,
        name: 'Montres',
        investments: [investment],
      );
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_investment_detail_test',
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: InvestmentDetailView(
              vaultPath: tempDir.path,
              account: account,
              investment: investment,
              hidden: false,
              onBack: () {},
              onChanged: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aucune transaction sur cette position : le seul "⋮" présent est
      // celui du menu de la position elle-même.
      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      // Libellé, puis identifiant (voir le nouvel ordre des champs) : on
      // vide l'identifiant saisi par erreur.
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), '');
      // L'enregistrement écrit réellement sur disque (`dart:io`) : sans
      // `runAsync`, cette écriture asynchrone ne se résout pas dans la zone
      // fake-async du test — voir le même motif ailleurs dans la suite
      // (ex : `stock_account_screen_test.dart`).
      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      final savedInvestment = saved!.single.investments.single;
      expect(savedInvestment.label, 'Rolex Submariner');
      expect(isGeneratedIdentifier(savedInvestment.isin), isTrue);
    },
  );
}

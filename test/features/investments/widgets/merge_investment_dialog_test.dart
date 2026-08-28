import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/widgets/merge_investment_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

void main() {
  late Directory tempDir;
  late InvestmentsRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_merge_investment_test_',
    );
    repo = InvestmentsRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Widget buildTrigger({
    required InvestmentAccount account,
    required Investment sourceInvestment,
    required Future<void> Function() onChanged,
  }) {
    return ShadcnApp(
      home: Scaffold(
        child: Builder(
          builder: (context) => OutlineButton(
            onPressed: () => showMergeInvestmentDialog(
              context,
              vaultPath: tempDir.path,
              account: account,
              sourceInvestment: sourceInvestment,
              onChanged: onChanged,
            ),
            child: const shadcn.Text('ouvrir'),
          ),
        ),
      ),
    );
  }

  Future<T> readAsync<T>(WidgetTester tester, Future<T> Function() read) =>
      tester.runAsync(read).then((value) => value as T);

  testWidgets(
    'fusionne toutes les transactions et documents de la source dans la '
    'destination présélectionnée (seule autre position du compte), puis '
    'supprime la source',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final a1 = Investment(
        isin: 'FR0000131104',
        label: 'TotalEnergies',
        transactions: [
          Transaction(
            id: 'a1_buy',
            date: DateTime(2023, 1, 1),
            isBuy: true,
            quantity: 5,
            unitPrice: 40,
          ),
        ],
      );
      // Le même titre, saisi une seconde fois sous un autre libellé.
      final a2 = Investment(
        isin: 'FR0000131104',
        label: 'Total Energies SE',
        transactions: [
          Transaction(
            id: 'a2_buy',
            date: DateTime(2024, 3, 1),
            isBuy: true,
            quantity: 3,
            unitPrice: 55,
          ),
        ],
      );
      final account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO A',
        investments: [a1, a2],
      );
      await tester.runAsync(() => repo.saveAccount(account));

      var changedCount = 0;
      await tester.pumpWidget(
        buildTrigger(
          account: account,
          sourceInvestment: a2,
          onChanged: () async {
            changedCount++;
          },
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      // Une seule autre position dans le compte : présélectionnée par
      // défaut, aucune interaction avec le `Select` nécessaire.
      expect(find.text('TotalEnergies'), findsWidgets);

      await tester.runAsync(() async {
        await tester.tap(find.text('Fusionner'));
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      expect(changedCount, 1);
      final all = await readAsync(tester, repo.listAll);
      final reloadedAccount = all.firstWhere((a) => a.id == account.id);

      // a2 a disparu, seule a1 reste.
      expect(reloadedAccount.investments, hasLength(1));
      final merged = reloadedAccount.investments.single;
      expect(merged.id, a1.id);
      expect(merged.label, 'TotalEnergies');

      // Les deux transactions cohabitent, inchangées.
      expect(merged.transactions, hasLength(2));
      final ids = merged.transactions.map((t) => t.id).toSet();
      expect(ids, {'a1_buy', 'a2_buy'});
      final movedTxn = merged.transactions.firstWhere(
        (t) => t.id == 'a2_buy',
      );
      expect(movedTxn.quantity, 3);
      expect(movedTxn.unitPrice, 55);
      expect(merged.quantityHeld, 8);
    },
  );
}

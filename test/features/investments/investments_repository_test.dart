import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';

void main() {
  late Directory tempDir;
  late InvestmentsRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_investments_repository_',
    );
    repo = InvestmentsRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('deleteTransaction', () {
    test('retire une transaction par id, où qu\'elle vive dans le vault '
        '(compte différent de celui d\'origine) — cas d\'usage : supprimer '
        'la contrepartie d\'un transfert/arbitrage', () async {
      final sourceAccount = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO A',
        investments: [
          Investment(
            isin: 'FR0000131104',
            label: 'BNP Paribas',
            transactions: [
              Transaction(
                id: 'sell_1',
                date: DateTime(2026, 1, 1),
                isBuy: false,
                quantity: 5,
                unitPrice: 60,
                type: TransactionType.transfer,
                linkedTransactionId: 'buy_1',
              ),
            ],
          ),
        ],
      );
      final destAccount = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.pea,
        name: 'PEA B',
        investments: [
          Investment(
            isin: 'FR0000131104',
            label: 'BNP Paribas',
            transactions: [
              Transaction(
                id: 'buy_1',
                date: DateTime(2026, 1, 1),
                isBuy: true,
                quantity: 5,
                unitPrice: 60,
                type: TransactionType.transfer,
                linkedTransactionId: 'sell_1',
              ),
            ],
          ),
        ],
      );
      await repo.saveAccount(sourceAccount);
      await repo.saveAccount(destAccount);

      await repo.deleteTransaction('buy_1');

      final all = await repo.listAll();
      final reloadedSource = all.firstWhere((a) => a.id == sourceAccount.id);
      final reloadedDest = all.firstWhere((a) => a.id == destAccount.id);
      // La transaction ciblée a disparu du compte destination...
      expect(reloadedDest.investments.single.transactions, isEmpty);
      // ... mais le compte source (et sa propre transaction) n'a pas bougé —
      // `deleteTransaction` seule ne supprime qu'un id à la fois, la
      // suppression de la contrepartie reste à la charge de l'appelant (voir
      // les gestionnaires `_deleteTransaction` de `position_detail_dialog.dart`
      // et consorts).
      expect(reloadedSource.investments.single.transactions, hasLength(1));
    });

    test('ne fait rien si aucune transaction ne porte cet id', () async {
      final account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO',
        investments: [
          Investment(
            isin: 'FR0000131104',
            label: 'BNP Paribas',
            transactions: [
              Transaction(
                id: 'txn_1',
                date: DateTime(2026, 1, 1),
                isBuy: true,
                quantity: 5,
                unitPrice: 60,
              ),
            ],
          ),
        ],
      );
      await repo.saveAccount(account);

      await repo.deleteTransaction('does_not_exist');

      final reloaded = (await repo.listAll()).single;
      expect(reloaded.investments.single.transactions, hasLength(1));
    });
  });
}

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

  group('migration : documents immobilier compte -> bien', () {
    test(
      'un compte immobilier avec un seul bien migre ses documents de '
      'compte vers ce bien, une seule fois, en réécrivant le fichier',
      () async {
        final property = Investment(
          isin: 'immobilier-abc',
          label: 'Appartement Lyon 6e',
          transactions: const [],
          documents: [VaultDocument(fileName: 'plan.pdf', category: 'Plan')],
        );
        final account = InvestmentAccount(
          assetClass: AssetClass.immobilier,
          envelope: AccountEnvelope.autre,
          name: 'Locatif',
          investments: [property],
          documents: [VaultDocument(fileName: 'acte-vente.pdf')],
        );
        await repo.saveAccount(account);

        final reloaded = (await repo.listAll()).single;
        expect(reloaded.documents, isEmpty);
        expect(reloaded.investments.single.documents, hasLength(2));
        expect(
          reloaded.investments.single.documents.map((d) => d.fileName),
          containsAll(['plan.pdf', 'acte-vente.pdf']),
        );

        // La migration ne se reproduit pas (déjà vide au niveau compte) :
        // une seconde lecture ne duplique pas les documents.
        final rereadAgain = (await repo.listAll()).single;
        expect(rereadAgain.investments.single.documents, hasLength(2));
      },
    );

    test(
      'un compte immobilier avec plusieurs biens (ambigu : lequel des '
      'biens un document concerne-t-il ?) ne migre PAS ses documents, '
      'plutôt que de deviner à tort',
      () async {
        final account = InvestmentAccount(
          assetClass: AssetClass.immobilier,
          envelope: AccountEnvelope.autre,
          name: 'Plusieurs biens',
          investments: [
            Investment(
              isin: 'immobilier-a',
              label: 'Bien A',
              transactions: const [],
            ),
            Investment(
              isin: 'immobilier-b',
              label: 'Bien B',
              transactions: const [],
            ),
          ],
          documents: [VaultDocument(fileName: 'acte-vente.pdf')],
        );
        await repo.saveAccount(account);

        final reloaded = (await repo.listAll()).single;
        expect(reloaded.documents, hasLength(1));
        expect(reloaded.investments.every((i) => i.documents.isEmpty), isTrue);
      },
    );

    test('un compte non immobilier n\'est jamais concerné par cette '
        'migration', () async {
      final account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO',
        investments: [
          Investment(
            isin: 'FR0000131104',
            label: 'BNP Paribas',
            transactions: const [],
          ),
        ],
        documents: [VaultDocument(fileName: 'releve.pdf')],
      );
      await repo.saveAccount(account);

      final reloaded = (await repo.listAll()).single;
      expect(reloaded.documents, hasLength(1));
      expect(reloaded.investments.single.documents, isEmpty);
    });
  });
}

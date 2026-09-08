import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/transactions_export/transactions_export_data.dart';

void main() {
  test('aplatit les transactions de tous les investissements/comptes '
      'sélectionnés, triées par date croissante', () {
    final account = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO Bourso',
      bankName: 'Bourso',
      investments: [
        Investment(
          isin: 'US0378331005',
          label: 'Apple',
          transactions: [
            Transaction(
              id: 't2',
              date: DateTime(2025, 6, 1),
              isBuy: true,
              quantity: 5,
              unitPrice: 150,
            ),
            Transaction(
              id: 't1',
              date: DateTime(2025, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 100,
              type: TransactionType.other,
              note: 'Premier achat',
            ),
          ],
        ),
      ],
    );

    final rows = buildTransactionExportRows(
      [account],
      selectedAccountIds: {account.id},
    );

    expect(rows, hasLength(2));
    expect(rows.first.id, 't1'); // triée par date croissante
    expect(rows.first.accountName, 'CTO Bourso');
    expect(rows.first.investmentLabel, 'Apple');
    expect(rows.first.amountEur, 1000);
    expect(rows.first.type, 'Autre');
    expect(rows.first.note, 'Premier achat');
    expect(rows.first.linkedContext, isNull);
    expect(rows.last.id, 't2');
  });

  test('un compte non sélectionné n\'apparaît pas dans l\'export', () {
    final included = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      investments: [
        Investment(
          isin: 'US0378331005',
          label: 'Apple',
          transactions: [
            Transaction(date: DateTime(2025, 1, 1), isBuy: true, quantity: 1, unitPrice: 100),
          ],
        ),
      ],
    );
    final excluded = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.pea,
      name: 'PEA',
      investments: [
        Investment(
          isin: 'FR0000131104',
          label: 'BNP',
          transactions: [
            Transaction(date: DateTime(2025, 1, 1), isBuy: true, quantity: 1, unitPrice: 50),
          ],
        ),
      ],
    );

    final rows = buildTransactionExportRows(
      [included, excluded],
      selectedAccountIds: {included.id},
    );

    expect(rows, hasLength(1));
    expect(rows.single.accountName, 'CTO');
  });

  test(
    'un transfert entre deux comptes produit deux lignes, chacune avec le '
    'contexte de sa contrepartie résolu — même quand le compte de la '
    'contrepartie n\'est pas lui-même sélectionné pour l\'export',
    () {
      final source = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.pea,
        name: 'PEA Bourso',
        investments: [
          Investment(
            isin: 'US0378331005',
            label: 'Apple',
            transactions: [
              Transaction(
                id: 'sell1',
                date: DateTime(2025, 3, 1),
                isBuy: false,
                quantity: 10,
                unitPrice: 150,
                type: TransactionType.transfer,
                linkedTransactionId: 'buy1',
              ),
            ],
          ),
        ],
      );
      final destination = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO Bourso',
        investments: [
          Investment(
            isin: 'US0378331005',
            label: 'Apple',
            transactions: [
              Transaction(
                id: 'buy1',
                date: DateTime(2025, 3, 1),
                isBuy: true,
                quantity: 10,
                unitPrice: 150,
                type: TransactionType.transfer,
                linkedTransactionId: 'sell1',
              ),
            ],
          ),
        ],
      );

      // Seul le compte source est sélectionné : le contexte de la
      // contrepartie doit quand même se résoudre (l'index se construit sur
      // TOUS les comptes, pas seulement la sélection).
      final rows = buildTransactionExportRows(
        [source, destination],
        selectedAccountIds: {source.id},
      );

      expect(rows, hasLength(1));
      expect(rows.single.linkedContext, 'Vers CTO Bourso · Apple');

      final both = buildTransactionExportRows(
        [source, destination],
        selectedAccountIds: {source.id, destination.id},
      );
      final destinationRow = both.singleWhere((r) => r.id == 'buy1');
      expect(destinationRow.linkedContext, 'Depuis PEA Bourso · Apple');
    },
  );

  test('toJson expose les champs attendus, omet ceux non renseignés', () {
    final row = TransactionExportRow(
      id: 't1',
      date: DateTime.utc(2025, 1, 1),
      accountName: 'CTO',
      investmentLabel: 'Apple',
      isBuy: true,
      quantity: 10,
      unitPrice: 100,
      currency: 'EUR',
      fxRateToEur: 1,
      amountEur: 1000,
    );
    final json = row.toJson();
    expect(json['id'], 't1');
    expect(json['compte'], 'CTO');
    expect(json['sens'], 'achat');
    expect(json['montantEur'], 1000);
    expect(json.containsKey('type'), isFalse);
    expect(json.containsKey('note'), isFalse);
    expect(json.containsKey('lien'), isFalse);
  });
}

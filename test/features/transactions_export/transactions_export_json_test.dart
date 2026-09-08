import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/transactions_export/transactions_export_data.dart';
import 'package:opime/features/transactions_export/transactions_export_json.dart';

void main() {
  test('produit un tableau JSON indenté, un objet par ligne, redécodable', () {
    final rows = [
      TransactionExportRow(
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
      ),
    ];

    final json = buildTransactionsExportJson(rows);
    // Indenté (convention `JsonEncoder.withIndent('  ')` de tout le vault) :
    // au moins un retour à la ligne suivi de deux espaces.
    expect(json, contains('\n  '));

    final decoded = jsonDecode(json) as List<dynamic>;
    expect(decoded, hasLength(1));
    final entry = decoded.single as Map<String, dynamic>;
    expect(entry['id'], 't1');
    expect(entry['compte'], 'CTO');
    expect(entry['montantEur'], 1000);
  });

  test('liste vide produit un tableau JSON vide', () {
    expect(buildTransactionsExportJson(const []), '[]');
  });
}

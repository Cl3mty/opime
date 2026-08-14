import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/ibkr/ibkr_statement_parser.dart';

void main() {
  late String csv;

  setUpAll(() {
    csv = File(
      'test/fixtures/ibkr_activity_statement.csv',
    ).readAsStringSync();
  });

  test(
      'parses the standard Activity Statement format (section name + '
      'Header/Data rows, no ClientAccountID column)', () {
    final result = parseIbkrStatement(csv);
    // Même relevé que ibkr_sample_statement.csv, exporté sous l'autre
    // format : mêmes décomptes.
    expect(result.trades, hasLength(30));
    expect(result.cashConversions, hasLength(9));
    expect(result.cashFlows, hasLength(55));
    // La section "Financial Instrument Information" du fixture couvre tous
    // les titres tradés : aucun avertissement d'ISIN introuvable attendu.
    expect(
      result.warnings.where((w) => w.contains('ISIN introuvable')),
      isEmpty,
    );
  });

  test('resolves ISIN and description from Financial Instrument Information', () {
    final result = parseIbkrStatement(csv);
    final aaplFirstBuy = result.trades.firstWhere(
      (t) => t.symbol == 'AAPL' && t.date == DateTime(2023, 2, 13),
    );
    expect(aaplFirstBuy.isin, 'US0378331005');
    expect(aaplFirstBuy.description, 'APPLE INC');
    expect(aaplFirstBuy.isBuy, isTrue);
    expect(aaplFirstBuy.quantity, 1);
    expect(aaplFirstBuy.tradePrice, closeTo(153.099, 0.0001));
    // Pas de colonne Taxes dans ce format : Proceeds (-153.099) +
    // Comm/Fee (-1) doit suffire à reconstituer le même NetCash que le
    // relevé Flex Query pour ce même achat réel.
    expect(aaplFirstBuy.netCashImpact, closeTo(-154.099, 0.0001));
  });

  test('parses a Forex conversion row, commission already in EUR', () {
    final result = parseIbkrStatement(csv);
    final row = result.cashConversions.firstWhere(
      (c) => c.date == DateTime(2023, 2, 13),
    );
    expect(row.baseCurrency, 'EUR');
    expect(row.quoteCurrency, 'USD');
    expect(row.baseQuantity, -190);
    expect(row.commission, closeTo(-1.87312, 0.0001));
    // À la différence du relevé Flex Query, la commission de conversion est
    // ici facturée directement en euros, pas dans la devise de cotation.
    expect(row.commissionCurrency, 'EUR');
  });

  test('strips thousands-separator commas from Forex quantities', () {
    final result = parseIbkrStatement(csv);
    final row = result.cashConversions.firstWhere(
      (c) => c.date == DateTime(2023, 2, 23),
    );
    expect(row.baseQuantity, -3006);
  });

  test('extracts the symbol from the description for dividend rows', () {
    final result = parseIbkrStatement(csv);
    final dividend = result.cashFlows.firstWhere(
      (f) => f.rawType == 'Dividends' && f.date == DateTime(2024, 2, 7),
    );
    expect(dividend.symbol, 'UIMM');
    expect(dividend.amount, closeTo(0.7, 0.0001));
    expect(dividend.currency, 'USD');
  });

  test('excludes the aggregated Total/Total in EUR rows', () {
    final result = parseIbkrStatement(csv);
    expect(
      result.cashFlows.where((f) => f.rawType == 'Dividends'),
      hasLength(23),
    );
    expect(
      result.cashFlows.where((f) => f.rawType == 'Withholding Tax'),
      hasLength(28),
    );
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/ibkr/ibkr_statement_parser.dart';

void main() {
  late String csv;

  setUpAll(() {
    csv = File('test/fixtures/ibkr_sample_statement.csv').readAsStringSync();
  });

  test('parses both sections of an IBKR activity statement', () {
    final result = parseIbkrStatement(csv);
    expect(result.trades, hasLength(30));
    expect(result.cashConversions, hasLength(9));
    expect(result.cashFlows, hasLength(55));
    expect(result.warnings, isEmpty);
  });

  test('reads a STK trade row with its net cash impact', () {
    final result = parseIbkrStatement(csv);
    final aaplFirstBuy = result.trades.firstWhere(
      (t) => t.isin == 'US0378331005' && t.date == DateTime(2023, 2, 13),
    );
    expect(aaplFirstBuy.isBuy, isTrue);
    expect(aaplFirstBuy.quantity, 1);
    expect(aaplFirstBuy.tradePrice, closeTo(153.099, 0.0001));
    // Proceeds (-153.099) + IBCommission (-1) : reconstitue le NetCash
    // (-154.099) du relevé.
    expect(aaplFirstBuy.netCashImpact, closeTo(-154.099, 0.0001));
  });

  test('reads a SELL trade row', () {
    final result = parseIbkrStatement(csv);
    final uimmSell = result.trades.firstWhere(
      (t) => t.isin == 'LU0629459743' && t.date == DateTime(2024, 2, 1),
    );
    expect(uimmSell.isBuy, isFalse);
    expect(uimmSell.quantity, 1);
    expect(uimmSell.tradePrice, closeTo(135.12, 0.0001));
    expect(uimmSell.netCashImpact, closeTo(132.12, 0.0001));
  });

  test('reads a currency conversion row', () {
    final result = parseIbkrStatement(csv);
    final row = result.cashConversions.firstWhere(
      (c) => c.date == DateTime(2023, 2, 13),
    );
    expect(row.baseCurrency, 'EUR');
    expect(row.quoteCurrency, 'USD');
    expect(row.baseQuantity, -190);
    expect(row.commissionCurrency, 'USD');
    // Proceeds (203.528) + IBCommission (-1.87312), facturée en USD pour ce
    // format (voir IbkrCashConversionRow.commissionCurrency).
    expect(row.proceeds + row.commission, closeTo(201.65488, 0.0001));
  });

  test('reads a dividend row for an ETF paid in USD', () {
    final result = parseIbkrStatement(csv);
    final dividend = result.cashFlows.firstWhere(
      (f) => f.rawType == 'Dividends' && f.symbol == 'UIMM',
    );
    expect(dividend.amount, closeTo(0.7, 0.0001));
    expect(dividend.currency, 'USD');
  });

  test('reads a withholding tax row', () {
    final result = parseIbkrStatement(csv);
    final tax = result.cashFlows.firstWhere(
      (f) =>
          f.rawType == 'Withholding Tax' &&
          f.symbol == 'AAPL' &&
          f.date == DateTime(2023, 5, 18),
    );
    expect(tax.amount, closeTo(-0.07, 0.0001));
  });

  test('reads deposit rows without a symbol', () {
    final result = parseIbkrStatement(csv);
    final deposits = result.cashFlows.where(
      (f) => f.rawType == 'Deposits/Withdrawals',
    );
    expect(deposits, hasLength(2));
    expect(deposits.every((f) => f.amount > 0), isTrue);
    expect(deposits.every((f) => f.currency == 'EUR'), isTrue);
  });
}

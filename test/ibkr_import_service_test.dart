import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/ibkr/ibkr_import_service.dart';
import 'package:opime/features/investments/ibkr/ibkr_statement_parser.dart';
import 'package:opime/features/investments/investments_models.dart';

InvestmentAccount _emptyCto() => InvestmentAccount(
  assetClass: AssetClass.actionsEtFonds,
  envelope: AccountEnvelope.cto,
  name: 'Interactive Brokers',
  investments: const [],
);

void main() {
  late String csv;

  setUpAll(() {
    csv = File('test/fixtures/ibkr_sample_statement.csv').readAsStringSync();
  });

  test('builds an import plan matching the statement content', () {
    final parsed = parseIbkrStatement(csv);
    final plan = buildIbkrImportPlan(_emptyCto(), parsed);
    final summary = plan.summary;

    expect(summary.securityTradesAdded, 30);
    expect(summary.currencyConversionsAdded, 9);
    expect(summary.dividendsAdded, 23);
    expect(summary.withholdingTaxAdded, 28);
    expect(summary.feesAdded, 2);
    expect(summary.depositsAdded, 2);
    expect(summary.withdrawalsAdded, 0);
    expect(summary.otherFlowsAdded, 0);
    expect(summary.duplicatesSkipped, 0);
    expect(summary.periodStart, DateTime(2023, 2, 13));
    expect(summary.periodEnd, DateTime(2024, 2, 7));

    // 11 titres (ISIN distincts du relevé) + 2 positions de cash (EUR, USD).
    expect(plan.mergedAccount.investments, hasLength(13));
  });

  test('reconciles the USD and EUR cash balances with the raw CSV rows', () {
    final parsed = parseIbkrStatement(csv);
    final plan = buildIbkrImportPlan(_emptyCto(), parsed);

    // La commission (et les taxes) d'une conversion se déduisent du côté de
    // la paire porté par `commissionCurrency` — voir
    // IbkrCashConversionRow.commissionCurrency et son utilisation dans
    // ibkr_import_service.dart.
    double baseImpact(IbkrCashConversionRow c) =>
        c.baseQuantity +
        (c.commissionCurrency == c.baseCurrency ? c.commission + c.taxes : 0);
    double quoteImpact(IbkrCashConversionRow c) =>
        c.proceeds +
        (c.commissionCurrency == c.quoteCurrency ? c.commission + c.taxes : 0);

    final expectedUsd =
        parsed.trades
            .where((t) => t.currency == 'USD')
            .fold(0.0, (sum, t) => sum + t.netCashImpact) +
        parsed.cashConversions
            .where((c) => c.quoteCurrency == 'USD')
            .fold(0.0, (sum, c) => sum + quoteImpact(c)) +
        parsed.cashFlows
            .where((f) => f.currency == 'USD')
            .fold(0.0, (sum, f) => sum + f.amount);
    final usdPosition = plan.mergedAccount.investments.firstWhere(
      (i) => i.isin == 'USD',
    );
    expect(usdPosition.quantityHeld, closeTo(expectedUsd, 0.001));

    final expectedEur =
        parsed.trades
            .where((t) => t.currency == 'EUR')
            .fold(0.0, (sum, t) => sum + t.netCashImpact) +
        parsed.cashConversions.fold(0.0, (sum, c) => sum + baseImpact(c)) +
        parsed.cashFlows
            .where((f) => f.currency == 'EUR')
            .fold(0.0, (sum, f) => sum + f.amount);
    final eurPosition = plan.mergedAccount.investments.firstWhere(
      (i) => i.isin == 'EUR',
    );
    expect(eurPosition.quantityHeld, closeTo(expectedEur, 0.001));
  });

  test('AAPL position quantity matches its three buy trades', () {
    final parsed = parseIbkrStatement(csv);
    final plan = buildIbkrImportPlan(_emptyCto(), parsed);
    final aapl = plan.mergedAccount.investments.firstWhere(
      (i) => i.isin == 'US0378331005',
    );
    expect(aapl.quantityHeld, 3);
    expect(aapl.symbol, 'AAPL');
  });

  test('a dividend transaction carries its type and a readable note', () {
    final parsed = parseIbkrStatement(csv);
    final plan = buildIbkrImportPlan(_emptyCto(), parsed);
    final usd = plan.mergedAccount.investments.firstWhere(
      (i) => i.isin == 'USD',
    );
    final dividend = usd.transactions.firstWhere(
      (t) => t.type == TransactionType.dividend && t.note == 'Dividende UIMM',
    );
    expect(dividend.isBuy, isTrue);
    expect(dividend.displayLabel, 'Dividende');
  });

  test(
      'deduces a missing ISIN from an existing position with the same '
      'symbol (e.g. an Activity Statement import into an account already '
      'populated via ISIN)', () {
    final existingAapl = Investment(
      isin: 'US0378331005',
      label: 'Apple Inc',
      symbol: 'AAPL',
      transactions: const [],
    );
    final account = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      investments: [existingAapl],
    );
    final row = IbkrTradeRow(
      date: DateTime(2024, 3, 1),
      isin: '', // absent du relevé (Activity Statement sans correspondance
      // dans "Financial Instrument Information").
      symbol: 'AAPL',
      description: 'AAPL',
      isBuy: true,
      quantity: 1,
      tradePrice: 200,
      commission: -1,
      taxes: 0,
      proceeds: -200,
      currency: 'USD',
      rawLine: 'n/a',
    );
    final plan = buildIbkrImportPlan(
      account,
      IbkrParseResult(
        trades: [row],
        cashConversions: const [],
        cashFlows: const [],
        warnings: const [],
      ),
    );

    // Pas de doublon créé sous le symbole nu : la transaction rejoint la
    // position déjà connue par son ISIN.
    expect(
      plan.mergedAccount.investments.where((i) => i.symbol == 'AAPL'),
      hasLength(1),
    );
    final aapl = plan.mergedAccount.investments.firstWhere(
      (i) => i.isin == 'US0378331005',
    );
    expect(aapl.quantityHeld, 1);
    expect(
      plan.summary.warnings.where((w) => w.contains('ISIN introuvable')),
      isEmpty,
    );
  });

  test(
      'falls back to the bare symbol and warns when the ISIN cannot be '
      'resolved at all', () {
    final account = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      investments: const [],
    );
    final row = IbkrTradeRow(
      date: DateTime(2024, 3, 1),
      isin: '',
      symbol: 'NVDA',
      description: 'NVDA',
      isBuy: true,
      quantity: 1,
      tradePrice: 900,
      commission: -1,
      taxes: 0,
      proceeds: -900,
      currency: 'USD',
      rawLine: 'n/a',
    );
    final plan = buildIbkrImportPlan(
      account,
      IbkrParseResult(
        trades: [row],
        cashConversions: const [],
        cashFlows: const [],
        warnings: const [],
      ),
    );

    final nvda = plan.mergedAccount.investments.firstWhere(
      (i) => i.symbol == 'NVDA',
    );
    expect(nvda.isin, 'NVDA');
    expect(
      plan.summary.warnings.any(
        (w) => w.contains('ISIN introuvable pour "NVDA"'),
      ),
      isTrue,
    );
  });

  test('re-importing the same statement adds nothing new', () {
    final parsed = parseIbkrStatement(csv);
    final firstPlan = buildIbkrImportPlan(_emptyCto(), parsed);
    final secondPlan = buildIbkrImportPlan(firstPlan.mergedAccount, parsed);

    expect(secondPlan.summary.totalTransactionsAdded, 0);
    expect(secondPlan.summary.duplicatesSkipped, greaterThan(0));

    final firstCounts = {
      for (final i in firstPlan.mergedAccount.investments)
        i.isin: i.transactions.length,
    };
    final secondCounts = {
      for (final i in secondPlan.mergedAccount.investments)
        i.isin: i.transactions.length,
    };
    expect(secondCounts, firstCounts);
  });
}

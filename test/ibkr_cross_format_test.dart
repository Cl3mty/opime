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
  late String flexQueryCsv;
  late String activityStatementCsv;

  setUpAll(() {
    flexQueryCsv = File(
      'test/fixtures/ibkr_sample_statement.csv',
    ).readAsStringSync();
    activityStatementCsv = File(
      'test/fixtures/ibkr_activity_statement.csv',
    ).readAsStringSync();
  });

  test(
      'the Flex Query and Activity Statement exports of the same account '
      'produce the same positions', () {
    final flexPlan = buildIbkrImportPlan(
      _emptyCto(),
      parseIbkrStatement(flexQueryCsv),
    );
    final activityPlan = buildIbkrImportPlan(
      _emptyCto(),
      parseIbkrStatement(activityStatementCsv),
    );

    expect(
      activityPlan.summary.securityTradesAdded,
      flexPlan.summary.securityTradesAdded,
    );
    expect(activityPlan.summary.dividendsAdded, flexPlan.summary.dividendsAdded);
    expect(
      activityPlan.summary.withholdingTaxAdded,
      flexPlan.summary.withholdingTaxAdded,
    );
    expect(activityPlan.summary.feesAdded, flexPlan.summary.feesAdded);
    expect(activityPlan.summary.depositsAdded, flexPlan.summary.depositsAdded);

    // Même quantité détenue par titre, quel que soit le format d'origine —
    // l'ISIN résolu depuis "Financial Instrument Information" doit
    // correspondre à celui du relevé Flex Query pour que les deux
    // s'alignent sur la même clé de position.
    for (final isin in [
      'US0378331005', // AAPL
      'US5949181045', // MSFT
      'US0231351067', // AMZN
      'US02079K1079', // GOOG
      'US1912161007', // KO
      'US3137451015', // FRT
      'US7134481081', // PEP
    ]) {
      final flexQty = flexPlan.mergedAccount.investments
          .firstWhere((i) => i.isin == isin)
          .quantityHeld;
      final activityQty = activityPlan.mergedAccount.investments
          .firstWhere((i) => i.isin == isin)
          .quantityHeld;
      expect(activityQty, closeTo(flexQty, 1e-9), reason: isin);
    }
  });

  test(
      're-importing the Activity Statement export a second time adds '
      'nothing new (same idempotence guarantee as the Flex Query format)',
      () {
    final parsed = parseIbkrStatement(activityStatementCsv);
    final firstPlan = buildIbkrImportPlan(_emptyCto(), parsed);
    final secondPlan = buildIbkrImportPlan(firstPlan.mergedAccount, parsed);

    expect(secondPlan.summary.totalTransactionsAdded, 0);
    expect(secondPlan.summary.duplicatesSkipped, greaterThan(0));
  });
}

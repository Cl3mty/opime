import 'dart:convert';

import 'transactions_export_data.dart';

/// Sérialise [rows] en JSON — même convention que tous les repositories du
/// vault (`JsonEncoder.withIndent('  ')`, voir `investments_repository.dart`).
String buildTransactionsExportJson(List<TransactionExportRow> rows) {
  return const JsonEncoder.withIndent(
    '  ',
  ).convert([for (final row in rows) row.toJson()]);
}

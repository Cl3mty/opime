import 'package:csv/csv.dart';

import 'transactions_export_data.dart';

const _headers = [
  'Date',
  'Compte',
  'Investissement',
  'Sens',
  'Quantité',
  'Prix unitaire',
  'Devise',
  'Taux de change',
  'Montant (€)',
  'Type',
  'Note',
  'Lien',
];

/// Sérialise [rows] en CSV — date au format ISO (YYYY-MM-DD, triable et
/// sans ambiguïté régionale, contrairement au JJ/MM/AAAA affiché ailleurs
/// dans l'app) : premier usage d'écriture CSV de l'app (`csv` n'était
/// jusqu'ici utilisé qu'en lecture, voir `real_estate_pricing/`).
String buildTransactionsExportCsv(List<TransactionExportRow> rows) {
  final table = [
    _headers,
    for (final row in rows)
      [
        _isoDate(row.date),
        row.accountName,
        row.investmentLabel,
        row.isBuy ? 'Achat' : 'Vente',
        row.quantity,
        row.unitPrice,
        row.currency,
        row.fxRateToEur,
        row.amountEur,
        row.type ?? '',
        row.note ?? '',
        row.linkedContext ?? '',
      ],
  ];
  return const CsvEncoder().convert(table);
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

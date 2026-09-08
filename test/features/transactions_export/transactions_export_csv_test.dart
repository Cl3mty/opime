import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/transactions_export/transactions_export_csv.dart';
import 'package:opime/features/transactions_export/transactions_export_data.dart';

/// Décode avec [CsvRow] (accès par nom de colonne) et types numériques
/// reconstruits — mêmes options que la lecture déjà pratiquée ailleurs dans
/// l'app (`geo_dvf_client.dart`), plus `dynamicTyping` pour un round-trip
/// fidèle des montants/quantités.
List<CsvRow> _decode(String csv) =>
    const CsvDecoder(parseHeaders: true, dynamicTyping: true)
        .convert(csv)
        .cast<CsvRow>();

void main() {
  test('produit un CSV redécodable avec les colonnes attendues, dans le '
      'bon ordre', () {
    final rows = [
      TransactionExportRow(
        id: 't1',
        date: DateTime.utc(2025, 3, 7),
        accountName: 'CTO Bourso',
        investmentLabel: 'Apple',
        isBuy: true,
        quantity: 10,
        unitPrice: 150,
        currency: 'USD',
        fxRateToEur: 0.92,
        amountEur: 1380,
        type: 'Transfert',
        note: 'Un commentaire, avec une virgule',
        linkedContext: 'Depuis PEA Bourso · Apple',
      ),
    ];

    final decoded = _decode(buildTransactionsExportCsv(rows));

    expect(decoded, hasLength(1));
    final row = decoded.single;
    expect(
      row.headerMap.keys.toList(),
      [
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
      ],
    );
    expect(row['Date'], '2025-03-07');
    expect(row['Compte'], 'CTO Bourso');
    expect(row['Investissement'], 'Apple');
    expect(row['Sens'], 'Achat');
    expect(row['Quantité'], 10);
    expect(row['Devise'], 'USD');
    expect(row['Montant (€)'], 1380);
    expect(row['Type'], 'Transfert');
    // La virgule dans la note ne casse pas le découpage des colonnes (le
    // champ doit avoir été mis entre guillemets par l'encodeur).
    expect(row['Note'], 'Un commentaire, avec une virgule');
    expect(row['Lien'], 'Depuis PEA Bourso · Apple');
  });

  test('une ligne sans type/note/lien laisse ces colonnes vides, sans '
      'planter', () {
    final rows = [
      TransactionExportRow(
        id: 't1',
        date: DateTime.utc(2025, 1, 1),
        accountName: 'CTO',
        investmentLabel: 'Apple',
        isBuy: false,
        quantity: 1,
        unitPrice: 100,
        currency: 'EUR',
        fxRateToEur: 1,
        amountEur: 100,
      ),
    ];

    final row = _decode(buildTransactionsExportCsv(rows)).single;
    expect(row['Sens'], 'Vente');
    expect(row['Type'], '');
    expect(row['Note'], '');
    expect(row['Lien'], '');
  });

  test('liste vide produit seulement la ligne d\'en-tête', () {
    final csv = buildTransactionsExportCsv(const []);
    expect(
      const CsvDecoder().convert(csv),
      [
        [
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
        ],
      ],
    );
  });
}

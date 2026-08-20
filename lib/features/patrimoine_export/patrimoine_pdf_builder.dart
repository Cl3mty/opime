/// Construit le document PDF de l'export patrimoine (voir
/// `patrimoine_export_data.dart` pour la couche de données) — tabulaire
/// uniquement (pas de graphique), pensé pour être présentable en entretien
/// bancaire : synthèse, une table par catégorie d'actif retenue, une table
/// des passifs retenus. Aucune dépendance à `BuildContext`/Flutter widgets.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/money_format.dart';
import '../liabilities/liabilities_models.dart' show formatFrenchDate;
import 'patrimoine_export_data.dart';

/// Police embarquée pour le PDF : les polices de base (Helvetica...) ne
/// couvrent pas le symbole "€" ni les accents français (voir
/// https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management) — Roboto (police
/// variable, une seule instance embarquée) couvre les deux, chargée depuis
/// les assets de l'app plutôt que téléchargée à la volée (app locale, sans
/// dépendance réseau pour une fonctionnalité aussi basique que du texte).
Future<pw.Font> _loadFont() async {
  final bytes = await rootBundle.load('assets/fonts/Roboto-Variable.ttf');
  return pw.Font.ttf(bytes);
}

/// Construit les octets du PDF prêts à être écrits sur disque.
Future<Uint8List> buildPatrimoinePdfBytes(PatrimoineExportData data) async {
  final font = await _loadFont();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => _buildHeader(data),
      footer: (context) => _buildFooter(context),
      build: (context) => [
        _buildSummary(data),
        pw.SizedBox(height: 20),
        for (final category in data.assetCategories) ...[
          _buildAssetCategoryTable(category),
          pw.SizedBox(height: 16),
        ],
        if (data.liabilities.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _buildLiabilitiesTable(data.liabilities, data.totalPassifs),
        ],
      ],
    ),
  );

  return doc.save();
}

pw.Widget _buildHeader(PatrimoineExportData data) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Situation patrimoniale — ${data.profileName}',
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'Établie le ${formatFrenchDate(data.generatedAt)}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 12),
      pw.Divider(thickness: 1, color: PdfColors.grey400),
      pw.SizedBox(height: 8),
    ],
  );
}

pw.Widget _buildFooter(pw.Context context) {
  return pw.Column(
    children: [
      pw.Divider(thickness: 0.5, color: PdfColors.grey400),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Généré par Opime',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _buildSummary(PatrimoineExportData data) {
  return pw.Row(
    children: [
      _summaryBox('Total actifs', data.totalActifs, PdfColors.green700),
      pw.SizedBox(width: 12),
      _summaryBox('Total passifs', data.totalPassifs, PdfColors.red700),
      pw.SizedBox(width: 12),
      _summaryBox('Patrimoine net', data.patrimoineNet, PdfColors.blue800),
    ],
  );
}

pw.Widget _summaryBox(String label, double value, PdfColor accent) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            formatEuros(value),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Une catégorie, groupée établissement → compte → lignes (voir
/// `patrimoine_export_data.dart`) : une table par compte plutôt qu'une
/// table unique pour toute la catégorie, pour une séparation franche entre
/// établissements/comptes — le nom du compte porteur n'est plus recopié en
/// sous-titre de chaque ligne d'investissement.
pw.Widget _buildAssetCategoryTable(PatrimoineExportCategory category) {
  final showsQuantite = category.allRows.any((r) => r.quantite != null);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        category.label,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      for (final establishment in category.establishments)
        _buildEstablishmentGroup(establishment, showsQuantite, category.showsPruColumn),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sous-total : ${formatEuros(category.total)}',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  );
}

pw.Widget _buildEstablishmentGroup(
  PatrimoineExportEstablishmentGroup establishment,
  bool showsQuantite,
  bool showsPruColumn,
) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (establishment.showEstablishmentHeader) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 4,
            ),
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            child: pw.Text(
              establishment.establishmentName,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
        ],
        for (final account in establishment.accounts)
          pw.Padding(
            padding: pw.EdgeInsets.only(
              left: establishment.showEstablishmentHeader ? 10 : 0,
              bottom: 8,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (account.showAccountHeader) ...[
                  pw.Text(
                    account.accountName,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                ],
                _buildAccountTable(account, showsQuantite, showsPruColumn),
              ],
            ),
          ),
      ],
    ),
  );
}

pw.Widget _buildAccountTable(
  PatrimoineExportAccountGroup account,
  bool showsQuantite,
  bool showsPruColumn,
) {
  final headers = [
    'Nom',
    if (showsQuantite) 'Quantité',
    'Valeur',
    if (showsPruColumn) 'PRU',
    'Plus-value',
  ];
  final rows = [
    for (final row in account.rows)
      [
        row.subtitle == null ? row.label : '${row.label}\n${row.subtitle}',
        if (showsQuantite) row.quantite?.toStringAsFixed(2) ?? '—',
        formatEuros(row.valeur),
        if (showsPruColumn) row.pru?.toStringAsFixed(2) ?? '—',
        '${formatSignedEuros(row.plusValueAbs)} (${displayPercent(row.plusValuePercent)})',
      ],
  ];

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    cellAlignments: {
      0: pw.Alignment.centerLeft,
      for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight,
    },
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
  );
}

pw.Widget _buildLiabilitiesTable(
  List<LiabilityExportRow> liabilities,
  double totalPassifs,
) {
  const headers = ['Nom', 'Type', 'Capital restant dû', 'Mensualité', 'Taux'];
  final rows = [
    for (final liability in liabilities)
      [
        liability.name,
        liability.typeLabel,
        formatEuros(liability.capitalRestantDu),
        formatEuros(liability.mensualite),
        '${liability.tauxInteret.toStringAsFixed(2)} %',
      ],
  ];

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Passifs',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      ),
      pw.SizedBox(height: 4),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Total : ${formatEuros(totalPassifs)}',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  );
}

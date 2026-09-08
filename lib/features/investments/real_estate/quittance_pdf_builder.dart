/// Construit le PDF d'une quittance de loyer pour une [RentPeriod] payée —
/// même stack que `patrimoine_pdf_builder.dart` (package `pdf`, police
/// Roboto embarquée pour le symbole "€" et les accents français). Aucune
/// dépendance à `BuildContext`/Flutter widgets.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/date_format.dart';
import '../../../core/money_format.dart';
import 'rent_models.dart';

Future<pw.Font> _loadFont() async {
  final bytes = await rootBundle.load('assets/fonts/Roboto-Variable.ttf');
  return pw.Font.ttf(bytes);
}

/// [propertyAddress] `null` retombe sur [propertyLabel] seul (un bien sans
/// adresse enregistrée — voir `Investment.addressLabel`, renseignée
/// seulement après une première "Réestimation"). [landlordName] est le nom
/// du profil actif (voir `ProfileController`), faute d'un champ dédié
/// "bailleur" sur le bien. [generatedAt] sert de repli pour la date de
/// signature quand [RentPeriod.paidAt] est absent (ne devrait pas arriver :
/// cette fonction n'est appelée que pour une période marquée payée, voir
/// `RentPeriodsSection`'s bouton "Télécharger la quittance").
Future<Uint8List> buildQuittancePdfBytes({
  required RentPeriod period,
  required String propertyLabel,
  String? propertyAddress,
  required String landlordName,
  required DateTime generatedAt,
}) async {
  final font = await _loadFont();
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: font));
  final amount = period.amountPaid ?? period.amountDue;
  final tenantName = period.tenantName?.trim().isNotEmpty == true
      ? period.tenantName!.trim()
      : 'le locataire';
  final signedAt = period.paidAt ?? generatedAt;
  final propertyLine = propertyAddress == null
      ? propertyLabel
      : '$propertyLabel — $propertyAddress';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'QUITTANCE DE LOYER',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Période du ${frenchMonths[period.periodStart.month - 1]} '
            '${period.periodStart.year}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 24),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 16),
          _infoRow('Bailleur', landlordName),
          pw.SizedBox(height: 6),
          _infoRow('Locataire', period.tenantName ?? 'Non renseigné'),
          pw.SizedBox(height: 6),
          _infoRow('Bien loué', propertyLine),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Montant reçu',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  formatEuros(amount),
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Je soussigné(e) $landlordName, propriétaire du logement '
            'désigné ci-dessus, déclare avoir reçu de $tenantName la '
            'somme de ${formatEuros(amount)} au titre du paiement du '
            'loyer et des charges pour la période du '
            '${formatDateFrLong(period.periodStart)} au '
            '${formatDateFrLong(period.periodEnd)}, et lui en donne '
            'quittance, sous réserve de tous mes droits.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Cette quittance annule tous les reçus qui auraient pu être '
            'établis précédemment en cas de paiement partiel du loyer '
            'ci-dessus mentionné.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 40),
          pw.Text(
            'Fait le ${formatDateFrLong(signedAt)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

pw.Widget _infoRow(String label, String value) => pw.Row(
  children: [
    pw.SizedBox(
      width: 90,
      child: pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
    ),
    pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
  ],
);

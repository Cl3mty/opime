import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// Longueur maximale (en caractères) du texte extrait conservé par document
/// joint à l'assistant — au-delà, le texte est tronqué avant d'être inséré
/// dans le contexte envoyé au modèle local (fenêtre de contexte bornée à
/// 8192 tokens, voir `OllamaClient.streamChat`).
const maxAttachedDocumentChars = 6000;

/// Extensions de fichier prises en charge pour l'extraction de texte.
const supportedDocumentExtensions = ['pdf', 'txt', 'md'];

/// Erreur explicite plutôt qu'un texte vide silencieux : un texte vide en
/// sortie d'extraction serait indiscernable d'un document réellement vide,
/// alors qu'il s'agit le plus souvent d'un PDF scanné sans couche texte —
/// non pris en charge, l'OCR n'étant pas implémenté.
class DocumentExtractionException implements Exception {
  final String message;
  DocumentExtractionException(this.message);
  @override
  String toString() => message;
}

/// Texte extrait d'un document joint, éventuellement tronqué pour respecter
/// [maxAttachedDocumentChars].
class ExtractedDocumentText {
  final String text;
  final bool truncated;
  const ExtractedDocumentText({required this.text, required this.truncated});
}

/// Extrait le texte d'un fichier joint à l'assistant IA (PDF avec couche
/// texte, .txt, .md). Lève [DocumentExtractionException] pour un format non
/// pris en charge, un fichier vide, ou un PDF sans texte sélectionnable
/// (scan/image).
Future<ExtractedDocumentText> extractDocumentText({
  required Uint8List bytes,
  required String fileName,
}) async {
  final ext = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  final String text;
  switch (ext) {
    case 'txt':
    case 'md':
      final decoded = utf8.decode(bytes, allowMalformed: true).trim();
      if (decoded.isEmpty) {
        throw DocumentExtractionException('« $fileName » est vide.');
      }
      text = decoded;
    case 'pdf':
      text = await _extractPdfText(bytes, fileName);
    default:
      throw DocumentExtractionException(
        'Format non pris en charge ($ext). Formats acceptés : '
        '${supportedDocumentExtensions.join(', ')}.',
      );
  }

  if (text.length <= maxAttachedDocumentChars) {
    return ExtractedDocumentText(text: text, truncated: false);
  }
  return ExtractedDocumentText(
    text: text.substring(0, maxAttachedDocumentChars),
    truncated: true,
  );
}

Future<String> _extractPdfText(Uint8List bytes, String fileName) async {
  await pdfrxFlutterInitialize();
  final document = await PdfDocument.openData(bytes, sourceName: fileName);
  try {
    final buffer = StringBuffer();
    for (final page in document.pages) {
      final raw = await page.loadText();
      final pageText = raw?.fullText.trim() ?? '';
      if (pageText.isNotEmpty) buffer.writeln(pageText);
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) {
      throw DocumentExtractionException(
        '« $fileName » ne contient pas de texte sélectionnable : c\'est '
        'probablement un scan ou une image, non pris en charge pour '
        'l\'instant.',
      );
    }
    return text;
  } finally {
    await document.dispose();
  }
}

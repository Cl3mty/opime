import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/assistant/document_text_extractor.dart';

// Le PDF (pdfrx/pdfium natif) n'est volontairement pas couvert ici :
// pdfium doit être chargé depuis le binaire natif que la chaîne de build de
// l'app embarque pour chaque plateforme (macOS/Windows/Linux) — `flutter
// test` exécute sur l'hôte sans passer par cette chaîne de build, donc
// `PdfDocument.openData` échoue systématiquement dans ce harnais avec
// « Tried to load the default PDFium module but it failed », quel que soit
// le contenu du PDF. Cette branche s'appuie sur l'API documentée de pdfrx
// (`PdfDocument.openData`, `PdfPage.loadText`) sans logique supplémentaire
// à couvrir ; les cas de texte brut ci-dessous couvrent le reste du
// contrat de `extractDocumentText` (troncature, erreurs, formats).

void main() {
  group('extractDocumentText — texte brut (.txt/.md)', () {
    test('décode un fichier texte tel quel', () async {
      final bytes = Uint8List.fromList(utf8.encode('Frais annuels : 1,2 %.'));
      final result = await extractDocumentText(
        bytes: bytes,
        fileName: 'notes.txt',
      );
      expect(result.text, 'Frais annuels : 1,2 %.');
      expect(result.truncated, isFalse);
    });

    test('.md est traité comme du texte brut', () async {
      final bytes = Uint8List.fromList(utf8.encode('# Contrat\nFrais : 2 %'));
      final result = await extractDocumentText(
        bytes: bytes,
        fileName: 'contrat.md',
      );
      expect(result.text, contains('Frais : 2 %'));
    });

    test('fichier texte vide : lève une erreur explicite', () async {
      final bytes = Uint8List.fromList(utf8.encode('   \n  '));
      expect(
        () => extractDocumentText(bytes: bytes, fileName: 'vide.txt'),
        throwsA(isA<DocumentExtractionException>()),
      );
    });

    test(
      'texte plus long que la limite : tronqué avec truncated=true',
      () async {
        final longText = 'a' * (maxAttachedDocumentChars + 500);
        final bytes = Uint8List.fromList(utf8.encode(longText));
        final result = await extractDocumentText(
          bytes: bytes,
          fileName: 'long.txt',
        );
        expect(result.text.length, maxAttachedDocumentChars);
        expect(result.truncated, isTrue);
      },
    );
  });

  test('format non pris en charge : lève une erreur explicite', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(
      () => extractDocumentText(bytes: bytes, fileName: 'image.png'),
      throwsA(isA<DocumentExtractionException>()),
    );
  });
}

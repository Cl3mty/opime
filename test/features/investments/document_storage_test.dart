import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_crypto.dart';
import 'package:opime/features/investments/document_storage.dart';
import 'package:opime/features/investments/investments_models.dart';

void main() {
  late Directory vaultDir;

  setUp(() async {
    vaultDir = await Directory.systemTemp.createTemp('opime_document_storage_test');
  });

  tearDown(() async {
    if (await vaultDir.exists()) await vaultDir.delete(recursive: true);
  });

  group('materializeForExternalOpen', () {
    test('vault en clair : le fichier temporaire a le même contenu', () async {
      final storage = DocumentStorage(vaultDir.path);
      final document = VaultDocument(fileName: 'facture.png');
      final originalBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      await storage.save(document, originalBytes);

      final file = await storage.materializeForExternalOpen(document);

      expect(await file.readAsBytes(), originalBytes);
      expect(file.path.endsWith('facture.png'), isTrue);
    });

    test(
      'vault chiffré : le fichier temporaire est déchiffré, pas une copie '
      'brute des octets chiffrés (le bug corrigé — voir documents_section.dart)',
      () async {
        final cipher = VaultCipher(generateDek());
        final storage = DocumentStorage(vaultDir.path, cipher: cipher);
        final document = VaultDocument(fileName: 'scelle.pdf');
        final originalBytes = Uint8List.fromList([9, 8, 7, 6, 5, 4, 3]);
        await storage.save(document, originalBytes);

        // Le fichier source, lui, est bien chiffré sur disque.
        final sourceBytes = await storage.fileFor(document).readAsBytes();
        expect(sourceBytes, isNot(originalBytes));

        final file = await storage.materializeForExternalOpen(document);

        expect(await file.readAsBytes(), originalBytes);
      },
    );

    test('un nouvel appel produit un nouveau fichier (pas de cache périmé)', () async {
      final storage = DocumentStorage(vaultDir.path);
      final document = VaultDocument(fileName: 'note.txt');
      await storage.save(document, Uint8List.fromList([1]));

      final first = await storage.materializeForExternalOpen(document);
      await storage.save(document, Uint8List.fromList([2]));
      final second = await storage.materializeForExternalOpen(document);

      expect(first.path, isNot(second.path));
      expect(await second.readAsBytes(), Uint8List.fromList([2]));
    });
  });
}

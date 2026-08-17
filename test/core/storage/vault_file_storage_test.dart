import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_crypto.dart';
import 'package:opime/core/storage/vault_file_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vaultDir;

  setUp(() async {
    vaultDir = await Directory.systemTemp.createTemp('opime_vault_storage_');
  });

  tearDown(() async {
    if (await vaultDir.exists()) await vaultDir.delete(recursive: true);
  });

  group('mode clair (cipher == null)', () {
    late VaultFileStorage storage;

    setUp(() {
      storage = VaultFileStorage(vaultPath: vaultDir.path);
    });

    test('exists renvoie false pour un fichier absent', () async {
      expect(await storage.exists('budget/budget_history.json'), isFalse);
    });

    test('aller-retour readString/writeString', () async {
      await storage.writeString('budget/budget_history.json', '[{"id":1}]');
      expect(
        await storage.readString('budget/budget_history.json'),
        '[{"id":1}]',
      );
    });

    test('writeString crée le dossier parent manquant', () async {
      await storage.writeString('nested/deep/file.json', 'content');
      expect(
        await File(p.join(vaultDir.path, 'nested/deep/file.json')).exists(),
        isTrue,
      );
    });

    test(
      'les octets sur disque sont le texte clair tel quel (aucun chiffrement)',
      () async {
        await storage.writeString('note.md', 'texte en clair');
        final onDisk = await File(
          p.join(vaultDir.path, 'note.md'),
        ).readAsString();
        expect(onDisk, 'texte en clair');
      },
    );

    test('aller-retour readBytes/writeBytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      await storage.writeBytes('doc.bin', bytes);
      expect(await storage.readBytes('doc.bin'), bytes);
    });

    test('delete supprime le fichier', () async {
      await storage.writeString('a.json', '{}');
      await storage.delete('a.json');
      expect(await storage.exists('a.json'), isFalse);
    });

    test('delete sur un fichier absent ne lève pas d\'exception', () async {
      await storage.delete('absent.json');
    });
  });

  group('mode chiffré (cipher non nul)', () {
    late VaultFileStorage storage;

    setUp(() {
      storage = VaultFileStorage(
        vaultPath: vaultDir.path,
        cipher: VaultCipher(generateDek()),
      );
    });

    test(
      'aller-retour readString/writeString restitue le texte clair',
      () async {
        await storage.writeString(
          'investissements/comptes.json',
          '[{"montant": 1234.56}]',
        );
        expect(
          await storage.readString('investissements/comptes.json'),
          '[{"montant": 1234.56}]',
        );
      },
    );

    test('les octets sur disque ne sont PAS le texte clair', () async {
      const plain = '{"secret": "12345"}';
      await storage.writeString('a.json', plain);
      final onDisk = await File(p.join(vaultDir.path, 'a.json')).readAsBytes();
      expect(utf8.decode(onDisk, allowMalformed: true), isNot(plain));
      // Le fichier chiffré n'est même pas un JSON valide.
      expect(
        () => jsonDecode(utf8.decode(onDisk, allowMalformed: true)),
        throwsFormatException,
      );
    });

    test('aller-retour readBytes/writeBytes (document binaire)', () async {
      final bytes = Uint8List.fromList(List.generate(50, (i) => i));
      await storage.writeBytes('investissements/documents/doc1.pdf', bytes);
      expect(
        await storage.readBytes('investissements/documents/doc1.pdf'),
        bytes,
      );
    });

    test(
      'deux écritures successives du même contenu produisent des octets différents sur disque (nonce distinct)',
      () async {
        await storage.writeString('a.json', 'même contenu');
        final first = await File(p.join(vaultDir.path, 'a.json')).readAsBytes();
        await storage.writeString('a.json', 'même contenu');
        final second = await File(
          p.join(vaultDir.path, 'a.json'),
        ).readAsBytes();
        expect(first, isNot(second));
      },
    );

    test('déchiffrer avec la mauvaise clé échoue', () async {
      await storage.writeString('a.json', 'contenu');
      final wrongStorage = VaultFileStorage(
        vaultPath: vaultDir.path,
        cipher: VaultCipher(generateDek()),
      );
      expect(() => wrongStorage.readString('a.json'), throwsA(anything));
    });
  });
}

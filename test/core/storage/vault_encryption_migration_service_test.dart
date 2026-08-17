import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_crypto.dart';
import 'package:opime/core/storage/vault_encryption_migration_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vaultDir;
  const service = VaultEncryptionMigrationService();

  setUp(() async {
    vaultDir = await Directory.systemTemp.createTemp('opime_migration_test_');

    Future<void> write(String relativePath, String content) async {
      final file = File(p.join(vaultDir.path, relativePath));
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }

    await write(
      'profiles.json',
      jsonEncode([
        {
          'id': 'master',
          'name': 'Moi',
          'relationship': 'Vous',
          'isMaster': true,
          'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        },
      ]),
    );
    await write(
      'profiles/master/budget/budget_history.json',
      '[{"id":"a","montant":1234.56}]',
    );
    await write(
      'profiles/master/investissements/comptes.json',
      '[{"nom":"CTO"}]',
    );
    await write('profiles/master/simulations/loan.json', '{"taux":3.5}');
    // Fichiers de cache/miroir qui ne doivent JAMAIS être touchés.
    await write(
      'profiles/master/simulations/department_boundaries.json',
      '{"public":true}',
    );
    await write(
      'profiles/master/investissements/logos_banques/boursorama.png',
      'pas vraiment un png',
    );
    await write(
      'profiles/master/investissements/metaux_precieux/or/2026-01-01/transaction.json',
      '{"miroir":true}',
    );
  });

  tearDown(() async {
    if (await vaultDir.exists()) await vaultDir.delete(recursive: true);
  });

  Future<String> read(String relativePath) =>
      File(p.join(vaultDir.path, relativePath)).readAsString();

  test(
    'encryptInPlace chiffre les fichiers privés, laisse les caches intacts',
    () async {
      final cipher = VaultCipher(generateDek());
      final progress = <(int, int)>[];

      await service.encryptInPlace(
        vaultPath: vaultDir.path,
        cipher: cipher,
        onProgress: (done, total) => progress.add((done, total)),
      );

      // Les fichiers privés ne sont plus lisibles en clair sur disque.
      for (final relativePath in [
        'profiles.json',
        'profiles/master/budget/budget_history.json',
        'profiles/master/investissements/comptes.json',
        'profiles/master/simulations/loan.json',
      ]) {
        final onDisk = await File(
          p.join(vaultDir.path, relativePath),
        ).readAsBytes();
        expect(
          () => jsonDecode(utf8.decode(onDisk, allowMalformed: true)),
          throwsFormatException,
          reason: '$relativePath devrait être chiffré (illisible en JSON)',
        );
      }

      // Les caches/miroir restent en clair, strictement inchangés.
      expect(
        await read('profiles/master/simulations/department_boundaries.json'),
        '{"public":true}',
      );
      expect(
        await read(
          'profiles/master/investissements/logos_banques/boursorama.png',
        ),
        'pas vraiment un png',
      );
      expect(
        await read(
          'profiles/master/investissements/metaux_precieux/or/2026-01-01/transaction.json',
        ),
        '{"miroir":true}',
      );

      // Progression cohérente : se termine à total/total.
      expect(progress, isNotEmpty);
      expect(progress.last.$1, progress.last.$2);
    },
  );

  test(
    'decryptInPlace après encryptInPlace restitue le contenu original',
    () async {
      final cipher = VaultCipher(generateDek());
      final originalBudget = await read(
        'profiles/master/budget/budget_history.json',
      );
      final originalComptes = await read(
        'profiles/master/investissements/comptes.json',
      );

      await service.encryptInPlace(vaultPath: vaultDir.path, cipher: cipher);
      await service.decryptInPlace(vaultPath: vaultDir.path, cipher: cipher);

      expect(
        await read('profiles/master/budget/budget_history.json'),
        originalBudget,
      );
      expect(
        await read('profiles/master/investissements/comptes.json'),
        originalComptes,
      );
      // Toujours intacts après les deux passes.
      expect(
        await read('profiles/master/simulations/department_boundaries.json'),
        '{"public":true}',
      );
    },
  );

  test('un vault sans aucun fichier privé ne fait rien (0/0)', () async {
    final emptyVault = await Directory.systemTemp.createTemp(
      'opime_migration_empty_',
    );
    addTearDown(() => emptyVault.delete(recursive: true));

    final progress = <(int, int)>[];
    await service.encryptInPlace(
      vaultPath: emptyVault.path,
      cipher: VaultCipher(generateDek()),
      onProgress: (done, total) => progress.add((done, total)),
    );

    expect(progress, [(0, 0)]);
  });
}

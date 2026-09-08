import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_encryption_metadata.dart';
import 'package:opime/core/storage/vault_encryption_repository.dart';

void main() {
  late Directory vaultDir;

  setUp(() async {
    vaultDir = await Directory.systemTemp.createTemp('opime_vault_enc_repo_');
  });

  tearDown(() async {
    if (await vaultDir.exists()) await vaultDir.delete(recursive: true);
  });

  test('load sans fichier existant renvoie null', () async {
    final repo = VaultEncryptionRepository(vaultDir.path);
    expect(await repo.load(), isNull);
  });

  test('save puis load restitue des métadonnées équivalentes', () async {
    final repo = VaultEncryptionRepository(vaultDir.path);
    final metadata = VaultEncryptionMetadata.create(
      password: 'password',
      recoveryKey: 'RECOVERY-KEY',
    );

    await repo.save(metadata);
    final loaded = await repo.load();

    expect(loaded, isNotNull);
    expect(loaded!.enabled, isTrue);
    final dek = metadata.unlockWithPassword('password');
    expect(loaded.unlockWithPassword('password'), dek);
  });

  test('le fichier vit sous .opime/vault_encryption.json', () async {
    final repo = VaultEncryptionRepository(vaultDir.path);
    await repo.save(
      VaultEncryptionMetadata.create(password: 'p', recoveryKey: 'r'),
    );

    expect(
      await File('${vaultDir.path}/.opime/vault_encryption.json').exists(),
      isTrue,
    );
  });

  test('delete supprime le fichier', () async {
    final repo = VaultEncryptionRepository(vaultDir.path);
    await repo.save(
      VaultEncryptionMetadata.create(password: 'p', recoveryKey: 'r'),
    );
    await repo.delete();
    expect(await repo.load(), isNull);
  });
}

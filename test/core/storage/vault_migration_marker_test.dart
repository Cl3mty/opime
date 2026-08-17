import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_migration_marker.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vaultDir;

  setUp(() async {
    vaultDir = await Directory.systemTemp.createTemp('opime_migration_marker_');
  });

  tearDown(() async {
    if (await vaultDir.exists()) await vaultDir.delete(recursive: true);
  });

  test('exists() est faux tant que rien n\'a été écrit', () async {
    expect(await VaultMigrationMarker.exists(vaultDir.path), isFalse);
  });

  test('write() puis exists() détecte le marqueur', () async {
    await VaultMigrationMarker.write(vaultDir.path, operation: 'encrypt');
    expect(await VaultMigrationMarker.exists(vaultDir.path), isTrue);
  });

  test('clear() supprime le marqueur', () async {
    await VaultMigrationMarker.write(vaultDir.path, operation: 'encrypt');
    await VaultMigrationMarker.clear(vaultDir.path);
    expect(await VaultMigrationMarker.exists(vaultDir.path), isFalse);
  });

  test('clear() sans marqueur existant ne lève pas d\'exception', () async {
    await VaultMigrationMarker.clear(vaultDir.path);
    expect(await VaultMigrationMarker.exists(vaultDir.path), isFalse);
  });

  test('le marqueur est écrit en clair, lisible sans déchiffrement', () async {
    await VaultMigrationMarker.write(vaultDir.path, operation: 'decrypt');
    final content = await File(
      p.join(vaultDir.path, '.opime', 'migration_in_progress.json'),
    ).readAsString();
    expect(content, contains('"operation":"decrypt"'));
  });
}

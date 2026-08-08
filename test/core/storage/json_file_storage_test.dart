import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/core/storage/json_file_storage.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('freenary_json_storage_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('hasVaultFolder reflète la présence d\'un chemin', () {
    expect(JsonFileStorage(vaultFolderPath: tempDir.path).hasVaultFolder, isTrue);
    expect(JsonFileStorage().hasVaultFolder, isFalse);
  });

  test('readVault retourne la structure par défaut si vault.json n\'existe pas', () async {
    final storage = JsonFileStorage(vaultFolderPath: tempDir.path);
    final data = await storage.readVault();
    expect(data, {'patrimoine': [], 'investissements': []});
  });

  test('writeVault puis readVault restitue les mêmes données', () async {
    final storage = JsonFileStorage(vaultFolderPath: tempDir.path);
    await storage.writeVault({
      'patrimoine': [
        {'nom': 'Résidence principale', 'valeur': 350000},
      ],
      'investissements': [],
    });

    final data = await storage.readVault();
    expect((data['patrimoine'] as List).single['nom'], 'Résidence principale');
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/strategy/strategy_folders_repository.dart';

void main() {
  late Directory tempDir;
  late StrategyFoldersRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_strategy_folders_repo_',
    );
    repo = StrategyFoldersRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('listFolders et noteFolders sont vides au départ', () async {
    expect(await repo.listFolders(), isEmpty);
    expect(await repo.noteFolders(), isEmpty);
  });

  test('createFolder crée un dossier et le persiste', () async {
    final folder = await repo.createFolder('Impôts', 0xFFE57373);
    expect(folder.name, 'Impôts');
    expect(folder.color, 0xFFE57373);

    final reloaded = await StrategyFoldersRepository(
      tempDir.path,
    ).listFolders();
    expect(reloaded, hasLength(1));
    expect(reloaded.single.id, folder.id);
    expect(reloaded.single.name, 'Impôts');
  });

  test('createFolder retombe sur un nom par défaut si laissé vide', () async {
    final folder = await repo.createFolder('   ', 0xFFE57373);
    expect(folder.name, 'Nouveau dossier');
  });

  test('renameFolder met à jour le nom sans toucher à la couleur', () async {
    final folder = await repo.createFolder('Impôts', 0xFFE57373);
    await repo.renameFolder(folder.id, 'Impôts 2026');

    final reloaded = await repo.listFolders();
    expect(reloaded.single.name, 'Impôts 2026');
    expect(reloaded.single.color, 0xFFE57373);
  });

  test('renameFolder ignore un nom vide', () async {
    final folder = await repo.createFolder('Impôts', 0xFFE57373);
    await repo.renameFolder(folder.id, '   ');
    expect((await repo.listFolders()).single.name, 'Impôts');
  });

  test('setFolderColor met à jour la couleur sans toucher au nom', () async {
    final folder = await repo.createFolder('Impôts', 0xFFE57373);
    await repo.setFolderColor(folder.id, 0xFF64B5F6);

    final reloaded = await repo.listFolders();
    expect(reloaded.single.name, 'Impôts');
    expect(reloaded.single.color, 0xFF64B5F6);
  });

  test(
    'moveNoteToFolder range une note dans un dossier, puis la retire si '
    'appelé avec null',
    () async {
      final folder = await repo.createFolder('Impôts', 0xFFE57373);
      await repo.moveNoteToFolder('note-1', folder.id);
      expect(await repo.noteFolders(), {'note-1': folder.id});

      await repo.moveNoteToFolder('note-1', null);
      expect(await repo.noteFolders(), isEmpty);
    },
  );

  test(
    'deleteFolder retire le dossier et libère les notes qu\'il contenait, '
    'sans toucher aux autres dossiers/notes',
    () async {
      final impots = await repo.createFolder('Impôts', 0xFFE57373);
      final autre = await repo.createFolder('Autre dossier', 0xFF64B5F6);
      await repo.moveNoteToFolder('note-1', impots.id);
      await repo.moveNoteToFolder('note-2', impots.id);
      await repo.moveNoteToFolder('note-3', autre.id);

      await repo.deleteFolder(impots.id);

      final folders = await repo.listFolders();
      expect(folders, hasLength(1));
      expect(folders.single.id, autre.id);

      final noteFolders = await repo.noteFolders();
      expect(noteFolders, {'note-3': autre.id});
    },
  );
}

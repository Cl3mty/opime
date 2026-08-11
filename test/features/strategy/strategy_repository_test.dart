import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/strategy/strategy_repository.dart';

void main() {
  late Directory tempDir;
  late StrategyRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_strategy_repo_');
    repo = StrategyRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('listNotes est vide au départ', () async {
    expect(await repo.listNotes(), isEmpty);
  });

  test('createNote crée une note avec un titre par défaut', () async {
    final note = await repo.createNote();
    expect(note.title, 'Nouvelle note');
    final content = await repo.readNote(note.id);
    expect(content, contains('Nouvelle note'));
  });

  test('writeNote puis readNote restituent le contenu exact', () async {
    final note = await repo.createNote();
    await repo.writeNote(note.id, '# Ma stratégie\n\nContenu détaillé.');
    expect(await repo.readNote(note.id), '# Ma stratégie\n\nContenu détaillé.');
  });

  test(
    'le titre affiché dans listNotes provient de la première ligne non vide',
    () async {
      final note = await repo.createNote();
      await repo.writeNote(note.id, '\n\n## Achat immobilier 2027\nDétails...');

      final notes = await repo.listNotes();
      expect(notes.single.title, 'Achat immobilier 2027');
    },
  );

  test('readNote sur un id inexistant retourne une chaîne vide', () async {
    expect(await repo.readNote('inexistant'), '');
  });

  test('deleteNote retire la note de la liste', () async {
    final note = await repo.createNote();
    await repo.deleteNote(note.id);
    expect(await repo.listNotes(), isEmpty);
  });

  test(
    'listNotes trie par date de création (id), la plus récente en premier',
    () async {
      final older = await repo.createNote();
      await repo.writeNote(older.id, '# Ancienne note');
      // On force un id de création postérieur pour simuler une note plus récente,
      // sans dépendre d'un vrai délai d'horloge dans le test.
      final newerId = (int.parse(older.id) + 1000).toString();
      await repo.writeNote(newerId, '# Nouvelle note');

      final notes = await repo.listNotes();
      expect(notes.first.id, newerId);
      expect(notes.last.id, older.id);
    },
  );
}

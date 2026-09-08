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

  test(
    'createTemplatesIfFirstVisit crée les 5 notes modèle au premier passage',
    () async {
      final created = await repo.createTemplatesIfFirstVisit();
      expect(created, isTrue);

      final notes = await repo.listNotes();
      expect(notes, hasLength(5));

      final titles = notes.map((n) => n.title).toList();
      for (final expected in [
        'Watchlist',
        "Thèse d'investissement",
        'Stratégie',
        'Objectifs',
        'Checklist',
      ]) {
        expect(
          titles.any((t) => t.contains(expected)),
          isTrue,
          reason: 'La note modèle "$expected" est absente',
        );
      }

      // Chaque note ne contient qu'un emoji et un titre.
      for (final note in notes) {
        final content = await repo.readNote(note.id);
        expect(content, matches(RegExp(r'^# .+\n$')));
      }
    },
  );

  test(
    'createTemplatesIfFirstVisit est sans effet au second passage',
    () async {
      await repo.createTemplatesIfFirstVisit();
      expect(await repo.createTemplatesIfFirstVisit(), isFalse);
      expect(await repo.listNotes(), hasLength(5));
    },
  );

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
    'duplicateNote crée un nouvel id distinct, avec "(copie)" suffixant le '
    'titre (première ligne), sans toucher au reste du contenu',
    () async {
      final note = await repo.createNote();
      await repo.writeNote(
        note.id,
        '# Ma stratégie\n\nContenu détaillé.\nSuite.',
      );

      final duplicate = await repo.duplicateNote(note.id);

      expect(duplicate.id, isNot(note.id));
      expect(duplicate.title, 'Ma stratégie (copie)');
      expect(
        await repo.readNote(duplicate.id),
        '# Ma stratégie (copie)\n\nContenu détaillé.\nSuite.',
      );
    },
  );

  test('duplicateNote laisse l\'original totalement inchangé', () async {
    final note = await repo.createNote();
    await repo.writeNote(note.id, '# Original\n\nTexte.');

    await repo.duplicateNote(note.id);

    expect(await repo.readNote(note.id), '# Original\n\nTexte.');
    final notes = await repo.listNotes();
    expect(notes, hasLength(2));
  });

  test(
    'duplicateNote d\'une note sans ligne non vide retombe sur un titre '
    'par défaut, plutôt qu\'un duplicata sans titre',
    () async {
      final note = await repo.createNote();
      await repo.writeNote(note.id, '');

      final duplicate = await repo.duplicateNote(note.id);

      expect(duplicate.title, 'Nouvelle note (copie)');
    },
  );

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

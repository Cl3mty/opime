import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/strategy/strategy_documents_repository.dart';

void main() {
  late Directory tempDir;
  late StrategyDocumentsRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_strategy_documents_repo_',
    );
    repo = StrategyDocumentsRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('documentsFor est vide pour une note sans document', () async {
    expect(await repo.documentsFor('note-1'), isEmpty);
  });

  test(
    'addDocument écrit les octets sur disque et enregistre les métadonnées',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final documents = await repo.addDocument(
        'note-1',
        'IBKR 2025.pdf',
        bytes,
        name: 'Résultats annuels IBKR',
      );

      expect(documents, hasLength(1));
      final document = documents.single;
      expect(document.fileName, 'IBKR 2025.pdf');
      expect(document.note, 'Résultats annuels IBKR');

      // Persisté dans l'index (relu depuis un nouveau repository, pas
      // seulement gardé en mémoire).
      final reloaded = await StrategyDocumentsRepository(
        tempDir.path,
      ).documentsFor('note-1');
      expect(reloaded, hasLength(1));
      expect(reloaded.single.fileName, 'IBKR 2025.pdf');

      // Les octets eux-mêmes sont bien sur disque, sous
      // strategy/documents/, séparés des documents de comptes/investissements.
      final file = File(
        '${tempDir.path}/strategy/documents/${document.id}.pdf',
      );
      expect(await file.exists(), isTrue);
    },
  );

  test(
    'des documents attachés à des notes différentes restent bien séparés',
    () async {
      await repo.addDocument(
        'note-1',
        'IBKR 2025.pdf',
        Uint8List.fromList([1]),
      );
      await repo.addDocument(
        'note-1',
        'Déclaration 2025.pdf',
        Uint8List.fromList([2]),
      );
      await repo.addDocument(
        'note-2',
        'Autre note.pdf',
        Uint8List.fromList([3]),
      );

      expect(await repo.documentsFor('note-1'), hasLength(2));
      expect(await repo.documentsFor('note-2'), hasLength(1));
    },
  );

  test(
    'removeDocument retire les octets et les métadonnées, sans toucher '
    'aux autres documents de la même note',
    () async {
      final afterAdd1 = await repo.addDocument(
        'note-1',
        'IBKR 2025.pdf',
        Uint8List.fromList([1]),
      );
      final toKeep = afterAdd1.single;
      final afterAdd2 = await repo.addDocument(
        'note-1',
        'Déclaration 2025.pdf',
        Uint8List.fromList([2]),
      );
      final toRemove = afterAdd2.last;

      final file = File(
        '${tempDir.path}/strategy/documents/${toRemove.id}.pdf',
      );
      expect(await file.exists(), isTrue);

      final remaining = await repo.removeDocument('note-1', toRemove);

      expect(remaining, hasLength(1));
      expect(remaining.single.id, toKeep.id);
      expect(await file.exists(), isFalse);
    },
  );

  test(
    'deleteAllFor supprime tous les documents (octets et métadonnées) '
    'd\'une note, sans toucher aux documents des autres notes',
    () async {
      await repo.addDocument('note-1', 'a.pdf', Uint8List.fromList([1]));
      final note1Second = (await repo.addDocument(
        'note-1',
        'b.pdf',
        Uint8List.fromList([2]),
      )).last;
      await repo.addDocument('note-2', 'c.pdf', Uint8List.fromList([3]));

      await repo.deleteAllFor('note-1');

      expect(await repo.documentsFor('note-1'), isEmpty);
      expect(await repo.documentsFor('note-2'), hasLength(1));
      final file = File(
        '${tempDir.path}/strategy/documents/${note1Second.id}.pdf',
      );
      expect(await file.exists(), isFalse);
    },
  );

  test('deleteAllFor sur une note sans document ne plante pas', () async {
    await repo.deleteAllFor('note-inexistante');
  });
}

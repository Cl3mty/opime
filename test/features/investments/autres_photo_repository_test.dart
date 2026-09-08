import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/autres_photo_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_autres_photo_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('importe une photo puis la retrouve par id d\'investissement', () async {
    final repo = AutresPhotoRepository(tempDir.path);
    final path = await repo.importPhoto(
      'inv-1',
      Uint8List.fromList([1, 2, 3]),
      sourceName: 'montre.jpg',
    );

    expect(path, isNotNull);
    expect(await File(path!).exists(), isTrue);

    final readBack = await repo.photoPathFor('inv-1');
    expect(readBack, path);
    expect(await File(readBack!).readAsBytes(), [1, 2, 3]);
  });

  test(
    'deux investissements de même libellé gardent des photos distinctes '
    '(indexées par id, pas par nom)',
    () async {
      final repo = AutresPhotoRepository(tempDir.path);
      await repo.importPhoto(
        'inv-1',
        Uint8List.fromList([1, 2, 3]),
        sourceName: 'a.jpg',
      );
      await repo.importPhoto(
        'inv-2',
        Uint8List.fromList([4, 5, 6]),
        sourceName: 'b.jpg',
      );

      expect(
        await File((await repo.photoPathFor('inv-1'))!).readAsBytes(),
        [1, 2, 3],
      );
      expect(
        await File((await repo.photoPathFor('inv-2'))!).readAsBytes(),
        [4, 5, 6],
      );
    },
  );

  test('une extension non-image est ignorée (pas de fichier, pas d\'index)', () async {
    final repo = AutresPhotoRepository(tempDir.path);
    final path = await repo.importPhoto(
      'inv-1',
      Uint8List.fromList([1, 2, 3]),
      sourceName: 'photo.txt',
    );

    expect(path, isNull);
    expect(await repo.photoPathFor('inv-1'), isNull);
    expect(await repo.readIndex(), isEmpty);
  });

  test(
    'réimporter une photo du même investissement écrase le fichier '
    'précédent',
    () async {
      final repo = AutresPhotoRepository(tempDir.path);
      await repo.importPhoto(
        'inv-1',
        Uint8List.fromList([1, 2, 3]),
        sourceName: 'montre.png',
      );
      final second = await repo.importPhoto(
        'inv-1',
        Uint8List.fromList([4, 5, 6]),
        sourceName: 'montre2.png',
      );

      expect(second, isNotNull);
      expect(await File(second!).readAsBytes(), [4, 5, 6]);
      // Le nom de fichier est stable (id de l'investissement) : un seul
      // fichier reste dans le dossier des photos.
      final files = Directory(
        '${tempDir.path}/investissements/autres/photos',
      ).listSync().whereType<File>();
      expect(files, hasLength(1));
    },
  );

  test('deletePhoto retire le fichier et l\'entrée d\'index', () async {
    final repo = AutresPhotoRepository(tempDir.path);
    await repo.importPhoto(
      'inv-1',
      Uint8List.fromList([1, 2, 3]),
      sourceName: 'montre.png',
    );
    await repo.deletePhoto('inv-1');

    expect(await repo.photoPathFor('inv-1'), isNull);
    expect(await repo.readIndex(), isEmpty);
  });

  test('un index corrompu retombe sur aucune photo plutôt que de planter', () async {
    final repo = AutresPhotoRepository(tempDir.path);
    await repo.importPhoto(
      'inv-1',
      Uint8List.fromList([1, 2, 3]),
      sourceName: 'montre.png',
    );
    // Corrompt l'index JSON.
    final indexFile = File(
      '${tempDir.path}/investissements/autres/photos.json',
    );
    await indexFile.writeAsString('{pas du json');

    expect(await repo.photoPathFor('inv-1'), isNull);
  });
}

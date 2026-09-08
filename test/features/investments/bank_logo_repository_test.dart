import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/bank_logo_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_bank_logo_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('importe un logo puis le retrouve par nom de banque', () async {
    final repo = BankLogoRepository(tempDir.path);
    final path = await repo.importLogo(
      'Banque Populaire',
      Uint8List.fromList([1, 2, 3]),
      sourceName: 'bp.png',
    );

    expect(path, isNotNull);
    expect(await File(path!).exists(), isTrue);

    final readBack = await repo.logoPathFor('Banque Populaire');
    expect(readBack, path);
    expect(await File(readBack!).readAsBytes(), [1, 2, 3]);
  });

  test('une extension non-image est ignorée (pas de fichier, pas d\'index)', () async {
    final repo = BankLogoRepository(tempDir.path);
    final path = await repo.importLogo(
      'Boursorama',
      Uint8List.fromList([1, 2, 3]),
      sourceName: 'logo.txt',
    );

    expect(path, isNull);
    expect(await repo.logoPathFor('Boursorama'), isNull);
    expect(await repo.readIndex(), isEmpty);
  });

  test('réimporter un logo de la même banque écrase le fichier précédent', () async {
    final repo = BankLogoRepository(tempDir.path);
    await repo.importLogo(
      'Boursorama',
      Uint8List.fromList([1, 2, 3]),
      sourceName: 'boursorama.png',
    );
    final second = await repo.importLogo(
      'Boursorama',
      Uint8List.fromList([4, 5, 6]),
      sourceName: 'boursorama2.png',
    );

    expect(second, isNotNull);
    expect(await File(second!).readAsBytes(), [4, 5, 6]);
    // Le nom de fichier est stable (slug de la banque) : un seul fichier
    // reste dans le dossier des logos.
    final files = Directory(
      '${tempDir.path}/investissements/logos_banques',
    ).listSync().whereType<File>();
    expect(files, hasLength(1));
  });

  test('deleteLogo retire le fichier et l\'entrée d\'index', () async {
    final repo = BankLogoRepository(tempDir.path);
    await repo.importLogo(
      'Boursorama',
      Uint8List.fromList([1, 2, 3]),
      sourceName: 'boursorama.png',
    );
    await repo.deleteLogo('Boursorama');

    expect(await repo.logoPathFor('Boursorama'), isNull);
    expect(await repo.readIndex(), isEmpty);
  });

  test('fileSlugFor produit un nom de fichier stable, minuscules sans accents', () {
    expect(BankLogoRepository.fileSlugFor('Banque Populaire'), 'banque_populaire');
    expect(BankLogoRepository.fileSlugFor('La Banque Postale'), 'la_banque_postale');
    expect(BankLogoRepository.fileSlugFor('  Crédit Agricole  '), 'credit_agricole');
  });

  test('un index corrompu retombe sur aucun logo plutôt que de planter', () async {
    final repo = BankLogoRepository(tempDir.path);
    await repo.importLogo(
      'Boursorama',
      Uint8List.fromList([1, 2, 3]),
      sourceName: 'boursorama.png',
    );
    // Corrompt l'index JSON.
    final indexFile = File('${tempDir.path}/investissements/logos_banques.json');
    await indexFile.writeAsString('{pas du json');

    expect(await repo.logoPathFor('Boursorama'), isNull);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/custom_other_categories_repository.dart';

void main() {
  late Directory tempDir;
  late CustomOtherCategoriesRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_other_categories_repo_',
    );
    repo = CustomOtherCategoriesRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('load renvoie une liste vide si aucun fichier n\'existe', () async {
    expect(await repo.load(), isEmpty);
  });

  test('addCategory puis load restitue la catégorie ajoutée', () async {
    await repo.addCategory('Vins de collection');
    expect(await repo.load(), ['Vins de collection']);
  });

  test('addCategory ne duplique pas une catégorie déjà présente', () async {
    await repo.addCategory('Vins de collection');
    await repo.addCategory('Vins de collection');
    expect(await repo.load(), ['Vins de collection']);
  });

  test('addCategory ignore un nom vide ou blanc', () async {
    await repo.addCategory('   ');
    expect(await repo.load(), isEmpty);
  });

  test('addCategory retire les espaces superflus (trim)', () async {
    await repo.addCategory('  Vins de collection  ');
    expect(await repo.load(), ['Vins de collection']);
  });

  test('renameCategory renomme une catégorie existante', () async {
    await repo.addCategory('Vins');
    await repo.renameCategory('Vins', 'Vins de collection');
    expect(await repo.load(), ['Vins de collection']);
  });

  test(
    'renameCategory vers un nom déjà pris retire simplement l\'ancien nom '
    '(pas de doublon)',
    () async {
      await repo.addCategory('Vins');
      await repo.addCategory('Vins de collection');
      await repo.renameCategory('Vins', 'Vins de collection');
      expect(await repo.load(), ['Vins de collection']);
    },
  );

  test('renameCategory est un no-op si l\'ancien nom n\'existe pas', () async {
    await repo.addCategory('Vins de collection');
    await repo.renameCategory('Inexistant', 'Autre chose');
    expect(await repo.load(), ['Vins de collection']);
  });

  test('removeCategory retire la catégorie de la liste', () async {
    await repo.addCategory('Vins de collection');
    await repo.addCategory('Sneakers');
    await repo.removeCategory('Vins de collection');
    expect(await repo.load(), ['Sneakers']);
  });

  test('removeCategory est un no-op si le nom n\'existe pas', () async {
    await repo.addCategory('Vins de collection');
    await repo.removeCategory('Inexistant');
    expect(await repo.load(), ['Vins de collection']);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/features/budget/budget_categories_repository.dart';

void main() {
  late Directory tempDir;
  late BudgetCategoriesRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('freenary_categories_repo_');
    repo = BudgetCategoriesRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('load crée et retourne les catégories par défaut si aucun fichier n\'existe', () async {
    final categories = await repo.load();
    expect(categories, BudgetCategoriesRepository.defaults);
  });

  test('save puis load restitue les catégories persistées', () async {
    await repo.save(['A', 'B', 'C']);
    expect(await repo.load(), ['A', 'B', 'C']);
  });

  test('addCategory ajoute une nouvelle catégorie sans doublon', () async {
    await repo.save(['Logement']);
    final result = await repo.addCategory('Transport');
    expect(result, ['Logement', 'Transport']);

    final resultDuplicate = await repo.addCategory('Transport');
    expect(resultDuplicate, ['Logement', 'Transport']);
  });

  test('un contenu de fichier corrompu retombe sur les valeurs par défaut', () async {
    await repo.save(['Sera écrasé']);
    final file = tempDir.listSync(recursive: true).whereType<File>().first;
    await file.writeAsString('{ceci n\'est pas du JSON valide');
    expect(await repo.load(), BudgetCategoriesRepository.defaults);
  });
}

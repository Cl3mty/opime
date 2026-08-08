import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/features/budget/budget_models.dart';
import 'package:freenary/features/budget/budget_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late BudgetRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('freenary_budget_repo_');
    repo = BudgetRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  BudgetData sampleData() => BudgetData(
        revenues: [BudgetItem(id: 'r1', name: 'Salaire', amount: 3000)],
        expenseCategories: [
          BudgetCategory(name: 'Logement', items: [BudgetItem(id: 'e1', name: 'Loyer', amount: 900)]),
        ],
        investmentCategories: const [],
      );

  test('listAll est vide avant toute sauvegarde', () async {
    expect(await repo.listAll(), isEmpty);
  });

  test('saveNew persiste un budget récupérable via loadSnapshot', () async {
    final id = await repo.saveNew(sampleData(), name: 'Mon budget');
    final loaded = await repo.loadSnapshot(id);
    expect(loaded.totalRevenues, 3000);
    expect(loaded.totalExpenses, 900);
  });

  test('listAll retourne le plus récent en premier', () async {
    await repo.saveNew(sampleData(), name: 'Premier');
    await Future.delayed(const Duration(milliseconds: 5));
    await repo.saveNew(sampleData(), name: 'Second');

    final all = await repo.listAll();
    expect(all.length, 2);
    expect(all.first.name, 'Second');
  });

  test('updateSnapshot conserve le nom et met à jour les données', () async {
    final id = await repo.saveNew(sampleData(), name: 'Original');
    final updated = sampleData().copyWith(revenues: [BudgetItem(id: 'r1', name: 'Salaire', amount: 4000)]);
    await repo.updateSnapshot(id, updated);

    final all = await repo.listAll();
    expect(all.single.name, 'Original');
    expect(all.single.data.totalRevenues, 4000);
  });

  test('renameSnapshot change uniquement le nom', () async {
    final id = await repo.saveNew(sampleData(), name: 'Ancien nom');
    await repo.renameSnapshot(id, 'Nouveau nom');
    final all = await repo.listAll();
    expect(all.single.name, 'Nouveau nom');
  });

  test('deleteSnapshot retire le budget de la liste', () async {
    final id = await repo.saveNew(sampleData());
    await repo.deleteSnapshot(id);
    expect(await repo.listAll(), isEmpty);
  });

  test('loadSnapshot lève une erreur pour un id inconnu', () async {
    expect(() => repo.loadSnapshot('inconnu'), throwsStateError);
  });

  test('les données sont écrites sur disque en JSON lisible', () async {
    await repo.saveNew(sampleData(), name: 'Persisté');
    final file = File(p.join(tempDir.path, 'budget', 'budget_history.json'));
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), contains('Persisté'));
  });
}

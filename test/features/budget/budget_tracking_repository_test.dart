import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/features/budget/budget_tracking_models.dart';
import 'package:freenary/features/budget/budget_tracking_repository.dart';

void main() {
  late Directory tempDir;
  late BudgetTrackingRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('freenary_tracking_repo_');
    repo = BudgetTrackingRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('load retourne un mois vide si aucun fichier n\'existe encore', () async {
    final month = await repo.load(2026, 3);
    expect(month.month, 3);
    expect(month.year, 2026);
    expect(month.revenues, isEmpty);
  });

  test('save puis load restitue les mêmes données', () async {
    final month = BudgetTrackingMonth.empty(3, 2026).copyWith(
      revenues: [TrackingItem(name: 'Salaire', budget: 3000, realite: 3050)],
    );
    await repo.save(month);

    final loaded = await repo.load(2026, 3);
    expect(loaded.revenues.single.name, 'Salaire');
    expect(loaded.totalRevenuesRealite, 3050);
  });

  test('chaque mois est stocké dans un fichier distinct', () async {
    await repo.save(BudgetTrackingMonth.empty(1, 2026));
    await repo.save(BudgetTrackingMonth.empty(2, 2026));

    final janFile = await repo.load(2026, 1);
    final febFile = await repo.load(2026, 2);
    expect(janFile.month, 1);
    expect(febFile.month, 2);
  });

  test('un contenu corrompu retombe sur un mois vide plutôt que de planter', () async {
    await repo.save(BudgetTrackingMonth.empty(5, 2026).copyWith(
      revenues: [TrackingItem(name: 'Test', budget: 100, realite: 100)],
    ));
    final file = tempDir.listSync(recursive: true).whereType<File>().first;
    await file.writeAsString('pas du json');

    final loaded = await repo.load(2026, 5);
    expect(loaded.revenues, isEmpty);
  });
}

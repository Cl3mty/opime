import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/budget/budget_tracking_models.dart';
import 'package:opime/features/budget/budget_tracking_repository.dart';

void main() {
  late Directory tempDir;
  late BudgetTrackingRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_tracking_repo_');
    repo = BudgetTrackingRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'load retourne un mois vide si aucun fichier n\'existe encore',
    () async {
      final month = await repo.load(2026, 3);
      expect(month.month, 3);
      expect(month.year, 2026);
      expect(month.revenues, isEmpty);
    },
  );

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

  test(
    'un contenu corrompu retombe sur un mois vide plutôt que de planter',
    () async {
      await repo.save(
        BudgetTrackingMonth.empty(5, 2026).copyWith(
          revenues: [TrackingItem(name: 'Test', budget: 100, realite: 100)],
        ),
      );
      final file = tempDir.listSync(recursive: true).whereType<File>().first;
      await file.writeAsString('pas du json');

      final loaded = await repo.load(2026, 5);
      expect(loaded.revenues, isEmpty);
    },
  );

  group('loadWithStatus (isNew)', () {
    test('isNew vrai quand aucun fichier n\'existe encore', () async {
      final result = await repo.loadWithStatus(2026, 3);
      expect(result.isNew, isTrue);
      expect(result.month.revenues, isEmpty);
    });

    test('isNew faux dès qu\'un fichier a été sauvegardé, même vide', () async {
      await repo.save(BudgetTrackingMonth.empty(3, 2026));
      final result = await repo.loadWithStatus(2026, 3);
      expect(result.isNew, isFalse);
    });

    test(
      'isNew faux pour un contenu corrompu (le fichier existe, même si '
      'illisible)',
      () async {
        await repo.save(BudgetTrackingMonth.empty(5, 2026));
        final file = tempDir.listSync(recursive: true).whereType<File>().first;
        await file.writeAsString('pas du json');

        final result = await repo.loadWithStatus(2026, 5);
        expect(result.isNew, isFalse);
        expect(result.month.revenues, isEmpty);
      },
    );

    test('load (sans statut) reste équivalent au .month de loadWithStatus', () async {
      await repo.save(
        BudgetTrackingMonth.empty(3, 2026).copyWith(
          revenues: [TrackingItem(name: 'Salaire', budget: 3000, realite: 0)],
        ),
      );
      final viaLoad = await repo.load(2026, 3);
      final viaStatus = await repo.loadWithStatus(2026, 3);
      expect(viaLoad.revenues.single.name, viaStatus.month.revenues.single.name);
    });
  });
}

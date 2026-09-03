import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/entities/entities_models.dart';
import 'package:opime/features/entities/entities_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_entities_repo_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  BusinessEntity entity({String? id, String name = 'Holding Dupont'}) =>
      BusinessEntity(
        id: id ?? generateEntityId(),
        name: name,
        type: EntityType.holding,
        ownershipPercent: 100,
      );

  test('listAll sur un coffre-fort vide renvoie une liste vide', () async {
    final repo = EntityRepository(tempDir.path);
    expect(await repo.listAll(), isEmpty);
  });

  test('saveEntity ajoute puis met à jour (upsert par id)', () async {
    final repo = EntityRepository(tempDir.path);
    final e = entity();

    await repo.saveEntity(e);
    expect(await repo.listAll(), hasLength(1));

    final updated = e.copyWith(name: 'Holding Dupont & Fils');
    await repo.saveEntity(updated);

    final all = await repo.listAll();
    expect(all, hasLength(1));
    expect(all.single.name, 'Holding Dupont & Fils');
  });

  test('deleteEntity retire l\'entité de la liste', () async {
    final repo = EntityRepository(tempDir.path);
    final e = entity();
    await repo.saveEntity(e);

    await repo.deleteEntity(e.id);

    expect(await repo.listAll(), isEmpty);
  });

  test('find retrouve une entité existante, null sinon', () async {
    final repo = EntityRepository(tempDir.path);
    final e = entity(name: 'SCI Les Tilleuls');
    await repo.saveEntity(e);

    expect((await repo.find(e.id))?.name, 'SCI Les Tilleuls');
    expect(await repo.find('introuvable'), isNull);
  });

  test(
    'les lignes d\'actif/passif survivent au round-trip disque',
    () async {
      final repo = EntityRepository(tempDir.path);
      final e = BusinessEntity(
        id: generateEntityId(),
        name: 'SCI Les Tilleuls',
        type: EntityType.sci,
        ownershipPercent: 60,
        assets: [
          EntityLine(id: generateEntityLineId(), label: 'Immeuble', amount: 200000),
        ],
        liabilities: [
          EntityLine(id: generateEntityLineId(), label: 'Emprunt', amount: 50000),
        ],
      );
      await repo.saveEntity(e);

      final reloaded = await repo.find(e.id);
      expect(reloaded!.assets.single.label, 'Immeuble');
      expect(reloaded.assets.single.amount, 200000);
      expect(reloaded.liabilities.single.label, 'Emprunt');
      expect(reloaded.netValue, 150000);
      expect(reloaded.ownedNetValue, 90000);
    },
  );
}

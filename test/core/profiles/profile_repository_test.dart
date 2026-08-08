import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/core/profiles/profile_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late ProfileRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('freenary_profile_repo_');
    repo = ProfileRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('listAll crée le profil master à la première lecture', () async {
    final profiles = await repo.listAll();
    expect(profiles.length, 1);
    expect(profiles.single.id, masterProfileId);
    expect(profiles.single.isMaster, isTrue);
  });

  test('le dossier de données du profil master est créé', () async {
    await repo.listAll();
    expect(await Directory(repo.pathFor(masterProfileId)).exists(), isTrue);
  });

  test('create ajoute un profil non-master et crée son dossier', () async {
    await repo.listAll();
    final profile = await repo.create(name: 'Conjoint', relationship: 'Époux');

    expect(profile.isMaster, isFalse);
    final all = await repo.listAll();
    expect(all.length, 2);
    expect(await Directory(repo.pathFor(profile.id)).exists(), isTrue);
  });

  test('rename met à jour nom et relation', () async {
    await repo.listAll();
    final profile = await repo.create(name: 'Ancien', relationship: 'Ami');
    await repo.rename(profile.id, name: 'Nouveau', relationship: 'Frère');

    final all = await repo.listAll();
    final updated = all.firstWhere((p) => p.id == profile.id);
    expect(updated.name, 'Nouveau');
    expect(updated.relationship, 'Frère');
  });

  test('delete ne supprime jamais le profil master', () async {
    await repo.listAll();
    await repo.delete(masterProfileId);
    final all = await repo.listAll();
    expect(all.any((p) => p.isMaster), isTrue);
  });

  test('delete supprime un profil secondaire', () async {
    await repo.listAll();
    final profile = await repo.create(name: 'À supprimer', relationship: 'Ami');
    await repo.delete(profile.id);

    final all = await repo.listAll();
    expect(all.any((p) => p.id == profile.id), isFalse);
  });

  test('pathFor pointe vers profiles/<id> sous le vault', () {
    expect(repo.pathFor('xyz'), p.join(tempDir.path, 'profiles', 'xyz'));
  });

  test('migre les données legacy (strategy/budget à la racine) vers le profil master', () async {
    final legacyStrategy = Directory(p.join(tempDir.path, 'strategy'));
    await legacyStrategy.create(recursive: true);
    await File(p.join(legacyStrategy.path, 'note.md')).writeAsString('# Note');

    final profiles = await repo.listAll();
    expect(profiles.single.isMaster, isTrue);

    final migratedFile = File(p.join(repo.pathFor(masterProfileId), 'strategy', 'note.md'));
    expect(await migratedFile.exists(), isTrue);
    expect(await legacyStrategy.exists(), isFalse);
  });
}

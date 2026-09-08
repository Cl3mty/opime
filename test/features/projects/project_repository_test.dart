import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/projects/project_models.dart';
import 'package:opime/features/projects/project_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_project_repo_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('listAll sur un vault vide renvoie une liste vide', () async {
    final repo = ProjectRepository(tempDir.path);
    expect(await repo.listAll(), isEmpty);
  });

  test('saveProject ajoute puis met à jour (upsert par id)', () async {
    final repo = ProjectRepository(tempDir.path);
    final project = Project(name: 'Retraite', echeance: DateTime.utc(2050, 1, 1));

    await repo.saveProject(project);
    expect(await repo.listAll(), hasLength(1));

    final updated = project.copyWith(name: 'Retraite anticipée');
    await repo.saveProject(updated);

    final all = await repo.listAll();
    expect(all, hasLength(1));
    expect(all.single.name, 'Retraite anticipée');
  });

  test('deleteProject retire le projet de la liste', () async {
    final repo = ProjectRepository(tempDir.path);
    final project = Project(name: 'Achat voiture', echeance: DateTime.utc(2027, 1, 1));
    await repo.saveProject(project);

    await repo.deleteProject(project.id);

    expect(await repo.listAll(), isEmpty);
  });

  test('find retrouve un projet existant, null sinon', () async {
    final repo = ProjectRepository(tempDir.path);
    final project = Project(name: 'Voyage', echeance: DateTime.utc(2026, 12, 1));
    await repo.saveProject(project);

    expect((await repo.find(project.id))?.name, 'Voyage');
    expect(await repo.find('introuvable'), isNull);
  });
}

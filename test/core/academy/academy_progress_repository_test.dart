import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/core/academy/academy_progress_repository.dart';

void main() {
  late Directory tempDir;
  late AcademyProgressRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('freenary_academy_repo_');
    repo = AcademyProgressRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('read retourne un ensemble vide si rien n\'a jamais été écrit', () async {
    expect(await repo.read(), isEmpty);
  });

  test('write puis read restitue les mêmes identifiants', () async {
    await repo.write({'envelope_pea', 'invest_risque'});
    expect(await repo.read(), {'envelope_pea', 'invest_risque'});
  });

  test('write écrase l\'état précédent plutôt que de le fusionner', () async {
    await repo.write({'a', 'b'});
    await repo.write({'c'});
    expect(await repo.read(), {'c'});
  });

  test('un contenu corrompu retombe sur un ensemble vide plutôt que de planter', () async {
    await repo.write({'a'});
    final file = tempDir.listSync(recursive: true).whereType<File>().first;
    await file.writeAsString('pas du json');

    expect(await repo.read(), isEmpty);
  });
}

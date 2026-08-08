import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/core/simulations/simulation_state_repository.dart';

void main() {
  late Directory tempDir;
  late SimulationStateRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('freenary_sim_state_');
    repo = SimulationStateRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('read retourne une map vide si rien n\'a jamais été écrit', () async {
    expect(await repo.read('wealth_simple'), isEmpty);
  });

  test('write puis read restitue les mêmes données', () async {
    await repo.write('transmission_demembrement', {'ageUsufruitier': 62, 'nombreEnfants': 2});
    final data = await repo.read('transmission_demembrement');
    expect(data['ageUsufruitier'], 62);
    expect(data['nombreEnfants'], 2);
  });

  test('chaque clé est isolée dans son propre fichier', () async {
    await repo.write('a', {'value': 1});
    await repo.write('b', {'value': 2});
    expect((await repo.read('a'))['value'], 1);
    expect((await repo.read('b'))['value'], 2);
  });

  test('delete supprime l\'état et read retombe sur une map vide', () async {
    await repo.write('loan', {'montantEmprunte': 100000});
    await repo.delete('loan');
    expect(await repo.read('loan'), isEmpty);
  });

  test('delete sur une clé jamais écrite ne lève pas d\'erreur', () async {
    await repo.delete('jamais_ecrit');
  });

  test('un contenu corrompu retombe sur une map vide plutôt que de planter', () async {
    await repo.write('taxation_ir', {'netImposable': 150000});
    final file = tempDir.listSync(recursive: true).whereType<File>().first;
    await file.writeAsString('{pas du json valide');

    expect(await repo.read('taxation_ir'), isEmpty);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_private_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory profileDir;

  setUp(() async {
    profileDir = await Directory.systemTemp.createTemp('opime_profile_');
  });

  tearDown(() async {
    if (await profileDir.exists()) await profileDir.delete(recursive: true);
  });

  Future<void> touch(String relativePath, [String content = '{}']) async {
    final file = File(p.join(profileDir.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  test('vault vide : aucun chemin privé', () async {
    expect(await privateRelativePathsForProfile(profileDir.path), isEmpty);
  });

  test('inclut les fichiers privés simples présents', () async {
    await touch('budget/budget_history.json');
    await touch('investissements/comptes.json');
    await touch('passifs/emprunts.json');
    await touch('projets/projets.json');
    await touch('analyses/parametres.json');

    final paths = await privateRelativePathsForProfile(profileDir.path);

    expect(
      paths,
      containsAll([
        'budget/budget_history.json',
        'investissements/comptes.json',
        'passifs/emprunts.json',
        'projets/projets.json',
        'analyses/parametres.json',
      ]),
    );
  });

  test('n\'inclut pas un fichier privé simple absent', () async {
    final paths = await privateRelativePathsForProfile(profileDir.path);
    expect(paths, isNot(contains('budget/budget_history.json')));
  });

  test('budget/tracking : inclut les mois et categories.json', () async {
    await touch('budget/tracking/2026_01.json');
    await touch('budget/tracking/2026_02.json');
    await touch('budget/tracking/categories.json');

    final paths = await privateRelativePathsForProfile(profileDir.path);

    expect(
      paths,
      containsAll([
        'budget/tracking/2026_01.json',
        'budget/tracking/2026_02.json',
        'budget/tracking/categories.json',
      ]),
    );
  });

  test(
    'investissements/documents : inclut tous les fichiers quelle que soit l\'extension',
    () async {
      await touch('investissements/documents/abc123.pdf', 'binaire');
      await touch('investissements/documents/def456.jpg', 'binaire');

      final paths = await privateRelativePathsForProfile(profileDir.path);

      expect(
        paths,
        containsAll([
          'investissements/documents/abc123.pdf',
          'investissements/documents/def456.jpg',
        ]),
      );
    },
  );

  test(
    'strategy : inclut les notes .md, pas le marqueur .templates_created',
    () async {
      await touch('strategy/1700000000000.md', '# Note');
      await touch('strategy/.templates_created', '2026-01-01');

      final paths = await privateRelativePathsForProfile(profileDir.path);

      expect(paths, contains('strategy/1700000000000.md'));
      expect(paths, isNot(contains('strategy/.templates_created')));
    },
  );

  test(
    'simulations : inclut les fichiers d\'état, exclut department_boundaries.json',
    () async {
      await touch('simulations/loan.json');
      await touch('simulations/immobilier.json');
      await touch('simulations/department_boundaries.json');

      final paths = await privateRelativePathsForProfile(profileDir.path);

      expect(
        paths,
        containsAll(['simulations/loan.json', 'simulations/immobilier.json']),
      );
      expect(paths, isNot(contains('simulations/department_boundaries.json')));
    },
  );

  test(
    'simulations : ne descend pas dans les sous-dossiers de cache (non récursif)',
    () async {
      await touch('simulations/loan.json');
      await touch('simulations/dvf_cache/75056_2024.json');
      await touch('simulations/commune_boundaries/75.json');
      await touch('simulations/dvf_department_cache/75_2024.json');
      await touch('simulations/rent_cache/maison.json');

      final paths = await privateRelativePathsForProfile(profileDir.path);

      expect(paths, ['simulations/loan.json']);
    },
  );

  test(
    'investissements : n\'inclut pas le miroir métaux précieux ni les logos/images cache',
    () async {
      await touch('investissements/comptes.json');
      await touch(
        'investissements/metaux_precieux/or/2026-01-01/transaction.json',
      );
      await touch('investissements/logos_banques/boursorama.png', 'binaire');
      await touch('investissements/metaux/images/piece.jpg', 'binaire');
      await touch('investissements/metaux/or.json');

      final paths = await privateRelativePathsForProfile(profileDir.path);

      expect(paths, ['investissements/comptes.json']);
    },
  );
}

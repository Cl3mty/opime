import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/search/global_search_index.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_search_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('index compiles sur un vault vide et couvre les catégories', () async {
    final entries = await GlobalSearchIndex.build(vaultPath: tempDir.path);
    final categories = entries.map((e) => e.category).toSet();
    // Le patrimoine réel est vide sur un vault sans comptes : toutes les
    // autres catégories (contenu statique) sont présentes — sauf Formation
    // (Opime Premium, sans contenu réel dans cette édition gratuite, voir
    // `features/academy/formation_data.dart`) et Vocabulaire (glossaire
    // alimenté uniquement par les leçons de Formation dans ce dépôt).
    expect(
      categories,
      containsAll(
        SearchCategory.values.where(
          (c) =>
              c != SearchCategory.patrimoine &&
              c != SearchCategory.formation &&
              c != SearchCategory.vocabulaire,
        ),
      ),
    );
  });

  test('recherche accent-insensible et tiret-insensible', () async {
    final entries = await GlobalSearchIndex.build(vaultPath: tempDir.path);
    // "épargne" (sans accent) trouve la page "Épargne"
    final epargne = GlobalSearchIndex.search(entries, 'epargne');
    expect(epargne.any((e) => e.title == 'Épargne'), isTrue);
    // "assurance vie" trouve l'enveloppe "Assurance-vie"
    final assuranceVie = GlobalSearchIndex.search(entries, 'assurance vie');
    expect(
      assuranceVie.any((e) => e.title == 'Assurance-vie'),
      isTrue,
    );
  });

  test(
    'le glossaire (Vocabulaire) est vide : son seul contenu était les '
    'leçons de Formation (Opime Premium), absentes de cette édition '
    'gratuite',
    () async {
      final entries = await GlobalSearchIndex.build(vaultPath: tempDir.path);
      expect(
        entries.where((e) => e.category == SearchCategory.vocabulaire),
        isEmpty,
      );
    },
  );

  test('champ patrimoine réel indexé', () async {
    final vault = Directory(tempDir.path);
    final dir = Directory('${vault.path}/investissements');
    dir.createSync(recursive: true);
    File('${dir.path}/comptes.json').writeAsStringSync('''
[
  {
    "id": "account_abc123",
    "assetClass": "epargne",
    "envelope": "livretA",
    "name": "Livret A Boursorama",
    "bankName": "Boursorama",
    "investments": []
  }
]
''');
    final entries = await GlobalSearchIndex.build(vaultPath: tempDir.path);
    final livret = GlobalSearchIndex.search(entries, 'boursorama');
    expect(
      livret.any(
        (e) =>
            e.category == SearchCategory.patrimoine &&
            e.title == 'Livret A Boursorama',
      ),
      isTrue,
    );
  });

  test('sans résultat, la recherche renvoie une liste vide', () async {
    final entries = await GlobalSearchIndex.build(vaultPath: tempDir.path);
    final none = GlobalSearchIndex.search(entries, 'zzzzqqqq');
    expect(none, isEmpty);
  });
}

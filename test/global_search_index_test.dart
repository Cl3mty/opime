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
    // autres catégories (contenu statique) sont présentes.
    expect(
      categories,
      containsAll(
        SearchCategory.values.where((c) => c != SearchCategory.patrimoine),
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

  test('terme du glossaire retrouvable par sa définition', () async {
    final entries = await GlobalSearchIndex.build(vaultPath: tempDir.path);
    // "spread" est un terme du vocabulaire de la formation Bourse
    final spread = GlobalSearchIndex.search(entries, 'spread');
    expect(
      spread.any((e) => e.category == SearchCategory.vocabulaire),
      isTrue,
    );
  });

  test('SCPI trouvée dans la formation et l\'enveloppe', () async {
    final entries = await GlobalSearchIndex.build(vaultPath: tempDir.path);
    final scpi = GlobalSearchIndex.search(entries, 'scpi');
    expect(scpi, isNotEmpty);
    expect(
      scpi.any(
        (e) =>
            e.category == SearchCategory.formation && e.title.contains('SCPI'),
      ),
      isTrue,
    );
  });

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

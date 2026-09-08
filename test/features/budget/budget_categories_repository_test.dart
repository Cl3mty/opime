import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/budget/budget_categories_repository.dart';

void main() {
  late Directory tempDir;
  late BudgetCategoriesRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_categories_repo_');
    repo = BudgetCategoriesRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'load crée et retourne les catégories par défaut si aucun fichier '
    'n\'existe, propres à chaque scope (Factures : assurance et '
    'abonnements uniquement, pour l\'instant)',
    () async {
      expect(
        await repo.load(BudgetCategoryScope.factures),
        BudgetCategoriesRepository.facturesDefaults,
      );
      expect(
        await repo.load(BudgetCategoryScope.depenses),
        BudgetCategoriesRepository.depensesDefaults,
      );
    },
  );

  test(
    'save puis load restitue les catégories Dépenses persistées',
    () async {
      await repo.save(BudgetCategoryScope.depenses, ['Courses', 'Loisirs']);
      expect(await repo.load(BudgetCategoryScope.depenses), [
        'Courses',
        'Loisirs',
      ]);
    },
  );

  test(
    'une fois le premier load Factures passé (correction ponctuelle '
    'consommée, voir le groupe "réinitialisation ponctuelle" plus bas), '
    'save/load Factures round-trip normalement, sans jamais toucher '
    'Dépenses',
    () async {
      await repo.load(BudgetCategoryScope.factures);
      await repo.save(BudgetCategoryScope.factures, ['Loyer', 'Assurance']);

      expect(await repo.load(BudgetCategoryScope.factures), [
        'Loyer',
        'Assurance',
      ]);
      expect(
        await repo.load(BudgetCategoryScope.depenses),
        BudgetCategoriesRepository.depensesDefaults,
      );
    },
  );

  test(
    'addCategory ajoute une nouvelle catégorie sans doublon, dans le '
    'scope demandé uniquement',
    () async {
      // Premier load Factures : consomme la correction ponctuelle avant
      // de tester le comportement normal d'ajout.
      await repo.load(BudgetCategoryScope.factures);
      await repo.save(BudgetCategoryScope.factures, ['Logement']);

      final result = await repo.addCategory(
        BudgetCategoryScope.factures,
        'Transport',
      );
      expect(result, ['Logement', 'Transport']);

      final resultDuplicate = await repo.addCategory(
        BudgetCategoryScope.factures,
        'Transport',
      );
      expect(resultDuplicate, ['Logement', 'Transport']);

      // N'a jamais touché Dépenses.
      expect(
        await repo.load(BudgetCategoryScope.depenses),
        BudgetCategoriesRepository.depensesDefaults,
      );
    },
  );

  test(
    'renameCategory renomme en place, sans changer l\'ordre, et ne touche '
    'pas l\'autre scope',
    () async {
      await repo.load(BudgetCategoryScope.factures);
      await repo.save(BudgetCategoryScope.factures, [
        'Loyer',
        'Assurance',
        'Abonnements',
      ]);

      final result = await repo.renameCategory(
        BudgetCategoryScope.factures,
        'Assurance',
        'Assurances',
      );
      expect(result, ['Loyer', 'Assurances', 'Abonnements']);
      expect(await repo.load(BudgetCategoryScope.factures), [
        'Loyer',
        'Assurances',
        'Abonnements',
      ]);
      expect(
        await repo.load(BudgetCategoryScope.depenses),
        BudgetCategoriesRepository.depensesDefaults,
      );
    },
  );

  test(
    'renameCategory vers un nom déjà existant fusionne : l\'ancien nom '
    'disparaît plutôt que de créer un doublon',
    () async {
      await repo.load(BudgetCategoryScope.factures);
      await repo.save(BudgetCategoryScope.factures, [
        'Assurance',
        'Assurances',
      ]);

      final result = await repo.renameCategory(
        BudgetCategoryScope.factures,
        'Assurance',
        'Assurances',
      );
      expect(result, ['Assurances']);
    },
  );

  test(
    'renameCategory est un no-op si l\'ancien nom n\'existe pas dans la '
    'liste',
    () async {
      await repo.load(BudgetCategoryScope.factures);
      await repo.save(BudgetCategoryScope.factures, ['Loyer']);

      final result = await repo.renameCategory(
        BudgetCategoryScope.factures,
        'Introuvable',
        'Peu importe',
      );
      expect(result, ['Loyer']);
    },
  );

  test(
    'removeCategory retire la catégorie de la liste, sans affecter '
    'l\'autre scope',
    () async {
      await repo.load(BudgetCategoryScope.factures);
      await repo.save(BudgetCategoryScope.factures, [
        'Loyer',
        'Assurance',
        'Abonnements',
      ]);

      final result = await repo.removeCategory(
        BudgetCategoryScope.factures,
        'Assurance',
      );
      expect(result, ['Loyer', 'Abonnements']);
      expect(await repo.load(BudgetCategoryScope.factures), [
        'Loyer',
        'Abonnements',
      ]);
      expect(
        await repo.load(BudgetCategoryScope.depenses),
        BudgetCategoriesRepository.depensesDefaults,
      );
    },
  );

  test(
    'un contenu de fichier corrompu retombe sur les valeurs par défaut '
    'du scope concerné',
    () async {
      await repo.load(BudgetCategoryScope.factures);
      await repo.save(BudgetCategoryScope.factures, ['Sera écrasé']);
      final facturesFile = File(
        '${tempDir.path}/budget/tracking/categories_factures.json',
      );
      await facturesFile.writeAsString('{ceci n\'est pas du JSON valide');
      expect(
        await repo.load(BudgetCategoryScope.factures),
        BudgetCategoriesRepository.facturesDefaults,
      );
    },
  );

  test(
    'migration : une ancienne liste unique (avant la séparation Factures/'
    'Dépenses) amorce Dépenses depuis les catégories déjà créées par '
    'l\'utilisateur, mais jamais Factures — qui démarre toujours sur '
    'facturesDefaults, sinon elle redeviendrait identique à Dépenses',
    () async {
      final legacyFile = File(
        '${tempDir.path}/budget/tracking/categories.json',
      );
      await legacyFile.create(recursive: true);
      await legacyFile.writeAsString(
        jsonEncode(['Salle de sport', 'Streaming']),
      );

      final factures = await repo.load(BudgetCategoryScope.factures);
      final depenses = await repo.load(BudgetCategoryScope.depenses);

      expect(factures, BudgetCategoriesRepository.facturesDefaults);
      expect(depenses, ['Salle de sport', 'Streaming']);

      // Une fois amorcée, chaque liste évolue ensuite indépendamment.
      await repo.addCategory(BudgetCategoryScope.factures, 'Loyer');
      expect(await repo.load(BudgetCategoryScope.factures), [
        ...BudgetCategoriesRepository.facturesDefaults,
        'Loyer',
      ]);
      expect(await repo.load(BudgetCategoryScope.depenses), [
        'Salle de sport',
        'Streaming',
      ]);
    },
  );

  test(
    'sans ancienne liste ni fichier scopé : retombe sur les valeurs par '
    'défaut du scope, pas sur une liste vide',
    () async {
      expect(
        await repo.load(BudgetCategoryScope.depenses),
        BudgetCategoriesRepository.depensesDefaults,
      );
    },
  );

  group('réinitialisation ponctuelle de Factures (bug historique)', () {
    // Avant l'introduction de facturesDefaults, `categories_factures.json`
    // pouvait déjà avoir été amorcé (à tort) depuis la même source que
    // Dépenses — le premier `load(factures)` d'une installation existante
    // corrige ça une fois pour toutes, quel qu'ait été ce contenu résiduel.
    Future<void> writeExistingFacturesFile(List<String> content) async {
      final file = File(
        '${tempDir.path}/budget/tracking/categories_factures.json',
      );
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode(content));
    }

    test(
      'un fichier Factures déjà identique à Dépenses (résidu du bug) est '
      'ramené sur facturesDefaults au premier load',
      () async {
        await writeExistingFacturesFile(
          BudgetCategoriesRepository.depensesDefaults,
        );

        expect(
          await repo.load(BudgetCategoryScope.factures),
          BudgetCategoriesRepository.facturesDefaults,
        );
      },
    );

    test(
      'même un contenu Factures qui ne recoupe pas Dépenses est '
      'réinitialisé au tout premier load — la correction est '
      'inconditionnelle, pas une simple détection de doublon avec '
      'Dépenses (fragile : un contenu résiduel pourrait avoir divergé de '
      'Dépenses depuis, ex. après un ajout dans Dépenses)',
      () async {
        await writeExistingFacturesFile(['Salle de sport', 'Streaming']);

        expect(
          await repo.load(BudgetCategoryScope.factures),
          BudgetCategoriesRepository.facturesDefaults,
        );
      },
    );

    test(
      'la réinitialisation ne se produit qu\'une seule fois : un ajout '
      'après le premier load survit aux load suivants',
      () async {
        await writeExistingFacturesFile(
          BudgetCategoriesRepository.depensesDefaults,
        );

        await repo.load(BudgetCategoryScope.factures); // consomme le reset
        await repo.addCategory(BudgetCategoryScope.factures, 'Mutuelle');

        expect(await repo.load(BudgetCategoryScope.factures), [
          ...BudgetCategoriesRepository.facturesDefaults,
          'Mutuelle',
        ]);
      },
    );

    test(
      'sans aucun fichier Factures préexistant, le premier load ne '
      'change rien au comportement habituel (facturesDefaults)',
      () async {
        expect(
          await repo.load(BudgetCategoryScope.factures),
          BudgetCategoriesRepository.facturesDefaults,
        );
      },
    );
  });
}

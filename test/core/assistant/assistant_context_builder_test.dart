import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/assistant/assistant_context_builder.dart';
import 'package:opime/features/budget/budget_tracking_models.dart';
import 'package:opime/features/budget/budget_tracking_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_assistant_ctx_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'le contexte inclut le suivi budgétaire mensuel (postes nommés, ex : '
    '"Amazon" en Dépenses avec son montant Réalité) — pas seulement le '
    'budget prévisionnel, qui ne porte aucun historique daté',
    () async {
      final now = DateTime.now();
      final repo = BudgetTrackingRepository(tempDir.path);
      await repo.save(
        BudgetTrackingMonth(
          month: now.month,
          year: now.year,
          revenues: const [],
          factures: const [],
          depenses: [
            TrackingItem(
              name: 'Amazon',
              budget: 50,
              realite: 63.42,
              category: 'Nourriture',
            ),
          ],
          investEpargnes: const [],
          projets: const [],
          dettes: const [],
        ),
      );

      final context = await AssistantContextBuilder(
        tempDir.path,
      ).buildPatrimoineContext();

      expect(context, contains('Suivi budgétaire mensuel'));
      expect(context, contains('Amazon'));
      expect(context, contains('63'));
    },
  );

  test(
    'agrège plusieurs mois (jusqu\'à 12) pour permettre un résumé annuel '
    'd\'un poste donné',
    () async {
      final now = DateTime.now();
      final repo = BudgetTrackingRepository(tempDir.path);
      final lastMonth = DateTime(now.year, now.month - 1);
      await repo.save(
        BudgetTrackingMonth(
          month: now.month,
          year: now.year,
          revenues: const [],
          factures: const [],
          depenses: [
            TrackingItem(name: 'Amazon', budget: 0, realite: 40),
          ],
          investEpargnes: const [],
          projets: const [],
          dettes: const [],
        ),
      );
      await repo.save(
        BudgetTrackingMonth(
          month: lastMonth.month,
          year: lastMonth.year,
          revenues: const [],
          factures: const [],
          depenses: [
            TrackingItem(name: 'Amazon', budget: 0, realite: 25),
          ],
          investEpargnes: const [],
          projets: const [],
          dettes: const [],
        ),
      );

      final context = await AssistantContextBuilder(
        tempDir.path,
      ).buildPatrimoineContext();

      final amazonMentions = 'Amazon'.allMatches(context).length;
      expect(
        amazonMentions,
        greaterThanOrEqualTo(2),
        reason: 'les deux mois devraient tous les deux mentionner Amazon',
      );
    },
  );

  test(
    'sans aucun suivi mensuel renseigné : le dit explicitement plutôt que '
    'de laisser une section vide ambiguë',
    () async {
      final context = await AssistantContextBuilder(
        tempDir.path,
      ).buildPatrimoineContext();

      expect(
        context,
        contains('Aucun suivi budgétaire mensuel n\'a encore été renseigné'),
      );
    },
  );

  test(
    'un mois entièrement vide (aucun poste dans aucune des 6 catégories) '
    'n\'apparaît pas dans le contexte',
    () async {
      final now = DateTime.now();
      await BudgetTrackingRepository(
        tempDir.path,
      ).save(BudgetTrackingMonth.empty(now.month, now.year));

      final context = await AssistantContextBuilder(
        tempDir.path,
      ).buildPatrimoineContext();

      expect(
        context,
        contains('Aucun suivi budgétaire mensuel n\'a encore été renseigné'),
      );
    },
  );
}

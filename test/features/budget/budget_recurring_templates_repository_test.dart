import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/budget/budget_recurring_templates_models.dart';
import 'package:opime/features/budget/budget_recurring_templates_repository.dart';

void main() {
  late Directory tempDir;
  late BudgetRecurringTemplatesRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_recurring_templates_repo_',
    );
    repo = BudgetRecurringTemplatesRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('load retourne une liste vide si aucun fichier n\'existe encore', () async {
    expect(await repo.load(), isEmpty);
  });

  test('add puis load restitue le template ajouté', () async {
    await repo.add(
      RecurringTemplate(
        name: 'Loyer',
        amount: 900,
        section: BudgetSection.facture,
      ),
    );
    final all = await repo.load();
    expect(all, hasLength(1));
    expect(all.single.name, 'Loyer');
  });

  test('plusieurs templates de sections différentes coexistent dans le même fichier', () async {
    await repo.add(
      RecurringTemplate(
        name: 'Loyer',
        amount: 900,
        section: BudgetSection.facture,
      ),
    );
    await repo.add(
      RecurringTemplate(
        name: 'Salaire',
        amount: 2500,
        section: BudgetSection.revenue,
      ),
    );
    final all = await repo.load();
    expect(all, hasLength(2));
    expect(all.map((t) => t.section), [
      BudgetSection.facture,
      BudgetSection.revenue,
    ]);
  });

  test('remove retire uniquement le template ciblé', () async {
    final keep = RecurringTemplate(
      name: 'Loyer',
      amount: 900,
      section: BudgetSection.facture,
    );
    final drop = RecurringTemplate(
      name: 'Abonnement',
      amount: 15,
      section: BudgetSection.facture,
    );
    await repo.add(keep);
    await repo.add(drop);
    await repo.remove(drop.id);
    final all = await repo.load();
    expect(all, hasLength(1));
    expect(all.single.id, keep.id);
  });

  test('un contenu corrompu retombe sur une liste vide plutôt que de planter', () async {
    final file = File('${tempDir.path}/budget/tracking/recurring_templates.json');
    await file.create(recursive: true);
    await file.writeAsString('{ceci n\'est pas du JSON valide');
    expect(await repo.load(), isEmpty);
  });
}

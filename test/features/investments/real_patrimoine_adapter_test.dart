import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/real_patrimoine_adapter.dart';
import 'package:opime/features/investments/yahoo_finance_client.dart';

void main() {
  InvestmentAccount epargneAccount({
    required String name,
    String? bankName,
    required AccountEnvelope envelope,
  }) =>
      InvestmentAccount(
        assetClass: AssetClass.epargne,
        envelope: envelope,
        name: name,
        bankName: bankName,
        // Une enveloppe d'épargne tient sa devise (EUR) : sans elle, aucun
        // investissement → aucune feuille ne serait construite par
        // `buildRealCategoriesByAccount`.
        investments: [
          Investment(isin: 'EUR', label: 'EUR', transactions: const []),
        ],
      );

  test(
      'épargne sans banque garde son nom réel (comptes pré-bankName), '
      'épargne avec banque affiche le libellé d\'enveloppe', () {
    // Compte créé avant l'introduction du champ "banque" : le nom réel
    // porte l'identité (ici la banque, dans le nom) — sans cela,
    // l'accordéon grouperait par libellé d'enveloppe et fusionnerait des
    // comptes différents du même type.
    final legacy = epargneAccount(
      name: 'Livret A Boursorama',
      envelope: AccountEnvelope.livretA,
    );
    final withBank = epargneAccount(
      name: 'Boursorama',
      bankName: 'Boursorama',
      envelope: AccountEnvelope.ldds,
    );
    final categories = buildRealCategoriesByAccount(
      [legacy, withBank],
      const <String, List<PricePoint>>{},
      '/vault',
    );
    final epargne = categories.singleWhere(
      (c) => c.id == AssetClass.epargne.categoryId,
    );

    final leafById = {for (final a in epargne.accounts) a.id: a};
    // Sans banque : le nom réel du compte est conservé.
    expect(leafById[legacy.id]!.name, 'Livret A Boursorama');
    expect(leafById[legacy.id]!.bankName, isNull);
    // Avec banque : le nom est le libellé d'enveloppe, la banque est portée
    // par la clé de groupement de l'accordéon.
    expect(leafById[withBank.id]!.name, 'LDDS');
    expect(leafById[withBank.id]!.bankName, 'Boursorama');
  });

  test('une devise logée dans un CTO garde son code en avatar', () {
    final cto = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO Bourso',
      bankName: 'Bourso',
      investments: [
        // Titre : avatar à initiales dérivées du libellé.
        Investment(isin: 'FR0012345678', label: 'TotalEnergies', transactions: const []),
        // Devise créée via la bascule "Investissement / Devise".
        Investment(isin: 'USD', label: 'USD', transactions: const []),
      ],
    );
    final categories = buildRealCategories(
      [cto],
      const <String, List<PricePoint>>{},
      '/vault',
    );
    final actions = categories.singleWhere(
      (c) => c.id == AssetClass.actionsEtFonds.categoryId,
    );
    final leafById = {for (final a in actions.accounts) a.id: a};
    // La devise affiche son code (l'avatar d'un titre reste à initiales).
    expect(leafById[cto.investments[1].id]!.avatarInitials, 'USD');
    expect(leafById[cto.investments[0].id]!.avatarInitials, isNull);
  });

  test('cours d\'un titre coté en devise étrangère converti en euros', () {
    final cto = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO Bourso',
      bankName: 'Bourso',
      investments: [
        // Action US : le dernier cours Yahoo est en dollars, la feuille
        // doit l'afficher en euros au taux de change enregistré.
        Investment(
          isin: 'US0378331005',
          label: 'META',
          quoteCurrency: 'USD',
          lastPrice: 173,
          lastFxRateToEur: 0.92,
          transactions: [
            Transaction(
              date: DateTime(2026, 1, 15),
              isBuy: true,
              quantity: 10,
              unitPrice: 150,
            ),
          ],
        ),
      ],
    );
    final categories = buildRealCategories(
      [cto],
      const <String, List<PricePoint>>{},
      '/vault',
    );
    final actions = categories.singleWhere(
      (c) => c.id == AssetClass.actionsEtFonds.categoryId,
    );
    final leaf = actions.accounts.single;
    // 173 $ × 0,92 = 159,16 € ; valeur = 10 × 159,16 = 1591,60 €.
    expect(leaf.cours, closeTo(159.16, 1e-9));
    expect(leaf.valeur, closeTo(1591.6, 1e-9));
  });

  test(
      'Actions & Fonds : sous-titre = description facultative, pas une '
      'répétition du nom (comme l\'épargne)', () {
    final pea = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.pea,
      // Créé via le flux "Quel compte ?", le nom porte déjà le type
      // (libellé d'enveloppe) — un sous-titre "PEA" ne ferait que le répéter.
      name: 'PEA',
      bankName: 'Bourse Direct',
      description: 'PEA long terme',
      investments: [
        Investment(
          isin: 'FR0012345678',
          label: 'Interparfums',
          transactions: const [],
        ),
      ],
    );
    final cto = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      bankName: 'Bourse Direct',
      // Sans description : aucun sous-titre (pas de rappel de l'enveloppe).
      investments: [
        Investment(
          isin: 'FR0098765432',
          label: 'Amundi ETF',
          transactions: const [],
        ),
      ],
    );
    final categories = buildRealCategoriesByAccount(
      [pea, cto],
      const <String, List<PricePoint>>{},
      '/vault',
    );
    final actions = categories.singleWhere(
      (c) => c.id == AssetClass.actionsEtFonds.categoryId,
    );
    final leafById = {for (final a in actions.accounts) a.id: a};
    expect(leafById[pea.id]!.name, 'PEA');
    expect(leafById[pea.id]!.subtitle, 'PEA long terme');
    expect(leafById[cto.id]!.name, 'CTO');
    expect(leafById[cto.id]!.subtitle, isNull);
  });

  test(
      'accordéon établissement → comptes : une position entièrement soldée '
      'disparaît du compte, seul ce qui est encore détenu compte pour sa '
      'valeur', () {
    final cto = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      bankName: 'Bourse Direct',
      investments: [
        // Encore détenu : doit rester visible.
        Investment(
          isin: 'FR0012345678',
          label: 'TotalEnergies',
          transactions: [
            Transaction(date: DateTime(2026, 1, 10), isBuy: true, quantity: 5, unitPrice: 50),
          ],
        ),
        // Entièrement revendu (achat puis vente du même nombre de parts) :
        // ne doit plus apparaître dans l'accordéon, ni peser sur la valeur
        // affichée du compte — même si son historique de transactions
        // (`investment_detail_screen.dart`) continue, lui, de le montrer.
        Investment(
          isin: 'FR0098765432',
          label: 'Ancien titre soldé',
          transactions: [
            Transaction(date: DateTime(2025, 6, 1), isBuy: true, quantity: 3, unitPrice: 20),
            Transaction(date: DateTime(2025, 12, 1), isBuy: false, quantity: 3, unitPrice: 25),
          ],
        ),
      ],
    );
    final categories = buildRealCategoriesByAccount(
      [cto],
      const <String, List<PricePoint>>{},
      '/vault',
    );
    final actions = categories.singleWhere(
      (c) => c.id == AssetClass.actionsEtFonds.categoryId,
    );
    final leaf = actions.accounts.singleWhere((a) => a.id == cto.id);

    expect(leaf.investments, hasLength(1));
    expect(leaf.investments.single.name, 'TotalEnergies');
    // 5 × 50 € : la position soldée (investedAmount = -15 €) ne doit pas
    // s'ajouter à la valeur affichée du compte.
    expect(leaf.valeur, closeTo(250, 1e-9));
  });
}

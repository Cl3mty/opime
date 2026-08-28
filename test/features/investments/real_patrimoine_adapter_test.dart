import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/real_patrimoine_adapter.dart';
import 'package:opime/features/investments/yahoo_finance_client.dart';

void main() {
  InvestmentAccount epargneAccount({
    required String name,
    String? bankName,
    required AccountEnvelope envelope,
  }) => InvestmentAccount(
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

  test('épargne sans banque garde son nom réel (comptes pré-bankName), '
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
    final buy = Transaction(
      date: DateTime.utc(2024, 1, 1),
      isBuy: true,
      quantity: 10,
      unitPrice: 40,
    );
    final cto = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO Bourso',
      bankName: 'Bourso',
      investments: [
        // Titre : avatar à initiales dérivées du libellé.
        Investment(
          isin: 'FR0012345678',
          label: 'TotalEnergies',
          transactions: [buy],
        ),
        // Devise créée via la bascule "Investissement / Devise".
        Investment(isin: 'USD', label: 'USD', transactions: [buy]),
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
    'manualPriceAt propagé au PatrimoineAccount seulement quand le cours '
    'vient bien de l\'estimation manuelle (pas d\'un cours de marché connu) '
    '— voir `category_detail_screen.dart`\'s `_CoursCell`',
    () {
      final cto = InvestmentAccount(
        assetClass: AssetClass.autres,
        envelope: AccountEnvelope.montre,
        name: 'Montres',
        investments: [
          Investment(
            isin: 'autre-1',
            label: 'Rolex Submariner',
            manualPrice: 9500,
            manualPriceAt: DateTime(2026, 1, 15),
            transactions: [
              Transaction(
                date: DateTime(2022, 1, 1),
                isBuy: true,
                quantity: 1,
                unitPrice: 8000,
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
      final autres = categories.singleWhere(
        (c) => c.id == AssetClass.autres.categoryId,
      );
      final leaf = autres.accounts.single;
      expect(leaf.cours, 9500);
      expect(leaf.manualPriceAt, DateTime(2026, 1, 15));
      expect(leaf.lastPriceDate, isNull);
    },
  );

  test('Actions & Fonds : sous-titre = description facultative, pas une '
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

  test('accordéon établissement → comptes : une position entièrement soldée '
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
            Transaction(
              date: DateTime(2026, 1, 10),
              isBuy: true,
              quantity: 5,
              unitPrice: 50,
            ),
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
            Transaction(
              date: DateTime(2025, 6, 1),
              isBuy: true,
              quantity: 3,
              unitPrice: 20,
            ),
            Transaction(
              date: DateTime(2025, 12, 1),
              isBuy: false,
              quantity: 3,
              unitPrice: 25,
            ),
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

  test('un compte sans aucun investissement reste visible dans l\'accordéon '
      '(à l\'utilisateur de décider de le supprimer)', () {
    final emptyCto = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO tout juste créé',
      bankName: 'Interactive Brokers',
      investments: const [],
    );
    final categories = buildRealCategoriesByAccount(
      [emptyCto],
      const <String, List<PricePoint>>{},
      '/vault',
    );
    final actions = categories.singleWhere(
      (c) => c.id == AssetClass.actionsEtFonds.categoryId,
    );
    final leaf = actions.accounts.singleWhere((a) => a.id == emptyCto.id);

    expect(leaf.name, 'CTO tout juste créé');
    expect(leaf.bankName, 'Interactive Brokers');
    expect(leaf.investments, isEmpty);
    expect(leaf.valeur, 0);
    expect(leaf.canDelete, isTrue);
  });

  test('dans l\'accordéon d\'un compte, les positions en devise passent '
      'après les titres et sont marquées isCurrency', () {
    Transaction buy(double quantity) => Transaction(
      date: DateTime(2026, 1, 10),
      isBuy: true,
      quantity: quantity,
      unitPrice: 10,
    );
    final cto = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      bankName: 'Interactive Brokers',
      // Ordre volontairement entremêlé : devise, titre, devise, titre.
      investments: [
        Investment(isin: 'USD', label: 'USD', transactions: [buy(100)]),
        Investment(
          isin: 'FR0012345678',
          label: 'TotalEnergies',
          transactions: [buy(5)],
        ),
        Investment(isin: 'EUR', label: 'EUR', transactions: [buy(50)]),
        Investment(
          isin: 'US0231351067',
          label: 'AMAZON.COM INC',
          transactions: [buy(2)],
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

    // Les titres gardent leur ordre d'origine, suivis des devises, elles
    // aussi dans leur ordre d'origine.
    expect(leaf.investments.map((i) => i.name).toList(), [
      'TotalEnergies',
      'AMAZON.COM INC',
      'USD',
      'EUR',
    ]);
    expect(leaf.investments.map((i) => i.isCurrency).toList(), [
      false,
      false,
      true,
      true,
    ]);
  });

  test('netWorthHistoryFor est bornée à [start, end] plutôt que sur '
      'l\'historique complet (régression : "1M" sur un vieux compte '
      'montrait quasiment tout l\'historique, pas un mois réel)', () {
    final investment = Investment(
      isin: 'FR0012345678',
      label: 'TotalEnergies',
      transactions: [
        Transaction(
          date: DateTime.utc(2024, 1, 1),
          isBuy: true,
          quantity: 10,
          unitPrice: 50,
        ),
      ],
    );
    // "1M" avant le 14/08/2026, sur un compte ouvert bien plus tôt.
    final start = DateTime.utc(2026, 7, 15);
    final end = DateTime.utc(2026, 8, 14);
    final points = netWorthHistoryFor(
      [investment],
      const {},
      start: start,
      end: end,
    );

    expect(points, isNotEmpty);
    for (final p in points) {
      expect(
        p.date.isBefore(start) || p.date.isAfter(end),
        isFalse,
        reason: 'point hors période : ${p.date}',
      );
    }
    expect(points.last.date, end);
  });

  test('netWorthHistoryFor convertit en euros un titre coté en devise '
      'étrangère à la date de chaque point (régression : le dernier point du '
      'graphique — aujourd\'hui — ne correspondait pas à la valeur actuelle '
      'affichée en haut, qui elle applique déjà le taux de change, voir '
      'Investment.marketValue)', () {
    final investment = Investment(
      isin: 'US0378331005',
      label: 'Apple',
      quoteCurrency: 'USD',
      lastFxRateToEur: 0.9,
      transactions: [
        Transaction(
          date: DateTime.utc(2025, 1, 1),
          isBuy: true,
          quantity: 10,
          unitPrice: 150,
        ),
      ],
    );
    final today = DateTime.utc(2026, 8, 14);
    final priceHistories = {
      'US0378331005': [
        PricePoint(DateTime.utc(2025, 1, 1), 150),
        PricePoint(today, 200),
      ],
      // Historique du taux de change synchronisé séparément (voir
      // `price_refresh_service.dart`) sous la clé de la paire elle-même.
      'USDEUR=X': [
        PricePoint(DateTime.utc(2025, 1, 1), 0.9),
        PricePoint(today, 0.92),
      ],
    };

    final points = netWorthHistoryFor(
      [investment],
      priceHistories,
      start: today,
      end: today,
    );

    // 10 actions × 200 $ × 0,92 €/$ = 1840 € — pas 2000 €, le cours brut
    // en dollars traité comme s'il était déjà en euros.
    expect(points.last.value, closeTo(1840, 1e-9));
  });

  test('netWorthHistoryFor retombe sur Investment.lastFxRateToEur sans '
      'historique de taux de change synchronisé pour la paire', () {
    final investment = Investment(
      isin: 'US0378331005',
      label: 'Apple',
      quoteCurrency: 'USD',
      lastFxRateToEur: 0.9,
      transactions: [
        Transaction(
          date: DateTime.utc(2025, 1, 1),
          isBuy: true,
          quantity: 10,
          unitPrice: 150,
        ),
      ],
    );
    final today = DateTime.utc(2026, 8, 14);
    final points = netWorthHistoryFor(
      [investment],
      {
        'US0378331005': [PricePoint(today, 200)],
      },
      start: today,
      end: today,
    );

    // 10 × 200 $ × 0,9 €/$ (repli sur le taux du jour) = 1800 €.
    expect(points.last.value, closeTo(1800, 1e-9));
  });

  test('buildRealTopAssets : changeForPeriod calcule MA performance sur la '
      'position (achat pile au début de l\'historique de cours connu → '
      'coïncide avec le rendement du cours seul)', () {
    final priceHistory = [
      PricePoint(DateTime.utc(2025, 1, 1), 100),
      PricePoint(DateTime.utc(2025, 2, 1), 120),
    ];
    final account = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      investments: [
        Investment(
          isin: 'FR0012345678',
          label: 'TotalEnergies',
          transactions: [
            Transaction(
              date: DateTime.utc(2025, 1, 1),
              isBuy: true,
              quantity: 5,
              unitPrice: 90,
            ),
          ],
        ),
      ],
    );
    final asset = buildRealTopAssets(
      [account],
      {'FR0012345678': priceHistory},
    ).single;

    // Détenue depuis le tout début de l'historique connu (100) jusqu'au
    // dernier cours (120) : +20 %, 5 × (120 − 100) = +100 €.
    final change = asset.changeForPeriod(DashboardPeriod.all);
    expect(change!.percent, closeTo(20, 1e-6));
    expect(change.euros, closeTo(100, 1e-6));
  });

  test('buildRealTopAssets : changeForPeriod reflète MA performance, pas '
      'celle du titre depuis son plus ancien cours connu — un achat fait '
      'après un pic n\'hérite pas de la hausse antérieure à mon achat', () {
    final priceHistory = [
      PricePoint(DateTime.utc(2025, 1, 1), 100),
      PricePoint(DateTime.utc(2025, 1, 15), 150),
      PricePoint(DateTime.utc(2025, 2, 1), 120),
    ];
    final account = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      investments: [
        Investment(
          isin: 'FR0012345678',
          label: 'TotalEnergies',
          // Achetée le 20/01, après le pic à 150 du 15/01 — le cours à
          // l'achat (dernier connu à ou avant le 20/01) est donc 150, pas
          // le tout premier cours connu (100) du 01/01.
          transactions: [
            Transaction(
              date: DateTime.utc(2025, 1, 20),
              isBuy: true,
              quantity: 5,
              unitPrice: 140,
            ),
          ],
        ),
      ],
    );
    final asset = buildRealTopAssets(
      [account],
      {'FR0012345678': priceHistory},
    ).single;

    // Achetée à 150 (cours au 20/01), vaut 120 aujourd'hui : -20 %, pas
    // +20 % (ce que donnerait, à tort, un rendement de cours parti du
    // 01/01 — l'ancienne formule, avant ce changement).
    final change = asset.changeForPeriod(DashboardPeriod.all);
    expect(change!.percent, closeTo(-20, 1e-6));
    expect(change.euros, closeTo(-150, 1e-6));
  });

  test('buildRealTopAssets : changeForPeriod reste défini (pas un plantage '
      'du tri de "Mes meilleures performances") sans historique de cours, '
      'avec un gain nul faute de cours pour le mesurer', () {
    final account = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      investments: [
        Investment(
          isin: 'FR0012345678',
          label: 'TotalEnergies',
          transactions: [
            Transaction(
              date: DateTime.utc(2025, 1, 1),
              isBuy: true,
              quantity: 5,
              unitPrice: 90,
            ),
          ],
        ),
      ],
    );
    final asset = buildRealTopAssets([
      account,
    ], const <String, List<PricePoint>>{}).single;

    // Sans historique de cours, la valorisation retombe sur le montant
    // investi (450 €) au départ comme aujourd'hui : gain nul, mais un
    // pourcentage de 0 % reste défini (netInvested > 0) — pas `null`.
    final change = asset.changeForPeriod(DashboardPeriod.all);
    expect(change!.euros, closeTo(0, 1e-6));
    expect(change.percent, closeTo(0, 1e-6));
  });

  test('buildRealCategories : une position entièrement vendue (quantité '
      'nulle) est exclue, une position partiellement vendue reste', () {
    final cto = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO Bourso',
      bankName: 'Bourso',
      investments: [
        Investment(
          id: 'sold-out',
          isin: 'FR0000120271',
          label: 'Totalement vendu',
          lastPrice: 50,
          transactions: [
            Transaction(
              date: DateTime.utc(2024, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 40,
            ),
            Transaction(
              date: DateTime.utc(2025, 1, 1),
              isBuy: false,
              quantity: 10,
              unitPrice: 50,
            ),
          ],
        ),
        Investment(
          id: 'still-held',
          isin: 'FR0012345678',
          label: 'Encore détenu',
          lastPrice: 50,
          transactions: [
            Transaction(
              date: DateTime.utc(2024, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 40,
            ),
            Transaction(
              date: DateTime.utc(2025, 1, 1),
              isBuy: false,
              quantity: 4,
              unitPrice: 50,
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

    expect(actions.accounts, hasLength(1));
    expect(actions.accounts.single.id, 'still-held');
  });

  test('un investissement exclu du patrimoine reste visible et compte '
      'toujours dans le total propre de sa catégorie, mais pas dans '
      'montantPatrimoine (le seul agrégat que lit la carte Allocation)', () {
    final cto = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO Bourso',
      bankName: 'Bourso',
      investments: [
        Investment(
          id: 'excluded',
          isin: 'FR0000120271',
          label: 'Exclu du patrimoine',
          lastPrice: 50,
          excludedFromPatrimoine: true,
          transactions: [
            Transaction(
              date: DateTime.utc(2024, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 40,
            ),
          ],
        ),
        Investment(
          id: 'counted',
          isin: 'FR0012345678',
          label: 'Compté normalement',
          lastPrice: 50,
          transactions: [
            Transaction(
              date: DateTime.utc(2024, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 40,
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

    // Reste visible (positions bien tenues) : les deux lignes sont là.
    expect(actions.accounts, hasLength(2));
    expect(
      actions.accounts.map((a) => a.id),
      containsAll(['excluded', 'counted']),
    );
    // Le total propre de la catégorie compte les deux positions (500 +
    // 500 = 1000 €) : la page de détail continue de tout comptabiliser.
    expect(actions.montant, 1000);
    // Seul l'agrégat dédié à la carte Allocation ignore la position
    // exclue.
    expect(actions.montantPatrimoine, 500);
  });

  test('buildRealTopAssets exclut un investissement marqué '
      'excludedFromPatrimoine (n\'a pas sa place dans un classement de '
      'performance)', () {
    final account = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      investments: [
        Investment(
          isin: 'FR0012345678',
          label: 'Exclu',
          excludedFromPatrimoine: true,
          transactions: [
            Transaction(
              date: DateTime.utc(2025, 1, 1),
              isBuy: true,
              quantity: 5,
              unitPrice: 90,
            ),
          ],
        ),
      ],
    );

    final assets = buildRealTopAssets([
      account,
    ], const <String, List<PricePoint>>{});
    expect(assets, isEmpty);
  });

  test('netWorthHistoryFor compte toujours un investissement exclu du '
      'patrimoine (la page de catégorie garde son vrai historique) — seul '
      'investmentsForEffectiveClass(excludeFlagged: true) le filtre en amont, '
      'pour la courbe globale du Dashboard', () {
    final priceHistory = [
      PricePoint(DateTime.utc(2025, 1, 1), 100),
      PricePoint(DateTime.utc(2025, 2, 1), 120),
    ];
    final counted = Investment(
      isin: 'COUNTED',
      label: 'Compté',
      transactions: [
        Transaction(
          date: DateTime.utc(2025, 1, 1),
          isBuy: true,
          quantity: 1,
          unitPrice: 100,
        ),
      ],
    );
    final excluded = Investment(
      isin: 'EXCLUDED',
      label: 'Exclu',
      excludedFromPatrimoine: true,
      transactions: [
        Transaction(
          date: DateTime.utc(2025, 1, 1),
          isBuy: true,
          quantity: 1,
          unitPrice: 100,
        ),
      ],
    );

    final withBoth = netWorthHistoryFor(
      [counted, excluded],
      {'COUNTED': priceHistory, 'EXCLUDED': priceHistory},
      start: DateTime.utc(2025, 2, 1),
      end: DateTime.utc(2025, 2, 1),
    );
    final countedOnly = netWorthHistoryFor(
      [counted],
      {'COUNTED': priceHistory},
      start: DateTime.utc(2025, 2, 1),
      end: DateTime.utc(2025, 2, 1),
    );

    // 120 (compté) + 120 (exclu, mais netWorthHistoryFor ne filtre plus
    // rien lui-même) ≠ 120 seul.
    expect(withBoth.last.value, 2 * countedOnly.last.value);
  });

  test(
    'investmentsForEffectiveClass(excludeFlagged: true) omet un '
    'investissement individuel exclu et tout un compte marqué exclu — '
    'c\'est le seul filtre appliqué avant la courbe globale du Dashboard',
    () {
      final normalAccount = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO compté',
        investments: [
          Investment(isin: 'A', label: 'Compté', transactions: const []),
          Investment(
            isin: 'B',
            label: 'Exclu individuellement',
            excludedFromPatrimoine: true,
            transactions: const [],
          ),
        ],
      );
      final excludedAccount = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO exclu en entier',
        excludedFromPatrimoine: true,
        investments: [
          Investment(
            isin: 'C',
            label: 'Dans un compte exclu',
            transactions: const [],
          ),
        ],
      );

      final all = investmentsForEffectiveClass([
        normalAccount,
        excludedAccount,
      ], AssetClass.actionsEtFonds);
      expect(all.map((i) => i.isin), containsAll(['A', 'B', 'C']));

      final onlyCounted = investmentsForEffectiveClass(
        [normalAccount, excludedAccount],
        AssetClass.actionsEtFonds,
        excludeFlagged: true,
      );
      expect(onlyCounted.map((i) => i.isin), ['A']);
    },
  );

  test('netWorthHistoryFor reflète le cours estimé à la main d\'un objet '
      '"Autres" — pas seulement le montant investi, qui ne bougeait jamais '
      'quand l\'estimation était mise à jour (régression signalée)', () {
    final watch = Investment(
      isin: 'autre-1',
      label: 'Rolex Submariner',
      assetClass: AssetClass.autres,
      manualPrice: 450,
      manualPriceAt: DateTime.utc(2026, 8, 20),
      transactions: [
        Transaction(
          date: DateTime.utc(2026, 1, 1),
          isBuy: true,
          quantity: 1,
          unitPrice: 1,
        ),
      ],
    );

    final today = DateTime.utc(2026, 8, 27);
    final points = netWorthHistoryFor(
      [watch],
      const <String, List<PricePoint>>{},
      start: today,
      end: today,
    );

    // Aujourd'hui (après manualPriceAt) : le cours estimé (450 €), pas le
    // montant investi (1 €, resté figé quel que soit le cours saisi).
    expect(points.last.value, 450);
  });

  test('netWorthHistoryFor retombe sur le montant investi avant la date de '
      'l\'estimation manuelle (aucun historique de cours antérieur connu)', () {
    final watch = Investment(
      isin: 'autre-1',
      label: 'Rolex Submariner',
      assetClass: AssetClass.autres,
      manualPrice: 450,
      manualPriceAt: DateTime.utc(2026, 8, 20),
      transactions: [
        Transaction(
          date: DateTime.utc(2026, 1, 1),
          isBuy: true,
          quantity: 1,
          unitPrice: 1,
        ),
      ],
    );

    final beforeEstimate = DateTime.utc(2026, 6, 1);
    final points = netWorthHistoryFor(
      [watch],
      const <String, List<PricePoint>>{},
      start: beforeEstimate,
      end: beforeEstimate,
    );

    expect(points.last.value, 1);
  });

  test('netWorthHistoryFor multiplie le cours manuel par la quantité détenue '
      'à la date évaluée, pas la quantité actuelle', () {
    final watches = Investment(
      isin: 'autre-1',
      label: 'Montres identiques',
      assetClass: AssetClass.autres,
      manualPrice: 100,
      manualPriceAt: DateTime.utc(2026, 1, 1),
      transactions: [
        Transaction(
          date: DateTime.utc(2026, 1, 1),
          isBuy: true,
          quantity: 1,
          unitPrice: 80,
        ),
        Transaction(
          date: DateTime.utc(2026, 6, 1),
          isBuy: true,
          quantity: 1,
          unitPrice: 90,
        ),
      ],
    );

    final beforeSecondBuy = DateTime.utc(2026, 3, 1);
    final afterSecondBuy = DateTime.utc(2026, 8, 1);

    final before = netWorthHistoryFor(
      [watches],
      const <String, List<PricePoint>>{},
      start: beforeSecondBuy,
      end: beforeSecondBuy,
    );
    final after = netWorthHistoryFor(
      [watches],
      const <String, List<PricePoint>>{},
      start: afterSecondBuy,
      end: afterSecondBuy,
    );

    expect(before.last.value, 100);
    expect(after.last.value, 200);
  });

  test('un objet "Autres" reçu en cadeau (prix d\'achat 0) a un '
      'plusValuePercent nul, pas infini — le montant de plus-value reste '
      'affiché seul', () {
    final gift = InvestmentAccount(
      assetClass: AssetClass.autres,
      envelope: AccountEnvelope.montre,
      name: 'Montre offerte',
      investments: [
        Investment(
          isin: 'autre-1',
          label: 'Montre offerte',
          manualPrice: 500,
          transactions: [
            Transaction(
              date: DateTime.utc(2024, 1, 1),
              isBuy: true,
              quantity: 1,
              unitPrice: 0,
            ),
          ],
        ),
      ],
    );

    final categories = buildRealCategories(
      [gift],
      const <String, List<PricePoint>>{},
      '/vault',
    );
    final autres = categories.singleWhere(
      (c) => c.id == AssetClass.autres.categoryId,
    );
    final row = autres.accounts.single;

    expect(row.plusValueAbs, 500);
    expect(row.plusValuePercent, isNull);
  });

  group('buildRealCategoriesByInvestment', () {
    test('un même ISIN détenu dans deux comptes fusionne en une ligne : '
        'quantité/valeur/plus-value sommées, PRU en moyenne pondérée', () {
      final pea = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.pea,
        name: 'PEA Bourso',
        bankName: 'Bourso',
        investments: [
          Investment(
            isin: 'US0378331005',
            label: 'Apple',
            lastPrice: 120,
            lastPriceDate: DateTime.utc(2024, 6, 1),
            transactions: [
              Transaction(
                date: DateTime.utc(2024, 1, 1),
                isBuy: true,
                quantity: 10,
                unitPrice: 100,
              ),
            ],
          ),
        ],
      );
      final cto = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO Bourso',
        bankName: 'Bourso',
        investments: [
          Investment(
            isin: 'US0378331005',
            label: 'Apple',
            // Même cours que la position du PEA (le même titre réel a un
            // seul cours de marché) : sans lui, cette position retomberait
            // sur son montant investi (voir `Investment.effectiveMarketValue`),
            // ce qui fausserait la vérification de la valeur fusionnée.
            lastPrice: 120,
            lastPriceDate: DateTime.utc(2024, 5, 1),
            transactions: [
              Transaction(
                date: DateTime.utc(2024, 3, 1),
                isBuy: true,
                quantity: 5,
                unitPrice: 130,
              ),
            ],
          ),
        ],
      );

      final categories = buildRealCategoriesByInvestment(
        [pea, cto],
        const <String, List<PricePoint>>{},
        '/vault',
      );
      final actions = categories.singleWhere(
        (c) => c.id == AssetClass.actionsEtFonds.categoryId,
      );
      final merged = actions.accounts.single;

      // Quantité (10 + 5) et coût investi (1000 + 650) sommés, PRU
      // recalculé sur l'ensemble (1650 / 15), pas la simple moyenne des
      // deux PRU individuels (100 et 130).
      expect(merged.quantite, 15);
      expect(merged.pru, closeTo(110, 0.001));
      // Cours de marché partagé (le même titre réel).
      expect(merged.cours, 120);
      // Valeur (10*120 + 5*120) et plus-value ((1200-1000) + (600-650)).
      expect(merged.valeur, 1800);
      expect(merged.plusValueAbs, 150);
      expect(merged.plusValuePercent, closeTo(150 / 1650 * 100, 0.001));
      // La plus récente des deux dates de cours (PEA : 1er juin).
      expect(merged.lastPriceDate, DateTime.utc(2024, 6, 1));
      expect(merged.subtitle, '2 comptes');
      // Détail par compte disponible pour le second niveau de
      // l'accordéon (voir `_AccountAccordionTile`).
      expect(merged.investments, hasLength(2));
      expect(
        merged.investments.map((i) => i.quantite),
        containsAll(<double>[10, 5]),
      );
    });

    test('un ISIN détenu dans un seul compte n\'est pas fusionné : ligne '
        'identique à `buildRealCategories`, sans détail par compte', () {
      final cto = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO Bourso',
        bankName: 'Bourso',
        investments: [
          Investment(
            isin: 'US0378331005',
            label: 'Apple',
            transactions: [
              Transaction(
                date: DateTime.utc(2024, 1, 1),
                isBuy: true,
                quantity: 10,
                unitPrice: 100,
              ),
            ],
          ),
        ],
      );

      final byInvestment = buildRealCategoriesByInvestment(
        [cto],
        const <String, List<PricePoint>>{},
        '/vault',
      ).singleWhere((c) => c.id == AssetClass.actionsEtFonds.categoryId);
      final byActif = buildRealCategories(
        [cto],
        const <String, List<PricePoint>>{},
        '/vault',
      ).singleWhere((c) => c.id == AssetClass.actionsEtFonds.categoryId);

      expect(byInvestment.accounts.single.id, byActif.accounts.single.id);
      expect(
        byInvestment.accounts.single.quantite,
        byActif.accounts.single.quantite,
      );
      expect(byInvestment.accounts.single.investments, isEmpty);
    });

    test('une position exclue du patrimoine sur un seul des deux comptes ne '
        'marque pas la ligne fusionnée — seule une exclusion sur les deux '
        'comptes le fait', () {
      InvestmentAccount account(String name, bool excluded) =>
          InvestmentAccount(
            assetClass: AssetClass.actionsEtFonds,
            envelope: AccountEnvelope.cto,
            name: name,
            bankName: name,
            investments: [
              Investment(
                isin: 'US0378331005',
                label: 'Apple',
                excludedFromPatrimoine: excluded,
                transactions: [
                  Transaction(
                    date: DateTime.utc(2024, 1, 1),
                    isBuy: true,
                    quantity: 1,
                    unitPrice: 100,
                  ),
                ],
              ),
            ],
          );

      final partial = buildRealCategoriesByInvestment(
        [account('A', true), account('B', false)],
        const <String, List<PricePoint>>{},
        '/vault',
      ).singleWhere((c) => c.id == AssetClass.actionsEtFonds.categoryId);
      expect(partial.accounts.single.excludedFromPatrimoine, isFalse);

      final both = buildRealCategoriesByInvestment(
        [account('A', true), account('B', true)],
        const <String, List<PricePoint>>{},
        '/vault',
      ).singleWhere((c) => c.id == AssetClass.actionsEtFonds.categoryId);
      expect(both.accounts.single.excludedFromPatrimoine, isTrue);
    });
  });
}

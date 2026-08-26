import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/currency_data.dart';
import 'package:opime/features/investments/investments_models.dart';

void main() {
  InvestmentAccount account({String? description, DateTime? openingDate}) =>
      InvestmentAccount(
        assetClass: AssetClass.epargne,
        envelope: AccountEnvelope.livretA,
        name: 'Boursorama',
        bankName: 'Boursorama',
        description: description,
        openingDate: openingDate,
        investments: const [],
      );

  test('description round-trip JSON', () {
    final a = account(description: 'Épargne vacances');
    final b = InvestmentAccount.fromJson(a.toJson());
    expect(b.description, 'Épargne vacances');
  });

  test('description absente (ou vide) round-trip vers null', () {
    final a = account();
    final b = InvestmentAccount.fromJson(a.toJson());
    expect(b.description, isNull);
  });

  test('copyWith efface la description avec null explicite', () {
    final a = account(description: 'Épargne vacances');
    expect(a.copyWith(description: null).description, isNull);
    // Paramètre non fourni : la description est conservée.
    expect(a.copyWith(name: 'Renommé').description, 'Épargne vacances');
  });

  test('openingDate round-trip JSON (jour calendaire conservé)', () {
    final a = account(openingDate: DateTime(2021, 3, 15));
    final b = InvestmentAccount.fromJson(a.toJson());
    expect(b.openingDate, DateTime(2021, 3, 15));
  });

  test('openingDate absente round-trip vers null', () {
    final a = account();
    final b = InvestmentAccount.fromJson(a.toJson());
    expect(b.openingDate, isNull);
  });

  test('copyWith efface la date d\'ouverture avec null explicite', () {
    final a = account(openingDate: DateTime(2021, 3, 15));
    expect(a.copyWith(openingDate: null).openingDate, isNull);
    // Paramètre non fourni : la date est conservée.
    expect(a.copyWith(name: 'Renommé').openingDate, DateTime(2021, 3, 15));
  });

  test('accountHasOpeningDate : comptes d\'investissement uniquement', () {
    // Classes à établissement : la date d'ouverture a un sens.
    expect(accountHasOpeningDate(AssetClass.epargne), isTrue);
    expect(accountHasOpeningDate(AssetClass.actionsEtFonds), isTrue);
    expect(accountHasOpeningDate(AssetClass.privateEquity), isTrue);
    expect(accountHasOpeningDate(AssetClass.autres), isTrue);
    // Crypto, métaux et immobilier : pas de date d'ouverture.
    expect(accountHasOpeningDate(AssetClass.crypto), isFalse);
    expect(accountHasOpeningDate(AssetClass.metauxPrecieux), isFalse);
    expect(accountHasOpeningDate(AssetClass.immobilier), isFalse);
  });

  test('requiresLabelFieldFor : pas de libellé séparé pour l\'épargne', () {
    expect(requiresLabelFieldFor(AssetClass.epargne), isFalse);
    expect(
      requiresLabelFieldFor(
        AssetClass.metauxPrecieux,
        accountEnvelope: AccountEnvelope.coffrePersonnel,
      ),
      isFalse,
    );
    // Un ETC métaux dans un CTO est un titre coté : libellé séparé.
    expect(
      requiresLabelFieldFor(
        AssetClass.metauxPrecieux,
        accountEnvelope: AccountEnvelope.cto,
      ),
      isTrue,
    );
    expect(requiresLabelFieldFor(AssetClass.actionsEtFonds), isTrue);
  });

  test(
    '"Autres" n\'a pas de notion d\'établissement financier : pas d\'étape '
    '"Quel établissement ?", pas de champ banque (comme la crypto, '
    'l\'immobilier)',
    () {
      expect(assetClassRequiresEstablishmentStep(AssetClass.autres), isFalse);
      expect(assetClassSupportsBankName(AssetClass.autres), isFalse);
      // Contrairement à l'épargne/aux comptes-titres, qui en ont bien un.
      expect(assetClassRequiresEstablishmentStep(AssetClass.epargne), isTrue);
      expect(assetClassSupportsBankName(AssetClass.epargne), isTrue);
    },
  );

  test(
    'identifierOptionsFor : l\'épargne propose la liste des devises connues',
    () {
      expect(identifierOptionsFor(AssetClass.epargne), kKnownCurrencies);
    },
  );

  group('excludedFromPatrimoine (Investment)', () {
    Investment investment({bool excluded = false}) => Investment(
      isin: 'FR0000131104',
      label: 'BNP Paribas',
      transactions: [
        Transaction(date: DateTime(2024, 1, 1), isBuy: true, quantity: 10, unitPrice: 50),
      ],
      excludedFromPatrimoine: excluded,
    );

    test('faux par défaut', () {
      expect(investment().excludedFromPatrimoine, isFalse);
    });

    test('round-trip JSON quand vrai', () {
      final a = investment(excluded: true);
      final b = Investment.fromJson(a.toJson());
      expect(b.excludedFromPatrimoine, isTrue);
    });

    test('absent du JSON quand faux (ne alourdit pas les comptes existants)', () {
      expect(investment().toJson().containsKey('excludedFromPatrimoine'), isFalse);
    });

    test('copyWith bascule le drapeau', () {
      final a = investment();
      expect(a.copyWith(excludedFromPatrimoine: true).excludedFromPatrimoine, isTrue);
      // Paramètre non fourni : conserve la valeur existante.
      expect(a.copyWith(symbol: 'BNP').excludedFromPatrimoine, isFalse);
    });

    test(
      'InvestmentAccount.totalMarketValue/totalInvested continuent de '
      'compter un investissement marqué (seuls les agrégats globaux du '
      'Dashboard l\'ignorent, pas le total propre du compte)',
      () {
        final acc = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO',
          investments: [
            investment(), // 10 * 50 = 500 investis
            investment(excluded: true), // 10 * 50 = 500 investis aussi
          ],
        );
        expect(acc.totalInvested, 1000);
        expect(acc.totalMarketValue, 1000);
      },
    );
  });

  group('excludedFromPatrimoine (InvestmentAccount)', () {
    InvestmentAccount account({bool excluded = false}) => InvestmentAccount(
      assetClass: AssetClass.autres,
      name: 'Montres',
      investments: const [],
      excludedFromPatrimoine: excluded,
    );

    test('faux par défaut', () {
      expect(account().excludedFromPatrimoine, isFalse);
    });

    test('round-trip JSON quand vrai', () {
      final a = account(excluded: true);
      final b = InvestmentAccount.fromJson(a.toJson());
      expect(b.excludedFromPatrimoine, isTrue);
    });

    test('absent du JSON quand faux (ne alourdit pas les comptes existants)', () {
      expect(
        account().toJson().containsKey('excludedFromPatrimoine'),
        isFalse,
      );
    });

    test('copyWith bascule le drapeau', () {
      final a = account();
      expect(
        a.copyWith(excludedFromPatrimoine: true).excludedFromPatrimoine,
        isTrue,
      );
      // Paramètre non fourni : conserve la valeur existante.
      expect(a.copyWith(name: 'Autre nom').excludedFromPatrimoine, isFalse);
    });
  });

  group('customOtherCategory (InvestmentAccount)', () {
    InvestmentAccount autresAccount({String? customOtherCategory}) =>
        InvestmentAccount(
          assetClass: AssetClass.autres,
          envelope: AccountEnvelope.autre,
          name: customOtherCategory ?? AccountEnvelope.autre.label,
          investments: const [],
          customOtherCategory: customOtherCategory,
        );

    test('round-trip JSON', () {
      final a = autresAccount(customOtherCategory: 'Vins de collection');
      final b = InvestmentAccount.fromJson(a.toJson());
      expect(b.customOtherCategory, 'Vins de collection');
    });

    test('absente round-trip vers null', () {
      final a = autresAccount();
      final b = InvestmentAccount.fromJson(a.toJson());
      expect(b.customOtherCategory, isNull);
    });

    test('copyWith efface le type personnalisé avec null explicite', () {
      final a = autresAccount(customOtherCategory: 'Vins de collection');
      expect(a.copyWith(customOtherCategory: null).customOtherCategory, isNull);
      // Paramètre non fourni : conserve la valeur existante.
      expect(
        a.copyWith(name: 'Renommé').customOtherCategory,
        'Vins de collection',
      );
    });
  });

  group('positions en devise (épargne et comptes-titres)', () {
    final cto = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO Bourso',
      bankName: 'Bourso',
      investments: const [],
    );
    final epargne = InvestmentAccount(
      assetClass: AssetClass.epargne,
      envelope: AccountEnvelope.livretA,
      name: 'Boursorama',
      bankName: 'Boursorama',
      investments: const [],
    );

    Investment devise(String code, {AssetClass? assetClass}) => Investment(
      isin: code,
      label: code,
      assetClass: assetClass,
      transactions: const [],
    );

    test(
      'Investment.isCurrency : une devise logée dans un CTO est reconnue',
      () {
        expect(devise('USD').isCurrency, isTrue);
        expect(devise('usd').isCurrency, isTrue);
        expect(devise('FR0012345678').isCurrency, isFalse);
      },
    );

    test(
      'isCurrencyInvestment : toute épargne est une devise, même hors liste',
      () {
        // Une épargne dont l'identifiant manquerait dans kKnownCurrencies reste
        // une position en devise (règle de l'épargne : l'identifiant EST la
        // devise tenue, voir `identifierOptionsFor`).
        expect(isCurrencyInvestment(epargne, devise('XX')), isTrue);
      },
    );

    test('isCurrencyInvestment : une devise dans un CTO est reconnue, pas un '
        'titre', () {
      expect(isCurrencyInvestment(cto, devise('USD')), isTrue);
      expect(isCurrencyInvestment(cto, devise('FR0012345678')), isFalse);
    });

    test('un titre et une devise peuvent coexister dans le même CTO', () {
      final account = cto.copyWith(
        investments: [devise('USD'), devise('FR0012345678')],
      );
      expect(account.investments.map((i) => isCurrencyInvestment(account, i)), [
        true,
        false,
      ]);
    });

    test(
      'toJson : la devise d\'un CTO garde sa précision au-delà du centime',
      () {
        // Même exigence que l'épargne en devise étrangère (1 JPY ≈ 0,006 €) :
        // un arrondi au centime fausserait la quantité/cours d'un ordre de
        // grandeur.
        final account = cto.copyWith(
          investments: [
            Investment(
              isin: 'JPY',
              label: 'JPY',
              transactions: [
                Transaction(
                  isBuy: true,
                  date: DateTime(2026),
                  quantity: 0.0067,
                  unitPrice: 0.0062,
                ),
              ],
            ),
          ],
        );
        final json = account.toJson();
        final roundTripped = InvestmentAccount.fromJson(json);
        final investment = roundTripped.investments.single;
        expect(investment.quantityHeld, 0.0067);
        expect(investment.pru, closeTo(0.0062, 1e-9));
      },
    );
  });

  group('transactions saisies en devise étrangère (stock picking)', () {
    test('amount : quantité × prix × taux de change, en euros', () {
      // 10 actions META à 173 $, 1 $ ≈ 0,92 € → 1591,60 €.
      final txn = Transaction(
        date: DateTime(2026),
        isBuy: true,
        quantity: 10,
        unitPrice: 173,
        currency: 'USD',
        fxRateToEur: 0.92,
      );
      expect(txn.amount, closeTo(1591.6, 1e-9));
      // Le montant brut reste en dollars, sans conversion.
      expect(txn.amountInCurrency, 1730);
    });

    test('transaction par défaut : euros et taux unitaire', () {
      final txn = Transaction(
        date: DateTime(2026),
        isBuy: true,
        quantity: 2,
        unitPrice: 50,
      );
      expect(txn.currency, 'EUR');
      expect(txn.fxRateToEur, 1.0);
      expect(txn.amount, 100);
    });

    test('toJson : devise et taux persistés, taux en pleine précision', () {
      final json = Transaction(
        date: DateTime(2026),
        isBuy: true,
        quantity: 10,
        unitPrice: 173,
        currency: 'USD',
        fxRateToEur: 0.922378,
      ).toJson();
      expect(json['currency'], 'USD');
      expect(json['fxRateToEur'], 0.922378);
      // Le montant en euros n'est jamais stocké : recalculé à la lecture.
      expect(json.containsKey('amount'), isFalse);
    });

    test(
      'toJson rétro-compatible : une transaction en euros reste minimale',
      () {
        final json = Transaction(
          date: DateTime(2026),
          isBuy: true,
          quantity: 2,
          unitPrice: 50,
        ).toJson();
        expect(json.containsKey('currency'), isFalse);
        expect(json.containsKey('fxRateToEur'), isFalse);
      },
    );

    test(
      'fromJson rétro-compatible : une transaction sans devise est en euros',
      () {
        final txn = Transaction.fromJson({
          'id': 'txn_1',
          'date': '2026-01-01T00:00:00.000',
          'isBuy': true,
          'quantity': 2,
          'unitPrice': 50,
        });
        expect(txn.currency, 'EUR');
        expect(txn.fxRateToEur, 1.0);
        expect(txn.amount, 100);
      },
    );

    test('round-trip JSON d\'une transaction en devise étrangère', () {
      final txn = Transaction(
        id: 'txn_1',
        date: DateTime(2026, 1, 15),
        isBuy: true,
        quantity: 3,
        unitPrice: 173.5,
        currency: 'USD',
        fxRateToEur: 0.9204,
      );
      final roundTripped = Transaction.fromJson(txn.toJson());
      expect(roundTripped.currency, 'USD');
      expect(roundTripped.fxRateToEur, 0.9204);
      expect(roundTripped.amount, closeTo(txn.amount, 1e-9));
    });
  });

  group('investissement coté en devise étrangère', () {
    Investment usStock({
      double? lastPrice,
      String? quoteCurrency,
      double? lastFxRateToEur,
    }) => Investment(
      isin: 'US0378331005',
      label: 'META',
      quoteCurrency: quoteCurrency,
      lastPrice: lastPrice,
      lastFxRateToEur: lastFxRateToEur,
      transactions: const [],
    );

    test('marketValue : quantité × dernier cours × taux de change', () {
      // 10 actions × 173 $ = 1730 $ → 1591,60 €.
      final i =
          usStock(
            lastPrice: 173,
            quoteCurrency: 'USD',
            lastFxRateToEur: 0.92,
          ).copyWith(
            transactions: [
              Transaction(
                date: DateTime(2026),
                isBuy: true,
                quantity: 10,
                unitPrice: 150,
              ),
            ],
          );
      expect(i.marketValue, closeTo(1591.6, 1e-9));
    });

    test(
      'marketValue : sans taux enregistré, vaut quantité × dernier cours',
      () {
        final i = usStock(lastPrice: 100).copyWith(
          transactions: [
            Transaction(
              date: DateTime(2026),
              isBuy: true,
              quantity: 2,
              unitPrice: 90,
            ),
          ],
        );
        expect(i.marketValue, 200);
      },
    );

    test(
      'toJson/fromJson round-trip : devise de cotation et taux conservés',
      () {
        final i = usStock(
          lastPrice: 173.2,
          quoteCurrency: 'USD',
          lastFxRateToEur: 0.9211,
        );
        final roundTripped = Investment.fromJson(i.toJson());
        expect(roundTripped.quoteCurrency, 'USD');
        expect(roundTripped.lastFxRateToEur, 0.9211);
        expect(roundTripped.marketValue, closeTo(i.marketValue!, 1e-9));
      },
    );

    test('toJson minimal pour un titre coté en euros (rétro-compatible)', () {
      final json = usStock(lastPrice: 100).toJson();
      expect(json.containsKey('quoteCurrency'), isFalse);
      expect(json.containsKey('lastFxRateToEur'), isFalse);
    });
  });

  group('isPriceFresh', () {
    Investment withPriceDate(DateTime? date) => Investment(
      isin: 'US0378331005',
      label: 'META',
      transactions: const [],
      lastPrice: 100,
      lastPriceDate: date,
    );

    test('true quand le cours a été récupéré aujourd\'hui', () {
      final now = DateTime.now();
      expect(withPriceDate(now).isPriceFresh, isTrue);
    });

    test('false quand le cours date d\'un jour antérieur', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(withPriceDate(yesterday).isPriceFresh, isFalse);
    });

    test('false sans lastPriceDate (jamais rafraîchi)', () {
      expect(withPriceDate(null).isPriceFresh, isFalse);
    });
  });

  group('FundStyle (style de gestion)', () {
    Investment stock({FundStyle? fundStyle}) => Investment(
      isin: 'FR0000120271',
      label: 'TotalEnergies',
      transactions: const [],
      fundStyle: fundStyle,
    );

    test('toJson/fromJson round-trip quand renseigné', () {
      final roundTripped = Investment.fromJson(
        stock(fundStyle: FundStyle.indiciel).toJson(),
      );
      expect(roundTripped.fundStyle, FundStyle.indiciel);
    });

    test('non classé (null) : clé omise du JSON, reste null au décodage', () {
      final json = stock().toJson();
      expect(json.containsKey('fundStyle'), isFalse);
      expect(Investment.fromJson(json).fundStyle, isNull);
    });

    test(
      'FundStyle.fromName : nom inconnu renvoie null, pas de repli par défaut',
      () {
        expect(FundStyle.fromName('inconnu'), isNull);
        expect(FundStyle.fromName(null), isNull);
      },
    );
  });

  group('Estimation immobilière (surfaceM2/estimatedPricePerSqm)', () {
    Investment property({
      double? surfaceM2,
      double? estimatedPricePerSqm,
      DateTime? estimatedValueAt,
      double buyAmount = 200000,
    }) => Investment(
      isin: 'immo-1',
      label: 'Appartement',
      assetClass: AssetClass.immobilier,
      transactions: [
        Transaction(
          date: DateTime(2020, 1, 1),
          isBuy: true,
          quantity: 1,
          unitPrice: buyAmount,
        ),
      ],
      surfaceM2: surfaceM2,
      estimatedPricePerSqm: estimatedPricePerSqm,
      estimatedValueAt: estimatedValueAt,
    );

    test('round-trip JSON des nouveaux champs', () {
      final original = property(
        surfaceM2: 65,
        estimatedPricePerSqm: 4200,
        estimatedValueAt: DateTime.utc(2026, 8, 15),
      );
      final restored = Investment.fromJson(original.toJson());

      expect(restored.surfaceM2, 65);
      expect(restored.estimatedPricePerSqm, 4200);
      expect(restored.estimatedValueAt, DateTime.utc(2026, 8, 15));
    });

    test('champs absents : clés omises du JSON, restent null au décodage', () {
      final json = property().toJson();
      expect(json.containsKey('surfaceM2'), isFalse);
      expect(json.containsKey('estimatedPricePerSqm'), isFalse);
      expect(json.containsKey('estimatedValueAt'), isFalse);

      final restored = Investment.fromJson(json);
      expect(restored.surfaceM2, isNull);
      expect(restored.estimatedPricePerSqm, isNull);
      expect(restored.estimatedValue, isNull);
    });

    test('estimatedValue null si un seul des deux facteurs est renseigné', () {
      expect(property(surfaceM2: 65).estimatedValue, isNull);
      expect(property(estimatedPricePerSqm: 4200).estimatedValue, isNull);
    });

    test('estimatedValue = surface × prix/m² quand les deux sont connus', () {
      final investment = property(surfaceM2: 65, estimatedPricePerSqm: 4200);
      expect(investment.estimatedValue, 65 * 4200);
    });

    test(
      'effectiveMarketValue retombe sur estimatedValue sans cours de marché',
      () {
        final investment = property(surfaceM2: 65, estimatedPricePerSqm: 4200);
        expect(
          investment.marketValue,
          isNull,
        ); // pas de lastPrice pour l'immobilier
        expect(investment.effectiveMarketValue, 65 * 4200);
      },
    );

    test('unrealizedGain calculé à partir de l\'estimation quand présente', () {
      final investment = property(
        surfaceM2: 65,
        estimatedPricePerSqm: 4200,
        buyAmount: 250000,
      );
      expect(investment.unrealizedGain, 65 * 4200 - 250000);
    });

    test('sans estimation : unrealizedGain reste null (aucune régression)', () {
      final investment = property();
      expect(investment.effectiveMarketValue, isNull);
      expect(investment.unrealizedGain, isNull);
    });
  });

  group('Cours estimé à la main "Autres" (manualPrice)', () {
    Investment collectible({
      double? manualPrice,
      DateTime? manualPriceAt,
      double quantity = 1,
      double buyAmount = 8000,
    }) => Investment(
      isin: 'autre-1',
      label: 'Rolex Submariner',
      assetClass: AssetClass.autres,
      transactions: [
        Transaction(
          date: DateTime(2022, 1, 1),
          isBuy: true,
          quantity: quantity,
          unitPrice: buyAmount / quantity,
        ),
      ],
      manualPrice: manualPrice,
      manualPriceAt: manualPriceAt,
    );

    test('round-trip JSON', () {
      final original = collectible(
        manualPrice: 9500,
        manualPriceAt: DateTime.utc(2026, 8, 15),
      );
      final restored = Investment.fromJson(original.toJson());

      expect(restored.manualPrice, 9500);
      expect(restored.manualPriceAt, DateTime.utc(2026, 8, 15));
    });

    test('absent : clés omises du JSON, restent null au décodage', () {
      final json = collectible().toJson();
      expect(json.containsKey('manualPrice'), isFalse);
      expect(json.containsKey('manualPriceAt'), isFalse);

      final restored = Investment.fromJson(json);
      expect(restored.manualPrice, isNull);
      expect(restored.estimatedValue, isNull);
    });

    test(
      'estimatedValue = cours manuel × quantité détenue (une seule unité)',
      () {
        final investment = collectible(manualPrice: 9500);
        expect(investment.estimatedValue, 9500);
      },
    );

    test(
      'estimatedValue multiplie bien le cours manuel par la quantité '
      'détenue quand elle dépasse 1 (ex : plusieurs objets identiques)',
      () {
        final investment = collectible(manualPrice: 100, quantity: 3);
        expect(investment.quantityHeld, 3);
        expect(investment.estimatedValue, 300);
      },
    );

    test(
      'effectiveMarketValue retombe sur l\'estimation manuelle sans cours '
      'de marché',
      () {
        final investment = collectible(manualPrice: 9500);
        expect(investment.marketValue, isNull);
        expect(investment.effectiveMarketValue, 9500);
      },
    );

    test('unrealizedGain calculé à partir de l\'estimation manuelle', () {
      final investment = collectible(manualPrice: 9500, buyAmount: 8000);
      expect(investment.unrealizedGain, 9500 - 8000);
    });

    test('sans estimation : effectiveMarketValue/unrealizedGain restent null', () {
      final investment = collectible();
      expect(investment.effectiveMarketValue, isNull);
      expect(investment.unrealizedGain, isNull);
    });

    test(
      'copyWith bascule l\'estimation manuelle sans affecter l\'estimation '
      'immobilière (les deux mécanismes ne se recouvrent jamais)',
      () {
        final investment = collectible();
        final updated = investment.copyWith(
          manualPrice: 9500,
          manualPriceAt: DateTime(2026, 8, 15),
        );
        expect(updated.estimatedValue, 9500);
        expect(updated.surfaceM2, isNull);
        expect(updated.estimatedPricePerSqm, isNull);
      },
    );
  });

  group('accountFiscalMilestone', () {
    final today = DateTime(2026, 6, 15);

    test('null sans enveloppe ni date d\'ouverture', () {
      expect(
        accountFiscalMilestone(
          envelope: null,
          openingDate: DateTime(2020, 1, 1),
        ),
        isNull,
      );
      expect(
        accountFiscalMilestone(
          envelope: AccountEnvelope.pea,
          openingDate: null,
        ),
        isNull,
      );
    });

    test(
      'null pour une enveloppe sans jalon à durée fixe (CTO, PER, livret A)',
      () {
        for (final envelope in [
          AccountEnvelope.cto,
          AccountEnvelope.per,
          AccountEnvelope.livretA,
        ]) {
          expect(
            accountFiscalMilestone(
              envelope: envelope,
              openingDate: DateTime(2020, 1, 1),
            ),
            isNull,
          );
        }
      },
    );

    test('PEA : avantage fiscal à 5 ans, non atteint', () {
      final milestone = accountFiscalMilestone(
        envelope: AccountEnvelope.pea,
        openingDate: DateTime(2023, 1, 1),
        today: today,
      )!;
      expect(milestone.kind, FiscalMilestoneKind.avantageFiscal);
      expect(milestone.date, DateTime(2028, 1, 1));
      expect(milestone.reached, isFalse);
    });

    test('PEA-PME : même règle que le PEA (5 ans, avantage fiscal)', () {
      final milestone = accountFiscalMilestone(
        envelope: AccountEnvelope.peaPme,
        openingDate: DateTime(2020, 1, 1),
        today: today,
      )!;
      expect(milestone.kind, FiscalMilestoneKind.avantageFiscal);
      expect(milestone.reached, isTrue);
    });

    test('PEG/PEE : null, le déblocage se calcule par versement, pas sur le '
        'compte entier (voir pegPeeUnlockTranches)', () {
      for (final envelope in [AccountEnvelope.peg, AccountEnvelope.pee]) {
        expect(
          accountFiscalMilestone(
            envelope: envelope,
            openingDate: DateTime(2023, 1, 1),
            today: today,
          ),
          isNull,
        );
      }
    });

    test(
      'Assurance vie/contrat de capitalisation : avantage fiscal à 8 ans',
      () {
        for (final envelope in [
          AccountEnvelope.assuranceVie,
          AccountEnvelope.contratCapitalisation,
        ]) {
          final milestone = accountFiscalMilestone(
            envelope: envelope,
            openingDate: DateTime(2020, 1, 1),
            today: today,
          )!;
          expect(milestone.kind, FiscalMilestoneKind.avantageFiscal);
          expect(milestone.date, DateTime(2028, 1, 1));
          expect(milestone.reached, isFalse);
        }
      },
    );

    test('reached devient vrai exactement à la date du jalon', () {
      final milestone = accountFiscalMilestone(
        envelope: AccountEnvelope.pea,
        openingDate: DateTime(2021, 6, 15),
        today: DateTime(2026, 6, 15),
      )!;
      expect(milestone.date, DateTime(2026, 6, 15));
      expect(milestone.reached, isTrue);
    });

    test('la veille du jalon, reached est encore faux', () {
      final milestone = accountFiscalMilestone(
        envelope: AccountEnvelope.pea,
        openingDate: DateTime(2021, 6, 15),
        today: DateTime(2026, 6, 14),
      )!;
      expect(milestone.reached, isFalse);
    });
  });

  group('pegPeeUnlockTranches', () {
    Transaction buy(DateTime date, double amount) =>
        Transaction(date: date, isBuy: true, quantity: amount, unitPrice: 1);

    test('vide sans investissement', () {
      expect(pegPeeUnlockTranches(investments: const []), isEmpty);
    });

    test('chaque versement se débloque 5 ans après sa propre date, pas '
        'la date du premier versement', () {
      final today = DateTime(2026, 6, 15);
      final investment = Investment(
        isin: 'FR0000000001',
        label: 'Fonds actions',
        transactions: [
          // Intéressement de la 1re année de présence : déjà débloqué.
          buy(DateTime(2020, 1, 1), 1000),
          // Intéressement de la 3e année : pas encore débloqué.
          buy(DateTime(2023, 1, 1), 1000),
        ],
      );

      final tranches = pegPeeUnlockTranches(
        investments: [investment],
        today: today,
      );

      expect(tranches, hasLength(2));
      expect(tranches[0].date, DateTime(2020, 1, 1));
      expect(tranches[0].unlockDate, DateTime(2025, 1, 1));
      expect(tranches[0].unlocked, isTrue);
      expect(tranches[1].date, DateTime(2023, 1, 1));
      expect(tranches[1].unlockDate, DateTime(2028, 1, 1));
      expect(tranches[1].unlocked, isFalse);
    });

    test('ignore les ventes, seuls les versements (achats) comptent', () {
      final investment = Investment(
        isin: 'FR0000000001',
        label: 'Fonds actions',
        transactions: [
          buy(DateTime(2020, 1, 1), 1000),
          Transaction(
            date: DateTime(2021, 1, 1),
            isBuy: false,
            quantity: 100,
            unitPrice: 1,
          ),
        ],
      );

      final tranches = pegPeeUnlockTranches(investments: [investment]);

      expect(tranches, hasLength(1));
      expect(tranches.single.date, DateTime(2020, 1, 1));
    });

    test('agrège les versements de tous les investissements du compte', () {
      final today = DateTime(2026, 6, 15);
      final fondsA = Investment(
        isin: 'FR0000000001',
        label: 'Fonds A',
        transactions: [buy(DateTime(2020, 1, 1), 1000)],
      );
      final fondsB = Investment(
        isin: 'FR0000000002',
        label: 'Fonds B',
        transactions: [buy(DateTime(2024, 1, 1), 500)],
      );

      final tranches = pegPeeUnlockTranches(
        investments: [fondsA, fondsB],
        today: today,
      );

      expect(tranches, hasLength(2));
      // Triées par date de versement croissante, toutes sources confondues.
      expect(tranches[0].amount, 1000);
      expect(tranches[1].amount, 500);
    });
  });
}

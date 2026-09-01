import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/currency_data.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/real_estate/rent_models.dart';

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

  test('accountAcceptsCrossClassInvestment : une SCPI peut se loger dans un '
      'compte Actions & Fonds en assurance vie déjà créé, pas besoin d\'un '
      'compte immobilier dédié — même principe qu\'un ETC métaux dans un '
      'CTO', () {
    final assuranceVie = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.assuranceVie,
      name: 'Boursorama Vie',
      bankName: 'Boursorama',
      investments: const [],
    );
    expect(
      accountAcceptsCrossClassInvestment(assuranceVie, AssetClass.immobilier),
      isTrue,
    );
    // Un autre compte Actions & Fonds (CTO) n'accepte pas de SCPI.
    final cto = assuranceVie.copyWith(envelope: AccountEnvelope.cto);
    expect(
      accountAcceptsCrossClassInvestment(cto, AssetClass.immobilier),
      isFalse,
    );
    // Un compte immobilier n'a, lui, jamais besoin de ce mécanisme (il
    // accepte déjà nativement une SCPI, voir `accountEnvelopesFor`).
    final immobilier = InvestmentAccount(
      assetClass: AssetClass.immobilier,
      envelope: AccountEnvelope.scpi,
      name: 'Biens immobiliers',
      investments: const [],
    );
    expect(
      accountAcceptsCrossClassInvestment(immobilier, AssetClass.immobilier),
      isFalse,
    );
  });

  test('accountEnvelopesFor(AssetClass.immobilier) propose la résidence '
      'secondaire, distincte de la résidence principale', () {
    final envelopes = accountEnvelopesFor(AssetClass.immobilier);
    expect(envelopes, contains(AccountEnvelope.residenceSecondaire));
    expect(envelopes, contains(AccountEnvelope.residencePrincipale));
    expect(
      AccountEnvelope.residenceSecondaire.label,
      'Résidence secondaire',
    );
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

  test('"Autres" n\'a pas de notion d\'établissement financier : pas d\'étape '
      '"Quel établissement ?", pas de champ banque (comme la crypto, '
      'l\'immobilier)', () {
    expect(assetClassRequiresEstablishmentStep(AssetClass.autres), isFalse);
    expect(assetClassSupportsBankName(AssetClass.autres), isFalse);
    // Contrairement à l'épargne/aux comptes-titres, qui en ont bien un.
    expect(assetClassRequiresEstablishmentStep(AssetClass.epargne), isTrue);
    expect(assetClassSupportsBankName(AssetClass.epargne), isTrue);
  });

  test(
    'identifierOptionsFor : l\'épargne propose la liste des devises connues',
    () {
      expect(identifierOptionsFor(AssetClass.epargne), kKnownCurrencies);
    },
  );

  group('isinOptionalFor (fonds PEE/PEG/PER sans ISIN public)', () {
    test('immobilier et "Autres" : toujours facultatif, sans enveloppe', () {
      expect(isinOptionalFor(AssetClass.immobilier), isTrue);
      expect(isinOptionalFor(AssetClass.autres), isTrue);
    });

    test('Actions & Fonds en PEE/PEG/PER : facultatif (fonds interne à '
        'l\'entreprise ou au contrat, souvent sans ISIN public)', () {
      expect(
        isinOptionalFor(
          AssetClass.actionsEtFonds,
          accountEnvelope: AccountEnvelope.peg,
        ),
        isTrue,
      );
      expect(
        isinOptionalFor(
          AssetClass.actionsEtFonds,
          accountEnvelope: AccountEnvelope.pee,
        ),
        isTrue,
      );
      expect(
        isinOptionalFor(
          AssetClass.actionsEtFonds,
          accountEnvelope: AccountEnvelope.per,
        ),
        isTrue,
      );
    });

    test(
      'Actions & Fonds hors PEE/PEG/PER (CTO, PEA...) : ISIN toujours requis',
      () {
        expect(
          isinOptionalFor(
            AssetClass.actionsEtFonds,
            accountEnvelope: AccountEnvelope.cto,
          ),
          isFalse,
        );
        expect(
          isinOptionalFor(
            AssetClass.actionsEtFonds,
            accountEnvelope: AccountEnvelope.pea,
          ),
          isFalse,
        );
        expect(isinOptionalFor(AssetClass.actionsEtFonds), isFalse);
      },
    );

    test('autres classes : ISIN toujours requis', () {
      expect(isinOptionalFor(AssetClass.crypto), isFalse);
      expect(isinOptionalFor(AssetClass.metauxPrecieux), isFalse);
    });

    test(
      'Private Equity : ISIN facultatif — un club deal/FCPR n\'a pas '
      'd\'ISIN, seul le nom du fonds (déjà saisi dans le libellé) l\'identifie',
      () {
        expect(isinOptionalFor(AssetClass.privateEquity), isTrue);
      },
    );
  });

  group('isGeneratedIdentifier (identifiant auto-généré, rien à afficher)', () {
    test('reconnaît les quatre préfixes générés à la création', () {
      expect(isGeneratedIdentifier('immobilier-abc123'), isTrue);
      expect(isGeneratedIdentifier('autre-abc123'), isTrue);
      expect(isGeneratedIdentifier('fcpe-abc123'), isTrue);
      expect(isGeneratedIdentifier('pe-abc123'), isTrue);
    });

    test('un vrai ISIN, ticker ou référence saisie n\'est pas confondu', () {
      expect(isGeneratedIdentifier('FR0000131104'), isFalse);
      expect(isGeneratedIdentifier('US0378331005'), isFalse);
      expect(isGeneratedIdentifier('BTC'), isFalse);
      // Une référence saisie à la main qui contiendrait ces mots ne doit
      // matcher que si elle commence bien par le préfixe technique complet
      // suivi d'un tiret, pas juste "au hasard".
      expect(isGeneratedIdentifier('Autres infos'), isFalse);
      expect(isGeneratedIdentifier(''), isFalse);
    });
  });

  group('excludedFromPatrimoine (Investment)', () {
    Investment investment({bool excluded = false}) => Investment(
      isin: 'FR0000131104',
      label: 'BNP Paribas',
      transactions: [
        Transaction(
          date: DateTime(2024, 1, 1),
          isBuy: true,
          quantity: 10,
          unitPrice: 50,
        ),
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

    test(
      'absent du JSON quand faux (ne alourdit pas les comptes existants)',
      () {
        expect(
          investment().toJson().containsKey('excludedFromPatrimoine'),
          isFalse,
        );
      },
    );

    test('copyWith bascule le drapeau', () {
      final a = investment();
      expect(
        a.copyWith(excludedFromPatrimoine: true).excludedFromPatrimoine,
        isTrue,
      );
      // Paramètre non fourni : conserve la valeur existante.
      expect(a.copyWith(symbol: 'BNP').excludedFromPatrimoine, isFalse);
    });

    test('InvestmentAccount.totalMarketValue/totalInvested continuent de '
        'compter un investissement marqué (seuls les agrégats globaux du '
        'Dashboard l\'ignorent, pas le total propre du compte)', () {
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
    });
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

    test(
      'absent du JSON quand faux (ne alourdit pas les comptes existants)',
      () {
        expect(
          account().toJson().containsKey('excludedFromPatrimoine'),
          isFalse,
        );
      },
    );

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

    test(
      'round-trip JSON de manualUnlockDate (déblocage anticipé PEG/PEE)',
      () {
        final txn = Transaction(
          id: 'txn_1',
          date: DateTime(2023, 1, 1),
          isBuy: true,
          quantity: 1000,
          unitPrice: 1,
          manualUnlockDate: DateTime(2024, 3, 1),
        );
        final roundTripped = Transaction.fromJson(txn.toJson());
        expect(roundTripped.manualUnlockDate, DateTime(2024, 3, 1));
      },
    );

    test('manualUnlockDate absente round-trip vers null (pas sérialisée)', () {
      final txn = Transaction(
        date: DateTime(2023, 1, 1),
        isBuy: true,
        quantity: 1000,
        unitPrice: 1,
      );
      expect(txn.toJson().containsKey('manualUnlockDate'), isFalse);
      expect(Transaction.fromJson(txn.toJson()).manualUnlockDate, isNull);
    });

    test(
      'round-trip JSON de linkedTransactionId (paire transfert/arbitrage)',
      () {
        final txn = Transaction(
          id: 'txn_1',
          date: DateTime(2026, 1, 1),
          isBuy: false,
          quantity: 10,
          unitPrice: 100,
          type: TransactionType.transfer,
          linkedTransactionId: 'txn_2',
        );
        final roundTripped = Transaction.fromJson(txn.toJson());
        expect(roundTripped.linkedTransactionId, 'txn_2');
        expect(roundTripped.type, TransactionType.transfer);
      },
    );

    test(
      'linkedTransactionId absente round-trip vers null (pas sérialisée)',
      () {
        final txn = Transaction(
          date: DateTime(2023, 1, 1),
          isBuy: true,
          quantity: 1000,
          unitPrice: 1,
        );
        expect(txn.toJson().containsKey('linkedTransactionId'), isFalse);
        expect(Transaction.fromJson(txn.toJson()).linkedTransactionId, isNull);
      },
    );

    test('TransactionType.transfer/.arbitrage ont leurs propres libellés, '
        'affichés via displayLabel des deux côtés de la paire (achat comme '
        'vente) plutôt que "Achat"/"Vente"', () {
      expect(TransactionType.transfer.label, 'Transfert');
      expect(TransactionType.arbitrage.label, 'Arbitrage');
      final sell = Transaction(
        date: DateTime(2026, 1, 1),
        isBuy: false,
        quantity: 1,
        unitPrice: 1,
        type: TransactionType.transfer,
      );
      final buy = Transaction(
        date: DateTime(2026, 1, 1),
        isBuy: true,
        quantity: 1,
        unitPrice: 1,
        type: TransactionType.transfer,
      );
      expect(sell.displayLabel, 'Transfert');
      expect(buy.displayLabel, 'Transfert');
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

  group('rentPeriods/workItems (Investment immobilier)', () {
    Investment property({
      List<RentPeriod> rentPeriods = const [],
      List<WorkItem> workItems = const [],
    }) => Investment(
      isin: 'immobilier-abc123',
      label: 'Appartement Lyon 6e',
      realEstateType: RealEstateType.locationLongueDureeNue,
      transactions: [
        Transaction(date: DateTime(2020, 1, 1), isBuy: true, quantity: 1, unitPrice: 250000),
      ],
      rentPeriods: rentPeriods,
      workItems: workItems,
    );

    test('round-trip JSON conserve les deux listes', () {
      final rent = RentPeriod(
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 1, 31),
        amountDue: 800,
      );
      final work = WorkItem(
        label: 'Peinture',
        amount: 800,
        date: DateTime(2026, 2, 1),
      );
      final original = property(rentPeriods: [rent], workItems: [work]);
      final restored = Investment.fromJson(original.toJson());

      expect(restored.rentPeriods, hasLength(1));
      expect(restored.rentPeriods.single.id, rent.id);
      expect(restored.workItems, hasLength(1));
      expect(restored.workItems.single.id, work.id);
    });

    test('listes vides : clés omises du JSON, restent vides au décodage '
        '(pas null)', () {
      final json = property().toJson();
      expect(json.containsKey('rentPeriods'), isFalse);
      expect(json.containsKey('workItems'), isFalse);

      final restored = Investment.fromJson(json);
      expect(restored.rentPeriods, isEmpty);
      expect(restored.workItems, isEmpty);
    });

    test(
      'copyWith reporte les deux listes quand non explicitement changées '
      '(régression : une reconstruction manuelle de Investment — voir '
      '_commitEditInvestment — pourrait les oublier)',
      () {
        final rent = RentPeriod(
          periodStart: DateTime(2026, 1, 1),
          periodEnd: DateTime(2026, 1, 31),
          amountDue: 800,
        );
        final work = WorkItem(
          label: 'Peinture',
          amount: 800,
          date: DateTime(2026, 2, 1),
        );
        final original = property(rentPeriods: [rent], workItems: [work]);
        final edited = original.copyWith(
          realEstateType: RealEstateType.residencePrincipale,
        );

        expect(edited.rentPeriods, [rent]);
        expect(edited.workItems, [work]);
      },
    );
  });

  group('VaultDocument.category (regroupement immobilier : Facture/Plan/'
      'Photo/Quittance/Autre)', () {
    test('round-trip JSON conserve la catégorie', () {
      final doc = VaultDocument(fileName: 'facture.pdf', category: 'Facture');
      final restored = VaultDocument.fromJson(doc.toJson());
      expect(restored.category, 'Facture');
    });

    test('sans catégorie : clé omise du JSON, reste null au décodage '
        '(rétrocompatible avec les documents existants hors immobilier)', () {
      final doc = VaultDocument(fileName: 'contrat.pdf');
      final json = doc.toJson();
      expect(json.containsKey('category'), isFalse);
      expect(VaultDocument.fromJson(json).category, isNull);
    });

    test('copyWith change la catégorie sans toucher au reste', () {
      final doc = VaultDocument(fileName: 'photo.jpg', note: 'Façade');
      final recategorized = doc.copyWith(category: 'Photo');
      expect(recategorized.category, 'Photo');
      expect(recategorized.fileName, 'photo.jpg');
      expect(recategorized.note, 'Façade');
    });
  });

  group('"Autres" reçu en cadeau (prix d\'achat 0)', () {
    Investment gift({double manualPrice = 500}) => Investment(
      isin: 'autre-1',
      label: 'Montre offerte',
      assetClass: AssetClass.autres,
      manualPrice: manualPrice,
      transactions: [
        Transaction(
          date: DateTime(2024, 1, 1),
          isBuy: true,
          quantity: 1,
          unitPrice: 0,
        ),
      ],
    );

    test('investedAmount et pru valent 0, sans erreur', () {
      final investment = gift();
      expect(investment.investedAmount, 0);
      expect(investment.pru, 0);
    });

    test('unrealizedGain reste défini (montant absolu), pas de division '
        'par zéro', () {
      final investment = gift(manualPrice: 500);
      expect(investment.effectiveMarketValue, 500);
      expect(investment.unrealizedGain, 500);
    });

    test('une vente ultérieure (donné à quelqu\'un d\'autre) reste calculable '
        'normalement', () {
      final investment = gift().copyWith(
        transactions: [
          Transaction(
            date: DateTime(2024, 1, 1),
            isBuy: true,
            quantity: 1,
            unitPrice: 0,
          ),
          Transaction(
            date: DateTime(2025, 1, 1),
            isBuy: false,
            quantity: 1,
            unitPrice: 0,
          ),
        ],
      );
      expect(investment.quantityHeld, 0);
      expect(investment.investedAmount, 0);
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

    test('estimatedValue multiplie bien le cours manuel par la quantité '
        'détenue quand elle dépasse 1 (ex : plusieurs objets identiques)', () {
      final investment = collectible(manualPrice: 100, quantity: 3);
      expect(investment.quantityHeld, 3);
      expect(investment.estimatedValue, 300);
    });

    test('effectiveMarketValue retombe sur l\'estimation manuelle sans cours '
        'de marché', () {
      final investment = collectible(manualPrice: 9500);
      expect(investment.marketValue, isNull);
      expect(investment.effectiveMarketValue, 9500);
    });

    test('unrealizedGain calculé à partir de l\'estimation manuelle', () {
      final investment = collectible(manualPrice: 9500, buyAmount: 8000);
      expect(investment.unrealizedGain, 9500 - 8000);
    });

    test(
      'sans estimation : effectiveMarketValue/unrealizedGain restent null',
      () {
        final investment = collectible();
        expect(investment.effectiveMarketValue, isNull);
        expect(investment.unrealizedGain, isNull);
      },
    );

    test('copyWith bascule l\'estimation manuelle sans affecter l\'estimation '
        'immobilière (les deux mécanismes ne se recouvrent jamais)', () {
      final investment = collectible();
      final updated = investment.copyWith(
        manualPrice: 9500,
        manualPriceAt: DateTime(2026, 8, 15),
      );
      expect(updated.estimatedValue, 9500);
      expect(updated.surfaceM2, isNull);
      expect(updated.estimatedPricePerSqm, isNull);
    });

    test('fonctionne aussi pour un fonds PEE/PEG sans ISIN (Actions & Fonds) : '
        'manualPrice n\'est pas réservé à "Autres"', () {
      final fcpeFund = Investment(
        isin: 'fcpe-1',
        label: 'FCPE Diversifié Entreprise',
        assetClass: AssetClass.actionsEtFonds,
        manualPrice: 42,
        manualPriceAt: DateTime(2026, 8, 27),
        transactions: [
          Transaction(
            date: DateTime(2024, 1, 1),
            isBuy: true,
            quantity: 10,
            unitPrice: 35,
          ),
        ],
      );
      expect(fcpeFund.marketValue, isNull);
      expect(fcpeFund.estimatedValue, 420);
      expect(fcpeFund.effectiveMarketValue, 420);
      expect(fcpeFund.unrealizedGain, 420 - 350);
    });
  });

  group('Valorisation manuelle Private Equity (manualValuation)', () {
    Investment fund({
      double? manualValuation,
      DateTime? manualValuationAt,
      List<Transaction>? transactions,
    }) => Investment(
      isin: 'pe-1',
      label: 'Ardian Expansion Fund',
      assetClass: AssetClass.privateEquity,
      transactions:
          transactions ??
          [
            Transaction(
              date: DateTime(2022, 1, 1),
              isBuy: true,
              quantity: 1,
              unitPrice: 10000,
            ),
          ],
      manualValuation: manualValuation,
      manualValuationAt: manualValuationAt,
    );

    test('round-trip JSON', () {
      final original = fund(
        manualValuation: 15000,
        manualValuationAt: DateTime.utc(2026, 8, 15),
      );
      final restored = Investment.fromJson(original.toJson());

      expect(restored.manualValuation, 15000);
      expect(restored.manualValuationAt, DateTime.utc(2026, 8, 15));
    });

    test('absent : clés omises du JSON, restent null au décodage', () {
      final json = fund().toJson();
      expect(json.containsKey('manualValuation'), isFalse);
      expect(json.containsKey('manualValuationAt'), isFalse);

      final restored = Investment.fromJson(json);
      expect(restored.manualValuation, isNull);
      expect(restored.estimatedValue, isNull);
    });

    test(
      'estimatedValue = manualValuation tel quel — jamais multiplié par '
      'quantityHeld, contrairement à manualPrice : plusieurs versements '
      '(chacun quantité 1, voir usesTotalAmountTransaction) ne doivent pas '
      'gonfler artificiellement la valorisation du fonds',
      () {
        final investment = fund(
          manualValuation: 15000,
          transactions: [
            Transaction(
              date: DateTime(2022, 1, 1),
              isBuy: true,
              quantity: 1,
              unitPrice: 5000,
            ),
            Transaction(
              date: DateTime(2023, 1, 1),
              isBuy: true,
              quantity: 1,
              unitPrice: 5000,
            ),
          ],
        );
        expect(investment.quantityHeld, 2);
        expect(investment.estimatedValue, 15000);
      },
    );

    test(
      'effectiveMarketValue retombe sur la valorisation manuelle sans cours '
      'de marché',
      () {
        final investment = fund(manualValuation: 15000);
        expect(investment.marketValue, isNull);
        expect(investment.effectiveMarketValue, 15000);
      },
    );

    test('unrealizedGain calculé à partir de la valorisation manuelle', () {
      final investment = fund(manualValuation: 15000);
      expect(investment.unrealizedGain, 15000 - 10000);
    });

    test(
      'sans valorisation : effectiveMarketValue/unrealizedGain restent null '
      '— displayValue retombe sur le capital net investi',
      () {
        final investment = fund();
        expect(investment.effectiveMarketValue, isNull);
        expect(investment.unrealizedGain, isNull);
        expect(investment.displayValue, 10000);
      },
    );

    test(
      'copyWith bascule la valorisation manuelle sans affecter '
      'manualPrice/l\'estimation immobilière (mécanismes indépendants)',
      () {
        final investment = fund();
        final updated = investment.copyWith(
          manualValuation: 15000,
          manualValuationAt: DateTime(2026, 8, 15),
        );
        expect(updated.estimatedValue, 15000);
        expect(updated.manualPrice, isNull);
        expect(updated.surfaceM2, isNull);
      },
    );
  });

  group(
    'usesTotalAmountTransaction (montant total plutôt que quantité × prix)',
    () {
      test('immobilier et Private Equity fonds : montant total', () {
        expect(usesTotalAmountTransaction(AssetClass.immobilier), isTrue);
        expect(usesTotalAmountTransaction(AssetClass.privateEquity), isTrue);
        expect(
          usesTotalAmountTransaction(
            AssetClass.privateEquity,
            privateEquityKind: PrivateEquityKind.fonds,
          ),
          isTrue,
        );
      });

      test(
        'Private Equity actionsSalarie (BSPCE/stock-options/AGA) : '
        'quantité × prix unitaire, comme "Actions & Fonds"',
        () {
          expect(
            usesTotalAmountTransaction(
              AssetClass.privateEquity,
              privateEquityKind: PrivateEquityKind.actionsSalarie,
            ),
            isFalse,
          );
        },
      );

      test('autres classes : quantité × prix unitaire classique', () {
        expect(usesTotalAmountTransaction(AssetClass.actionsEtFonds), isFalse);
        expect(usesTotalAmountTransaction(AssetClass.crypto), isFalse);
        expect(usesTotalAmountTransaction(AssetClass.autres), isFalse);
        expect(usesTotalAmountTransaction(AssetClass.epargne), isFalse);
        expect(usesTotalAmountTransaction(AssetClass.metauxPrecieux), isFalse);
      });
    },
  );

  group(
    'allowsFreeTransactionPrice (prix unitaire nul autorisé — cadeau/AGA)',
    () {
      test('"Autres" et Private Equity actionsSalarie : prix nul autorisé', () {
        expect(allowsFreeTransactionPrice(AssetClass.autres), isTrue);
        expect(
          allowsFreeTransactionPrice(
            AssetClass.privateEquity,
            privateEquityKind: PrivateEquityKind.actionsSalarie,
          ),
          isTrue,
        );
      });

      test(
        'Private Equity fonds (ou sans variante précisée) : prix nul refusé '
        '— un versement à un fonds n\'est jamais gratuit',
        () {
          expect(allowsFreeTransactionPrice(AssetClass.privateEquity), isFalse);
          expect(
            allowsFreeTransactionPrice(
              AssetClass.privateEquity,
              privateEquityKind: PrivateEquityKind.fonds,
            ),
            isFalse,
          );
        },
      );

      test('autres classes : prix nul toujours refusé', () {
        expect(allowsFreeTransactionPrice(AssetClass.actionsEtFonds), isFalse);
        expect(allowsFreeTransactionPrice(AssetClass.crypto), isFalse);
        expect(allowsFreeTransactionPrice(AssetClass.immobilier), isFalse);
      });
    },
  );

  group('PrivateEquityKind (BSPCE/stock-options/AGA vs fonds)', () {
    Investment equityGrant({
      double? manualPrice,
      DateTime? manualPriceAt,
      List<Transaction>? transactions,
    }) => Investment(
      isin: 'pe-2',
      label: 'Ma startup SAS',
      assetClass: AssetClass.privateEquity,
      privateEquityKind: PrivateEquityKind.actionsSalarie,
      transactions:
          transactions ??
          [
            Transaction(
              date: DateTime(2024, 1, 1),
              isBuy: true,
              quantity: 1000,
              unitPrice: 0,
            ),
          ],
      manualPrice: manualPrice,
      manualPriceAt: manualPriceAt,
    );

    test('round-trip JSON de privateEquityKind', () {
      final restored = Investment.fromJson(equityGrant().toJson());
      expect(restored.privateEquityKind, PrivateEquityKind.actionsSalarie);
    });

    test('null au décodage si absent (position créée avant cet ajout)', () {
      final json = Investment(
        isin: 'pe-3',
        label: 'Fonds historique',
        assetClass: AssetClass.privateEquity,
        transactions: const [],
      ).toJson();
      expect(json.containsKey('privateEquityKind'), isFalse);
      expect(Investment.fromJson(json).privateEquityKind, isNull);
    });

    test(
      'estimatedValue = manualPrice × quantityHeld (nombre réel de titres) '
      '— comme "Autres", pas comme manualValuation',
      () {
        final investment = equityGrant(manualPrice: 8);
        expect(investment.quantityHeld, 1000);
        expect(investment.estimatedValue, 8000);
      },
    );

    test('une AGA (prix 0) n\'empêche pas le calcul de plus-value latente', () {
      final investment = equityGrant(manualPrice: 8);
      expect(investment.investedAmount, 0);
      expect(investment.unrealizedGain, 8000);
    });

    test(
      'round-trip JSON de vestingCliffMonths/vestingDurationMonths/'
      'exerciseDeadline',
      () {
        final original = equityGrant().copyWith(
          vestingCliffMonths: 12,
          vestingDurationMonths: 48,
          exerciseDeadline: DateTime.utc(2030, 6, 1),
        );
        final restored = Investment.fromJson(original.toJson());
        expect(restored.vestingCliffMonths, 12);
        expect(restored.vestingDurationMonths, 48);
        expect(restored.exerciseDeadline, DateTime.utc(2030, 6, 1));
      },
    );

    test('absents : clés omises du JSON, restent null au décodage', () {
      final json = equityGrant().toJson();
      expect(json.containsKey('vestingCliffMonths'), isFalse);
      expect(json.containsKey('vestingDurationMonths'), isFalse);
      expect(json.containsKey('exerciseDeadline'), isFalse);
    });
  });

  group('vestedQuantityFor (vesting cliff + durée)', () {
    test('vesting non suivi (cliff ou durée absent) : quantityHeld tel quel', () {
      final investment = Investment(
        isin: 'pe-4',
        label: 'Startup A',
        assetClass: AssetClass.privateEquity,
        privateEquityKind: PrivateEquityKind.actionsSalarie,
        transactions: [
          Transaction(
            date: DateTime(2024, 1, 1),
            isBuy: true,
            quantity: 1000,
            unitPrice: 0,
          ),
        ],
      );
      expect(
        vestedQuantityFor(investment, asOf: DateTime(2025, 1, 1)),
        1000,
      );
    });

    test('avant le cliff : rien de vesté', () {
      final investment = Investment(
        isin: 'pe-5',
        label: 'Startup B',
        assetClass: AssetClass.privateEquity,
        privateEquityKind: PrivateEquityKind.actionsSalarie,
        vestingCliffMonths: 12,
        vestingDurationMonths: 48,
        transactions: [
          Transaction(
            date: DateTime(2024, 1, 1),
            isBuy: true,
            quantity: 1000,
            unitPrice: 0,
          ),
        ],
      );
      expect(
        vestedQuantityFor(investment, asOf: DateTime(2024, 6, 1)),
        0,
      );
    });

    test('exactement au cliff : le prorata déjà écoulé est vesté', () {
      final investment = Investment(
        isin: 'pe-6',
        label: 'Startup C',
        assetClass: AssetClass.privateEquity,
        privateEquityKind: PrivateEquityKind.actionsSalarie,
        vestingCliffMonths: 12,
        vestingDurationMonths: 48,
        transactions: [
          Transaction(
            date: DateTime(2024, 1, 1),
            isBuy: true,
            quantity: 4800,
            unitPrice: 0,
          ),
        ],
      );
      // 12 mois écoulés sur 48 → environ un quart vesté.
      final vested = vestedQuantityFor(investment, asOf: DateTime(2025, 1, 1));
      expect(vested, closeTo(1200, 50));
    });

    test('après la durée complète : tout est vesté', () {
      final investment = Investment(
        isin: 'pe-7',
        label: 'Startup D',
        assetClass: AssetClass.privateEquity,
        privateEquityKind: PrivateEquityKind.actionsSalarie,
        vestingCliffMonths: 12,
        vestingDurationMonths: 48,
        transactions: [
          Transaction(
            date: DateTime(2020, 1, 1),
            isBuy: true,
            quantity: 4800,
            unitPrice: 0,
          ),
        ],
      );
      expect(
        vestedQuantityFor(investment, asOf: DateTime(2026, 1, 1)),
        4800,
      );
    });

    test('une vente est déduite du total vesté', () {
      final investment = Investment(
        isin: 'pe-8',
        label: 'Startup E',
        assetClass: AssetClass.privateEquity,
        privateEquityKind: PrivateEquityKind.actionsSalarie,
        vestingCliffMonths: 0,
        vestingDurationMonths: 12,
        transactions: [
          Transaction(
            date: DateTime(2020, 1, 1),
            isBuy: true,
            quantity: 1000,
            unitPrice: 0,
          ),
          Transaction(
            date: DateTime(2024, 1, 1),
            isBuy: false,
            quantity: 300,
            unitPrice: 5,
          ),
        ],
      );
      expect(
        vestedQuantityFor(investment, asOf: DateTime(2026, 1, 1)),
        700,
      );
    });

    test('plusieurs tranches (grants successifs) vestent indépendamment', () {
      final investment = Investment(
        isin: 'pe-9',
        label: 'Startup F',
        assetClass: AssetClass.privateEquity,
        privateEquityKind: PrivateEquityKind.actionsSalarie,
        vestingCliffMonths: 12,
        vestingDurationMonths: 12,
        transactions: [
          // Entièrement vestée au 1er janvier 2026 (cliff == durée : 100 %
          // dès le cliff atteint).
          Transaction(
            date: DateTime(2020, 1, 1),
            isBuy: true,
            quantity: 500,
            unitPrice: 0,
          ),
          // Pas encore vestée (grant trop récent, cliff pas atteint).
          Transaction(
            date: DateTime(2025, 12, 1),
            isBuy: true,
            quantity: 500,
            unitPrice: 0,
          ),
        ],
      );
      expect(
        vestedQuantityFor(investment, asOf: DateTime(2026, 1, 1)),
        500,
      );
    });
  });

  group('placeholderIsinFor', () {
    test('Private Equity génère un identifiant préfixé "pe-"', () {
      final placeholder = placeholderIsinFor(AssetClass.privateEquity);
      expect(placeholder, startsWith('pe-'));
      expect(isGeneratedIdentifier(placeholder), isTrue);
    });
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

  group('pegPeeUnlockDateFor', () {
    test('5 ans après la date du versement', () {
      expect(pegPeeUnlockDateFor(DateTime(2026, 3, 15)), DateTime(2031, 3, 15));
    });

    test('reste cohérent avec pegPeeUnlockTranches pour la même date', () {
      final date = DateTime(2024, 1, 1);
      final tranches = pegPeeUnlockTranches(
        investments: [
          Investment(
            isin: 'fcpe-1',
            label: 'FCPE',
            transactions: [
              Transaction(date: date, isBuy: true, quantity: 1, unitPrice: 100),
            ],
          ),
        ],
      );
      expect(tranches.single.unlockDate, pegPeeUnlockDateFor(date));
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

    test('une date de déblocage saisie à la main (manualUnlockDate) prend le '
        'pas sur la règle des 5 ans, pour un déblocage anticipé', () {
      final today = DateTime(2026, 6, 15);
      // Achat de la résidence principale : déblocage anticipé, bien avant
      // les 5 ans par défaut.
      final manualUnlockDate = DateTime(2024, 3, 1);
      final investment = Investment(
        isin: 'FR0000000001',
        label: 'Fonds actions',
        transactions: [
          Transaction(
            date: DateTime(2023, 1, 1),
            isBuy: true,
            quantity: 1000,
            unitPrice: 1,
            manualUnlockDate: manualUnlockDate,
          ),
        ],
      );

      final tranches = pegPeeUnlockTranches(
        investments: [investment],
        today: today,
      );

      expect(tranches.single.unlockDate, manualUnlockDate);
      expect(tranches.single.unlocked, isTrue);
    });
  });

  group(
    'displayValue (position soldée : jamais l\'investedAmount résiduel)',
    () {
      test(
        'position ouverte avec cours connu : la valeur de marché habituelle',
        () {
          final investment = Investment(
            isin: 'FR0000131104',
            label: 'TotalEnergies',
            lastPrice: 60,
            transactions: [
              Transaction(
                date: DateTime(2024, 1, 1),
                isBuy: true,
                quantity: 10,
                unitPrice: 50,
              ),
            ],
          );
          expect(investment.displayValue, 600);
        },
      );

      test(
        'position soldée (arbitrage à un cours différent du PRU moyen) : '
        'displayValue vaut 0, pas le résidu algébrique de investedAmount',
        () {
          final investment = Investment(
            isin: 'FR0000131104',
            label: 'TotalEnergies',
            transactions: [
              Transaction(
                date: DateTime(2024, 1, 1),
                isBuy: true,
                quantity: 10,
                unitPrice: 50,
              ),
              // Vendue au cours du marché (60), différent du PRU (50) — un
              // arbitrage réalise sa plus-value, laissant un investedAmount
              // net non nul même quantité tombée à 0.
              Transaction(
                date: DateTime(2024, 6, 1),
                isBuy: false,
                quantity: 10,
                unitPrice: 60,
                type: TransactionType.arbitrage,
              ),
            ],
          );
          expect(investment.quantityHeld, 0);
          expect(investment.investedAmount, -100); // résidu non nul
          expect(investment.displayValue, 0);
        },
      );

      test(
        'InvestmentAccount.totalMarketValue ignore le résidu d\'une '
        'position soldée sans cours connu',
        () {
          final open = Investment(
            isin: 'FR0000131104',
            label: 'TotalEnergies',
            lastPrice: 60,
            transactions: [
              Transaction(
                date: DateTime(2024, 1, 1),
                isBuy: true,
                quantity: 10,
                unitPrice: 50,
              ),
            ],
          );
          final closed = Investment(
            isin: 'FR0000120271',
            label: 'Fonds soldé',
            transactions: [
              Transaction(
                date: DateTime(2022, 1, 1),
                isBuy: true,
                quantity: 5,
                unitPrice: 20,
              ),
              Transaction(
                date: DateTime(2024, 9, 1),
                isBuy: false,
                quantity: 5,
                unitPrice: 30,
                type: TransactionType.arbitrage,
              ),
            ],
          );
          final acc = InvestmentAccount(
            assetClass: AssetClass.actionsEtFonds,
            envelope: AccountEnvelope.cto,
            name: 'CTO',
            investments: [open, closed],
          );
          expect(closed.investedAmount, -50); // résidu non nul
          // 600 (position ouverte) seulement — le -50 de la position soldée
          // n'est jamais compté.
          expect(acc.totalMarketValue, 600);
        },
      );
    },
  );
}

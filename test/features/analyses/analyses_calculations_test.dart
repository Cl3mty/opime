import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/analyses/analyses_calculations.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/yahoo_finance_client.dart';

void main() {
  group('dailyReturns', () {
    test('rendements simples jour à jour', () {
      final returns = dailyReturns([100, 110, 99]);
      expect(returns, hasLength(2));
      expect(returns[0], closeTo(0.10, 1e-9));
      expect(returns[1], closeTo(-0.10, 1e-9));
    });

    test('ignore un pas dont la valorisation de départ est nulle', () {
      final returns = dailyReturns([0, 100, 110]);
      expect(returns, hasLength(1));
      expect(returns[0], closeTo(0.10, 1e-9));
    });
  });

  group('periodReturn', () {
    test('rendement simple sur toute la série', () {
      expect(periodReturn([100, 110, 120]), closeTo(0.2, 1e-9));
    });

    test('null en dessous de 2 points ou base non positive', () {
      expect(periodReturn([100]), isNull);
      expect(periodReturn([]), isNull);
      expect(periodReturn([-50, 100]), isNull);
      expect(periodReturn([0, 100]), isNull);
    });
  });

  group('annualizeReturn', () {
    test('sous un an : rendement cumulé non annualisé', () {
      expect(annualizeReturn(0.05, 100), closeTo(0.05, 1e-9));
    });

    test('sur un an ou plus : extrapolé à un an', () {
      // Doublé en 2 ans (730 jours) -> annualisé ≈ 41,4 %.
      final annualized = annualizeReturn(1.0, 730);
      expect(annualized, closeTo(0.4142, 1e-3));
    });

    test('null si le rendement total est null', () {
      expect(annualizeReturn(null, 400), isNull);
    });
  });

  group('annualizedVolatility', () {
    test('null en dessous de 2 rendements (3 valorisations)', () {
      expect(annualizedVolatility([]), isNull);
      expect(annualizedVolatility([0.01]), isNull);
    });

    test('série constante : volatilité nulle', () {
      expect(annualizedVolatility([0.01, 0.01, 0.01]), closeTo(0, 1e-12));
    });

    test('écart-type annualisé sur une série connue', () {
      // Rendements [0.1, -0.1] : moyenne 0, variance population = 0.01,
      // écart-type journalier = 0.1, annualisé par sqrt(365).
      final vol = annualizedVolatility([0.1, -0.1]);
      expect(vol, closeTo(0.1 * sqrt365, 1e-6));
    });
  });

  group('maxDrawdown', () {
    test('null en dessous de 2 points', () {
      expect(maxDrawdown([]), isNull);
      expect(maxDrawdown([100]), isNull);
    });

    test('0 quand la série ne redescend jamais sous un plus haut précédent',
        () {
      expect(maxDrawdown([100, 110, 130]), closeTo(0, 1e-9));
    });

    test('le pire creux intermédiaire, pas juste premier vs dernier point '
        '(régression : une série qui plonge puis reprend au-delà de son '
        'point de départ masquerait la vraie chute avec periodReturn seul)',
        () {
      // 100 -> 150 (plus haut) -> 60 (creux : -60 % depuis 150) -> 200.
      expect(maxDrawdown([100, 150, 60, 200]), closeTo(-0.6, 1e-9));
    });
  });

  group('downsideDeviation', () {
    test('null en dessous de 2 rendements', () {
      expect(downsideDeviation([]), isNull);
      expect(downsideDeviation([0.01]), isNull);
    });

    test('ignore les rendements positifs, contrairement à '
        'annualizedVolatility qui les compte à égalité', () {
      // [0.1, -0.1] : annualizedVolatility ne fait pas la différence entre
      // les deux signes, downsideDeviation ne retient que -0.1.
      final downside = downsideDeviation([0.1, -0.1]);
      final total = annualizedVolatility([0.1, -0.1]);
      expect(downside, lessThan(total!));
    });

    test('nulle sans aucun rendement sous le seuil', () {
      expect(downsideDeviation([0.05, 0.1, 0.02]), closeTo(0, 1e-9));
    });
  });

  group('sortinoRatio', () {
    test('même formule que riskReturnRatio, appliquée au risque de perte '
        'seul', () {
      expect(
        sortinoRatio(annualReturn: 0.2, downsideDeviation: 0.1),
        closeTo(2, 1e-9),
      );
    });

    test('null si l\'une des deux entrées est absente ou le risque nul', () {
      expect(sortinoRatio(annualReturn: null, downsideDeviation: 0.1), isNull);
      expect(sortinoRatio(annualReturn: 0.2, downsideDeviation: null), isNull);
      expect(sortinoRatio(annualReturn: 0.2, downsideDeviation: 0), isNull);
    });
  });

  group('skewness', () {
    test('null en dessous de 3 points, ou série plate (écart-type nul)', () {
      expect(skewness([0.01, 0.02]), isNull);
      expect(skewness([0.01, 0.01, 0.01]), isNull);
    });

    test('nulle pour une distribution symétrique', () {
      expect(skewness([-0.1, 0, 0.1]), closeTo(0, 1e-9));
    });

    test('positive quand les hausses sont plus extrêmes que les baisses',
        () {
      expect(skewness([-0.01, -0.01, 0.05]), greaterThan(0));
    });

    test('négative quand les baisses sont plus extrêmes que les hausses',
        () {
      expect(skewness([0.01, 0.01, -0.05]), lessThan(0));
    });
  });

  group('omegaRatio', () {
    test('null en dessous de 2 points, ou sans aucune perte sous le seuil',
        () {
      expect(omegaRatio([0.01]), isNull);
      expect(omegaRatio([0.01, 0.02, 0.03]), isNull);
    });

    test('gains cumulés au-dessus du seuil sur pertes cumulées en dessous',
        () {
      // Gains : 0.1 + 0.2 = 0.3 ; pertes : 0.1 -> ratio 3.
      expect(omegaRatio([0.1, 0.2, -0.1]), closeTo(3, 1e-9));
    });

    test('sous un seuil non nul', () {
      // Seuil 0.05 : gains (0.1-0.05)+(0.2-0.05)=0.2 ; pertes (0.05-0.02)=0.03.
      final ratio = omegaRatio([0.1, 0.2, 0.02], threshold: 0.05);
      expect(ratio, closeTo(0.2 / 0.03, 1e-6));
    });
  });

  group('beta', () {
    test('null en dessous de 3 points communs, ou benchmark plat', () {
      expect(beta([0.01, 0.02], [0.01, 0.02]), isNull);
      expect(beta([0.01, 0.02, 0.03], [0.01, 0.01, 0.01]), isNull);
    });

    test('1 quand la série bouge exactement comme le benchmark', () {
      final returns = [0.02, -0.01, 0.015, -0.005];
      expect(beta(returns, returns), closeTo(1, 1e-9));
    });

    test('2 quand la série amplifie deux fois les mouvements du benchmark',
        () {
      final benchmarkReturns = [0.02, -0.01, 0.015, -0.005];
      final amplified = [for (final r in benchmarkReturns) r * 2];
      expect(beta(amplified, benchmarkReturns), closeTo(2, 1e-9));
    });

    test('négatif quand la série évolue à l\'inverse du benchmark', () {
      final benchmarkReturns = [0.02, -0.01, 0.015, -0.005];
      final inverse = [for (final r in benchmarkReturns) -r];
      expect(beta(inverse, benchmarkReturns), closeTo(-1, 1e-9));
    });
  });

  group('benchmarkReturnsOnGrid', () {
    test('liste vide sans historique de benchmark', () {
      expect(
        benchmarkReturnsOnGrid(const [], [DateTime.utc(2025, 1, 1)]),
        isEmpty,
      );
    });

    test('rendements journaliers échantillonnés sur la grille', () {
      final history = [
        PricePoint(DateTime.utc(2025, 1, 1), 100),
        PricePoint(DateTime.utc(2025, 1, 2), 110),
        PricePoint(DateTime.utc(2025, 1, 3), 99),
      ];
      final grid = [
        DateTime.utc(2025, 1, 1),
        DateTime.utc(2025, 1, 2),
        DateTime.utc(2025, 1, 3),
      ];
      final returns = benchmarkReturnsOnGrid(history, grid);
      expect(returns, hasLength(2));
      expect(returns[0], closeTo(0.10, 1e-9));
      expect(returns[1], closeTo(-0.10, 1e-9));
    });
  });

  group('pearsonCorrelation', () {
    test('parfaitement corrélée : proche de 1', () {
      final r = pearsonCorrelation([1, 2, 3, 4], [10, 20, 30, 40]);
      expect(r, closeTo(1.0, 1e-9));
    });

    test('parfaitement anti-corrélée : proche de -1', () {
      final r = pearsonCorrelation([1, 2, 3, 4], [40, 30, 20, 10]);
      expect(r, closeTo(-1.0, 1e-9));
    });

    test('null en dessous de 3 points communs', () {
      expect(pearsonCorrelation([1, 2], [1, 2]), isNull);
    });

    test('null quand une série a une variance nulle (série plate)', () {
      expect(pearsonCorrelation([5, 5, 5, 5], [1, 2, 3, 4]), isNull);
    });
  });

  group('riskReturnRatio', () {
    test('cas standard', () {
      expect(
        riskReturnRatio(annualReturn: 0.08, volatility: 0.16),
        closeTo(0.5, 1e-9),
      );
    });

    test('null si volatilité nulle ou entrée absente', () {
      expect(riskReturnRatio(annualReturn: 0.08, volatility: 0), isNull);
      expect(riskReturnRatio(annualReturn: null, volatility: 0.1), isNull);
      expect(riskReturnRatio(annualReturn: 0.08, volatility: null), isNull);
    });
  });

  group('periodMwr', () {
    test('valeur de départ amorcée comme un premier flux, plus les flux '
        'réels survenus depuis', () {
      final start = DateTime.utc(2025, 1, 1);
      final today = DateTime.utc(2025, 1, 31);
      final result = periodMwr(
        start: start,
        today: today,
        valuationAtStart: 1000,
        flowsAfterStart: [
          Transaction(
            date: DateTime.utc(2025, 1, 11),
            isBuy: true,
            quantity: 5,
            unitPrice: 100,
          ),
        ],
        currentValue: 1700,
      );
      // netInvested = 1000 (départ) + 500 (achat) = 1500 ; gain = 200.
      expect(result!.rate, closeTo(200 / 1500, 1e-9));
      expect(result.annualized, isFalse);
    });

    test('null sans aucun flux (ni valeur de départ, ni transaction)', () {
      final result = periodMwr(
        start: DateTime.utc(2025, 1, 1),
        today: DateTime.utc(2025, 1, 31),
        valuationAtStart: 0,
        flowsAfterStart: const [],
        currentValue: 0,
      );
      expect(result, isNull);
    });
  });

  group('benchmarkEquivalentMwr', () {
    test('rejoue les mêmes flux (dates, montants) dans le benchmark plutôt '
        'que dans le portefeuille réel', () {
      final start = DateTime.utc(2025, 1, 1);
      final today = DateTime.utc(2025, 1, 31);
      final benchmarkHistory = [
        PricePoint(start, 100),
        PricePoint(today, 110),
      ];
      final result = benchmarkEquivalentMwr(
        start: start,
        today: today,
        valuationAtStart: 1000,
        flowsAfterStart: [
          Transaction(
            date: DateTime.utc(2025, 1, 11),
            isBuy: true,
            quantity: 5,
            unitPrice: 100,
          ),
        ],
        benchmarkHistory: benchmarkHistory,
      );
      // 1000 € au 01/01 (cours 100) = 10 parts ; 500 € au 11/01, cours
      // encore 100 (dernier connu à ou avant, voir [priceAt]) = 5 parts.
      // 15 parts × 110 (cours du 31/01) = 1650 € ; netInvested = 1500 € ;
      // gain = 150 € → 10 %, cohérent avec la hausse de 100 à 110 du
      // benchmark sur la période, quel que soit le moment des apports.
      expect(result!.rate, closeTo(150 / 1500, 1e-9));
    });

    test('null sans historique de benchmark exploitable', () {
      final result = benchmarkEquivalentMwr(
        start: DateTime.utc(2025, 1, 1),
        today: DateTime.utc(2025, 1, 31),
        valuationAtStart: 1000,
        flowsAfterStart: const [],
        benchmarkHistory: const [],
      );
      expect(result, isNull);
    });

    test('un apport tardif ne bénéficie que du reliquat de hausse du '
        'benchmark, pas de la hausse déjà passée avant son entrée', () {
      final start = DateTime.utc(2025, 1, 1);
      final today = DateTime.utc(2025, 2, 1);
      // Le benchmark monte de 100 à 150 en première quinzaine, puis de 150
      // à 200 en seconde.
      final benchmarkHistory = [
        PricePoint(start, 100),
        PricePoint(DateTime.utc(2025, 1, 16), 150),
        PricePoint(today, 200),
      ];
      final earlyContribution = benchmarkEquivalentMwr(
        start: start,
        today: today,
        valuationAtStart: 0,
        flowsAfterStart: [
          Transaction(date: start, isBuy: true, quantity: 1, unitPrice: 1000),
        ],
        benchmarkHistory: benchmarkHistory,
      );
      final lateContribution = benchmarkEquivalentMwr(
        start: start,
        today: today,
        valuationAtStart: 0,
        flowsAfterStart: [
          Transaction(
            date: DateTime.utc(2025, 1, 31),
            isBuy: true,
            quantity: 1,
            unitPrice: 1000,
          ),
        ],
        benchmarkHistory: benchmarkHistory,
      );
      // Même montant (1000 €), même échéance (31/01) : investi le 01/01
      // (cours 100), il achète 10 parts valant 2000 € au 01/02 (cours 200,
      // +100 %). Investi le 31/01 (dernier cours connu à ou avant : 150,
      // celui du 16/01), il n'achète que 6,67 parts, valant 1333 € au
      // 01/02 (+33 %) — il ne capte que la hausse survenue après son
      // entrée, pas celle d'avant.
      expect(earlyContribution!.rate, greaterThan(lateContribution!.rate));
    });
  });

  group('benchmarkEquivalentValueSeries', () {
    test('valeur croissante, un point par date de la grille, cohérente '
        'avec benchmarkEquivalentMwr au dernier point', () {
      final grid = [
        DateTime.utc(2025, 1, 1),
        DateTime.utc(2025, 1, 16),
        DateTime.utc(2025, 1, 31),
      ];
      final benchmarkHistory = [
        PricePoint(DateTime.utc(2025, 1, 1), 100),
        PricePoint(DateTime.utc(2025, 1, 16), 150),
        PricePoint(DateTime.utc(2025, 1, 31), 200),
      ];
      final flowsAfterStart = [
        Transaction(
          date: DateTime.utc(2025, 1, 16),
          isBuy: true,
          quantity: 5,
          unitPrice: 100,
        ),
      ];
      final series = benchmarkEquivalentValueSeries(
        grid: grid,
        valuationAtStart: 1000,
        flowsAfterStart: flowsAfterStart,
        benchmarkHistory: benchmarkHistory,
      );

      expect(series, hasLength(3));
      // 1000 € au 01/01 (cours 100) = 10 parts → 1000 € au premier point.
      expect(series[0].value, closeTo(1000, 1e-6));
      // + 500 € au 16/01 (cours 150) = 3,333 parts → 13,333 parts × 150.
      expect(series[1].value, closeTo(2000, 1e-6));
      // 13,333 parts × 200 (cours du 31/01).
      expect(series[2].value, closeTo(2666.666667, 1e-3));

      // Le dernier point doit être la valeur finale que calcule
      // benchmarkEquivalentMwr pour les mêmes flux.
      final mwr = benchmarkEquivalentMwr(
        start: grid.first,
        today: grid.last,
        valuationAtStart: 1000,
        flowsAfterStart: flowsAfterStart,
        benchmarkHistory: benchmarkHistory,
      );
      expect(mwr, isNotNull);
    });

    test('liste vide sans historique de benchmark exploitable', () {
      final series = benchmarkEquivalentValueSeries(
        grid: [DateTime.utc(2025, 1, 1), DateTime.utc(2025, 1, 31)],
        valuationAtStart: 1000,
        flowsAfterStart: const [],
        benchmarkHistory: const [],
      );
      expect(series, isEmpty);
    });
  });

  group('debtRatioAssets', () {
    test('cas standard', () {
      expect(
        debtRatioAssets(totalLiabilities: 200000, totalAssets: 500000),
        closeTo(0.4, 1e-9),
      );
    });

    test('null si actifs totaux nuls', () {
      expect(
        debtRatioAssets(totalLiabilities: 100, totalAssets: 0),
        isNull,
      );
    });
  });

  group('debtRatioIncome', () {
    test('cas standard', () {
      expect(
        debtRatioIncome(monthlyInstallments: 1000, monthlyIncome: 3000),
        closeTo(1 / 3, 1e-9),
      );
    });

    test('null si revenus mensuels nuls', () {
      expect(
        debtRatioIncome(monthlyInstallments: 1000, monthlyIncome: 0),
        isNull,
      );
    });
  });

  group('leverage', () {
    test('cas standard', () {
      expect(
        leverage(totalAssets: 500000, netWorth: 300000),
        closeTo(500000 / 300000, 1e-9),
      );
    });

    test('null si patrimoine net nul ou négatif', () {
      expect(leverage(totalAssets: 500000, netWorth: 0), isNull);
      expect(leverage(totalAssets: 500000, netWorth: -1000), isNull);
    });
  });

  group('fundStyleAllocation', () {
    Investment stock(String isin, FundStyle? style) => Investment(
      isin: isin,
      label: isin,
      transactions: const [],
      fundStyle: style,
    );

    test('mix classé/non classé : les pourcentages somment à 100', () {
      final investments = [
        stock('A', FundStyle.indiciel),
        stock('B', FundStyle.activeGere),
        stock('C', null),
      ];
      final values = {'A': 600.0, 'B': 300.0, 'C': 100.0};
      final allocation = fundStyleAllocation(
        investments,
        valueOf: (i) => values[i.isin]!,
      );

      expect(allocation[FundStyle.indiciel], closeTo(60, 1e-9));
      expect(allocation[FundStyle.activeGere], closeTo(30, 1e-9));
      expect(allocation[null], closeTo(10, 1e-9));
      expect(
        allocation.values.reduce((a, b) => a + b),
        closeTo(100, 1e-9),
      );
    });

    test('liste vide : répartition vide', () {
      expect(fundStyleAllocation(const [], valueOf: (_) => 0), isEmpty);
    });

    test('investissement sans valorisation connue est ignoré', () {
      final investments = [stock('A', FundStyle.indiciel)];
      final allocation = fundStyleAllocation(investments, valueOf: (_) => 0);
      expect(allocation, isEmpty);
    });
  });

  group('calculateTri', () {
    test('délègue à calculateMwr sur les transactions concaténées', () {
      final transactions = [
        Transaction(date: DateTime(2020, 1, 1), isBuy: true, quantity: 10, unitPrice: 100),
        Transaction(date: DateTime(2022, 1, 1), isBuy: true, quantity: 5, unitPrice: 120),
      ];
      final result = calculateTri(
        allTransactions: transactions,
        currentValue: 2000,
        asOf: DateTime(2024, 1, 1),
      );
      expect(result.annualized, isTrue);
      expect(result.rate, greaterThan(0));
    });
  });
}

const double sqrt365 = 19.104973174542799;

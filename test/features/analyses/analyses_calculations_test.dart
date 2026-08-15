import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/analyses/analyses_calculations.dart';
import 'package:opime/features/investments/investments_models.dart';

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

  group('simpleAlpha', () {
    test('surperformance : alpha positif', () {
      expect(
        simpleAlpha(portfolioAnnualReturn: 0.12, benchmarkAnnualReturn: 0.08),
        closeTo(0.04, 1e-9),
      );
    });

    test('sous-performance : alpha négatif', () {
      expect(
        simpleAlpha(portfolioAnnualReturn: 0.03, benchmarkAnnualReturn: 0.08),
        closeTo(-0.05, 1e-9),
      );
    });

    test('null si une des deux entrées est absente', () {
      expect(
        simpleAlpha(portfolioAnnualReturn: null, benchmarkAnnualReturn: 0.08),
        isNull,
      );
      expect(
        simpleAlpha(portfolioAnnualReturn: 0.08, benchmarkAnnualReturn: null),
        isNull,
      );
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

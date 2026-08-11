import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/performance_calculator.dart';
import 'package:opime/features/investments/yahoo_finance_client.dart';

void main() {
  test('un seul achat : MWR et TWR coïncident', () {
    final buyDate = DateTime.utc(2023, 1, 1);
    final asOf = DateTime.utc(2024, 1, 1); // 365 jours plus tard
    final transactions = [
      Transaction(date: buyDate, isBuy: true, quantity: 10, unitPrice: 100),
    ];

    final mwr = calculateMwr(
      transactions: transactions,
      currentValue: 1200,
      asOf: asOf,
    );
    final twr = calculateTwr(
      transactions: transactions,
      priceHistory: [PricePoint(buyDate, 100), PricePoint(asOf, 120)],
      currentValue: 1200,
      asOf: asOf,
    );

    expect(mwr.annualized, isTrue);
    expect(mwr.rate, closeTo(0.20, 0.001));
    expect(twr, isNotNull);
    expect(twr!.annualized, isTrue);
    expect(twr.rate, closeTo(mwr.rate, 0.001));
  });

  test(
    'deux achats à des dates différentes : MWR et TWR divergent de façon cohérente',
    () {
      // Le cours monte de 100 à 130 (jour 0 -> 300) puis retombe à 120
      // (jour 300 -> 365). Un second achat important juste avant la baisse
      // expose une grosse part du capital à cette baisse : le rendement
      // pondéré par les flux (MWR) doit donc être nettement inférieur au
      // rendement de l'actif lui-même (TWR), qui ne voit que 100 -> 120.
      final day0 = DateTime.utc(2023, 1, 1);
      final day300 = day0.add(const Duration(days: 300));
      final asOf = day0.add(const Duration(days: 365));

      final transactions = [
        Transaction(date: day0, isBuy: true, quantity: 10, unitPrice: 100),
        Transaction(date: day300, isBuy: true, quantity: 10, unitPrice: 130),
      ];
      const currentValue = 2400.0; // 20 unités * 120

      final twr = calculateTwr(
        transactions: transactions,
        priceHistory: [
          PricePoint(day0, 100),
          PricePoint(day300, 130),
          PricePoint(asOf, 120),
        ],
        currentValue: currentValue,
        asOf: asOf,
      );
      final mwr = calculateMwr(
        transactions: transactions,
        currentValue: currentValue,
        asOf: asOf,
      );

      // TWR ne dépend que du cours (100 -> 120 sur ~1 an) : ~+20 %.
      expect(twr, isNotNull);
      expect(twr!.rate, closeTo(0.20, 0.01));
      // MWR est tiré vers le bas par le gros achat tardif exposé à la
      // baisse de fin de période : nettement inférieur au TWR.
      expect(mwr.rate, lessThan(twr.rate - 0.05));
      expect(mwr.rate, greaterThan(0));
    },
  );

  test('TWR retourne null sans historique de cours couvrant la période', () {
    final buyDate = DateTime.utc(2023, 1, 1);
    final laterDate = buyDate.add(const Duration(days: 10));
    final transactions = [
      Transaction(date: buyDate, isBuy: true, quantity: 10, unitPrice: 100),
    ];

    final twr = calculateTwr(
      transactions: transactions,
      priceHistory: [PricePoint(laterDate, 105)],
      currentValue: 1100,
      asOf: buyDate.add(const Duration(days: 30)),
    );

    expect(twr, isNull);
  });

  test('MWR retourne 0 sans transaction', () {
    final mwr = calculateMwr(
      transactions: const [],
      currentValue: 0,
      asOf: DateTime.now(),
    );
    expect(mwr.rate, 0);
    expect(mwr.annualized, isFalse);
  });

  test(
    'détention de quelques jours : le rendement n\'est pas annualisé (pas de taux absurde)',
    () {
      // Avant le correctif, annualiser un gain de 5 % sur 3 jours donnait
      // un taux "par an" dans les dizaines de milliers de pourcents — le
      // bug remonté par l'utilisateur ("4400 % c'est monstrueux"). En
      // dessous d'un an de détention, on attend le rendement cumulé brut
      // (~5 %), pas un taux extrapolé.
      final buyDate = DateTime.utc(2024, 1, 1);
      final asOf = buyDate.add(const Duration(days: 3));
      final transactions = [
        Transaction(date: buyDate, isBuy: true, quantity: 10, unitPrice: 100),
      ];

      final mwr = calculateMwr(
        transactions: transactions,
        currentValue: 1050,
        asOf: asOf,
      );
      final twr = calculateTwr(
        transactions: transactions,
        priceHistory: [PricePoint(buyDate, 100), PricePoint(asOf, 105)],
        currentValue: 1050,
        asOf: asOf,
      );

      expect(mwr.annualized, isFalse);
      expect(mwr.rate, closeTo(0.05, 0.001));
      expect(twr, isNotNull);
      expect(twr!.annualized, isFalse);
      expect(twr.rate, closeTo(0.05, 0.001));
    },
  );
}

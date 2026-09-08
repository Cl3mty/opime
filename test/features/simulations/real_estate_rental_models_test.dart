import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/simulations/real_estate_rental_models.dart';

void main() {
  group('RentalStrategy.annualGrossRevenue', () {
    test('longue durée : loyer mensuel × 12', () {
      final strategy = RentalStrategy.longTerm(monthlyRent: 900);
      expect(strategy.annualGrossRevenue, 10800);
    });

    test('courte durée : tarif/nuit × 365 × taux d\'occupation', () {
      final strategy = RentalStrategy.shortTerm(
        nightlyRate: 80,
        occupancyRatePercent: 50,
      );
      expect(strategy.annualGrossRevenue, closeTo(80 * 365 * 0.5, 0.01));
    });

    test('mix saisonnier : somme des deux sous-périodes', () {
      final strategy = RentalStrategy.seasonalMix(
        longTermMonths: 9,
        longTermMonthlyRent: 700,
        shortTermMonths: 3,
        shortTermNightlyRate: 100,
        shortTermOccupancyRatePercent: 80,
      );
      final expected = 700 * 9 + 100 * (3 * 30.44) * 0.8;
      expect(strategy.annualGrossRevenue, closeTo(expected, 0.01));
    });

    test('colocation : somme des loyers des chambres × 12', () {
      final strategy = RentalStrategy.colocation(
        rooms: [
          RentalRoom(label: 'Chambre 1', monthlyRent: 450),
          RentalRoom(label: 'Chambre 2', monthlyRent: 450),
          RentalRoom(label: 'Chambre 3', monthlyRent: 400),
        ],
      );
      expect(strategy.annualGrossRevenue, (450 + 450 + 400) * 12);
    });
  });

  group('JSON round-trip', () {
    test('longTerm', () {
      final strategy = RentalStrategy.longTerm(monthlyRent: 900);
      final restored = RentalStrategy.fromJson(strategy.toJson());
      expect(restored.kind, RentalStrategyKind.longTerm);
      expect(restored.annualGrossRevenue, strategy.annualGrossRevenue);
    });

    test('shortTerm', () {
      final strategy = RentalStrategy.shortTerm(
        nightlyRate: 80,
        occupancyRatePercent: 60,
      );
      final restored = RentalStrategy.fromJson(strategy.toJson());
      expect(restored.kind, RentalStrategyKind.shortTerm);
      expect(restored.annualGrossRevenue, strategy.annualGrossRevenue);
    });

    test('seasonalMix', () {
      final strategy = RentalStrategy.seasonalMix(
        longTermMonths: 9,
        longTermMonthlyRent: 700,
        shortTermMonths: 3,
        shortTermNightlyRate: 100,
        shortTermOccupancyRatePercent: 80,
      );
      final restored = RentalStrategy.fromJson(strategy.toJson());
      expect(restored.kind, RentalStrategyKind.seasonalMix);
      expect(restored.annualGrossRevenue, closeTo(strategy.annualGrossRevenue, 0.01));
    });

    test('colocation avec plusieurs chambres', () {
      final strategy = RentalStrategy.colocation(
        rooms: [
          RentalRoom(label: 'Chambre A', monthlyRent: 500),
          RentalRoom(label: 'Chambre B', monthlyRent: 520),
        ],
      );
      final restored = RentalStrategy.fromJson(strategy.toJson());
      expect(restored.kind, RentalStrategyKind.colocation);
      expect(restored.rooms, hasLength(2));
      expect(restored.rooms[0].label, 'Chambre A');
      expect(restored.rooms[1].monthlyRent, 520);
      expect(restored.annualGrossRevenue, strategy.annualGrossRevenue);
    });

    test('RentalUnit', () {
      final unit = RentalUnit(
        label: 'Studio annexe',
        strategy: RentalStrategy.longTerm(monthlyRent: 600),
      );
      final restored = RentalUnit.fromJson(unit.toJson());
      expect(restored.id, unit.id);
      expect(restored.label, 'Studio annexe');
      expect(restored.annualGrossRevenue, 7200);
    });
  });

  test('RentalUnit.copyWith conserve l\'id', () {
    final unit = RentalUnit(
      label: 'Chambre 1',
      strategy: RentalStrategy.longTerm(monthlyRent: 450),
    );
    final renamed = unit.copyWith(label: 'Chambre 1 bis');
    expect(renamed.id, unit.id);
    expect(renamed.label, 'Chambre 1 bis');
    expect(renamed.strategy.monthlyRent, 450);
  });
}

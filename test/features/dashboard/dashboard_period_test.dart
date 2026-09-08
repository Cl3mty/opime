import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';

void main() {
  final today = DateTime.utc(2026, 8, 14);
  // Compte de ~2 ans et demi — assez vieux pour que l'ancien bug (tranchage
  // par nombre de points plutôt que par date) aurait rendu "1M" quasiment
  // identique à "Tout".
  final earliest = DateTime.utc(2024, 1, 1);

  group('DashboardPeriod.startFor', () {
    test('1J = hier', () {
      expect(
        DashboardPeriod.day1.startFor(today: today, earliest: earliest),
        DateTime.utc(2026, 8, 13),
      );
    });

    test('7J = il y a 7 jours', () {
      expect(
        DashboardPeriod.days7.startFor(today: today, earliest: earliest),
        DateTime.utc(2026, 8, 7),
      );
    });

    test('1M = il y a 30 jours', () {
      expect(
        DashboardPeriod.month1.startFor(today: today, earliest: earliest),
        DateTime.utc(2026, 7, 15),
      );
    });

    test('YTD = 1er janvier de l\'année en cours (régression : n\'était '
        'auparavant qu\'une approximation à 220 jours)', () {
      expect(
        DashboardPeriod.ytd.startFor(today: today, earliest: earliest),
        DateTime.utc(2026, 1, 1),
      );
    });

    test('1A = il y a 365 jours', () {
      expect(
        DashboardPeriod.year1.startFor(today: today, earliest: earliest),
        DateTime.utc(2025, 8, 14),
      );
    });

    test('Tout = la donnée la plus ancienne', () {
      expect(
        DashboardPeriod.all.startFor(today: today, earliest: earliest),
        earliest,
      );
    });

    test('ne remonte jamais avant `earliest`, même pour "1A" sur un '
        'compte plus jeune', () {
      final youngEarliest = DateTime.utc(2026, 8, 1);
      expect(
        DashboardPeriod.year1.startFor(
          today: today,
          earliest: youngEarliest,
        ),
        youngEarliest,
      );
    });

    test('les 6 périodes produisent des bornes de départ distinctes sur ce '
        'même compte (régression : YTD/1A/Tout se confondaient tous en '
        '"depuis le début")', () {
      final starts = {
        for (final period in DashboardPeriod.values)
          period: period.startFor(today: today, earliest: earliest),
      };
      expect(starts.values.toSet(), hasLength(DashboardPeriod.values.length));
    });
  });
}

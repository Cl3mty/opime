import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/projects/project_trajectory.dart';

void main() {
  group('computeProjectTrajectory', () {
    test('échéance dans le futur : premier point = valeur actuelle, dernier = échéance', () {
      final today = DateTime(2026, 1, 1);
      final echeance = DateTime(2028, 1, 1);
      final points = computeProjectTrajectory(
        currentValue: 10000,
        rendementAttenduPercent: 5,
        today: today,
        echeance: echeance,
      );

      expect(points.first.date, today);
      expect(points.first.value, closeTo(10000, 0.01));
      expect(points.last.date, echeance);
      // ~2 ans à 5 % composé : 10000 * 1.05^2 ≈ 11025.
      expect(points.last.value, closeTo(11025, 5));
    });

    test('croissance strictement monotone à taux positif', () {
      final points = computeProjectTrajectory(
        currentValue: 5000,
        rendementAttenduPercent: 3,
        today: DateTime(2026, 1, 1),
        echeance: DateTime(2031, 1, 1),
      );
      for (var i = 1; i < points.length; i++) {
        expect(points[i].value, greaterThan(points[i - 1].value));
      }
    });

    test('taux à 0 % : valeur constante sur toute la trajectoire', () {
      final points = computeProjectTrajectory(
        currentValue: 8000,
        rendementAttenduPercent: 0,
        today: DateTime(2026, 1, 1),
        echeance: DateTime(2030, 1, 1),
      );
      for (final p in points) {
        expect(p.value, closeTo(8000, 0.01));
      }
    });

    test('échéance déjà dépassée renvoie 2 points à valeur constante', () {
      final points = computeProjectTrajectory(
        currentValue: 3000,
        rendementAttenduPercent: 5,
        today: DateTime(2026, 6, 1),
        echeance: DateTime(2026, 1, 1),
      );
      expect(points, hasLength(2));
      expect(points.every((p) => p.value == 3000), isTrue);
    });
  });

  group('isProjectOnTrack', () {
    test('null sans montant cible', () {
      expect(
        isProjectOnTrack(
          currentValue: 1000,
          rendementAttenduPercent: 5,
          montantCible: null,
          today: DateTime(2026, 1, 1),
          echeance: DateTime(2030, 1, 1),
        ),
        isNull,
      );
    });

    test('true quand la trajectoire projetée atteint la cible', () {
      expect(
        isProjectOnTrack(
          currentValue: 100000,
          rendementAttenduPercent: 7,
          montantCible: 130000,
          today: DateTime(2026, 1, 1),
          echeance: DateTime(2030, 1, 1),
        ),
        isTrue,
      );
    });

    test('false quand la trajectoire projetée n\'atteint pas la cible', () {
      expect(
        isProjectOnTrack(
          currentValue: 10000,
          rendementAttenduPercent: 1,
          montantCible: 100000,
          today: DateTime(2026, 1, 1),
          echeance: DateTime(2027, 1, 1),
        ),
        isFalse,
      );
    });
  });
}

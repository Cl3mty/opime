import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/donut_hover.dart';

void main() {
  const center = Offset(100, 100);
  const radius = 50.0;
  const strokeWidth = 20.0;

  /// Point sur le cercle de rayon [r] (dans [innerRadius, outerRadius]),
  /// à l'angle [degrees] depuis 12 h, dans le sens horaire — même
  /// convention que [hitTestDonutSlice] et `Canvas.drawArc` avec un angle
  /// de départ de `-pi/2`.
  Offset pointAt(double degrees, {double r = radius}) {
    final theta = degrees * math.pi / 180;
    return center + Offset(r * math.sin(theta), -r * math.cos(theta));
  }

  test('dans le trou central : aucune part survolée', () {
    expect(
      hitTestDonutSlice(
        point: center,
        center: center,
        radius: radius,
        strokeWidth: strokeWidth,
        values: [1, 1],
      ),
      isNull,
    );
  });

  test('bien au-delà du rayon extérieur : aucune part survolée', () {
    expect(
      hitTestDonutSlice(
        point: pointAt(0, r: radius + strokeWidth),
        center: center,
        radius: radius,
        strokeWidth: strokeWidth,
        values: [1, 1],
      ),
      isNull,
    );
  });

  test('au centre du trait (sur le rayon) : la bonne part est trouvée', () {
    // 2 parts égales : la première couvre [0°, 180°), la seconde [180°, 360°).
    expect(
      hitTestDonutSlice(
        point: pointAt(10),
        center: center,
        radius: radius,
        strokeWidth: strokeWidth,
        values: [1, 1],
      ),
      0,
    );
    expect(
      hitTestDonutSlice(
        point: pointAt(190),
        center: center,
        radius: radius,
        strokeWidth: strokeWidth,
        values: [1, 1],
      ),
      1,
    );
  });

  test(
    'régression : la moitié extérieure du trait (entre le rayon et le '
    'bord extérieur) doit détecter la part, pas seulement la moitié '
    'intérieure — l\'ancienne version testait '
    '[radius - strokeWidth, radius] au lieu de '
    '[radius - strokeWidth/2, radius + strokeWidth/2], ratant '
    'systématiquement cette moitié',
    () {
      final outerEdge = pointAt(10, r: radius + strokeWidth / 2 - 1);
      expect(
        hitTestDonutSlice(
          point: outerEdge,
          center: center,
          radius: radius,
          strokeWidth: strokeWidth,
          values: [1, 1],
        ),
        0,
      );
    },
  );

  test(
    'régression : une part fine (petit balayage angulaire) reste '
    'détectable sur toute la largeur du trait, y compris sa moitié '
    'extérieure où elle concentre le plus de pixels (l\'arc s\'élargit '
    'avec le rayon) — c\'est precisément le cas que l\'ancienne bande de '
    'détection, décalée vers l\'intérieur, ratait le plus souvent',
    () {
      // Une part énorme (999) puis une part fine (1, soit 0.36° de
      // balayage) : la part fine occupe juste avant de refaire le tour
      // complet (359.64° à 360°).
      const values = [999.0, 1.0];
      final thinSliceAngle = 359.8;

      for (final r in [
        radius - strokeWidth / 2 + 0.5, // bord intérieur du trait
        radius, // centre du trait
        radius + strokeWidth / 2 - 0.5, // bord extérieur du trait
      ]) {
        final point = pointAt(thinSliceAngle, r: r);
        expect(
          hitTestDonutSlice(
            point: point,
            center: center,
            radius: radius,
            strokeWidth: strokeWidth,
            values: values,
          ),
          1,
          reason: 'à r=$r sur la part fine',
        );
      }
    },
  );

  test(
    'couverture complète du cercle : aucun angle ne doit retomber sur '
    '`null` à l\'intérieur du trait, quelle que soit la taille des parts',
    () {
      const values = [50.0, 5.0, 2.0, 40.0, 3.0];
      for (var deg = 0; deg < 360; deg++) {
        final index = hitTestDonutSlice(
          point: pointAt(deg.toDouble()),
          center: center,
          radius: radius,
          strokeWidth: strokeWidth,
          values: values,
        );
        expect(
          index,
          isNotNull,
          reason: 'angle $deg° ne devrait jamais retomber sur aucune part',
        );
        expect(index! >= 0 && index < values.length, isTrue);
      }
    },
  );

  test('aucune valeur, ou toutes nulles : aucune part survolée', () {
    expect(
      hitTestDonutSlice(
        point: pointAt(10),
        center: center,
        radius: radius,
        strokeWidth: strokeWidth,
        values: const [],
      ),
      isNull,
    );
    expect(
      hitTestDonutSlice(
        point: pointAt(10),
        center: center,
        radius: radius,
        strokeWidth: strokeWidth,
        values: [0, 0],
      ),
      isNull,
    );
  });
}

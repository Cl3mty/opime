import 'dart:ui';

import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/dashboard/widgets/net_worth_chart.dart';

void main() {
  group(
    'drawDateAxisLabels (régression : les repères "milieu" et "dernier '
    'point" se dessinaient l\'un sur l\'autre — deux dates superposées en '
    'bas à droite du graphique — dès que la période n\'avait que 2 points, '
    'car pointCount ~/ 2 vaut alors le même index que pointCount - 1)',
    () {
      Canvas canvas() => Canvas(PictureRecorder());

      test(
        '2 points : le repère "milieu" est omis, seuls le premier et le '
        'dernier sont dessinés',
        () {
          final queriedIndices = <int>[];
          drawDateAxisLabels(
            canvas(),
            2,
            (i) {
              queriedIndices.add(i);
              return DateTime(2026, 1, i + 1);
            },
            (i) => i * 10.0,
            100,
            Colors.black,
          );
          expect(queriedIndices, [0, 1]);
        },
      );

      test(
        '3 points : les trois repères (premier, milieu, dernier) sont '
        'distincts, tous dessinés',
        () {
          final queriedIndices = <int>[];
          drawDateAxisLabels(
            canvas(),
            3,
            (i) {
              queriedIndices.add(i);
              return DateTime(2026, 1, i + 1);
            },
            (i) => i * 10.0,
            100,
            Colors.black,
          );
          expect(queriedIndices, [0, 1, 2]);
        },
      );

      test(
        'beaucoup de points : le repère "milieu" reste un vrai point '
        'intermédiaire, distinct du premier et du dernier',
        () {
          final queriedIndices = <int>[];
          drawDateAxisLabels(
            canvas(),
            30,
            (i) {
              queriedIndices.add(i);
              return DateTime(2026, 1, 1).add(Duration(days: i));
            },
            (i) => i * 10.0,
            100,
            Colors.black,
          );
          expect(queriedIndices, [0, 15, 29]);
        },
      );
    },
  );
}

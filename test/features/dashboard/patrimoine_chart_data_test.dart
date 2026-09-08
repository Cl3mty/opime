import 'dart:ui' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:opime/features/dashboard/widgets/patrimoine_chart_widgets.dart';

/// Trois classes d'actif avec des séries de trois points alignées, utilisées
/// dans tous les cas pour vérifier les règles net/brut de
/// [buildPatrimoineChartData].
const _layers = [
  ChartLayer(id: 'a', label: 'A', color: Color(0xFF111111)),
  ChartLayer(id: 'b', label: 'B', color: Color(0xFF222222)),
  ChartLayer(id: 'c', label: 'C', color: Color(0xFF333333)),
];

List<List<NetWorthPoint>> _series() => [
      [for (var i = 0; i < 3; i++) _p(i, 100.0 + i * 10)], // a : 100, 110, 120
      [for (var i = 0; i < 3; i++) _p(i, 50.0 + i * 5)], //  b : 50, 55, 60
      [for (var i = 0; i < 3; i++) _p(i, 25.0 + i * 2)], //  c : 25, 27, 29
    ];

List<NetWorthPoint> _passifs() => [for (var i = 0; i < 3; i++) _p(i, 30.0 + i * 3)];

NetWorthPoint _p(int i, double value) =>
    NetWorthPoint(DateTime(2026, 1, 1).add(Duration(days: i)), value);

void main() {
  group('Patrimoine net', () {
    test('affiche une seule courbe dorée = somme des actifs − passifs', () {
      final data = buildPatrimoineChartData(
        kind: PatrimoineKind.net,
        allLayers: _layers,
        allSeries: _series(),
        selectedIds: {'a', 'b'},
        passifSeries: _passifs(),
      );

      expect(data.layers.length, 1);
      expect(data.layers.first.id, '_patrimoine_net');
      expect(data.layers.first.label, 'Patrimoine net');
      expect(data.layers.first.color, netWorthColor);
      expect(data.totalPoints.length, 3);
      // À chaque instant : (a + b + c) − passifs.
      expect(data.totalPoints[0].value, closeTo(100 + 50 + 25 - 30, 1e-9));
      expect(data.totalPoints[1].value, closeTo(110 + 55 + 27 - 33, 1e-9));
      expect(data.totalPoints[2].value, closeTo(120 + 60 + 29 - 36, 1e-9));
      expect(data.cumulativeTop.single, [
        for (final p in data.totalPoints) p.value,
      ]);
    });

    test('ignore la sélection multi-classes : toutes les classes comptent', () {
      final data = buildPatrimoineChartData(
        kind: PatrimoineKind.net,
        allLayers: _layers,
        allSeries: _series(),
        selectedIds: const {},
        passifSeries: _passifs(),
      );

      // Même sans rien de sélectionné, la courbe vaut encore a + b + c − passifs.
      expect(data.totalPoints.last.value, closeTo(120 + 60 + 29 - 36, 1e-9));
    });

    test('reprend la série nette fournie en override (carte démo)', () {
      final override = [for (var i = 0; i < 3; i++) _p(i, 1000.0 + i)];
      final data = buildPatrimoineChartData(
        kind: PatrimoineKind.net,
        allLayers: _layers,
        allSeries: _series(),
        selectedIds: const {},
        passifSeries: _passifs(),
        netSeriesOverride: override,
      );

      expect(data.layers.single.color, netWorthColor);
      expect(
        [for (final p in data.totalPoints) p.value],
        [1000.0, 1001.0, 1002.0],
      );
    });

    test('passifs plus courts que les actifs : déficit traité comme zéro', () {
      final shortPassifs = [for (var i = 0; i < 1; i++) _p(i, 999)];
      final data = buildPatrimoineChartData(
        kind: PatrimoineKind.net,
        allLayers: _layers,
        allSeries: _series(),
        selectedIds: const {},
        passifSeries: shortPassifs,
      );

      // i = 2 : aucune dette alignée sur cette date, net = a + b + c.
      expect(data.totalPoints[2].value, closeTo(120 + 60 + 29, 1e-9));
    });
  });

  group('Patrimoine brut', () {
    test('empile uniquement les actifs sélectionnés, dans leur couleur', () {
      final data = buildPatrimoineChartData(
        kind: PatrimoineKind.brut,
        allLayers: _layers,
        allSeries: _series(),
        selectedIds: {'a', 'c'},
        passifSeries: _passifs(),
      );

      expect([for (final l in data.layers) l.id], ['a', 'c']);
      expect([for (final l in data.layers) l.color], [
        _layers[0].color,
        _layers[2].color,
      ]);
      // Cumul : i = 1 -> a = 110 puis a + c = 110 + 27 = 137.
      expect(data.cumulativeTop[0][1], closeTo(110, 1e-9));
      expect(data.cumulativeTop[1][1], closeTo(137, 1e-9));
    });

    test('n\'intègre jamais les passifs dans les valeurs', () {
      final withPassifs = buildPatrimoineChartData(
        kind: PatrimoineKind.brut,
        allLayers: _layers,
        allSeries: _series(),
        selectedIds: {'a', 'b', 'c'},
        passifSeries: _passifs(),
      );
      final withoutPassifs = buildPatrimoineChartData(
        kind: PatrimoineKind.brut,
        allLayers: _layers,
        allSeries: _series(),
        selectedIds: {'a', 'b', 'c'},
        passifSeries: null,
      );

      expect(withPassifs.totalPoints.last.value, closeTo(120 + 60 + 29, 1e-9));
      expect(
        withPassifs.totalPoints.last.value,
        withoutPassifs.totalPoints.last.value,
      );
    });

    test('toutes classes sélectionnées : pile complète dans l\'ordre', () {
      final data = buildPatrimoineChartData(
        kind: PatrimoineKind.brut,
        allLayers: _layers,
        allSeries: _series(),
        selectedIds: {'a', 'b', 'c'},
        passifSeries: _passifs(),
      );

      expect([for (final l in data.layers) l.id], ['a', 'b', 'c']);
      expect(data.cumulativeTop.last[0], closeTo(100 + 50 + 25, 1e-9));
      expect(data.cumulativeTop.last[2], closeTo(120 + 60 + 29, 1e-9));
      expect(data.totalPoints.last.value, closeTo(120 + 60 + 29, 1e-9));
    });

    test('sélection vide : aucune couche ni point', () {
      final data = buildPatrimoineChartData(
        kind: PatrimoineKind.brut,
        allLayers: _layers,
        allSeries: _series(),
        selectedIds: const {},
        passifSeries: _passifs(),
      );

      expect(data.layers, isEmpty);
      expect(data.totalPoints, isEmpty);
    });
  });

  test('les classes sans historique sur la période sont écartées', () {
    final data = buildPatrimoineChartData(
      kind: PatrimoineKind.brut,
      allLayers: _layers,
      allSeries: [_series()[0], const [], _series()[2]],
      selectedIds: {'a', 'b', 'c'},
      passifSeries: _passifs(),
    );

    expect([for (final l in data.layers) l.id], ['a', 'c']);
  });

  test('les dates des points suivent la grille des séries sources', () {
    final data = buildPatrimoineChartData(
      kind: PatrimoineKind.brut,
      allLayers: _layers,
      allSeries: _series(),
      selectedIds: {'a'},
      passifSeries: _passifs(),
    );

    expect(
      [for (final d in data.dates) d],
      [for (final p in _series().first) p.date],
    );
    expect([for (final p in data.totalPoints) p.date], data.dates);
  });

  group('changePercentFor', () {
    test('null sans au moins deux points', () {
      expect(changePercentFor(const []), isNull);
      expect(changePercentFor([_p(0, 100)]), isNull);
    });

    test(
        'null quand le premier point est négatif ou nul — même si la '
        'variation absolue est positive (régression : un patrimoine net qui '
        'repart d\'une valeur négative affichait un pourcentage sans '
        'rapport avec le sens réel de l\'évolution)', () {
      expect(changePercentFor([_p(0, -500), _p(1, 2000)]), isNull);
      expect(changePercentFor([_p(0, 0), _p(1, 2000)]), isNull);
    });

    test('pourcentage correct quand le premier point est strictement positif',
        () {
      expect(changePercentFor([_p(0, 100), _p(1, 120)]), closeTo(20, 1e-9));
      expect(changePercentFor([_p(0, 100), _p(1, 80)]), closeTo(-20, 1e-9));
    });

    test(
        'reste défini même quand le premier point est minuscule devant le '
        'dernier (un versement ultérieur, même modeste, y apparaît comme '
        'une hausse énorme — voir isExtremeChangePercent, qui signale ce '
        'cas sans masquer le chiffre)', () {
      // 0,40 € en premier point (première transaction minime, ex : un
      // reliquat de dividende) puis 48 115 € au dernier : +12 028 375 %.
      final percent = changePercentFor([_p(0, 0.40), _p(1, 48115)]);
      expect(percent, closeTo(12028650, 1));
    });
  });

  group('isExtremeChangePercent', () {
    test('faux pour un pourcentage plausible', () {
      expect(isExtremeChangePercent(20), isFalse);
      expect(isExtremeChangePercent(-999), isFalse);
    });

    test('vrai au-delà de 1000 % en valeur absolue', () {
      expect(isExtremeChangePercent(1000.01), isTrue);
      expect(isExtremeChangePercent(-1000.01), isTrue);
    });
  });
}

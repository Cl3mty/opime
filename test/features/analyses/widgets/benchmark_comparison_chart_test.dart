import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/analyses/widgets/benchmark_comparison_chart.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets(
    'BenchmarkComparisonChart : rend les deux courbes et la légende sans '
    'planter avec des données valides',
    (tester) async {
      final portfolio = [
        NetWorthPoint(DateTime.utc(2025, 1, 1), 1000),
        NetWorthPoint(DateTime.utc(2025, 1, 16), 2100),
        NetWorthPoint(DateTime.utc(2025, 1, 31), 2800),
      ];
      final benchmark = [
        NetWorthPoint(DateTime.utc(2025, 1, 1), 1000),
        NetWorthPoint(DateTime.utc(2025, 1, 16), 2000),
        NetWorthPoint(DateTime.utc(2025, 1, 31), 2666),
      ];

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: SizedBox(
              width: 400,
              height: 200,
              child: BenchmarkComparisonChart(
                portfolioPoints: portfolio,
                benchmarkPoints: benchmark,
                benchmarkTicker: 'URTH',
                hidden: false,
                portfolioColor: Colors.orange,
                benchmarkColor: Colors.gray,
                gridColor: Colors.gray,
                textColor: Colors.gray,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Actions & Fonds'), findsOneWidget);
      expect(find.text('URTH'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BenchmarkComparisonChart : rend sans planter quand les courbes se '
    'croisent plusieurs fois (l\'écart change de sens à chaque '
    'croisement, voir le découpage par segment de _ComparisonChartPainter)',
    (tester) async {
      // Portefeuille en dessous, puis au-dessus, puis en dessous du
      // benchmark : deux croisements successifs.
      final portfolio = [
        NetWorthPoint(DateTime.utc(2025, 1, 1), 1000),
        NetWorthPoint(DateTime.utc(2025, 1, 8), 1500),
        NetWorthPoint(DateTime.utc(2025, 1, 16), 900),
        NetWorthPoint(DateTime.utc(2025, 1, 24), 1400),
      ];
      final benchmark = [
        NetWorthPoint(DateTime.utc(2025, 1, 1), 1000),
        NetWorthPoint(DateTime.utc(2025, 1, 8), 1100),
        NetWorthPoint(DateTime.utc(2025, 1, 16), 1300),
        NetWorthPoint(DateTime.utc(2025, 1, 24), 1050),
      ];

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: SizedBox(
              width: 400,
              height: 200,
              child: BenchmarkComparisonChart(
                portfolioPoints: portfolio,
                benchmarkPoints: benchmark,
                benchmarkTicker: 'URTH',
                hidden: false,
                portfolioColor: Colors.orange,
                benchmarkColor: Colors.gray,
                gridColor: Colors.gray,
                textColor: Colors.gray,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BenchmarkComparisonChart : message de repli sans assez de points, '
    'sans planter',
    (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: SizedBox(
              width: 400,
              height: 200,
              child: BenchmarkComparisonChart(
                portfolioPoints: const [],
                benchmarkPoints: const [],
                benchmarkTicker: 'URTH',
                hidden: false,
                portfolioColor: Colors.orange,
                benchmarkColor: Colors.gray,
                gridColor: Colors.gray,
                textColor: Colors.gray,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pas assez de données sur cette période'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

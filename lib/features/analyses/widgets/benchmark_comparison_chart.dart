import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../dashboard/patrimoine_models.dart' show NetWorthPoint;
import '../../dashboard/widgets/net_worth_chart.dart'
    show
        chartLeftAxisWidth,
        drawAxisLabel,
        drawDashedLine,
        drawDateAxisLabels,
        formatChartTooltipDate;

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Deux courbes superposées, même grille de dates : la valorisation réelle
/// "Actions & Fonds" et ce que les mêmes flux auraient donné investis dans
/// le benchmark à la place (voir `analyses_calculations.dart`'s
/// `benchmarkEquivalentValueSeries`) — la traduction visuelle de l'alpha
/// affiché juste à côté. Les deux courbes partent du même point par
/// construction (même position de départ) ; l'écart entre elles est rempli
/// point par point — vert là où le portefeuille dépasse le benchmark
/// équivalent, rouge là où il est en dessous — plutôt qu'une seule couleur
/// pour tout le graphique, pour rester honnête même quand les deux courbes
/// se croisent plusieurs fois sur la période. Même pattern [CustomPainter]
/// main que [StackedNetWorthChart]/`NetWorthChart` (`net_worth_chart.dart`,
/// `patrimoine_chart_widgets.dart`), simplifié pour deux lignes non
/// empilées plutôt qu'une pile.
class BenchmarkComparisonChart extends StatefulWidget {
  final List<NetWorthPoint> portfolioPoints;
  final List<NetWorthPoint> benchmarkPoints;
  final String benchmarkTicker;
  final bool hidden;
  final Color portfolioColor;
  final Color benchmarkColor;
  final Color gridColor;
  final Color textColor;

  const BenchmarkComparisonChart({
    super.key,
    required this.portfolioPoints,
    required this.benchmarkPoints,
    required this.benchmarkTicker,
    required this.hidden,
    required this.portfolioColor,
    required this.benchmarkColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  State<BenchmarkComparisonChart> createState() =>
      _BenchmarkComparisonChartState();
}

class _BenchmarkComparisonChartState extends State<BenchmarkComparisonChart> {
  int? _hoveredIndex;

  void _updateHover(Offset localPosition, double width) {
    final count = widget.portfolioPoints.length;
    if (count < 2) return;
    final plotWidth = math.max(1.0, width - chartLeftAxisWidth);
    final fraction = ((localPosition.dx - chartLeftAxisWidth) / plotWidth)
        .clamp(0.0, 1.0);
    final index = (fraction * (count - 1)).round().clamp(0, count - 1);
    if (index != _hoveredIndex) setState(() => _hoveredIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = widget.portfolioPoints;
    final benchmark = widget.benchmarkPoints;
    if (portfolio.length < 2 ||
        benchmark.length < 2 ||
        portfolio.length != benchmark.length) {
      return Center(
        child: shadcn.Text(
          'Pas assez de données sur cette période',
        ).muted().small(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: widget.portfolioColor, label: 'Actions & Fonds'),
            const SizedBox(width: 16),
            _LegendDot(color: widget.benchmarkColor, label: widget.benchmarkTicker),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return MouseRegion(
                onHover: (event) =>
                    _updateHover(event.localPosition, size.width),
                onExit: (_) => setState(() => _hoveredIndex = null),
                child: GestureDetector(
                  onPanDown: (d) => _updateHover(d.localPosition, size.width),
                  onPanUpdate: (d) =>
                      _updateHover(d.localPosition, size.width),
                  onPanEnd: (_) => setState(() => _hoveredIndex = null),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: size,
                        painter: _ComparisonChartPainter(
                          portfolio: portfolio,
                          benchmark: benchmark,
                          portfolioColor: widget.portfolioColor,
                          benchmarkColor: widget.benchmarkColor,
                          gridColor: widget.gridColor,
                          textColor: widget.textColor,
                          hoveredIndex: _hoveredIndex,
                        ),
                      ),
                      if (_hoveredIndex != null)
                        Positioned(
                          left: _tooltipLeft(size.width),
                          top: 0,
                          child: IgnorePointer(
                            child: _ComparisonTooltip(
                              date: portfolio[_hoveredIndex!].date,
                              portfolioValue: portfolio[_hoveredIndex!].value,
                              benchmarkValue: benchmark[_hoveredIndex!].value,
                              benchmarkTicker: widget.benchmarkTicker,
                              hidden: widget.hidden,
                              portfolioColor: widget.portfolioColor,
                              benchmarkColor: widget.benchmarkColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  double _tooltipLeft(double width) {
    if (_hoveredIndex == null || widget.portfolioPoints.length < 2) return 0;
    final plotWidth = math.max(1.0, width - chartLeftAxisWidth);
    final x =
        chartLeftAxisWidth +
        plotWidth * (_hoveredIndex! / (widget.portfolioPoints.length - 1));
    return (x - 100).clamp(0.0, math.max(0.0, width - 200));
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        shadcn.Text(label).muted().xSmall(),
      ],
    );
  }
}

class _ComparisonTooltip extends StatelessWidget {
  final DateTime date;
  final double portfolioValue;
  final double benchmarkValue;
  final String benchmarkTicker;
  final bool hidden;
  final Color portfolioColor;
  final Color benchmarkColor;

  const _ComparisonTooltip({
    required this.date,
    required this.portfolioValue,
    required this.benchmarkValue,
    required this.benchmarkTicker,
    required this.hidden,
    required this.portfolioColor,
    required this.benchmarkColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.card.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              shadcn.Text(formatChartTooltipDate(date)).muted().xSmall(),
              _TooltipRow(
                color: portfolioColor,
                label: 'Actions & Fonds',
                value: displayEuros(portfolioValue, hidden),
              ),
              _TooltipRow(
                color: benchmarkColor,
                label: benchmarkTicker,
                value: displayEuros(benchmarkValue, hidden),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _TooltipRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          shadcn.Text(label).muted().xSmall(),
          const SizedBox(width: 8),
          shadcn.Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ).xSmall(),
        ],
      ),
    );
  }
}

class _ComparisonChartPainter extends CustomPainter {
  final List<NetWorthPoint> portfolio;
  final List<NetWorthPoint> benchmark;
  final Color portfolioColor;
  final Color benchmarkColor;
  final Color gridColor;
  final Color textColor;
  final int? hoveredIndex;

  _ComparisonChartPainter({
    required this.portfolio,
    required this.benchmark,
    required this.portfolioColor,
    required this.benchmarkColor,
    required this.gridColor,
    required this.textColor,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomAxisHeight = 20.0;
    final chartWidth = math.max(0.0, size.width - chartLeftAxisWidth);
    final chartHeight = math.max(0.0, size.height - bottomAxisHeight);
    final pointCount = portfolio.length;

    final allValues = [
      for (final p in portfolio) p.value,
      for (final p in benchmark) p.value,
    ];
    final minValue = allValues.reduce(math.min);
    final maxValue = allValues.reduce(math.max);
    final range = (maxValue - minValue).abs() < 1 ? 1.0 : maxValue - minValue;

    const topMargin = 8.0;
    final plotHeight = math.max(0.0, chartHeight - topMargin);

    double xFor(int i) =>
        chartLeftAxisWidth + chartWidth * (i / (pointCount - 1));
    double yFor(double value) =>
        topMargin + plotHeight - ((value - minValue) / range) * plotHeight;

    // Écart entre les deux courbes, rempli segment par segment — vert là
    // où le portefeuille dépasse le benchmark équivalent, rouge là où il
    // est en dessous. Un segment où les deux courbes se croisent (le
    // portefeuille passe au-dessus ou en dessous entre deux points de la
    // grille) est scindé au point de croisement exact (interpolé
    // linéairement) plutôt que peint d'une seule couleur qui trahirait le
    // sens réel de l'écart d'un des deux côtés du croisement.
    void fillGapQuad(
      double xLeft,
      double portfolioYLeft,
      double benchmarkYLeft,
      double xRight,
      double portfolioYRight,
      double benchmarkYRight,
      bool portfolioAbove,
    ) {
      final quad = Path()
        ..moveTo(xLeft, portfolioYLeft)
        ..lineTo(xRight, portfolioYRight)
        ..lineTo(xRight, benchmarkYRight)
        ..lineTo(xLeft, benchmarkYLeft)
        ..close();
      canvas.drawPath(
        quad,
        Paint()..color = (portfolioAbove ? _green : _red).withValues(alpha: 0.16),
      );
    }

    for (var i = 0; i < pointCount - 1; i++) {
      final xLeft = xFor(i);
      final xRight = xFor(i + 1);
      final portfolioLeft = portfolio[i].value;
      final portfolioRight = portfolio[i + 1].value;
      final benchmarkLeft = benchmark[i].value;
      final benchmarkRight = benchmark[i + 1].value;
      final diffLeft = portfolioLeft - benchmarkLeft;
      final diffRight = portfolioRight - benchmarkRight;

      if (diffLeft == 0 || diffRight == 0 || diffLeft.sign == diffRight.sign) {
        fillGapQuad(
          xLeft,
          yFor(portfolioLeft),
          yFor(benchmarkLeft),
          xRight,
          yFor(portfolioRight),
          yFor(benchmarkRight),
          (diffLeft + diffRight) >= 0,
        );
        continue;
      }

      // Croisement dans ce segment : la fraction où l'écart passe par
      // zéro, puis la valeur (identique pour les deux courbes à cet
      // instant précis) à ce point.
      final crossingFraction = diffLeft / (diffLeft - diffRight);
      final crossingX = xLeft + (xRight - xLeft) * crossingFraction;
      final crossingValue =
          portfolioLeft + (portfolioRight - portfolioLeft) * crossingFraction;
      final crossingY = yFor(crossingValue);
      fillGapQuad(
        xLeft,
        yFor(portfolioLeft),
        yFor(benchmarkLeft),
        crossingX,
        crossingY,
        crossingY,
        diffLeft >= 0,
      );
      fillGapQuad(
        crossingX,
        crossingY,
        crossingY,
        xRight,
        yFor(portfolioRight),
        yFor(benchmarkRight),
        diffRight >= 0,
      );
    }

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topMargin + plotHeight * (i / 2);
      drawDashedLine(
        canvas,
        Offset(chartLeftAxisWidth, y),
        Offset(chartLeftAxisWidth + chartWidth, y),
        gridPaint,
      );
      drawAxisLabel(
        canvas,
        displayEurosCompact(maxValue - (maxValue - minValue) * (i / 2), false),
        y,
        textColor,
      );
    }

    void drawLine(List<NetWorthPoint> points, Color color) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final point = Offset(xFor(i), yFor(points[i].value));
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Le benchmark d'abord, la vraie courbe par-dessus — elle est celle
    // qui compte le plus, elle ne doit jamais être masquée par l'autre là
    // où elles se croisent.
    drawLine(benchmark, benchmarkColor);
    drawLine(portfolio, portfolioColor);

    drawDateAxisLabels(
      canvas,
      pointCount,
      (i) => portfolio[i].date,
      xFor,
      chartHeight,
      textColor,
    );

    if (hoveredIndex != null) {
      final x = xFor(hoveredIndex!);
      final dashPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      drawDashedLine(canvas, Offset(x, 0), Offset(x, chartHeight), dashPaint);
      for (final (points, color) in [
        (benchmark, benchmarkColor),
        (portfolio, portfolioColor),
      ]) {
        final point = Offset(x, yFor(points[hoveredIndex!].value));
        canvas.drawCircle(point, 4, Paint()..color = color);
        canvas.drawCircle(
          point,
          4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ComparisonChartPainter oldDelegate) {
    return oldDelegate.portfolio != portfolio ||
        oldDelegate.benchmark != benchmark ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

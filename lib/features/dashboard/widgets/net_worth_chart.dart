import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../patrimoine_models.dart';

/// Largeur réservée à gauche du graphique pour les repères de montant sur
/// l'axe des ordonnées — partagée avec le graphique empilé de
/// `RealPatrimoineCard` (`StackedNetWorthChart`, dans
/// `patrimoine_chart_widgets.dart`) pour un alignement visuel cohérent
/// entre les deux types de graphiques.
const chartLeftAxisWidth = 46.0;

/// Graphique mono-courbe (aire + ligne) avec tooltip au survol, réutilisé
/// par la page de détail d'une catégorie et la vue détaillée d'un passif.
/// Pas de dépendance de charts : [CustomPainter] fait main, suit le pattern
/// déjà en place dans les simulations.
class NetWorthChart extends StatefulWidget {
  final List<NetWorthPoint> points;
  final String Function(double value) formatValue;
  final String Function(double value) axisLabelFormat;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  const NetWorthChart({
    super.key,
    required this.points,
    required this.formatValue,
    required this.axisLabelFormat,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  State<NetWorthChart> createState() => _NetWorthChartState();
}

class _NetWorthChartState extends State<NetWorthChart> {
  int? _hoveredIndex;

  void _updateHover(Offset localPosition, double width) {
    final points = widget.points;
    if (points.length < 2) return;
    final plotWidth = math.max(1.0, width - chartLeftAxisWidth);
    final fraction = ((localPosition.dx - chartLeftAxisWidth) / plotWidth)
        .clamp(0.0, 1.0);
    final index = (fraction * (points.length - 1)).round().clamp(
      0,
      points.length - 1,
    );
    if (index != _hoveredIndex) setState(() => _hoveredIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return Center(
        child: shadcn.Text(
          'Pas assez de données sur cette période',
        ).muted().small(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final hovered = _hoveredIndex != null
            ? widget.points[_hoveredIndex!]
            : null;
        return MouseRegion(
          onHover: (event) => _updateHover(event.localPosition, size.width),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: GestureDetector(
            onPanDown: (d) => _updateHover(d.localPosition, size.width),
            onPanUpdate: (d) => _updateHover(d.localPosition, size.width),
            onPanEnd: (_) => setState(() => _hoveredIndex = null),
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _NetWorthChartPainter(
                    points: widget.points,
                    axisLabelFormat: widget.axisLabelFormat,
                    lineColor: widget.lineColor,
                    gridColor: widget.gridColor,
                    textColor: widget.textColor,
                    hoveredIndex: _hoveredIndex,
                  ),
                ),
                if (hovered != null)
                  Positioned(
                    left: _tooltipLeft(size.width),
                    top: 0,
                    child: IgnorePointer(
                      child: _ChartTooltip(
                        point: hovered,
                        formatValue: widget.formatValue,
                        color: widget.lineColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _tooltipLeft(double width) {
    if (_hoveredIndex == null || widget.points.length < 2) return 0;
    final plotWidth = math.max(1.0, width - chartLeftAxisWidth);
    final x =
        chartLeftAxisWidth +
        plotWidth * (_hoveredIndex! / (widget.points.length - 1));
    return (x - 90).clamp(0.0, math.max(0.0, width - 180));
  }
}

class _ChartTooltip extends StatelessWidget {
  final NetWorthPoint point;
  final String Function(double value) formatValue;
  final Color color;

  const _ChartTooltip({
    required this.point,
    required this.formatValue,
    required this.color,
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
            color: theme.colorScheme.card.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              shadcn.Text(formatChartTooltipDate(point.date)).muted().xSmall(),
              shadcn.Text(
                formatValue(point.value),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ).small(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetWorthChartPainter extends CustomPainter {
  final List<NetWorthPoint> points;
  final String Function(double value) axisLabelFormat;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final int? hoveredIndex;

  _NetWorthChartPainter({
    required this.points,
    required this.axisLabelFormat,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomAxisHeight = 20.0;
    final chartWidth = math.max(0.0, size.width - chartLeftAxisWidth);
    final chartHeight = math.max(0.0, size.height - bottomAxisHeight);

    final values = points.map((p) => p.value);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs() < 1 ? 1.0 : maxValue - minValue;

    const topMargin = 8.0;
    final plotHeight = math.max(0.0, chartHeight - topMargin);

    double xFor(int i) =>
        chartLeftAxisWidth + chartWidth * (i / (points.length - 1));
    double yFor(double value) =>
        topMargin + plotHeight - ((value - minValue) / range) * plotHeight;

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
        axisLabelFormat(maxValue - (maxValue - minValue) * (i / 2)),
        y,
        textColor,
      );
    }

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xFor(i);
      final y = yFor(points[i].value);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final areaPath = Path()
      ..addPath(linePath, Offset.zero)
      ..lineTo(xFor(points.length - 1), chartHeight)
      ..lineTo(xFor(0), chartHeight)
      ..close();
    final areaPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, topMargin),
        Offset(0, chartHeight),
        [lineColor.withValues(alpha: 0.32), lineColor.withValues(alpha: 0.0)],
      );
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    drawDateLabel(
      canvas,
      points.first.date,
      xFor(0),
      chartHeight,
      TextAlign.left,
      textColor,
    );
    drawDateLabel(
      canvas,
      points[points.length ~/ 2].date,
      xFor(points.length ~/ 2),
      chartHeight,
      TextAlign.center,
      textColor,
    );
    drawDateLabel(
      canvas,
      points.last.date,
      xFor(points.length - 1),
      chartHeight,
      TextAlign.right,
      textColor,
    );

    if (hoveredIndex != null) {
      final x = xFor(hoveredIndex!);
      final y = yFor(points[hoveredIndex!].value);
      final dashPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      drawDashedLine(canvas, Offset(x, 0), Offset(x, chartHeight), dashPaint);
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = lineColor);
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NetWorthChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.lineColor != lineColor;
  }
}

/// Rangée d'onglets de période (1J/7J/1M/YTD/1A/Tout), réutilisée par
/// `RealPatrimoineCard`, la page de détail catégorie et "Mes meilleurs
/// actifs".
class PeriodTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const PeriodTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 4,
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: i == index ? theme.colorScheme.primary : null,
                borderRadius: BorderRadius.circular(999),
              ),
              child: shadcn.Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == index ? FontWeight.w600 : FontWeight.normal,
                  color: i == index
                      ? theme.colorScheme.primaryForeground
                      : theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// [DashboardPeriod] vit dans `patrimoine_models.dart` (déjà importé plus
// haut) plutôt qu'ici : c'est une notion de domaine (bornes de dates),
// réutilisée par les adaptateurs (`real_patrimoine_adapter.dart`), pas
// seulement par les widgets de ce fichier.

// ---------------------------------------------------------------------------
// Helpers de dessin partagés (aussi utilisés par le graphique empilé de
// RealPatrimoineCard, dans patrimoine_chart_widgets.dart).
// ---------------------------------------------------------------------------

void drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dashWidth = 4.0;
  const dashSpace = 4.0;
  final distance = (end - start).distance;
  if (distance == 0) return;
  final direction = (end - start) / distance;
  var covered = 0.0;
  while (covered < distance) {
    final segmentEnd = math.min(covered + dashWidth, distance);
    canvas.drawLine(
      start + direction * covered,
      start + direction * segmentEnd,
      paint,
    );
    covered += dashWidth + dashSpace;
  }
}

void drawDateLabel(
  Canvas canvas,
  DateTime date,
  double x,
  double y,
  TextAlign align,
  Color textColor,
) {
  final text =
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: 10, color: textColor),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout();
  double dx;
  switch (align) {
    case TextAlign.left:
      dx = x;
    case TextAlign.right:
      dx = x - painter.width;
    default:
      dx = x - painter.width / 2;
  }
  painter.paint(canvas, Offset(dx, y + 4));
}

/// Repère de montant sur l'axe des ordonnées, à gauche d'une ligne de
/// grille horizontale — aligné à droite, dans la marge [chartLeftAxisWidth].
void drawAxisLabel(Canvas canvas, String text, double y, Color textColor) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: 10, color: textColor),
    ),
    textAlign: TextAlign.right,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: chartLeftAxisWidth - 8);
  painter.paint(
    canvas,
    Offset(chartLeftAxisWidth - 8 - painter.width, y - painter.height / 2),
  );
}

String formatChartTooltipDate(DateTime date) {
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

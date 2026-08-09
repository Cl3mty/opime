import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/frosted_card.dart';
import '../dashboard_dummy_data.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Carte "Patrimoine net" : montant total, variation sur la période
/// sélectionnée, et graphique d'évolution avec tooltip au survol. Suit le
/// pattern de graphique fait main déjà utilisé dans les simulations
/// ([CustomPainter], pas de dépendance de charts ajoutée).
class PatrimoineCard extends StatefulWidget {
  final DashboardSampleData data;
  final bool hidden;

  const PatrimoineCard({super.key, required this.data, required this.hidden});

  @override
  State<PatrimoineCard> createState() => _PatrimoineCardState();
}

class _PatrimoineCardState extends State<PatrimoineCard> {
  static const _periods = [
    ('1J', 1),
    ('7J', 7),
    ('1M', 30),
    ('YTD', 220),
    ('1A', 365),
    ('Tout', 100000),
  ];

  int _periodIndex = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = widget.data.sliceForDays(_periods[_periodIndex].$2);
    final changePercent = widget.data.changePercentFor(points);
    final positive = changePercent >= 0;
    final changeColor = positive ? _green : _red;

    return FrostedCard(
      expand: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 460;
                final title = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    shadcn.Text('Patrimoine net').semiBold().large(),
                    const SizedBox(width: 4),
                    Icon(
                      LucideIcons.chevronDown,
                      size: 16,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ],
                );
                final tabs = _PeriodTabs(
                  labels: [for (final p in _periods) p.$1],
                  index: _periodIndex,
                  onChanged: (i) => setState(() => _periodIndex = i),
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), tabs],
                  );
                }
                return Row(children: [title, const Spacer(), tabs]);
              },
            ),
            const SizedBox(height: 12),
            shadcn.Text(
              displayEuros(widget.data.latestValue, widget.hidden),
            ).x2Large().bold(),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  positive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                  size: 14,
                  color: changeColor,
                ),
                const SizedBox(width: 4),
                shadcn.Text(
                  '${positive ? '+' : ''}${changePercent.toStringAsFixed(2)} %',
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ).small(),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _NetWorthChart(
                points: points,
                hidden: widget.hidden,
                lineColor: theme.colorScheme.primary,
                gridColor: theme.colorScheme.border,
                textColor: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const _PeriodTabs({
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

class _NetWorthChart extends StatefulWidget {
  final List<NetWorthPoint> points;
  final bool hidden;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  const _NetWorthChart({
    required this.points,
    required this.hidden,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  State<_NetWorthChart> createState() => _NetWorthChartState();
}

class _NetWorthChartState extends State<_NetWorthChart> {
  int? _hoveredIndex;

  void _updateHover(Offset localPosition, double width) {
    final points = widget.points;
    if (points.length < 2) return;
    final fraction = (localPosition.dx / width).clamp(0.0, 1.0);
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
                        hidden: widget.hidden,
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
    final x = width * (_hoveredIndex! / (widget.points.length - 1));
    return (x - 90).clamp(0.0, math.max(0.0, width - 180));
  }
}

class _ChartTooltip extends StatelessWidget {
  final NetWorthPoint point;
  final bool hidden;
  final Color color;

  const _ChartTooltip({
    required this.point,
    required this.hidden,
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
              shadcn.Text(_formatDate(point.date)).muted().xSmall(),
              shadcn.Text(
                displayEuros(point.value, hidden),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ).small(),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
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
}

class _NetWorthChartPainter extends CustomPainter {
  final List<NetWorthPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final int? hoveredIndex;

  _NetWorthChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomAxisHeight = 20.0;
    final chartWidth = size.width;
    final chartHeight = math.max(0.0, size.height - bottomAxisHeight);

    final values = points.map((p) => p.value);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs() < 1 ? 1.0 : maxValue - minValue;

    const topMargin = 8.0;
    final plotHeight = math.max(0.0, chartHeight - topMargin);

    double xFor(int i) => chartWidth * (i / (points.length - 1));
    double yFor(double value) =>
        topMargin + plotHeight - ((value - minValue) / range) * plotHeight;

    // Grille horizontale légère (3 lignes)
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topMargin + plotHeight * (i / 2);
      _drawDashedLine(canvas, Offset(0, y), Offset(chartWidth, y), gridPaint);
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

    // Labels de dates : début, milieu, fin.
    _drawDateLabel(
      canvas,
      points.first.date,
      xFor(0),
      chartHeight,
      TextAlign.left,
    );
    _drawDateLabel(
      canvas,
      points[points.length ~/ 2].date,
      xFor(points.length ~/ 2),
      chartHeight,
      TextAlign.center,
    );
    _drawDateLabel(
      canvas,
      points.last.date,
      xFor(points.length - 1),
      chartHeight,
      TextAlign.right,
    );

    if (hoveredIndex != null) {
      final x = xFor(hoveredIndex!);
      final y = yFor(points[hoveredIndex!].value);
      final dashPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      _drawDashedLine(canvas, Offset(x, 0), Offset(x, chartHeight), dashPaint);
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

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
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

  void _drawDateLabel(
    Canvas canvas,
    DateTime date,
    double x,
    double y,
    TextAlign align,
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

  @override
  bool shouldRepaint(covariant _NetWorthChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.lineColor != lineColor;
  }
}

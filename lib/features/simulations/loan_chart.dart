import 'dart:math';
import 'dart:ui' as ui;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../l10n/app_localizations.dart';
import 'loan_calculator.dart';

/// Pastille de légende (pastille de couleur + libellé + valeur), utilisée
/// à la fois par la simulation de prêt et le détail d'un passif réel pour
/// annoter les trois composantes d'une mensualité (capital/intérêts/
/// assurance) au-dessus de [LoanChart].
class LegendPill extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const LegendPill({
    super.key,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          shadcn.Text(label).small(),
          const SizedBox(width: 6),
          shadcn.Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ).small(),
        ],
      ),
    );
  }
}

/// Graphique en barres empilées (capital / intérêts / assurance par
/// année) — montre visuellement la part des intérêts qui diminue dans la
/// mensualité au fil du remboursement. Utilisé par la simulation de prêt
/// (`simulations_loan_screen.dart`) et par le détail d'un passif réel
/// (`liabilities/liability_detail_view.dart`), toutes deux dérivant
/// [years] du même moteur [simulateLoan].
class LoanChart extends StatefulWidget {
  final List<YearBar> years;
  final Color red;
  final Color blue;
  final Color gold;
  final Color textColor;
  final Color gridColor;
  final Color cardColor;
  final bool hidden;

  const LoanChart({
    super.key,
    required this.years,
    required this.red,
    required this.blue,
    required this.gold,
    required this.textColor,
    required this.gridColor,
    required this.cardColor,
    required this.hidden,
  });

  @override
  State<LoanChart> createState() => _LoanChartState();
}

class _LoanChartState extends State<LoanChart> {
  int? _hoveredYear;

  static const double _leftAxisWidth = 60;
  static const double _bottomAxisHeight = 24;

  @override
  Widget build(BuildContext context) {
    if (widget.years.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final chartWidth = width - _leftAxisWidth;
        final chartHeight = height - _bottomAxisHeight;
        final n = widget.years.length;
        final barSlot = chartWidth / n;

        void updateHover(Offset local) {
          final idx = ((local.dx - _leftAxisWidth) / barSlot).floor().clamp(
            0,
            n - 1,
          );
          if (idx != _hoveredYear) setState(() => _hoveredYear = idx);
        }

        YearBar? hovered = _hoveredYear != null
            ? widget.years[_hoveredYear!]
            : null;

        return MouseRegion(
          onHover: (e) => updateHover(e.localPosition),
          onExit: (_) => setState(() => _hoveredYear = null),
          child: GestureDetector(
            onPanDown: (details) => updateHover(details.localPosition),
            onPanUpdate: (details) => updateHover(details.localPosition),
            onPanEnd: (_) => setState(() => _hoveredYear = null),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(width, height),
                  painter: LoanChartPainter(
                    years: widget.years,
                    red: widget.red,
                    blue: widget.blue,
                    gold: widget.gold,
                    textColor: widget.textColor,
                    gridColor: widget.gridColor,
                    hoveredYear: _hoveredYear,
                    hidden: widget.hidden,
                    todayLabel: l10n.simulations_loan_chart_today,
                    yearsLabel: l10n.investments_delay_years(
                      widget.years.length,
                    ),
                  ),
                ),
                if (hovered != null)
                  Positioned(
                    left: (_leftAxisWidth + barSlot * _hoveredYear! - 130)
                        .clamp(
                          _leftAxisWidth,
                          max(_leftAxisWidth, width - 280),
                        ),
                    top: (chartHeight / 2 - 90).clamp(
                      0,
                      max(0.0, chartHeight - 180),
                    ),
                    child: ChartTooltip(
                      title: l10n.simulations_loan_chart_year_label(
                        hovered.year + 1,
                      ),
                      capital: hovered.capital,
                      interest: hovered.interest,
                      insurance: hovered.insurance,
                      red: widget.red,
                      blue: widget.blue,
                      gold: widget.gold,
                      cardColor: widget.cardColor,
                      hidden: widget.hidden,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ChartTooltip extends StatelessWidget {
  final String title;
  final double capital;
  final double interest;
  final double insurance;
  final Color red;
  final Color blue;
  final Color gold;
  final Color cardColor;
  final bool hidden;

  const ChartTooltip({
    super.key,
    required this.title,
    required this.capital,
    required this.interest,
    required this.insurance,
    required this.red,
    required this.blue,
    required this.gold,
    required this.cardColor,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(title).muted(),
                const SizedBox(height: 8),
                shadcn.Text(
                  displayEuros(capital + interest + insurance, hidden),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                shadcn.Text(
                  l10n.simulations_loan_chart_average_monthly_payment,
                ).muted().small(),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 8),
                _row(l10n.simulations_loan_chart_capital, capital, red),
                const SizedBox(height: 6),
                _row(l10n.simulations_loan_chart_interest, interest, blue),
                const SizedBox(height: 6),
                _row(l10n.simulations_loan_chart_insurance, insurance, gold),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: shadcn.Text(label)),
        shadcn.Text(
          displayEuros(value, hidden),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class LoanChartPainter extends CustomPainter {
  final List<YearBar> years;
  final Color red;
  final Color blue;
  final Color gold;
  final Color textColor;
  final Color gridColor;
  final int? hoveredYear;
  final bool hidden;
  final String todayLabel;
  final String yearsLabel;

  LoanChartPainter({
    required this.years,
    required this.red,
    required this.blue,
    required this.gold,
    required this.textColor,
    required this.gridColor,
    required this.hoveredYear,
    required this.hidden,
    required this.todayLabel,
    required this.yearsLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxisWidth = 60.0;
    const bottomAxisHeight = 24.0;
    final chartWidth = size.width - leftAxisWidth;
    final chartHeight = size.height - bottomAxisHeight;
    final n = years.length;
    final barSlot = chartWidth / n;
    final barWidth = barSlot * 0.6;

    final maxTotal = years
        .map((y) => y.capital + y.interest + y.insurance)
        .reduce((a, b) => a > b ? a : b);
    final axisMax = _niceCeil(maxTotal * 1.15);
    const gridLines = 4;
    final step = axisMax / gridLines;

    double yFor(double value) => chartHeight - (value / axisMax) * chartHeight;

    for (var i = 0; i <= gridLines; i++) {
      final v = step * i;
      final y = yFor(v);
      canvas.drawLine(
        Offset(leftAxisWidth, y),
        Offset(size.width, y),
        Paint()
          ..color = gridColor.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: displayEurosCompact(v, hidden),
          style: TextStyle(color: textColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftAxisWidth - tp.width - 8, y - tp.height / 2));
    }

    for (var idx = 0; idx < n; idx++) {
      final bar = years[idx];
      final x = leftAxisWidth + barSlot * idx + (barSlot - barWidth) / 2;
      final isHovered = hoveredYear == idx;
      final opacity = isHovered ? 1.0 : 0.85;

      var yCursor = chartHeight;
      // Capital (bas).
      final capitalTop = yFor(bar.capital);
      final capitalHeight = yCursor - capitalTop;
      _drawBarSegment(
        canvas,
        x,
        capitalTop,
        barWidth,
        capitalHeight,
        red.withValues(alpha: opacity),
        topRadius: bar.interest == 0 && bar.insurance == 0,
      );
      yCursor = capitalTop;

      // Intérêts (milieu).
      final interestTop = yFor(bar.capital + bar.interest);
      final interestHeight = yCursor - interestTop;
      _drawBarSegment(
        canvas,
        x,
        interestTop,
        barWidth,
        interestHeight,
        blue.withValues(alpha: opacity),
        topRadius: bar.insurance == 0,
      );
      yCursor = interestTop;

      // Assurance (haut).
      final insuranceTop = yFor(bar.capital + bar.interest + bar.insurance);
      final insuranceHeight = yCursor - insuranceTop;
      _drawBarSegment(
        canvas,
        x,
        insuranceTop,
        barWidth,
        insuranceHeight,
        gold.withValues(alpha: opacity),
        topRadius: true,
      );
    }

    _drawXLabel(
      canvas,
      todayLabel,
      leftAxisWidth,
      chartHeight,
      textColor,
      alignLeft: true,
    );
    _drawXLabel(
      canvas,
      yearsLabel,
      size.width,
      chartHeight,
      textColor,
      alignLeft: false,
    );
  }

  void _drawBarSegment(
    Canvas canvas,
    double x,
    double top,
    double width,
    double height,
    Color color, {
    bool topRadius = false,
  }) {
    if (height <= 0) return;
    final rect = Rect.fromLTWH(x, top, width, height);
    if (topRadius) {
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rrect, Paint()..color = color);
    } else {
      canvas.drawRect(rect, Paint()..color = color);
    }
  }

  void _drawXLabel(
    Canvas canvas,
    String text,
    double x,
    double y,
    Color color, {
    bool? alignLeft,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx;
    if (alignLeft == true) {
      dx = x;
    } else if (alignLeft == false) {
      dx = x - tp.width;
    } else {
      dx = x - tp.width / 2;
    }
    tp.paint(canvas, Offset(dx, y + 6));
  }

  double _niceCeil(double value) {
    if (value <= 0) return 100;
    var magnitude = 1.0;
    while (magnitude * 10 <= value) {
      magnitude *= 10;
    }
    final normalized = value / magnitude;
    double niceNormalized;
    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }
    return niceNormalized * magnitude;
  }

  @override
  bool shouldRepaint(covariant LoanChartPainter oldDelegate) =>
      oldDelegate.hoveredYear != hoveredYear ||
      oldDelegate.years != years ||
      oldDelegate.hidden != hidden;
}

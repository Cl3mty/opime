import 'dart:math' as math;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/ui/frosted_card.dart';
import '../dashboard_dummy_data.dart';
import 'net_worth_chart.dart' show PeriodTabs, dashboardPeriods;

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Palette cyclique pour les avatars à initiales des actifs, faute de
/// vrais logos (pas encore de module Patrimoine/import).
const _avatarPalette = [
  Color(0xFFF4BE7E),
  Color(0xFF7B8FE8),
  Color(0xFF6EE7B7),
  Color(0xFFF472B6),
  Color(0xFF60A5FA),
  Color(0xFFFBBF24),
];

/// Section "Mes meilleurs actifs" : une ligne de mini-cartes (nom, ticker,
/// variation, sparkline) qui défile horizontalement plutôt que de
/// s'enrouler, pour rester lisible même avec une dizaine d'actifs. Triée
/// par rendement décroissant sur la période choisie via [PeriodTabs].
class TopAssetsRow extends StatefulWidget {
  final List<DashboardAsset> assets;

  const TopAssetsRow({super.key, required this.assets});

  @override
  State<TopAssetsRow> createState() => _TopAssetsRowState();
}

class _TopAssetsRowState extends State<TopAssetsRow> {
  int _periodIndex = 2;

  @override
  Widget build(BuildContext context) {
    final days = dashboardPeriods[_periodIndex].$2;
    final sorted = [...widget.assets]
      ..sort(
        (a, b) => b
            .changePercentForDays(days)
            .compareTo(a.changePercentForDays(days)),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const shadcn.Text('Mes meilleurs actifs').large().medium(),
            const Spacer(),
            PeriodTabs(
              labels: [for (final p in dashboardPeriods) p.$1],
              index: _periodIndex,
              onChanged: (i) => setState(() => _periodIndex = i),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: 200,
              child: _AssetCard(
                asset: sorted[i],
                changePercent: sorted[i].changePercentForDays(days),
                avatarColor: _avatarPalette[i % _avatarPalette.length],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  final DashboardAsset asset;
  final double changePercent;
  final Color avatarColor;

  const _AssetCard({
    required this.asset,
    required this.changePercent,
    required this.avatarColor,
  });

  @override
  Widget build(BuildContext context) {
    final positive = changePercent >= 0;
    final color = positive ? _green : _red;

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Avatar(
                  size: 28,
                  initials: asset.initials,
                  backgroundColor: avatarColor.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      shadcn.Text(
                        asset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ).small().medium(),
                      shadcn.Text(asset.ticker).muted().xSmall(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                shadcn.Text(
                  '${positive ? '+' : ''}${changePercent.toStringAsFixed(2)} %',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ).small(),
                const Spacer(),
                SizedBox(
                  width: 64,
                  height: 24,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      values: asset.sparkline,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : maxValue - minValue;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - minValue) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

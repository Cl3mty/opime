import 'dart:math' as math;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/frosted_card.dart';
import '../patrimoine_models.dart';
import 'net_worth_chart.dart' show PeriodTabs;
import 'patrimoine_chart_widgets.dart' show ExtremePercentLabel;

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

/// Section "Mes meilleures performances" : une ligne de mini-cartes (nom,
/// ticker, +/- value, %, sparkline de la valeur de ma position) qui défile
/// horizontalement plutôt que de s'enrouler, pour rester lisible même avec
/// une dizaine d'actifs. Triée par performance décroissante sur la période
/// choisie via [PeriodTabs] — MA performance sur la position, pas le
/// rendement du cours du titre seul (voir
/// `real_patrimoine_adapter.dart`'s `buildRealTopAssets`).
class TopAssetsRow extends StatefulWidget {
  final List<DashboardAsset> assets;
  final bool hidden;

  const TopAssetsRow({super.key, required this.assets, required this.hidden});

  @override
  State<TopAssetsRow> createState() => _TopAssetsRowState();
}

class _TopAssetsRowState extends State<TopAssetsRow> {
  int _periodIndex = 2;

  @override
  Widget build(BuildContext context) {
    final period = DashboardPeriod.values[_periodIndex];
    // Performances nulles (rien d'investi ni détenu en début de période)
    // reléguées en fin de liste plutôt que de perturber le tri.
    final sorted = [...widget.assets]
      ..sort((a, b) {
        final aPercent = a.changeForPeriod(period)?.percent;
        final bPercent = b.changeForPeriod(period)?.percent;
        if (aPercent == null && bPercent == null) return 0;
        if (aPercent == null) return 1;
        if (bPercent == null) return -1;
        return bPercent.compareTo(aPercent);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const shadcn.Text('Mes meilleures performances').large().medium(),
            const Spacer(),
            PeriodTabs(
              labels: [for (final p in DashboardPeriod.values) p.label],
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
                change: sorted[i].changeForPeriod(period),
                sparkline: sorted[i].sparklineForPeriod(period),
                hidden: widget.hidden,
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
  final ({double euros, double? percent})? change;
  final List<double> sparkline;
  final bool hidden;
  final Color avatarColor;

  const _AssetCard({
    required this.asset,
    required this.change,
    required this.sparkline,
    required this.hidden,
    required this.avatarColor,
  });

  @override
  Widget build(BuildContext context) {
    final percent = change?.percent;
    final positive = (percent ?? change?.euros ?? 0) >= 0;
    final color = change == null
        ? const Color(0xFF94A3B8)
        : (positive ? _green : _red);

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      shadcn.Text(
                        change == null
                            ? '—'
                            : displayEuros(change!.euros, hidden),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ).small(),
                      if (percent != null)
                        ExtremePercentLabel(
                          percent: percent,
                          color: color,
                          style: Theme.of(context).typography.xSmall,
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 56,
                  height: 24,
                  child: CustomPaint(
                    painter: _SparklinePainter(values: sparkline, color: color),
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

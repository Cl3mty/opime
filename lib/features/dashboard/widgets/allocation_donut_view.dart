import 'dart:math' as math;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import 'allocation_blocks_view.dart';
import 'allocation_hover_tooltip.dart';

/// Vue "anneau" de l'Allocation : un donut chart avec le montant total au
/// centre (comme sur la capture Finary), et une légende compacte à côté
/// (en dessous si la carte est trop étroite). Le survol d'une section
/// (déterminé par l'angle du curseur autour du centre) l'isole — les
/// autres s'estompent — et affiche sa description. Prend les mêmes
/// [AllocationSlice] génériques que [AllocationBlocksView] pour être
/// réutilisable aussi bien par la carte Allocation (catégories) que par la
/// Distribution d'une page de détail (comptes/prêts) — voir
/// `category_detail_screen.dart`.
class AllocationDonutView extends StatefulWidget {
  final List<AllocationSlice> slices;
  final double total;
  final bool hidden;

  const AllocationDonutView({
    super.key,
    required this.slices,
    required this.total,
    required this.hidden,
  });

  @override
  State<AllocationDonutView> createState() => _AllocationDonutViewState();
}

class _AllocationDonutViewState extends State<AllocationDonutView> {
  String? _hoveredId;
  Offset? _pointer;

  void _updateHover(Offset localPosition, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.34;
    final innerRadius = radius - strokeWidth;
    final distance = (localPosition - center).distance;
    if (distance < innerRadius || distance > radius) {
      setState(() {
        _hoveredId = null;
        _pointer = localPosition;
      });
      return;
    }
    var angle =
        math.atan2(localPosition.dy - center.dy, localPosition.dx - center.dx) +
        math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    var cursor = 0.0;
    String? hoveredId;
    for (final slice in widget.slices) {
      final sweep = slice.percent / 100 * 2 * math.pi;
      if (angle >= cursor && angle < cursor + sweep) {
        hoveredId = slice.id;
        break;
      }
      cursor += sweep;
    }
    setState(() {
      _hoveredId = hoveredId;
      _pointer = localPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hoveredSlice = widget.slices
        .where((s) => s.id == _hoveredId)
        .firstOrNull;

    final ring = AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return MouseRegion(
            onHover: (event) => _updateHover(event.localPosition, size),
            onExit: (_) => setState(() {
              _hoveredId = null;
              _pointer = null;
            }),
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _DonutPainter(
                    slices: widget.slices,
                    hoveredId: _hoveredId,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      shadcn.Text(
                        displayEuros(widget.total, widget.hidden),
                      ).semiBold(),
                      shadcn.Text('Total').muted().xSmall(),
                    ],
                  ),
                ),
                if (hoveredSlice != null && _pointer != null)
                  Positioned(
                    left: (_pointer!.dx - 110).clamp(
                      0.0,
                      math.max(0.0, size.width - 220),
                    ),
                    top: (_pointer!.dy + 12).clamp(
                      0.0,
                      math.max(0.0, size.height - 60),
                    ),
                    child: IgnorePointer(
                      child: AllocationHoverTooltip(
                        label: hoveredSlice.label,
                        percent: hoveredSlice.percent,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    final legend = _Legend(slices: widget.slices, hoveredId: _hoveredId);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            children: [
              Expanded(child: Center(child: ring)),
              const SizedBox(height: 16),
              legend,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: Center(child: ring)),
            const SizedBox(width: 20),
            legend,
          ],
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _DonutPainter extends CustomPainter {
  final List<AllocationSlice> slices;
  final String? hoveredId;

  _DonutPainter({required this.slices, required this.hoveredId});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.34;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    final dimmed = hoveredId != null;
    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = slice.percent / 100 * 2 * math.pi;
      final isHovered = slice.id == hoveredId;
      final paint = Paint()
        ..color = slice.color.withValues(
          alpha: dimmed && !isHovered ? 0.3 : 1.0,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = dimmed && !isHovered ? strokeWidth * 0.95 : strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect,
        startAngle,
        math.max(sweep - 0.02, 0.001),
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.hoveredId != hoveredId;
}

class _Legend extends StatelessWidget {
  final List<AllocationSlice> slices;
  final String? hoveredId;

  const _Legend({required this.slices, required this.hoveredId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: hoveredId != null && hoveredId != slice.id ? 0.35 : 1.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  shadcn.Text(slice.label).small(),
                  const SizedBox(width: 6),
                  shadcn.Text(
                    slice.percent < 1
                        ? '${slice.percent.toStringAsFixed(2)} %'
                        : '${slice.percent.toStringAsFixed(0)} %',
                  ).muted().xSmall(),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

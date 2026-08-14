import 'dart:math' as math;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import '../patrimoine_models.dart';
import 'allocation_hover_tooltip.dart';

/// Vue "pyramide" de l'Allocation : les catégories sont regroupées par
/// [AllocationTier] en bandes trapézoïdales — socle (fondation) en bas,
/// croissance au milieu, opportuniste (spéculatif) en haut. La largeur de
/// chaque bande est ∝ à la racine carrée du pourcentage cumulé depuis le
/// sommet (plutôt que strictement proportionnelle), pour que les tiers
/// minoritaires (crypto, start-up) restent visibles — c'est un visuel
/// illustratif du niveau de risque, pas un graphique à aire strictement
/// proportionnelle. Le survol d'une section l'isole (les autres s'estompent)
/// et affiche son nom et son pourcentage.
class AllocationPyramidView extends StatefulWidget {
  final List<(PatrimoineCategory, double)> slices;

  const AllocationPyramidView({super.key, required this.slices});

  @override
  State<AllocationPyramidView> createState() => _AllocationPyramidViewState();
}

class _AllocationPyramidViewState extends State<AllocationPyramidView> {
  String? _hoveredId;
  Offset? _pointer;

  void _updateHover(Offset localPosition, Size size) {
    final segments = _layoutSegments(widget.slices, size);
    String? hoveredId;
    for (final segment in segments) {
      if (segment.path.contains(localPosition)) {
        hoveredId = segment.category.id;
        break;
      }
    }
    setState(() {
      _hoveredId = hoveredId;
      _pointer = localPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hoveredSlice = widget.slices
        .where((s) => s.$1.id == _hoveredId)
        .firstOrNull;
    return LayoutBuilder(
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
                painter: _PyramidPainter(
                  slices: widget.slices,
                  hoveredId: _hoveredId,
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
                      label: hoveredSlice.$1.label,
                      percent: hoveredSlice.$2,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Segment {
  final PatrimoineCategory category;
  final Path path;
  final Rect labelRect;

  const _Segment({
    required this.category,
    required this.path,
    required this.labelRect,
  });
}

const _tierOrderTopToBottom = [
  AllocationTier.opportuniste,
  AllocationTier.croissance,
  AllocationTier.fondation,
];

List<_Segment> _layoutSegments(
  List<(PatrimoineCategory, double)> slices,
  Size size,
) {
  final tierBands = <(AllocationTier, List<(PatrimoineCategory, double)>)>[
    for (final tier in _tierOrderTopToBottom)
      (
        tier,
        [
          for (final s in slices)
            if (s.$1.tier == tier) s,
        ],
      ),
  ]..removeWhere((band) => band.$2.isEmpty);
  if (tierBands.isEmpty) return [];

  final segments = <_Segment>[];
  final bandHeight = size.height / tierBands.length;
  var cumulative = 0.0;
  var topFraction = 0.0;

  for (var bandIndex = 0; bandIndex < tierBands.length; bandIndex++) {
    final (_, entries) = tierBands[bandIndex];
    final tierPercent = entries.fold<double>(0, (sum, e) => sum + e.$2);
    cumulative += tierPercent;
    final bottomFraction = math.sqrt((cumulative / 100).clamp(0.0, 1.0));

    final bandTop = bandIndex * bandHeight;
    final bandBottom = bandTop + bandHeight;
    final topWidth = size.width * topFraction;
    final bottomWidth = size.width * bottomFraction;
    final topLeft = (size.width - topWidth) / 2;
    final bottomLeft = (size.width - bottomWidth) / 2;

    var withinCumulative = 0.0;
    for (final (category, percent) in entries) {
      // tierPercent est nul si toutes les catégories de la bande valent 0
      // (ex : compte réel tout juste créé, sans transaction) — dans ce cas
      // les largeurs sont de toute façon nulles (bottomFraction ci-dessus
      // vaut 0), on évite juste la division par zéro qui produirait NaN.
      final startFrac = tierPercent == 0 ? 0.0 : withinCumulative / tierPercent;
      withinCumulative += percent;
      final endFrac = tierPercent == 0 ? 0.0 : withinCumulative / tierPercent;

      final segTopLeft = topLeft + topWidth * startFrac;
      final segTopRight = topLeft + topWidth * endFrac;
      final segBottomLeft = bottomLeft + bottomWidth * startFrac;
      final segBottomRight = bottomLeft + bottomWidth * endFrac;

      final path = Path()
        ..moveTo(segTopLeft, bandTop)
        ..lineTo(segTopRight, bandTop)
        ..lineTo(segBottomRight, bandBottom)
        ..lineTo(segBottomLeft, bandBottom)
        ..close();

      segments.add(
        _Segment(
          category: category,
          path: path,
          labelRect: Rect.fromLTRB(
            segBottomLeft,
            bandTop,
            segBottomRight,
            bandBottom,
          ),
        ),
      );
    }

    topFraction = bottomFraction;
  }

  return segments;
}

class _PyramidPainter extends CustomPainter {
  final List<(PatrimoineCategory, double)> slices;
  final String? hoveredId;

  _PyramidPainter({required this.slices, required this.hoveredId});

  @override
  void paint(Canvas canvas, Size size) {
    final segments = _layoutSegments(slices, size);
    final dimmed = hoveredId != null;

    for (final segment in segments) {
      final isHovered = segment.category.id == hoveredId;
      canvas.drawPath(
        segment.path,
        Paint()
          ..color = segment.category.color.withValues(
            alpha: dimmed && !isHovered ? 0.25 : 0.92,
          ),
      );
      _drawLabel(
        canvas,
        segment.category,
        segment.labelRect,
        dimmed && !isHovered,
      );
    }

    for (var i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..strokeWidth = 1,
      );
    }
  }

  /// Toujours une seule ligne "Libellé • X %" — réduit la taille de
  /// police par paliers jusqu'à ce qu'elle tienne dans la largeur de la
  /// section plutôt que de laisser le libellé passer sur 2 lignes.
  void _drawLabel(
    Canvas canvas,
    PatrimoineCategory category,
    Rect rect,
    bool dim,
  ) {
    if (rect.width < 30 || rect.height < 14) return;
    final percent = slices.firstWhere((s) => s.$1.id == category.id).$2;
    final percentText = percent < 1
        ? percent.toStringAsFixed(2)
        : percent.toStringAsFixed(0);
    final text = '${category.label} • $percentText %';
    final maxWidth = rect.width - 6;
    final color = Colors.white.withValues(alpha: dim ? 0.5 : 1);

    TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    for (
      var fontSize = 10.0;
      painter.width > maxWidth && fontSize >= 7;
      fontSize -= 1
    ) {
      painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    }
    if (painter.height > rect.height) return;
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _PyramidPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.hoveredId != hoveredId;
}

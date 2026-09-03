import 'dart:math' as math;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/donut_hover.dart';
import 'allocation_blocks_view.dart';
import 'allocation_hover_tooltip.dart';

/// Vue "anneau" de l'Allocation : un donut chart avec le montant total au
/// centre (comme sur la capture Finary), et une légende compacte à côté
/// (en dessous si la carte est trop étroite). Le survol d'une section
/// (déterminé par l'angle du curseur autour du centre) l'isole — les
/// autres s'estompent — et affiche son nom et son pourcentage. Prend les mêmes
/// [AllocationSlice] génériques que [AllocationBlocksView] pour être
/// réutilisable aussi bien par la carte Allocation du Dashboard (catégories)
/// que par celle d'une page de détail (comptes/prêts) — voir
/// `category_detail_screen.dart`.
class AllocationDonutView extends StatefulWidget {
  final List<AllocationSlice> slices;
  final double total;
  final bool hidden;

  /// Appelé à chaque changement de la part survolée (`null` quand la
  /// souris quitte l'anneau/la légende) — optionnel, pour qu'un parent
  /// affiche le détail (ex : les investissements) de la part actuellement
  /// survolée sans dupliquer la logique de hit-test du donut.
  final ValueChanged<String?>? onHoveredIdChanged;

  /// Appelé au clic sur une part (anneau ou légende) — optionnel, pour
  /// qu'un parent "épingle" une sélection qui reste visible même une fois
  /// la souris repartie (contrairement à [onHoveredIdChanged], purement
  /// transitoire).
  final ValueChanged<String>? onSliceTap;

  const AllocationDonutView({
    super.key,
    required this.slices,
    required this.total,
    required this.hidden,
    this.onHoveredIdChanged,
    this.onSliceTap,
  });

  @override
  State<AllocationDonutView> createState() => _AllocationDonutViewState();
}

class _AllocationDonutViewState extends State<AllocationDonutView> {
  String? _hoveredId;
  Offset? _pointer;

  /// Filtrage partagé par tout le hit-test/rendu : une part à 0 % ne
  /// dessine rien, elle ne doit donc pas non plus compter au survol/clic.
  List<AllocationSlice> get _visibleSlices =>
      widget.slices.where((s) => s.percent > 0).toList();

  int? _hitTest(Offset localPosition, Size size, List<AllocationSlice> slices) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.34;
    return hitTestDonutSlice(
      point: localPosition,
      center: center,
      // `_DonutPainter` dessine le trait centré sur `radius - strokeWidth /
      // 2` (voir son `Rect.fromCircle`, requis pour que le bord extérieur
      // de l'anneau affleure exactement `radius` sans déborder de la
      // boîte) — [hitTestDonutSlice] doit recevoir cette même valeur
      // "ligne médiane", pas `radius` brut, sinon sa zone de détection
      // ([radius - strokeWidth/2, radius + strokeWidth/2]) est décalée
      // vers l'extérieur par rapport à l'anneau réellement dessiné
      // ([radius - strokeWidth, radius]) : régression trouvée en
      // implémentant — la moitié intérieure de l'anneau visible ne
      // déclenchait alors jamais le survol.
      radius: radius - strokeWidth / 2,
      strokeWidth: strokeWidth,
      values: [for (final s in slices) s.percent],
    );
  }

  void _setHoveredId(String? id) {
    if (id == _hoveredId) return;
    setState(() => _hoveredId = id);
    widget.onHoveredIdChanged?.call(id);
  }

  void _updateHover(Offset localPosition, Size size) {
    final slices = _visibleSlices;
    final hoveredIndex = _hitTest(localPosition, size, slices);
    setState(() => _pointer = localPosition);
    _setHoveredId(hoveredIndex == null ? null : slices[hoveredIndex].id);
  }

  void _handleTapUp(Offset localPosition, Size size) {
    final slices = _visibleSlices;
    final tappedIndex = _hitTest(localPosition, size, slices);
    if (tappedIndex != null) widget.onSliceTap?.call(slices[tappedIndex].id);
  }

  @override
  Widget build(BuildContext context) {
    // Une part à 0 % (catégorie ou compte sans valeur) ne dessine rien :
    // la filtrer évite un point parasite dans l'anneau et une ligne
    // "0 %" dans la légende, sans changer le total affiché au centre.
    final slices = widget.slices.where((s) => s.percent > 0).toList();

    final hoveredSlice = slices.where((s) => s.id == _hoveredId).firstOrNull;

    final ring = AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return MouseRegion(
            // `onEnter` en plus de `onHover` : Flutter ne déclenche
            // `onHover` que sur un vrai mouvement de la souris — quand
            // l'anneau apparaît *sous* une souris déjà immobile (ouverture
            // de la page, bascule d'onglet...), seul `onEnter` se déclenche
            // (voir `MouseTracker.updateAllDevices`, appelé après chaque
            // frame). Sans lui, aucune part ne se surlignait tant que la
            // souris ne bougeait pas d'un pixel de plus après être entrée
            // dans l'anneau — d'où la "latence" au survol.
            onEnter: (event) => _updateHover(event.localPosition, size),
            onHover: (event) => _updateHover(event.localPosition, size),
            onExit: (_) {
              setState(() => _pointer = null);
              _setHoveredId(null);
            },
            child: GestureDetector(
              onTapUp: (details) => _handleTapUp(details.localPosition, size),
              child: Stack(
                children: [
                  CustomPaint(
                    size: size,
                    painter: _DonutPainter(
                      slices: slices,
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
            ),
          );
        },
      ),
    );
    final legend = _Legend(
      slices: slices,
      hoveredId: _hoveredId,
      onHoveredIdChanged: _setHoveredId,
      onSliceTap: widget.onSliceTap,
    );

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
            // Largeur bornée : un libellé long ne doit pas rogner le donut à
            // l'excès — au-delà de cette largeur, les libellés sont
            // tronqués (voir [_Legend]).
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: legend,
            ),
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
  final ValueChanged<String?>? onHoveredIdChanged;
  final ValueChanged<String>? onSliceTap;

  const _Legend({
    required this.slices,
    required this.hoveredId,
    this.onHoveredIdChanged,
    this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: MouseRegion(
              cursor: onSliceTap == null
                  ? MouseCursor.defer
                  : SystemMouseCursors.click,
              onEnter: (_) => onHoveredIdChanged?.call(slice.id),
              onExit: (_) => onHoveredIdChanged?.call(null),
              child: GestureDetector(
                onTap: () => onSliceTap?.call(slice.id),
                child: AnimatedOpacity(
                  // Zéro délai : l'estompage de la légende doit suivre le
                  // survol au pixel près, comme l'arc du donut lui-même
                  // (`_DonutPainter`, un `CustomPainter` sans transition —
                  // repeint directement à chaque changement de `hoveredId`,
                  // aucune raison que la légende traîne derrière).
                  duration: Duration.zero,
                  opacity: hoveredId != null && hoveredId != slice.id
                      ? 0.35
                      : 1.0,
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
                      // Libellé tronqué quand il est trop long : la largeur
                      // de la légende est bornée (voir
                      // [AllocationDonutView]) pour ne pas réduire la
                      // taille du donut.
                      Flexible(
                        child: shadcn.Text(
                          slice.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ).small(),
                      ),
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
            ),
          ),
      ],
    );
  }
}

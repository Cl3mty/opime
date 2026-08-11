import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

/// Une part affichée comme bloc dans [AllocationBlocksView] — assez
/// générique pour représenter aussi bien une catégorie d'allocation
/// (carte Allocation) qu'un compte au sein d'une catégorie (Distribution
/// de la page de détail).
class AllocationSlice {
  final String id;
  final String label;
  final Color color;
  final double percent;

  const AllocationSlice({
    required this.id,
    required this.label,
    required this.color,
    required this.percent,
  });
}

/// Vue "blocs" en treemap simple fait de rectangles proportionnels (pas de
/// [CustomPainter] nécessaire ici, les blocs sont des rectangles
/// axis-aligned) — la plus grosse part occupe un bloc à gauche, les autres
/// s'empilent dans une colonne à droite. Chaque bloc s'estompe au survol
/// d'un autre bloc, et affiche son titre en bulle au survol.
class AllocationBlocksView extends StatefulWidget {
  final List<AllocationSlice> slices;

  const AllocationBlocksView({super.key, required this.slices});

  @override
  State<AllocationBlocksView> createState() => _AllocationBlocksViewState();
}

class _AllocationBlocksViewState extends State<AllocationBlocksView> {
  String? _hoveredId;

  @override
  Widget build(BuildContext context) {
    // Une part à 0 % (catégorie ou compte sans valeur) ne doit pas occuper
    // de bloc : filtrée ici, la plus grande part restante prend sa place
    // dans le treemap.
    final sorted = [
      for (final slice in widget.slices)
        if (slice.percent > 0) slice,
    ]..sort((a, b) => b.percent.compareTo(a.percent));
    if (sorted.isEmpty) return const SizedBox.shrink();

    final first = sorted.first;
    final rest = sorted.skip(1).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            flex: _flex(first.percent),
            child: _Block(
              slice: first,
              dimmed: _hoveredId != null && _hoveredId != first.id,
              onHoverChanged: (h) =>
                  setState(() => _hoveredId = h ? first.id : null),
            ),
          ),
          if (rest.isNotEmpty) ...[
            const SizedBox(width: 3),
            Expanded(
              flex: _flex(100 - first.percent),
              child: Column(
                children: [
                  for (var i = 0; i < rest.length; i++) ...[
                    if (i > 0) const SizedBox(height: 3),
                    Expanded(
                      flex: _flex(rest[i].percent),
                      child: _Block(
                        slice: rest[i],
                        dimmed: _hoveredId != null && _hoveredId != rest[i].id,
                        onHoverChanged: (h) =>
                            setState(() => _hoveredId = h ? rest[i].id : null),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Convertit un pourcentage en facteur `flex` entier (×10 pour garder une
  /// décimale de précision sur les petites catégories comme Crypto/Start-up).
  int _flex(double percent) => (percent * 10).round().clamp(1, 100000);
}

class _Block extends StatelessWidget {
  final AllocationSlice slice;
  final bool dimmed;
  final ValueChanged<bool> onHoverChanged;

  const _Block({
    required this.slice,
    required this.dimmed,
    required this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    final percentText = slice.percent < 1
        ? slice.percent.toStringAsFixed(2)
        : slice.percent.toStringAsFixed(0);
    final content = MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: dimmed ? 0.35 : 1.0,
        child: Container(
          color: slice.color.withValues(alpha: 0.88),
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          // FittedBox plutôt qu'un maxLines/overflow classique : le
          // libellé reste toujours sur une seule ligne, quitte à réduire
          // sa taille de police quand le bloc est étroit.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: shadcn.Text(
              '${slice.label} • $percentText %',
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ).small(),
          ),
        ),
      ),
    );
    // Toujours un tooltip au survol : le titre et le pourcentage du bloc
    // survolé doivent s'afficher — comme dans les autres vues d'allocation,
    // pas de description détaillée.
    return Tooltip(
      tooltip: (context) => TooltipContainer(
        child: shadcn.Text(
          '${slice.label} · $percentText %',
        ).semiBold().small(),
      ),
      child: content,
    );
  }
}

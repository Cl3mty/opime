import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

const _red = Color(0xFFEF4444);
const _green = Color(0xFF22C55E);
const _neutral = Color(0xFF64748B);

/// Grille N×N de corrélations de Pearson entre [labels] — une case
/// `matrix[i][j]` colorée du rouge (-1, anti-corrélées) au vert (+1,
/// corrélées), plus saturée à mesure que la corrélation est marquée dans
/// un sens ou l'autre ; `null` (pas assez de points communs, voir
/// `pearsonCorrelation`) affiché en gris neutre avec un tiret. La
/// diagonale (corrélation d'une ligne avec elle-même, toujours 1) est
/// grisée plutôt que colorée : information triviale, la mettre en avant
/// distrairait de ce que la matrice sert vraiment à lire.
///
/// [onSelectLabel], s'il est fourni, rend les en-têtes de ligne cliquables
/// (soulignés) — utilisé par `_CorrelationCard`
/// (`analyses_screen.dart`) pour permettre de passer de la matrice entre
/// catégories à la matrice, au sein d'une catégorie choisie, entre ses
/// investissements individuels.
class CorrelationMatrix extends StatelessWidget {
  final List<String> labels;
  final List<List<double?>> matrix;
  final void Function(int index)? onSelectLabel;

  const CorrelationMatrix({
    super.key,
    required this.labels,
    required this.matrix,
    this.onSelectLabel,
  });

  static const _cellSize = 68.0;
  static const _headerWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: _headerWidth),
              for (final label in labels)
                SizedBox(
                  width: _cellSize,
                  child: Tooltip(
                    tooltip: (context) =>
                        TooltipContainer(child: shadcn.Text(label)),
                    child: shadcn.Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ).muted().xSmall(),
                  ),
                ),
            ],
          ),
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _headerWidth,
                    child: onSelectLabel == null
                        ? shadcn.Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ).small()
                        : GestureDetector(
                            onTap: () => onSelectLabel!(i),
                            child: shadcn.Text(
                              labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ).small(),
                          ),
                  ),
                  for (var j = 0; j < labels.length; j++)
                    _Cell(
                      value: i == j ? 1.0 : matrix[i][j],
                      diagonal: i == j,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final double? value;
  final bool diagonal;

  const _Cell({required this.value, required this.diagonal});

  @override
  Widget build(BuildContext context) {
    final color = diagonal || value == null
        ? _neutral.withValues(alpha: 0.15)
        : _colorFor(value!);
    return Container(
      width: CorrelationMatrix._cellSize,
      height: CorrelationMatrix._cellSize,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: shadcn.Text(
        value == null ? '—' : value!.toStringAsFixed(2),
        style: TextStyle(
          color: diagonal || value == null
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.white,
          fontWeight: diagonal ? FontWeight.normal : FontWeight.w600,
        ),
      ).xSmall(),
    );
  }
}

/// Rouge à -1, vert à +1, opacité croissante avec la force de la
/// corrélation (un ±0,1 quasi nul reste presque invisible, un ±0,9 marqué
/// ressort nettement) — la couleur seule indique déjà le sens, la
/// saturation indique l'intensité.
Color _colorFor(double value) {
  final clamped = value.clamp(-1.0, 1.0);
  final base = clamped >= 0 ? _green : _red;
  return base.withValues(alpha: 0.18 + 0.5 * clamped.abs());
}

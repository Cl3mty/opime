import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

/// Bulle flottante (libellé + pourcentage exact) affichée près du curseur
/// au survol d'une section de la carte Allocation — partagée par les vues
/// pyramide et anneau (démo ou réelles, actifs ou passifs), dont les
/// segments sont dessinés sur un `Canvas` unique (pas de widget par
/// segment auquel accrocher un [Tooltip] classique, contrairement à la vue
/// blocs). Volontairement court : juste le libellé et le chiffre exact,
/// pas de phrase descriptive.
class AllocationHoverTooltip extends StatelessWidget {
  final String label;
  final double percent;

  const AllocationHoverTooltip({
    super.key,
    required this.label,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentText = percent < 1
        ? percent.toStringAsFixed(2)
        : percent.toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          shadcn.Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ).small(),
          const SizedBox(width: 6),
          shadcn.Text('$percentText %').muted().small(),
        ],
      ),
    );
  }
}

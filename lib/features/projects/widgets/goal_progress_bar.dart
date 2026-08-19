import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/gold_progress_bar.dart';

/// Barre de progression "objectif" — montant actuel à gauche, montant
/// cible à droite, remplissage doré dégradé entre les deux (même teinte
/// d'accent que le reste de l'app, `theme.colorScheme.primary`). Partagée
/// par la carte de la liste des projets (`projects_screen.dart`) et la vue
/// détail (`project_editor.dart`) pour un rendu identique aux deux
/// endroits.
///
/// Sans [montantCible] (projet sans montant cible, voir
/// `Project.montantCible`), affiche seulement le montant actuel, sans
/// barre — il n'y a rien à proportionner.
class GoalProgressBar extends StatelessWidget {
  final double currentValue;
  final double? montantCible;

  /// Hauteur du remplissage — plus haute pour la vue détail (Finary) que
  /// pour une ligne de liste compacte.
  final double height;

  const GoalProgressBar({
    super.key,
    required this.currentValue,
    required this.montantCible,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    final target = montantCible;
    if (target == null || target <= 0) {
      return shadcn.Text(formatEuros(currentValue)).semiBold();
    }

    final fraction = (currentValue / target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GoldProgressBar(fraction: fraction, height: height),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            shadcn.Text(formatEuros(currentValue)).small().semiBold(),
            shadcn.Text(formatEuros(target)).small().semiBold(),
          ],
        ),
      ],
    );
  }
}

/// Badge "En bonne voie" / "En retard" — voir
/// `project_trajectory.dart`'s `isProjectOnTrack`. Ne s'affiche pas
/// ([SizedBox.shrink]) sans montant cible ([onTrack] `null`), rien à
/// évaluer.
class ProjectOnTrackBadge extends StatelessWidget {
  final bool? onTrack;

  const ProjectOnTrackBadge({super.key, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    final onTrack = this.onTrack;
    if (onTrack == null) return const SizedBox.shrink();

    final color = onTrack ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
    final label = onTrack ? 'En bonne voie' : 'En retard';
    final icon = onTrack ? LucideIcons.circleCheck : LucideIcons.triangleAlert;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          shadcn.Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

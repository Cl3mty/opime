import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';

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
    final theme = Theme.of(context);
    final target = montantCible;
    if (target == null || target <= 0) {
      return shadcn.Text(formatEuros(currentValue)).semiBold();
    }

    final fraction = (currentValue / target).clamp(0.0, 1.0);
    final accent = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            // `theme.colorScheme.border`/`.muted` sont trop proches du blanc
            // en thème clair pour qu'on distingue où s'arrête la barre (à
            // peine 231 vs 255 de luminosité, vérifié pixel par pixel) —
            // teinté du même doré que le remplissage plutôt qu'un gris
            // neutre. Le doré étant déjà clair, une opacité aussi faible que
            // pour un gris neutre redevenait invisible sur fond blanc
            // (vérifié pixel par pixel à nouveau) : opacité bien plus élevée
            // ici pour compenser.
            border: Border.all(color: accent.withValues(alpha: 0.9)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: height,
                  color: accent.withValues(alpha: 0.35),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent.withValues(alpha: 0.7), accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Barre de progression pleine largeur, remplissage doré dégradé (même
/// teinte d'accent que le reste de l'app, `theme.colorScheme.primary`) —
/// primitive visuelle partagée par [GoalProgressBar]
/// (`features/projects/widgets/goal_progress_bar.dart`, montant actuel vs
/// cible) et la barre de jalon fiscal des comptes PEA/PEG/AV
/// (`features/investments/widgets/fiscal_milestone_bar.dart`, temps écoulé
/// vs durée du jalon) : même rendu partout plutôt que deux implémentations
/// qui pourraient diverger visuellement.
///
/// [fraction] est déjà bornée par l'appelant (0.0 à 1.0) — cette classe ne
/// fait que le dessin, aucune logique métier.
class GoldProgressBar extends StatelessWidget {
  final double fraction;
  final double height;

  const GoldProgressBar({super.key, required this.fraction, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        // `theme.colorScheme.border`/`.muted` sont trop proches du blanc en
        // thème clair pour qu'on distingue où s'arrête la barre (à peine
        // 231 vs 255 de luminosité, vérifié pixel par pixel) — teinté du
        // même doré que le remplissage plutôt qu'un gris neutre. Le doré
        // étant déjà clair, une opacité aussi faible que pour un gris
        // neutre redevenait invisible sur fond blanc (vérifié pixel par
        // pixel à nouveau) : opacité bien plus élevée ici pour compenser.
        border: Border.all(color: accent.withValues(alpha: 0.9)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Container(height: height, color: accent.withValues(alpha: 0.35)),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
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
    );
  }
}

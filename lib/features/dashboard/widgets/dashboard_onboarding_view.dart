import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/ui/frosted_card.dart';

/// Écran de démarrage affiché à la place du Dashboard tant qu'un profil
/// réel n'a strictement aucune donnée (aucun compte, aucun investissement,
/// aucun passif) — les cartes habituelles (Patrimoine, Allocation...)
/// n'auraient de toute façon rien à montrer. Le fond de page se met en
/// retrait (`theme.colorScheme.background` à 0.95 d'opacité, comme un
/// logiciel qui passe à l'arrière-plan) derrière un conseil centré, et une
/// flèche pointe vers le bouton "+ Compléter mon patrimoine" de la TopBar
/// au-dessus — lui-même mis en valeur pendant ce temps, voir
/// `AddMenuButton` (`navigation/top_bar_actions.dart`) et
/// [OnboardingHighlightController].
class DashboardOnboardingView extends StatelessWidget {
  const DashboardOnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: theme.colorScheme.background.withValues(alpha: 0.95),
          ),
        ),
        Positioned(
          top: 8,
          right: 24,
          child: _PointerToAddButton(color: theme.colorScheme.primary),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FrostedCard(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    shadcn.Text(
                      'Ton tableau de bord est vide',
                    ).large().semiBold(),
                    const SizedBox(height: 8),
                    shadcn.Text(
                      'Ajoute tes comptes, investissements et crédits pour '
                      'voir apparaître ton patrimoine, ton allocation et '
                      "leur évolution. Ça se passe avec le bouton "
                      '« Compléter mon patrimoine », en haut de l\'écran.',
                      textAlign: TextAlign.center,
                    ).muted().small(),
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

/// Flèche pointant vers le haut (le bouton "+" de la TopBar, juste
/// au-dessus du contenu de la page) avec un léger texte d'accroche —
/// positionnement approximatif plutôt qu'un suivi au pixel près du bouton
/// réel (qui vivrait dans un tout autre sous-arbre de widgets, la TopBar),
/// suffisant puisque le bouton est toujours immédiatement au-dessus de
/// cette zone.
class _PointerToAddButton extends StatelessWidget {
  final Color color;

  const _PointerToAddButton({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(LucideIcons.arrowUp, size: 28, color: color),
        const SizedBox(height: 4),
        shadcn.Text(
          'Clique ici pour commencer',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ).small(),
      ],
    );
  }
}

import 'package:shadcn_flutter/shadcn_flutter.dart' show StatelessWidget, LucideIcons, BuildContext, Widget;
import '../../core/premium/premium_mock_widgets.dart';

/// Aperçu illustratif de l'écran "Projets" (Opime Premium) : ni données
/// réelles ni calcul, juste une mise en page approximant la vraie page
/// (projets financiers avec échéance et avancement). Affiché figé/flouté
/// par `LockedFeatureScreen` — voir `core/premium/premium_lock.dart`.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PremiumMockScreen(
      cards: [
        PremiumMockCard(
          icon: LucideIcons.house,
          title: 'Résidence principale',
          caption: 'Objectif 2032 — 62 % de l\'apport visé atteint.',
        ),
        PremiumMockCard(
          icon: LucideIcons.sunset,
          title: 'Retraite',
          caption: 'Projection basée sur vos versements et votre allocation.',
        ),
        PremiumMockCard(
          icon: LucideIcons.graduationCap,
          title: 'Études des enfants',
          caption: 'Suivi d\'un montant cible avec échéance et rendement attendu.',
        ),
      ],
    );
  }
}

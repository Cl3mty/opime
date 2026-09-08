import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, StatelessWidget, BuildContext, Widget;
import '../../core/premium/premium_mock_widgets.dart';
import 'formation_data.dart';

/// Aperçu illustratif d'un parcours de Formation (Opime Premium) : ni vraie
/// leçon ni vocabulaire, juste une table des matières factice donnant une
/// idée de la structure d'un cursus. Affiché figé/flouté par
/// `LockedFeatureScreen` — voir `core/premium/premium_lock.dart`.
class FormationTrackScreen extends StatelessWidget {
  final FormationTrackInfo track;

  const FormationTrackScreen({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    return PremiumMockScreen(
      cards: [
        PremiumMockCard(
          icon: LucideIcons.bookOpen,
          title: 'Notions de base',
          caption: 'Les fondamentaux de ${track.title.toLowerCase()}, étape par étape.',
        ),
        const PremiumMockCard(
          icon: LucideIcons.libraryBig,
          title: 'Vocabulaire clé',
          caption: 'Les termes techniques expliqués simplement, en contexte.',
        ),
        const PremiumMockCard(
          icon: LucideIcons.flaskConical,
          title: 'Cas pratique',
          caption: 'Un exemple chiffré pour mettre la théorie en application.',
        ),
      ],
    );
  }
}

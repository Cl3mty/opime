import 'package:shadcn_flutter/shadcn_flutter.dart' show StatelessWidget, LucideIcons, BuildContext, Widget;
import '../../core/premium/premium_mock_widgets.dart';

/// Aperçu illustratif de l'écran "Entités" (Opime Premium) : ni vraie
/// création/édition ni organigramme interactif, juste une structure
/// factice donnant une idée de la fonctionnalité (holdings, sociétés
/// commerciales, SCI — "comptes professionnels"). Affiché figé/flouté par
/// `LockedFeatureScreen` — voir `core/premium/premium_lock.dart`.
class EntitiesScreen extends StatelessWidget {
  const EntitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PremiumMockScreen(
      cards: [
        PremiumMockCard(
          icon: LucideIcons.user,
          title: 'Moi-même',
          caption: 'Propriétaire à 100 % — patrimoine personnel.',
        ),
        PremiumMockCard(
          icon: LucideIcons.building2,
          title: 'Holding SAS',
          caption: 'Détenue à 80 % par vous, 20 % par un associé.',
        ),
        PremiumMockCard(
          icon: LucideIcons.building,
          title: 'SCI Immobilière',
          caption: 'Détenue à 100 % par Holding SAS.',
        ),
      ],
    );
  }
}

import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../ui/frosted_card.dart';

/// Bloc "illustration" réutilisé par les mockups des écrans réservés à
/// Opime Premium (voir `locked_feature_screen.dart`) : une carte avec une
/// icône, un titre et une légende factices, qui donne une idée de la
/// section réelle sans en reproduire la logique ni le contenu.
///
/// Ces mockups remplacent volontairement le vrai écran (voir la doc de
/// `premium_lock.dart`) : ni données réelles, ni calcul, juste une mise en
/// page illustrative — le voile flouté de [LockedFeatureScreen] s'occupe du
/// reste (assombrissement + appel à l'action).
class PremiumMockCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;

  const PremiumMockCard({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.mutedForeground;
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: mutedColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shadcn.Text(title).medium().semiBold(),
                  const SizedBox(height: 4),
                  shadcn.Text(caption).muted().small(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Écran mockup générique : une colonne défilante de [PremiumMockCard],
/// avec un padding cohérent avec les vrais écrans de l'app.
class PremiumMockScreen extends StatelessWidget {
  final List<PremiumMockCard> cards;

  const PremiumMockScreen({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final card in cards) ...[card, const SizedBox(height: 16)],
        ],
      ),
    );
  }
}

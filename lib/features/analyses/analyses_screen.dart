import 'package:shadcn_flutter/shadcn_flutter.dart' show StatelessWidget, LucideIcons, BuildContext, Widget;
import '../../core/premium/premium_mock_widgets.dart';

/// Aperçu illustratif de l'écran "Analyses" (Opime Premium) : ni données
/// réelles ni calcul, juste une mise en page approximant les sections de la
/// vraie page (répartition géographique, corrélation, performance vs
/// benchmark). Affiché figé/flouté par `LockedFeatureScreen` — voir
/// `core/premium/premium_lock.dart`.
class AnalysesScreen extends StatelessWidget {
  const AnalysesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PremiumMockScreen(
      cards: [
        PremiumMockCard(
          icon: LucideIcons.globe,
          title: 'Diversification géographique',
          caption: 'Répartition de votre patrimoine par zone géographique.',
        ),
        PremiumMockCard(
          icon: LucideIcons.grid3x3,
          title: 'Corrélation entre classes d\'actifs',
          caption: 'Matrice de corrélation entre vos différentes positions.',
        ),
        PremiumMockCard(
          icon: LucideIcons.trendingUp,
          title: 'Performance vs benchmark',
          caption: 'Comparaison de votre performance à un indice de référence.',
        ),
        PremiumMockCard(
          icon: LucideIcons.gauge,
          title: 'Volatilité, Sharpe, alpha',
          caption: 'Indicateurs de risque et de rendement ajusté au risque.',
        ),
      ],
    );
  }
}

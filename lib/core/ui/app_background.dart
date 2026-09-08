import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Fond derrière le contenu d'une page : un dégradé diagonal très discret
/// (pas de halos circulaires marqués) inspiré des pages Finary — la
/// variation entre coins est à peine perceptible, pas un effet "glow".
/// Les cartes ([FrostedCard]) restent des aplats uniformes par-dessus.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.background.computeLuminance() < 0.5;

    final tint = theme.colorScheme.primary;
    final topLeftAlpha = isDark ? 0.05 : 0.10;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tint.withValues(alpha: topLeftAlpha),
                    tint.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

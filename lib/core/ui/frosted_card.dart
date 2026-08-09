import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;

/// Carte "verre dépoli" : un aplat uniforme (pas de dégradé ni de tache de
/// couleur propres à la carte — ça, c'est le rôle de [AppBackground],
/// visible par transparence grâce au flou ci-dessous) avec un liseré du
/// haut légèrement éclairci en sombre, pour suggérer la lumière qui
/// accroche le bord.
class FrostedCard extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double overlayAlpha;

  /// Force la carte à remplir tout l'espace disponible (StackFit.expand)
  /// plutôt que de s'ajuster à son contenu. Nécessaire quand [child]
  /// démarre par un widget qui se contracte naturellement (ex :
  /// SingleChildScrollView) au lieu d'un LayoutBuilder — qui, lui, réclame
  /// toujours l'espace max et n'a pas besoin de ce paramètre. À laisser à
  /// false pour les cartes empilées dans une liste (ex : Réglages), qui
  /// doivent garder la hauteur de leur contenu.
  final bool expand;

  const FrostedCard({
    super.key,
    required this.child,
    this.blurSigma = 22,
    this.overlayAlpha = 0.46,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.background.computeLuminance() < 0.5;
    final radius = BorderRadius.circular(theme.radiusMd);

    final baseAlpha = isDark ? 0.62 : (overlayAlpha + 0.24).clamp(0.0, 1.0);
    // En sombre, colorScheme.card a exactement la même luminosité que le
    // fond (thème dark zinc) : un aplat "card" dessus se fond avec la
    // page. colorScheme.muted est un gris nettement plus clair et
    // désaturé, qui donne le vrai contraste "panneau dépoli" recherché.
    final fillColor = isDark ? theme.colorScheme.muted : theme.colorScheme.card;
    final borderColor = isDark
        ? theme.colorScheme.border.withValues(alpha: 0.60)
        : theme.colorScheme.border.withValues(alpha: 0.92);
    final topHighlight = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : borderColor;
    final shadowAlpha = isDark ? 0.35 : 0.10;

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: expand ? StackFit.expand : StackFit.loose,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: fillColor.withValues(alpha: baseAlpha),
                border: Border(
                  top: BorderSide(color: topHighlight),
                  left: BorderSide(color: borderColor),
                  right: BorderSide(color: borderColor),
                  bottom: BorderSide(color: borderColor),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: shadowAlpha),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

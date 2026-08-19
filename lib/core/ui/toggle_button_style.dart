import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Style d'un `SelectedButton` non sélectionné, pour tous les groupes de
/// bascule à choix multiples de l'app (Actifs/Passifs, Par compte/Par
/// investissement, vues Allocation/Distribution blocs/pyramide/anneau,
/// capital restant dû/répartition des mensualités...).
///
/// `ButtonStyle.ghost` n'a par construction ni fond ni bordure hors survol —
/// une option non sélectionnée s'y confond avec du texte flottant, pas un
/// bouton cliquable. `ButtonStyle.outline` a bien une bordure, mais sa
/// couleur par défaut (`colorScheme.border`) est presque invisible en thème
/// clair (231 vs 255 de luminosité, vérifié pixel par pixel — même constat
/// que pour la bordure de `GoldProgressBar`, voir `gold_progress_bar.dart`).
/// Cette fonction reprend `ButtonStyle.outline` avec une bordure teintée de
/// l'accent doré de l'app à une opacité assez élevée pour rester visible
/// dans les deux thèmes (même compensation que `GoldProgressBar`, l'or étant
/// intrinsèquement clair).
AbstractButtonStyle toggleUnselectedStyle(
  BuildContext context, {
  ButtonSize size = const ButtonSize(1),
}) {
  final accent = Theme.of(context).colorScheme.primary;
  return ButtonStyle.outline(size: size).withBorder(
    border: Border.all(color: accent.withValues(alpha: 0.9)),
    hoverBorder: Border.all(color: accent),
    focusBorder: Border.all(color: accent),
  );
}

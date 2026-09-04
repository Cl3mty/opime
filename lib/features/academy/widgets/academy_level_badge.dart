import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/academy/academy_level.dart';
import '../../../l10n/app_localizations.dart';
import '../academy_theme.dart';

class AcademyLevelBadge extends StatelessWidget {
  final AcademyLevel level;

  const AcademyLevelBadge({super.key, required this.level});

  /// Libellé localisé du niveau. [AcademyLevel.label] reste en français
  /// codé en dur (il vit dans un fichier sans `BuildContext`) : la
  /// traduction se fait ici, au seul point d'affichage.
  static String _labelFor(AppLocalizations l10n, AcademyLevel level) {
    return switch (level) {
      AcademyLevel.debutant => l10n.academy_level_debutant,
      AcademyLevel.intermediaire => l10n.academy_level_intermediaire,
      AcademyLevel.avance => l10n.academy_level_avance,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = level.color;
    final label = _labelFor(AppLocalizations.of(context), level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          shadcn.Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

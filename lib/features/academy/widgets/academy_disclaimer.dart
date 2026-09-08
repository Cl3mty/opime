import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../l10n/app_localizations.dart';

/// Rappel affiché en bas de chaque page de l'Académie : ce contenu est
/// pédagogique, pas un conseil en investissement personnalisé.
class AcademyDisclaimer extends StatelessWidget {
  const AcademyDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.info,
            size: 14,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: shadcn.Text(l10n.academy_disclaimer).muted().xSmall(),
          ),
        ],
      ),
    );
  }
}

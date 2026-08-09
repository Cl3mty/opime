import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

/// Rappel affiché en bas de chaque page de l'Académie : ce contenu est
/// pédagogique, pas un conseil en investissement personnalisé.
class AcademyDisclaimer extends StatelessWidget {
  const AcademyDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            child: shadcn.Text(
              "Contenu à vocation éducative et de vulgarisation uniquement, pas un "
              "conseil en investissement : nous ne sommes pas conseillers en gestion "
              "de patrimoine (CGP). Chacun prend ses décisions financières en son "
              "âme et conscience — l'objectif est simplement de donner au plus grand "
              "nombre les clés pour décider en connaissance de cause.",
            ).muted().xSmall(),
          ),
        ],
      ),
    );
  }
}

import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/academy/academy_models.dart';

/// Encadré "Vocabulaire" expliquant les termes techniques utilisés dans une
/// leçon, affiché directement au fil du contenu plutôt que dans un glossaire
/// séparé.
class AcademyVocabularyBox extends StatelessWidget {
  final List<GlossaryTerm> terms;

  const AcademyVocabularyBox({super.key, required this.terms});

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.bookOpenCheck,
                size: 15,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 6),
              shadcn.Text('Vocabulaire').semiBold().small(),
            ],
          ),
          const SizedBox(height: 10),
          for (final term in terms)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              // Deux Text séparés plutôt qu'un seul Text.rich/TextSpan :
              // ce dernier, répété plusieurs fois dans un Stepper, bloquait
              // le rendu indéfiniment (SelectableText de shadcn_flutter
              // dans ce contexte précis colonne+scroll imbriqués).
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shadcn.Text('${term.term} — ').small().semiBold(),
                  Expanded(child: shadcn.Text(term.definition).small()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

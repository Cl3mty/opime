import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/platform_info.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import 'top_bar_actions.dart';

/// Barre persistante au-dessus du contenu de la page en mise en page
/// "large" (sidebar, desktop ou tablette) : recherche/assistant, bascule
/// de confidentialité des montants, et ajout rapide.
///
/// L'Assistant reste réservé au poste de travail : le champ de recherche
/// n'apparaît que sur [isDesktopPlatform], même sur tablette où cette
/// barre est par ailleurs affichée.
///
/// En mode mobile (bottom nav), ces actions sont directement intégrées à
/// l'AppBar par [AppShell] : pas de barre séparée, pour économiser la
/// place verticale.
class TopBar extends StatelessWidget {
  final AmountVisibilityController amountVisibility;
  final ValueChanged<String> onSelect;

  const TopBar({
    super.key,
    required this.amountVisibility,
    required this.onSelect,
  });

  void _openAssistant(String query) {
    // Le champ ne fait que rediriger vers la page Assistant pour l'instant :
    // il n'y a pas encore d'intégration LLM branchée dessus.
    onSelect('assistant');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        children: [
          if (isDesktopPlatform)
            Expanded(
              child: TextField(
                placeholder: const shadcn.Text("Demander à l'assistant..."),
                border: Border.all(color: Colors.transparent),
                features: [
                  InputFeature.leading(
                    Icon(
                      LucideIcons.sparkles,
                      size: 16,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
                onSubmitted: _openAssistant,
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 8),
          AmountVisibilityToggleButton(amountVisibility: amountVisibility),
          const SizedBox(width: 4),
          const AddMenuButton(),
        ],
      ),
    );
  }
}

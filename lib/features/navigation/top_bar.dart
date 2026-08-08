import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/privacy/amount_visibility_controller.dart';

/// Barre persistante en haut de l'app (au-dessus du contenu de la page,
/// quelle que soit celle-ci) : recherche/assistant, bascule de
/// confidentialité des montants, et ajout rapide.
class TopBar extends StatelessWidget {
  final AmountVisibilityController amountVisibility;
  final ValueChanged<String> onSelect;
  final bool compact;

  const TopBar({
    super.key,
    required this.amountVisibility,
    required this.onSelect,
    this.compact = false,
  });

  void _openAssistant(String query) {
    // Le champ ne fait que rediriger vers la page Assistant pour l'instant :
    // il n'y a pas encore d'intégration LLM branchée dessus.
    onSelect('assistant');
  }

  void _openAddMenu(BuildContext anchorContext) {
    MenuButton comingSoonItem({required IconData icon, required String label}) {
      return MenuButton(
        enabled: false,
        leading: Icon(icon, size: 16),
        trailing: shadcn.Text('Bientôt').muted().xSmall(),
        child: shadcn.Text(label),
        onPressed: (ctx) {},
      );
    }

    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.bottomEnd,
      alignment: AlignmentDirectional.topEnd,
      offset: const Offset(0, 8),
      builder: (context) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 240, maxWidth: 280),
          child: DropdownMenu(children: [
            const MenuLabel(child: shadcn.Text('Ajouter')),
            comingSoonItem(icon: LucideIcons.arrowRightLeft, label: 'Transaction'),
            comingSoonItem(icon: LucideIcons.landmark, label: 'Compte'),
            comingSoonItem(icon: LucideIcons.fileText, label: 'Document'),
            comingSoonItem(icon: LucideIcons.target, label: 'Objectif'),
            const MenuDivider(),
            MenuLabel(
              child: shadcn.Text('Disponible une fois le module Patrimoine terminé.').muted().xSmall(),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              placeholder: const shadcn.Text("Demander à l'assistant..."),
              border: Border.all(color: Colors.transparent),
              features: [
                InputFeature.leading(Icon(LucideIcons.sparkles, size: 16, color: theme.colorScheme.mutedForeground)),
              ],
              onSubmitted: _openAssistant,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: amountVisibility,
            builder: (context, _) {
              final hidden = amountVisibility.hidden;
              return _TopBarIconButton(
                icon: hidden ? LucideIcons.eyeOff : LucideIcons.eye,
                tooltip: hidden ? 'Afficher les montants' : 'Masquer les montants',
                onPressed: amountVisibility.toggle,
              );
            },
          ),
          const SizedBox(width: 4),
          Builder(
            builder: (btnContext) => _TopBarIconButton(
              icon: LucideIcons.plus,
              tooltip: 'Ajouter',
              onPressed: () => _openAddMenu(btnContext),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _TopBarIconButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // ignore: implicit_call_tearoffs
      tooltip: TooltipContainer(child: shadcn.Text(tooltip)),
      child: IconButton.ghost(
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

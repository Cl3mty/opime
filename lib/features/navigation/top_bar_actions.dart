import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/privacy/amount_visibility_controller.dart';

/// Bouton icône avec tooltip, utilisé par les actions rapides de la barre
/// du haut (recherche/eye/plus), qu'elle soit rendue par [TopBar] (desktop)
/// ou directement dans l'AppBar mobile de [AppShell].
class TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const TopBarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // ignore: implicit_call_tearoffs
      tooltip: TooltipContainer(child: shadcn.Text(tooltip)),
      child: IconButton.ghost(icon: Icon(icon), onPressed: onPressed),
    );
  }
}

/// Bascule montrer/masquer les montants de l'app.
class AmountVisibilityToggleButton extends StatelessWidget {
  final AmountVisibilityController amountVisibility;

  const AmountVisibilityToggleButton({
    super.key,
    required this.amountVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: amountVisibility,
      builder: (context, _) {
        final hidden = amountVisibility.hidden;
        return TopBarIconButton(
          icon: hidden ? LucideIcons.eyeOff : LucideIcons.eye,
          tooltip: hidden ? 'Afficher les montants' : 'Masquer les montants',
          onPressed: amountVisibility.toggle,
        );
      },
    );
  }
}

/// Bouton "+" ouvrant le menu d'ajout rapide (transaction/compte/document/
/// objectif — toujours désactivés en attendant le module Patrimoine).
class AddMenuButton extends StatelessWidget {
  const AddMenuButton({super.key});

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
          child: DropdownMenu(
            children: [
              const MenuLabel(child: shadcn.Text('Ajouter')),
              comingSoonItem(
                icon: LucideIcons.arrowRightLeft,
                label: 'Transaction',
              ),
              comingSoonItem(icon: LucideIcons.landmark, label: 'Compte'),
              comingSoonItem(icon: LucideIcons.fileText, label: 'Document'),
              comingSoonItem(icon: LucideIcons.target, label: 'Objectif'),
              const MenuDivider(),
              MenuLabel(
                child: shadcn.Text(
                  'Disponible une fois le module Patrimoine terminé.',
                ).muted().xSmall(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnContext) => TopBarIconButton(
        icon: LucideIcons.plus,
        tooltip: 'Ajouter',
        onPressed: () => _openAddMenu(btnContext),
      ),
    );
  }
}

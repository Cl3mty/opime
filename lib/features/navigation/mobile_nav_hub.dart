import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/premium/premium_lock.dart';
import '../../l10n/app_localizations.dart';
import 'nav_models.dart';

/// Liste tactile d'items de navigation, utilisée comme "hub" par la barre
/// de navigation mobile (onglets Portfolio/Tools/Learn) pour atteindre les
/// pages de niveau inférieur qu'un [AppSidebar] exposerait via ses groupes
/// dépliables sur desktop. N'assume aucune logique de routage : le parent
/// décide quoi faire d'une feuille ([onTapLeaf]) ou d'un item à enfants
/// ([onTapParent]).
class MobileNavHub extends StatelessWidget {
  final List<NavItem> items;
  final ValueChanged<NavItem> onTapLeaf;
  final ValueChanged<NavItem> onTapParent;

  const MobileNavHub({
    super.key,
    required this.items,
    required this.onTapLeaf,
    required this.onTapParent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (context, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = items[index];
        final l10n = AppLocalizations.of(context);
        final hasChildren = item.children.isNotEmpty;
        // Réservé à Opime Premium dans cette édition gratuite (voir
        // `core/premium/premium_lock.dart`) : reste cliquable — un tap
        // affiche un aperçu figé de la vraie page — mais grisé + cadenas.
        final locked = isPremiumLocked(item.key);
        final mutedColor = Theme.of(context).colorScheme.mutedForeground;
        return Clickable(
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
          onPressed: () => hasChildren ? onTapParent(item) : onTapLeaf(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.card,
              borderRadius: BorderRadius.circular(Theme.of(context).radiusMd),
              border: Border.all(color: Theme.of(context).colorScheme.border),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: locked ? mutedColor : null),
                const SizedBox(width: 12),
                Expanded(
                  child: shadcn
                      .Text(
                        navLocalizedLabel(l10n, item.key, fallback: item.label),
                        style: locked ? TextStyle(color: mutedColor) : null,
                      )
                      .medium(),
                ),
                if (locked) ...[
                  Icon(LucideIcons.lock, size: 14, color: mutedColor),
                  const SizedBox(width: 8),
                ],
                Icon(
                  hasChildren
                      ? LucideIcons.chevronRight
                      : LucideIcons.arrowRight,
                  size: 16,
                  color: mutedColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

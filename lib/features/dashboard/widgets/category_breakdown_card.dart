import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/frosted_card.dart';
import '../../navigation/navigation_scope.dart';
import '../patrimoine_models.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

const _pruWidth = 76.0;
const _montantWidth = 96.0;
const _evolutionWidth = 110.0;

/// Carte "Actifs" ou "Passifs" du Dashboard : une ligne par catégorie
/// (montant + évolution agrégés), dépliable pour révéler les comptes qui
/// la composent (avec leur PRU — Prix de Revient Unitaire). Le détail par
/// investissement au sein d'un compte est un niveau d'accordéon
/// supplémentaire réservé à la page de détail de chaque classe d'actif
/// (voir `_AccountsCard` dans `dashboard/category_detail_screen.dart`), pas
/// dupliqué ici. Cliquer sur une catégorie (hors chevron) ouvre sa page de
/// détail via [NavigationScope].
class CategoryBreakdownCard extends StatefulWidget {
  final String title;
  final List<PatrimoineCategory> categories;
  final bool hidden;

  /// `false` masque la colonne PRU — un passif (prêt) n'a pas de Prix de
  /// Revient Unitaire, contrairement à un actif.
  final bool showPru;

  const CategoryBreakdownCard({
    super.key,
    required this.title,
    required this.categories,
    required this.hidden,
    this.showPru = true,
  });

  @override
  State<CategoryBreakdownCard> createState() => _CategoryBreakdownCardState();
}

class _CategoryBreakdownCardState extends State<CategoryBreakdownCard> {
  final Set<String> _expandedIds = {};

  void _toggleExpanded(String id) {
    setState(() {
      if (!_expandedIds.remove(id)) _expandedIds.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Une catégorie sans le moindre compte n'apporte rien à la liste (pas
    // de montant à comparer aux autres) : elle reste toutefois accessible
    // depuis la sidebar/`AllocationCard`, juste pas listée ici.
    final populated = [
      for (final category in widget.categories)
        if (category.accounts.isNotEmpty) category,
    ];
    if (populated.isEmpty) return const SizedBox.shrink();

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shadcn.Text(widget.title).semiBold().large(),
            const SizedBox(height: 16),
            _HeaderRow(showPru: widget.showPru),
            const SizedBox(height: 4),
            for (final category in populated)
              _CategoryTile(
                category: category,
                expanded: _expandedIds.contains(category.id),
                hidden: widget.hidden,
                showPru: widget.showPru,
                onToggleExpand: () => _toggleExpanded(category.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool showPru;

  const _HeaderRow({required this.showPru});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Un clone invisible (mais occupant l'espace) du chevron
        // d'expansion de `_CategoryTile` — sans lui, les colonnes PRU/
        // Montant/Évolution de l'en-tête se retrouvent décalées vers la
        // gauche par rapport aux vraies valeurs, qui laissent ce chevron
        // en tête de ligne.
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: IconButton.ghost(
            icon: const Icon(LucideIcons.chevronRight, size: 16),
            onPressed: () {},
          ),
        ),
        const Expanded(child: SizedBox()),
        if (showPru)
          SizedBox(
            width: _pruWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: shadcn.Text('PRU').muted().xSmall(),
            ),
          ),
        SizedBox(
          width: _montantWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: shadcn.Text('Montant').muted().xSmall(),
          ),
        ),
        SizedBox(
          width: _evolutionWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: shadcn.Text('Évolution').muted().xSmall(),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final PatrimoineCategory category;
  final bool expanded;
  final bool hidden;
  final bool showPru;
  final VoidCallback onToggleExpand;

  const _CategoryTile({
    required this.category,
    required this.expanded,
    required this.hidden,
    required this.showPru,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = category.plusValueAbs >= 0;
    final color = positive ? _green : _red;

    return Column(
      children: [
        Container(height: 1, color: theme.colorScheme.border),
        Row(
          children: [
            IconButton.ghost(
              icon: AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(LucideIcons.chevronRight, size: 16),
              ),
              onPressed: onToggleExpand,
            ),
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () =>
                      NavigationScope.maybeOf(context)?.call(category.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(category.icon, size: 18, color: category.color),
                        const SizedBox(width: 8),
                        // Flexible + maxLines/overflow : sans ça, un libellé
                        // long (ex. "Assurance-vie multisupport") déborde
                        // sur les colonnes Montant/Évolution au lieu de
                        // s'arrêter à la largeur réservée par l'Expanded
                        // parent (visible surtout en dessous de 800px).
                        Flexible(
                          child: shadcn.Text(
                            category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ).medium(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showPru) const SizedBox(width: _pruWidth),
            SizedBox(
              width: _montantWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: shadcn.Text(
                  displayEuros(category.montant, hidden),
                ).small(),
              ),
            ),
            SizedBox(
              width: _evolutionWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  shadcn.Text(
                    displayEuros(category.plusValueAbs, hidden),
                    style: TextStyle(color: color),
                  ).xSmall(),
                  shadcn.Text(
                    displayPercent(category.plusValuePercent),
                    style: TextStyle(color: color),
                  ).muted().xSmall(),
                ],
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 6),
                  child: Column(
                    children: [
                      for (final account in category.accounts)
                        _AccountRow(
                          account: account,
                          hidden: hidden,
                          showPru: showPru,
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  final PatrimoineAccount account;
  final bool hidden;
  final bool showPru;

  const _AccountRow({
    required this.account,
    required this.hidden,
    required this.showPru,
  });

  @override
  Widget build(BuildContext context) {
    final positive = account.plusValueAbs >= 0;
    final color = positive ? _green : _red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                shadcn.Text(account.name).small(),
                if (account.subtitle != null)
                  shadcn.Text(account.subtitle!).muted().xSmall(),
              ],
            ),
          ),
          if (showPru)
            SizedBox(
              width: _pruWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: shadcn.Text(
                  account.pru != null
                      ? displayEuros(account.pru!, hidden)
                      : '—',
                ).muted().xSmall(),
              ),
            ),
          SizedBox(
            width: _montantWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: shadcn.Text(displayEuros(account.valeur, hidden)).small(),
            ),
          ),
          SizedBox(
            width: _evolutionWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                shadcn.Text(
                  displayEuros(account.plusValueAbs, hidden),
                  style: TextStyle(color: color),
                ).xSmall(),
                shadcn.Text(
                  displayPercent(account.plusValuePercent),
                  style: TextStyle(color: color),
                ).muted().xSmall(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

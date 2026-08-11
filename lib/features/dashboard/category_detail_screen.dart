import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import '../navigation/navigation_scope.dart';
import 'dashboard_dummy_data.dart';
import 'widgets/allocation_blocks_view.dart';
import 'widgets/allocation_donut_view.dart';
import 'widgets/net_worth_chart.dart';
import 'widgets/patrimoine_chart_widgets.dart'
    show ChartLayer, CategoryMultiSelect;

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Page de détail générique d'une catégorie d'actif ou de passif : montant
/// + graphique sur la période sélectionnée, répartition par compte
/// ("Distribution", réutilise [AllocationBlocksView]) et tableau des
/// comptes de la catégorie — inspirée de la capture Finary "Crypto"
/// fournie. Réutilisée pour les 9 catégories `actifs_*`/`passifs_*` de
/// `nav_models.dart`.
class CategoryDetailScreen extends StatefulWidget {
  final PatrimoineCategory category;
  final AmountVisibilityController amountVisibility;

  /// Appelé quand une ligne du tableau des comptes est cliquée (hors
  /// données de démo, où il reste `null` — les lignes ne sont alors pas
  /// cliquables) : permet à l'appelant (voir `RealCategoryDetailScreen`)
  /// d'ouvrir la vue de détail du compte/investissement réel correspondant.
  final ValueChanged<PatrimoineAccount>? onAccountTap;

  /// Contenu ajouté en bas de page, après le tableau des comptes — utilisé
  /// par `RealPassifDetailScreen` pour y insérer le bouton/formulaire
  /// d'ajout d'un nouveau passif sans dupliquer le reste de cette page.
  /// `null` (par défaut) n'ajoute rien.
  final Widget? trailingSection;

  /// Regroupement par compte (une ligne par compte, montants sommés) de la
  /// même catégorie que [category] — `null` (données de démo, Passifs)
  /// masque le switch "Par compte / Par actif" de la Distribution et
  /// n'affiche que [category.accounts] tel quel. Quand renseigné,
  /// [category.accounts] est utilisé comme vue "Par actif" (une ligne par
  /// investissement, ex : Google/Meta/Nvidia) et ce paramètre comme vue
  /// "Par compte" (ex : CTO/AV/PER/PEA) — voir `real_patrimoine_adapter.dart`.
  final List<PatrimoineAccount>? distributionByAccount;

  /// Historique individuel de chaque ligne de [category.accounts] (clé :
  /// [PatrimoineAccount.id]), toutes sur une même grille de dates — `null`
  /// (comportement par défaut) affiche simplement [category.history] sans
  /// sélecteur. Quand renseigné (passifs réels, voir
  /// `real_passifs_adapter.dart`'s `perLiabilityHistoryOnGrid`), un
  /// [CategoryMultiSelect] permet de choisir un/plusieurs/tous les prêts
  /// dont la somme forme la courbe affichée.
  final Map<String, List<NetWorthPoint>>? historyByLineId;

  /// `false` masque l'avatar (initiales) devant chaque ligne du tableau des
  /// comptes — un prêt n'a pas d'initiales pertinentes, contrairement à un
  /// compte/investissement.
  final bool showAvatar;

  /// Titre du tableau des comptes de la catégorie — "Actifs" par défaut,
  /// "Passifs" pour les catégories de crédits/emprunts (voir
  /// `RealPassifDetailScreen`).
  final String accountsCardTitle;

  /// Menu "⋮" (Modifier/Supprimer) affiché au bout de chaque ligne de
  /// *compte* de l'accordéon (voir `_AccountAccordionTile`, uniquement
  /// quand [distributionByAccount] est renseigné) — `null` masque le menu
  /// entièrement (données de démo, où il n'y a pas de compte réel à
  /// éditer). "Supprimer" reste désactivé si [PatrimoineAccount.canDelete]
  /// vaut `false`.
  final ValueChanged<PatrimoineAccount>? onAccountEdit;
  final Future<void> Function(PatrimoineAccount)? onAccountDelete;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.amountVisibility,
    this.onAccountTap,
    this.trailingSection,
    this.distributionByAccount,
    this.historyByLineId,
    this.showAvatar = true,
    this.accountsCardTitle = 'Actifs',
    this.onAccountEdit,
    this.onAccountDelete,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  int _periodIndex = 5;
  late Set<String> _selectedLineIds = {
    for (final a in widget.category.accounts)
      if (a.id != null) a.id!,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.amountVisibility,
      builder: (context, _) {
        final hidden = widget.amountVisibility.hidden;
        final category = widget.category;
        final days = dashboardPeriods[_periodIndex].$2;
        final historyByLineId = widget.historyByLineId;
        final history = historyByLineId == null
            ? category.history
            : _combinedHistory(historyByLineId, _selectedLineIds);
        final points = dashboardSampleData.sliceForDays(history, days);
        final changePercent = dashboardSampleData.changePercentFor(points);
        final positive = changePercent >= 0;
        final color = positive ? _green : _red;

        final performanceCard = FrostedCard(
          expand: true,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (historyByLineId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: CategoryMultiSelect(
                        options: [
                          for (final a in category.accounts)
                            if (a.id != null)
                              ChartLayer(
                                id: a.id!,
                                label: a.name,
                                color: category.color,
                              ),
                        ],
                        selectedIds: _selectedLineIds,
                        onChanged: (ids) =>
                            setState(() => _selectedLineIds = ids),
                      ),
                    ),
                  ),
                shadcn.Text(
                  displayEuros(points.isEmpty ? 0 : points.last.value, hidden),
                ).x2Large().bold(),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      positive
                          ? LucideIcons.trendingUp
                          : LucideIcons.trendingDown,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    shadcn.Text(
                      displayPercent(changePercent),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ).small(),
                  ],
                ),
                const SizedBox(height: 12),
                PeriodTabs(
                  labels: [for (final p in dashboardPeriods) p.$1],
                  index: _periodIndex,
                  onChanged: (i) => setState(() => _periodIndex = i),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: NetWorthChart(
                    points: points,
                    formatValue: (v) => displayEuros(v, hidden),
                    axisLabelFormat: (v) => displayEurosCompact(v, hidden),
                    lineColor: category.color,
                    gridColor: Theme.of(context).colorScheme.border,
                    textColor: Theme.of(context).colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        );
        final distributionCard = _DistributionCard(
          category: category,
          byAccount: widget.distributionByAccount,
          hidden: hidden,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackHeader(category: category),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 800;
                  if (narrow) {
                    return Column(
                      children: [
                        SizedBox(height: 420, child: performanceCard),
                        const SizedBox(height: 16),
                        SizedBox(height: 320, child: distributionCard),
                      ],
                    );
                  }
                  return SizedBox(
                    height: 420,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: performanceCard),
                        const SizedBox(width: 16),
                        Expanded(child: distributionCard),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _AccountsCard(
                category: category,
                byAccount: widget.distributionByAccount,
                hidden: hidden,
                onAccountTap: widget.onAccountTap,
                showAvatar: widget.showAvatar,
                title: widget.accountsCardTitle,
                onAccountEdit: widget.onAccountEdit,
                onAccountDelete: widget.onAccountDelete,
              ),
              if (widget.trailingSection != null) ...[
                const SizedBox(height: 24),
                widget.trailingSection!,
              ],
            ],
          ),
        );
      },
    );
  }

  /// Somme, terme à terme (même grille de dates, voir
  /// `real_passifs_adapter.dart`'s `perLiabilityHistoryOnGrid`), les
  /// courbes des lignes actuellement sélectionnées dans le
  /// [CategoryMultiSelect] — la ligne vide (aucune sélection) retombe sur
  /// une courbe vide plutôt que de planter sur une division par zéro
  /// ailleurs dans l'écran.
  List<NetWorthPoint> _combinedHistory(
    Map<String, List<NetWorthPoint>> historyByLineId,
    Set<String> selectedIds,
  ) {
    final selected = [
      for (final id in selectedIds)
        if (historyByLineId[id] != null) historyByLineId[id]!,
    ];
    if (selected.isEmpty) return [];
    final pointCount = selected.first.length;
    return [
      for (var i = 0; i < pointCount; i++)
        NetWorthPoint(
          selected.first[i].date,
          selected.fold(0.0, (sum, series) => sum + series[i].value),
        ),
    ];
  }
}

class _BackHeader extends StatelessWidget {
  final PatrimoineCategory category;

  const _BackHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => NavigationScope.maybeOf(context)?.call('dashboard'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.chevronLeft, size: 20),
            const SizedBox(width: 4),
            shadcn.Text(category.label).x2Large().semiBold(),
          ],
        ),
      ),
    );
  }
}

enum _DistributionMode { parCompte, parActif }

enum _DistributionView { blocs, donut }

// Même correctif que le toggle Actifs/Passifs du Dashboard
// (`allocation_card.dart`) : la densité "compact" de shadcn_flutter rendait
// ces boutons illisibles/trop petits, mais la taille normale débordait sur
// les très grands écrans — on réduit donc de 5% seulement.
const _toggleButtonSize = ButtonSize(0.95);
const _toggleFontSize = 14.0 * 0.95;
const _toggleIconSize = 16.0 * 0.95;

/// Carte "Distribution" : répartition de la catégorie en blocs
/// ([AllocationBlocksView]) ou en anneau ([AllocationDonutView], mêmes 2
/// vues que la carte Allocation du Dashboard), soit par compte
/// (CTO/AV/PER/PEA...) soit par actif individuel (Google/Meta/Nvidia...)
/// quand [byAccount] est fourni — sans lui (données de démo, Passifs),
/// toujours [category.accounts] sans switch de mode visible.
class _DistributionCard extends StatefulWidget {
  final PatrimoineCategory category;
  final List<PatrimoineAccount>? byAccount;
  final bool hidden;

  const _DistributionCard({
    required this.category,
    this.byAccount,
    required this.hidden,
  });

  @override
  State<_DistributionCard> createState() => _DistributionCardState();
}

class _DistributionCardState extends State<_DistributionCard> {
  _DistributionMode _mode = _DistributionMode.parCompte;
  _DistributionView _view = _DistributionView.blocs;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final byAccount = widget.byAccount;
    final lines = byAccount == null
        ? category.accounts
        : (_mode == _DistributionMode.parCompte
              ? byAccount
              : category.accounts);
    final montant = lines.fold(0.0, (sum, a) => sum + a.valeur);
    final slices = [
      for (var i = 0; i < lines.length; i++)
        AllocationSlice(
          id: lines[i].id ?? lines[i].name,
          label: lines[i].name,
          color:
              Color.lerp(category.color, Colors.white, 0.16 * i) ??
              category.color,
          percent: montant == 0 ? 0 : lines[i].valeur / montant * 100,
        ),
    ];

    return FrostedCard(
      expand: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 420;
                final title = shadcn.Text('Distribution').semiBold().large();
                final controls = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (byAccount != null)
                      ButtonGroup(
                        children: [
                          SelectedButton(
                            value: _mode == _DistributionMode.parCompte,
                            selectedStyle: const ButtonStyle.primary(
                              size: _toggleButtonSize,
                            ),
                            style: const ButtonStyle.outline(
                              size: _toggleButtonSize,
                            ),
                            onChanged: (_) => setState(
                              () => _mode = _DistributionMode.parCompte,
                            ),
                            child: shadcn.Text(
                              'Par compte',
                              style: const TextStyle(fontSize: _toggleFontSize),
                            ),
                          ),
                          SelectedButton(
                            value: _mode == _DistributionMode.parActif,
                            selectedStyle: const ButtonStyle.primary(
                              size: _toggleButtonSize,
                            ),
                            style: const ButtonStyle.outline(
                              size: _toggleButtonSize,
                            ),
                            onChanged: (_) => setState(
                              () => _mode = _DistributionMode.parActif,
                            ),
                            child: shadcn.Text(
                              'Par actif',
                              style: const TextStyle(fontSize: _toggleFontSize),
                            ),
                          ),
                        ],
                      ),
                    ButtonGroup(
                      children: [
                        SelectedButton(
                          value: _view == _DistributionView.blocs,
                          selectedStyle: const ButtonStyle.primary(
                            size: _toggleButtonSize,
                          ),
                          style: const ButtonStyle.ghost(
                            size: _toggleButtonSize,
                          ),
                          onChanged: (_) =>
                              setState(() => _view = _DistributionView.blocs),
                          child: const Icon(
                            LucideIcons.layoutGrid,
                            size: _toggleIconSize,
                          ),
                        ),
                        SelectedButton(
                          value: _view == _DistributionView.donut,
                          selectedStyle: const ButtonStyle.primary(
                            size: _toggleButtonSize,
                          ),
                          style: const ButtonStyle.ghost(
                            size: _toggleButtonSize,
                          ),
                          onChanged: (_) =>
                              setState(() => _view = _DistributionView.donut),
                          child: const Icon(
                            LucideIcons.chartPie,
                            size: _toggleIconSize,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), controls],
                  );
                }
                return Row(children: [title, const Spacer(), controls]);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _view == _DistributionView.blocs
                  ? AllocationBlocksView(slices: slices)
                  : AllocationDonutView(
                      slices: slices,
                      total: montant,
                      hidden: widget.hidden,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tableau "Actifs" de la page de détail d'une classe. Quand [byAccount]
/// est fourni (profils réels), c'est un accordéon à deux niveaux : une
/// ligne par compte (montants sommés), dépliable pour révéler les
/// investissements individuels qui le composent
/// ([PatrimoineAccount.investments], voir `real_patrimoine_adapter.dart`).
/// Sans lui (données de démo, Passifs), reste la liste plate de
/// [PatrimoineCategory.accounts] d'origine.
class _AccountsCard extends StatefulWidget {
  final PatrimoineCategory category;
  final List<PatrimoineAccount>? byAccount;
  final bool hidden;
  final ValueChanged<PatrimoineAccount>? onAccountTap;
  final bool showAvatar;
  final String title;
  final ValueChanged<PatrimoineAccount>? onAccountEdit;
  final Future<void> Function(PatrimoineAccount)? onAccountDelete;

  const _AccountsCard({
    required this.category,
    this.byAccount,
    required this.hidden,
    this.onAccountTap,
    required this.showAvatar,
    required this.title,
    this.onAccountEdit,
    this.onAccountDelete,
  });

  @override
  State<_AccountsCard> createState() => _AccountsCardState();
}

class _AccountsCardState extends State<_AccountsCard> {
  final Set<String> _expandedIds = {};

  void _toggleExpanded(String id) {
    setState(() {
      if (!_expandedIds.remove(id)) _expandedIds.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byAccount = widget.byAccount;
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shadcn.Text(widget.title).semiBold().large(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: SizedBox()),
                _HeaderCell('Quantité'),
                _HeaderCell('Cours'),
                _HeaderCell('Valeur'),
                _HeaderCell('Évolution'),
                const SizedBox(width: _actionsWidth),
              ],
            ),
            if (byAccount != null)
              for (final account in byAccount) ...[
                Container(height: 1, color: theme.colorScheme.border),
                _AccountAccordionTile(
                  account: account,
                  hidden: widget.hidden,
                  expanded: _expandedIds.contains(account.id ?? account.name),
                  onToggleExpand: () =>
                      _toggleExpanded(account.id ?? account.name),
                  onInvestmentTap: widget.onAccountTap,
                  onEdit: widget.onAccountEdit,
                  onDelete: widget.onAccountDelete,
                ),
              ]
            else
              for (final account in widget.category.accounts) ...[
                Container(height: 1, color: theme.colorScheme.border),
                _AccountLine(
                  account: account,
                  hidden: widget.hidden,
                  showAvatar: widget.showAvatar,
                  onTap: widget.onAccountTap == null
                      ? null
                      : () => widget.onAccountTap!(account),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// Ligne de compte dépliable de l'accordéon : clic sur la ligne (pas de
/// navigation à ce niveau) pour révéler ses investissements en dessous,
/// chacun cliquable via [onInvestmentTap] comme le reste des lignes de ce
/// tableau.
class _AccountAccordionTile extends StatelessWidget {
  final PatrimoineAccount account;
  final bool hidden;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<PatrimoineAccount>? onInvestmentTap;
  final ValueChanged<PatrimoineAccount>? onEdit;
  final Future<void> Function(PatrimoineAccount)? onDelete;

  const _AccountAccordionTile({
    required this.account,
    required this.hidden,
    required this.expanded,
    required this.onToggleExpand,
    this.onInvestmentTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChildren = account.investments.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: hasChildren ? SystemMouseCursors.click : MouseCursor.defer,
          child: GestureDetector(
            onTap: hasChildren ? onToggleExpand : null,
            child: _AccountLine(
              account: account,
              hidden: hidden,
              leading: hasChildren
                  ? SizedBox(
                      width: 28,
                      child: Center(
                        child: AnimatedRotation(
                          turns: expanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: 28),
              trailing: _AccountActionsMenu(
                account: account,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
          ),
        ),
        if (hasChildren)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 38),
                    child: Column(
                      children: [
                        for (final investment in account.investments)
                          _AccountLine(
                            account: investment,
                            hidden: hidden,
                            onTap: onInvestmentTap == null
                                ? null
                                : () => onInvestmentTap!(investment),
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

const _colWidth = 92.0;

/// Largeur réservée pour la zone d'actions en bout de ligne (chevron de
/// navigation ou menu "⋮"), sur [_AccountLine] comme sur la ligne d'en-tête
/// du tableau (voir `_AccountsCardState.build`) — sans cette réservation
/// constante côté en-tête, la largeur variable de cette zone (rien, un
/// chevron, ou le menu "⋮", plus large) désalignait les colonnes de
/// valeurs des lignes selon ce qu'elles affichaient à leur bout.
const _actionsWidth = 32.0;

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _colWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: shadcn.Text(label).muted().xSmall(),
      ),
    );
  }
}

class _AccountLine extends StatelessWidget {
  final PatrimoineAccount account;
  final bool hidden;
  final VoidCallback? onTap;

  /// Remplace l'avatar par défaut — utilisé par [_AccountAccordionTile]
  /// pour afficher le chevron d'expansion à la place sur une ligne de
  /// compte, plutôt que d'ajouter une variante de widget séparée.
  final Widget? leading;

  /// `false` n'affiche ni [leading] ni l'avatar par défaut, juste
  /// l'espacement — un prêt n'a pas d'initiales pertinentes à afficher.
  final bool showAvatar;

  /// Widget affiché tout au bout de la ligne, après le chevron d'expansion
  /// éventuel — utilisé par [_AccountAccordionTile] pour son menu "⋮"
  /// (Modifier/Supprimer le compte). `null` n'ajoute rien.
  final Widget? trailing;

  const _AccountLine({
    required this.account,
    required this.hidden,
    this.trailing,
    this.onTap,
    this.leading,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = account.plusValueAbs >= 0;
    final color = positive ? _green : _red;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (showAvatar)
            leading ?? Avatar(size: 28, initials: account.initials)
          else
            const SizedBox(width: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                shadcn.Text(account.name).medium().small(),
                if (account.subtitle != null)
                  shadcn.Text(account.subtitle!).muted().xSmall(),
              ],
            ),
          ),
          SizedBox(
            width: _colWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: shadcn.Text(
                account.quantite != null
                    ? account.quantite!.toStringAsFixed(2)
                    : '—',
              ).small(),
            ),
          ),
          SizedBox(
            width: _colWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: shadcn.Text(
                account.cours != null
                    ? displayEuros(account.cours!, hidden)
                    : '—',
              ).small(),
            ),
          ),
          SizedBox(
            width: _colWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: shadcn.Text(displayEuros(account.valeur, hidden)).small(),
            ),
          ),
          SizedBox(
            width: _colWidth,
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
          SizedBox(
            width: _actionsWidth,
            child: Center(
              child:
                  trailing ??
                  (onTap != null
                      ? Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: theme.colorScheme.mutedForeground,
                        )
                      : null),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: row),
    );
  }
}

/// Menu "⋮" (Modifier/Supprimer le compte) d'une ligne de compte de
/// l'accordéon — même paire d'actions que `AccountDetailView`'s propre
/// menu (`account_detail_screen.dart`), exposée ici sans dépendre du
/// module Investissements (voir [CategoryDetailScreen.onAccountEdit]/
/// [CategoryDetailScreen.onAccountDelete]). Ne s'affiche que si au moins
/// une des deux actions est fournie — les données de démo n'en fournissent
/// aucune, pas de compte réel à éditer.
class _AccountActionsMenu extends StatelessWidget {
  final PatrimoineAccount account;
  final ValueChanged<PatrimoineAccount>? onEdit;
  final Future<void> Function(PatrimoineAccount)? onDelete;

  const _AccountActionsMenu({
    required this.account,
    this.onEdit,
    this.onDelete,
  });

  void _openMenu(BuildContext context) {
    showDropdown(
      context: context,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: DropdownMenu(
          children: [
            if (onEdit != null)
              MenuButton(
                leading: const Icon(LucideIcons.pencil, size: 14),
                child: const shadcn.Text('Modifier le compte'),
                onPressed: (_) => onEdit!(account),
              ),
            if (onDelete != null)
              MenuButton(
                enabled: account.canDelete,
                leading: const Icon(LucideIcons.trash2, size: 14),
                trailing: account.canDelete
                    ? null
                    : const shadcn.Text('Vide-le d\'abord').muted().xSmall(),
                child: const shadcn.Text('Supprimer le compte'),
                onPressed: (_) => onDelete!(account),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onEdit == null && onDelete == null) return const SizedBox.shrink();
    return Builder(
      builder: (context) => IconButton.ghost(
        icon: const Icon(LucideIcons.ellipsisVertical, size: 16),
        onPressed: () => _openMenu(context),
      ),
    );
  }
}

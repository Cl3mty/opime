import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import '../investments/bank_logo_avatar.dart';
import '../investments/bank_logo_repository.dart';
import '../investments/investments_models.dart';
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
  /// comptes et des investissements de l'accordéon — un prêt n'a pas
  /// d'initiales pertinentes, et les métaux précieux préfèrent des lignes
  /// sobres (initiales sans signification, ex : "L1" pour "Lingot 1Kg Or").
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

  /// Chemin du vault — permet d'importer/remplacer les logos de banques
  /// (l'avatar d'une banque est cliquable, voir `BankLogoAvatar`). `null`
  /// (données de démo, où il n'y a pas de vault) rend l'avatar non cliquable.
  final String? vaultPath;

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
    this.vaultPath,
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

  /// Repository des logos de banques — `null` sans vault (données de démo),
  /// où aucun logo ne peut être importé.
  BankLogoRepository? get _logoRepo {
    final vaultPath = widget.vaultPath;
    return vaultPath == null ? null : BankLogoRepository(vaultPath);
  }

  /// Logos déjà importés, par nom de banque → chemin absolu de l'image
  /// (vide tant que rien n'est importé, ou en cours de lecture).
  Map<String, String> _bankLogos = {};

  @override
  void initState() {
    super.initState();
    _loadBankLogos();
  }

  @override
  void didUpdateWidget(covariant CategoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Un rechargement des données (autre vault, compte ajouté/renommé...)
    // peut faire apparaître de nouvelles banques : on relit les logos.
    if (oldWidget.distributionByAccount != widget.distributionByAccount) {
      _loadBankLogos();
    }
  }

  Future<void> _loadBankLogos() async {
    final repo = _logoRepo;
    if (repo == null) return;
    final byAccount = widget.distributionByAccount ?? const [];
    final banks = {for (final a in byAccount) a.bankName ?? a.name};
    final logos = <String, String>{};
    for (final bank in banks) {
      final path = await repo.logoPathFor(bank);
      if (path != null) logos[bank] = path;
    }
    if (!mounted) return;
    setState(() => _bankLogos = logos);
  }

  /// L'avatar d'une banque est cliquable : l'utilisateur choisit une image
  /// sur son disque, copiée dans le vault (voir `BankLogoRepository`).
  Future<void> _importBankLogo(String bankName) async {
    final repo = _logoRepo;
    if (repo == null) return;
    final result = await FilePicker.pickFiles(withData: true);
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final path = await repo.importLogo(bankName, bytes, sourceName: file.name);
    if (path == null || !mounted) return;
    setState(() => _bankLogos = {..._bankLogos, bankName: path});
  }

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
                bankLogos: _bankLogos,
                onImportLogo: widget.vaultPath == null ? null : _importBankLogo,
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

  /// Regroupe les lignes de l'épargne par devise (le nom de chaque ligne
  /// est sa devise, ex : "EUR") et somme montants et plus-values des poches
  /// d'une même devise — les différentes poches EUR ne sont ainsi pas
  /// éclatées en plusieurs parts de l'allocation.
  List<PatrimoineAccount> _epargneLinesByCurrency(
    List<PatrimoineAccount> accounts,
  ) {
    final byCurrency = <String, List<PatrimoineAccount>>{};
    for (final account in accounts) {
      byCurrency.putIfAbsent(account.name, () => []).add(account);
    }
    return [
      for (final poches in byCurrency.values) _mergePoches(poches),
    ];
  }

  PatrimoineAccount _mergePoches(List<PatrimoineAccount> poches) {
    final valeur = poches.fold(0.0, (sum, a) => sum + a.valeur);
    final plusValueAbs = poches.fold(0.0, (sum, a) => sum + a.plusValueAbs);
    final costBasis = valeur - plusValueAbs;
    return PatrimoineAccount(
      id: poches.first.name,
      name: poches.first.name,
      valeur: valeur,
      plusValueAbs: plusValueAbs,
      plusValuePercent: costBasis == 0 ? 0 : plusValueAbs / costBasis * 100,
    );
  }

  /// Libellé d'une part de la distribution. Pour l'épargne, un type de
  /// compte ouvrable plusieurs fois (assurance vie, contrat de
  /// capitalisation, "autre" — voir `epargneEnvelopeIsUniquePerBank`) peut
  /// exister en plusieurs exemplaires, même dans une même banque : sa
  /// description facultative est alors ajoutée au libellé pour distinguer
  /// les comptes entre eux.
  String _distributionLabel(
    PatrimoineAccount line,
    PatrimoineCategory category,
  ) {
    if (category.id != AssetClass.epargne.categoryId) return line.name;
    final envelope = AccountEnvelope.values.firstWhere(
      (e) => e.label == line.name,
      orElse: () => AccountEnvelope.autre,
    );
    final description = line.subtitle;
    if (description == null ||
        description.isEmpty ||
        epargneEnvelopeIsUniquePerBank(envelope)) {
      return line.name;
    }
    return '${line.name} · $description';
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final byAccount = widget.byAccount;
    // Vue "Par actif" de l'épargne : une même devise (EUR, USD...) détenue
    // dans plusieurs comptes (Livret A, LDDS, assurance vie...) ne forme
    // pas plusieurs catégories d'allocation distinctes — seul le
    // regroupement par devise compte, les poches d'une même devise sont
    // donc fusionnées (voir `_epargneLinesByCurrency`).
    final lines = byAccount == null
        ? category.accounts
        : (_mode == _DistributionMode.parCompte
              ? byAccount
              : category.id == AssetClass.epargne.categoryId
                  ? _epargneLinesByCurrency(category.accounts)
                  : category.accounts);
    final montant = lines.fold(0.0, (sum, a) => sum + a.valeur);
    final slices = [
      for (var i = 0; i < lines.length; i++)
        AllocationSlice(
          id: lines[i].id ?? lines[i].name,
          label: _distributionLabel(lines[i], category),
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

  /// Logos importés par nom de banque → chemin absolu de l'image — voir
  /// `_CategoryDetailScreenState._bankLogos`.
  final Map<String, String> bankLogos;

  /// Importe/remplace le logo d'une banque (avatar cliquable de
  /// `_BankAccordionTile`), `null` quand aucun vault n'est disponible.
  final ValueChanged<String>? onImportLogo;

  const _AccountsCard({
    required this.category,
    this.byAccount,
    required this.hidden,
    this.onAccountTap,
    required this.showAvatar,
    required this.title,
    this.onAccountEdit,
    this.onAccountDelete,
    this.bankLogos = const {},
    this.onImportLogo,
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

  /// La vue "par compte" regroupe les comptes par banque (la clé est
  /// [PatrimoineAccount.bankName], le nom du compte tenant lieu de banque à
  /// défaut) : un accordéon "banque → comptes → investissements". Un compte
  /// sans banque distincte (son nom fait banque) garde son accordéon simple
  /// actuel pour éviter un niveau d'imbrication redondant.
  List<Widget> _buildAccountAccordions(
    List<PatrimoineAccount> byAccount,
    bool showPru,
  ) {
    final theme = Theme.of(context);
    final groups = <String, List<PatrimoineAccount>>{};
    for (final account in byAccount) {
      final key = account.bankName ?? account.name;
      groups.putIfAbsent(key, () => []).add(account);
    }
    final tiles = <Widget>[];
    for (final group in groups.entries) {
      tiles.add(Container(height: 1, color: theme.colorScheme.border));
      if (group.value.length == 1 && group.value.single.bankName == null) {
        final account = group.value.single;
        tiles.add(
          _AccountAccordionTile(
            account: account,
            hidden: widget.hidden,
            showAvatar: widget.showAvatar,
            showPru: showPru,
            expanded: _expandedIds.contains(account.id ?? account.name),
            onToggleExpand: () => _toggleExpanded(account.id ?? account.name),
            onInvestmentTap: widget.onAccountTap,
            onEdit: widget.onAccountEdit,
            onDelete: widget.onAccountDelete,
          ),
        );
        continue;
      }
      // Banque avec logo : un accordéon banque qui révèle ses comptes, eux-
      // mêmes des accordéons vers leurs investissements. L'identité visuelle
      // porte sur la ligne banque seule : les lignes de compte (et leurs
      // investissements) n'affichent pas d'avatar sous une banque.
      final children = <Widget>[];
      for (final account in group.value) {
        children.add(Container(height: 1, color: theme.colorScheme.border));
        children.add(
          _AccountAccordionTile(
            account: account,
            hidden: widget.hidden,
            showAvatar: false,
            showPru: showPru,
            expanded: _expandedIds.contains(account.id ?? account.name),
            onToggleExpand: () => _toggleExpanded(account.id ?? account.name),
            onInvestmentTap: widget.onAccountTap,
            onEdit: widget.onAccountEdit,
            onDelete: widget.onAccountDelete,
          ),
        );
      }
      tiles.add(
        _BankAccordionTile(
          bankName: group.key,
          accounts: group.value,
          logoPath: widget.bankLogos[group.key],
          onImportLogo: widget.onImportLogo,
          hidden: widget.hidden,
          showPru: showPru,
          expanded: _expandedIds.contains('bank:$group.key'),
          onToggleExpand: () => _toggleExpanded('bank:$group.key'),
          children: children,
        ),
      );
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byAccount = widget.byAccount;
    final showPru = widget.category.showsPruColumn;
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
                if (showPru) _HeaderCell('PRU'),
                _HeaderCell('Cours'),
                _HeaderCell('Valeur'),
                _HeaderCell('Évolution'),
                const SizedBox(width: _actionsWidth),
              ],
            ),
            if (byAccount != null) ...[
              ..._buildAccountAccordions(byAccount, showPru),
            ] else
              for (final account in widget.category.accounts) ...[
                Container(height: 1, color: theme.colorScheme.border),
                _AccountLine(
                  account: account,
                  hidden: widget.hidden,
                  showAvatar: widget.showAvatar,
                  showPru: showPru,
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

  /// `false` masque aussi l'avatar (initiales) des lignes d'investissement
  /// du second niveau de l'accordéon — voir [CategoryDetailScreen.showAvatar].
  final bool showAvatar;

  /// Affiche la colonne PRU (Prix de Revient Unitaire) du tableau, cf.
  /// [PatrimoineCategory.showsPruColumn] — propagée aux deux niveaux de
  /// l'accordéon.
  final bool showPru;

  const _AccountAccordionTile({
    required this.account,
    required this.hidden,
    required this.expanded,
    required this.onToggleExpand,
    this.onInvestmentTap,
    this.onEdit,
    this.onDelete,
    this.showAvatar = true,
    this.showPru = false,
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
              showPru: showPru,
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
                            showAvatar: showAvatar,
                            showPru: showPru,
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

/// Accordéon d'une banque : l'avatar (logo importé ou initiales, cliquable
/// pour importer/remplacer l'image) + le nom de la banque et la somme de ses
/// comptes, dépliable pour révéler ces comptes — eux-mêmes des accordéons
/// vers leurs investissements (voir [_AccountAccordionTile], passé dans
/// [children]).
class _BankAccordionTile extends StatelessWidget {
  final String bankName;
  final List<PatrimoineAccount> accounts;
  final String? logoPath;
  final ValueChanged<String>? onImportLogo;
  final bool hidden;
  final bool expanded;
  final VoidCallback onToggleExpand;

  /// Contenu déplié : les accordéons de comptes de cette banque (avec leurs
  /// séparateurs), construits par `_AccountsCardState` qui détient l'état
  /// d'expansion de chaque compte.
  final List<Widget> children;

  /// Affiche la colonne PRU (Prix de Revient Unitaire) du tableau — les
  /// cases Quantité/PRU/Cours restent vides sur une ligne banque (la somme
  /// n'y a pas de sens à l'unité).
  final bool showPru;

  const _BankAccordionTile({
    required this.bankName,
    required this.accounts,
    this.logoPath,
    this.onImportLogo,
    required this.hidden,
    required this.expanded,
    required this.onToggleExpand,
    required this.children,
    this.showPru = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = accounts.fold(0.0, (sum, a) => sum + a.valeur);
    final plusValueAbs = accounts.fold(0.0, (sum, a) => sum + a.plusValueAbs);
    final costBasis = total - plusValueAbs;
    final percent = costBasis == 0 ? 0.0 : plusValueAbs / costBasis * 100;
    final positive = plusValueAbs >= 0;
    final color = positive ? _green : _red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  // Le chevron d'expansion occupe la même case que l'avatar
                  // des lignes de compte, la banque étant décalée d'un
                  // niveau d'imbrication.
                  SizedBox(
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
                  ),
                  BankLogoAvatar(
                    bankName: bankName,
                    logoPath: logoPath,
                    onTap: onImportLogo == null
                        ? null
                        : () => onImportLogo!(bankName),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        shadcn.Text(bankName).medium().small(),
                        shadcn.Text(
                          accounts.length == 1
                              ? '1 compte'
                              : '${accounts.length} comptes',
                        ).muted().xSmall(),
                      ],
                    ),
                  ),
                  // Cases Quantité/PRU/Cours : une banque n'a pas de sens à
                  // l'unité, on n'affiche que Valeur et Évolution.
                  const SizedBox(width: _colWidth),
                  if (showPru) const SizedBox(width: _colWidth),
                  const SizedBox(width: _colWidth),
                  SizedBox(
                    width: _colWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: shadcn.Text(
                        displayEuros(total, hidden),
                      ).small(),
                    ),
                  ),
                  SizedBox(
                    width: _colWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        shadcn.Text(
                          displayEuros(plusValueAbs, hidden),
                          style: TextStyle(color: color),
                        ).xSmall(),
                        shadcn.Text(
                          displayPercent(percent),
                          style: TextStyle(color: color),
                        ).muted().xSmall(),
                      ],
                    ),
                  ),
                  const SizedBox(width: _actionsWidth),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: Column(children: children),
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

/// Avatar d'une ligne du tableau : la photo du produit ([PatrimoineAccount
/// .avatarImagePath], métaux précieux physiques) quand elle est disponible,
/// sinon les initiales — celles dérivées du nom, ou l'override éventuel
/// ([PatrimoineAccount.avatarInitials], ex : "ETC" pour un métal coté).
/// Un échec de lecture de l'image (fichier supprimé, corrompu...) retombe
/// silencieusement sur les initiales.
class _AccountAvatar extends StatelessWidget {
  final PatrimoineAccount account;

  const _AccountAvatar({required this.account});

  @override
  Widget build(BuildContext context) {
    final imagePath = account.avatarImagePath;
    if (imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          File(imagePath),
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() => Avatar(
    size: 28,
    initials: account.avatarInitials ?? account.initials,
  );
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

  /// Affiche la colonne PRU (Prix de Revient Unitaire) entre la quantité et
  /// le cours — cf. [PatrimoineCategory.showsPruColumn].
  final bool showPru;

  const _AccountLine({
    required this.account,
    required this.hidden,
    this.trailing,
    this.onTap,
    this.leading,
    this.showAvatar = true,
    this.showPru = false,
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
            leading ?? _AccountAvatar(account: account)
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
          if (showPru)
            SizedBox(
              width: _colWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: shadcn.Text(
                  account.pru != null
                      ? displayEuros(account.pru!, hidden)
                      : '—',
                ).small(),
              ),
            ),
          SizedBox(
            width: _colWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: account.priceUnavailable == true && account.cours == null
                  // Un cours a été cherché et n'a pas été trouvé : on le
                  // signale plutôt que de ne laisser qu'un « — » silencieux
                  // (voir [PatrimoineAccount.priceUnavailable]).
                  ? Tooltip(
                      tooltip: (context) => TooltipContainer(
                        child: shadcn.Text(
                          'Cours introuvable sur Yahoo Finance pour cet '
                          'investissement.',
                        ),
                      ),
                      child: Icon(
                        LucideIcons.triangleAlert,
                        size: 14,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    )
                  : shadcn.Text(
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

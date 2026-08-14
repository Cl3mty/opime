import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/date_format.dart';
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../../core/ui/mobile_orientation.dart';
import '../../core/ui/slide_page_route.dart';
import 'budget_models.dart';
import 'budget_repository.dart';
import 'budget_sankey.dart';

/// Largeur en dessous de laquelle il n'y a plus assez de place pour
/// l'historique des budgets ET l'éditeur côte à côte (mode desktop) :
/// l'historique devient alors sa propre page, avec un éditeur poussé en
/// plein écran (glissement depuis la droite, retour via un chevron dans
/// l'AppBar).
const _splitThreshold = 700.0;

/// Même seuil que celui de [AppShell] pour distinguer téléphone et
/// tablette : une tablette a assez de largeur en portrait pour la
/// ventilation, seul un téléphone doit basculer temporairement en
/// paysage pour le graphique de flux.
const _tabletShortestSide = 800.0;

class BudgetScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;
  const BudgetScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late BudgetRepository _repo;

  final ValueNotifier<List<BudgetSnapshot>> _history = ValueNotifier([]);
  String? _selectedId;
  bool _loading = true;
  bool _loadError = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _repo = BudgetRepository(widget.vaultPath);
    _init();
  }

  @override
  void didUpdateWidget(covariant BudgetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) {
      _repo = BudgetRepository(widget.vaultPath);
      _history.value = const [];
      _selectedId = null;
      _loading = true;
      _loadError = false;
      _init();
    }
  }

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final generation = ++_loadGeneration;
    try {
      // Un dossier Vault sur un emplacement synchronisé (iCloud Drive...)
      // peut mettre du temps à répondre, voire ne jamais répondre si le
      // fournisseur cloud est indisponible : un délai borné évite un
      // spinner infini et silencieux, remplacé par un état d'erreur
      // explicite avec bouton "Réessayer".
      final list = await _repo.listAll().timeout(const Duration(seconds: 15));
      if (!mounted || generation != _loadGeneration) return;
      _history.value = list;
      if (list.isNotEmpty) {
        _selectedId = list.first.id;
      }
      setState(() {
        _loading = false;
        _loadError = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  void _retryInit() {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    _init();
  }

  Future<void> _refreshHistory() async {
    _history.value = await _repo.listAll();
  }

  Future<void> _deleteSnapshot(String id) async {
    await _repo.deleteSnapshot(id);
    if (_selectedId == id) setState(() => _selectedId = null);
    await _refreshHistory();
  }

  Future<void> _renameSnapshot(String id, String name) async {
    await _repo.renameSnapshot(id, name);
    await _refreshHistory();
  }

  void _onEditorSaved(String id) {
    setState(() => _selectedId = id);
    _refreshHistory();
  }

  BudgetSnapshot? _snapshotById(String? id) {
    if (id == null) return null;
    for (final snapshot in _history.value) {
      if (snapshot.id == id) return snapshot;
    }
    return null;
  }

  void _openBudgetDetail(BuildContext context, BudgetSnapshot? snapshot) {
    Navigator.of(context).push(
      slidePageRoute(
        (context) => Scaffold(
          headers: [
            AppBar(
              title: shadcn.Text(snapshot?.displayName ?? 'Nouveau budget'),
              leading: [
                IconButton.ghost(
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
          child: _BudgetEditor(
            repository: _repo,
            snapshot: snapshot,
            amountVisibility: widget.amountVisibility,
            onSaved: _onEditorSaved,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError) {
      return LoadErrorView(
        message:
            'Impossible de charger les budgets. Vérifiez que le dossier '
            'Vault est accessible.',
        onRetry: _retryInit,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FrostedCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= _splitThreshold) {
              return _buildDesktopSplit();
            }
            return _BudgetHistoryColumn(
              history: _history,
              selectedId: _selectedId,
              showSearch: true,
              onSelect: (snapshot) {
                setState(() => _selectedId = snapshot.id);
                _openBudgetDetail(context, snapshot);
              },
              onNew: () {
                setState(() => _selectedId = null);
                _openBudgetDetail(context, null);
              },
              onDelete: _deleteSnapshot,
              onRename: _renameSnapshot,
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopSplit() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _BudgetHistoryColumn(
              history: _history,
              selectedId: _selectedId,
              onSelect: (snapshot) => setState(() => _selectedId = snapshot.id),
              onNew: () => setState(() => _selectedId = null),
              onDelete: _deleteSnapshot,
              onRename: _renameSnapshot,
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _BudgetEditor(
            key: ValueKey(_selectedId),
            repository: _repo,
            snapshot: _snapshotById(_selectedId),
            amountVisibility: widget.amountVisibility,
            onSaved: _onEditorSaved,
          ),
        ),
      ],
    );
  }
}

/// Formulaire + graphique d'un budget (nouveau ou existant), autonome :
/// gère sa propre donnée éditée et ne notifie le parent qu'à la
/// sauvegarde ([onSaved]). Utilisé aussi bien inline (desktop, à côté de
/// l'historique) qu'en page poussée plein écran (mobile).
class _BudgetEditor extends StatefulWidget {
  final BudgetRepository repository;
  final BudgetSnapshot? snapshot;
  final AmountVisibilityController amountVisibility;
  final ValueChanged<String> onSaved;

  const _BudgetEditor({
    super.key,
    required this.repository,
    required this.snapshot,
    required this.amountVisibility,
    required this.onSaved,
  });

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  late BudgetData _data;
  late String? _selectedId;
  int _tabIndex = 0;
  bool _isTablet = false;
  bool _orientationInitialized = false;

  final GlobalKey _sankeyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _data = widget.snapshot?.data ?? BudgetData.empty();
    _selectedId = widget.snapshot?.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery n'est pas disponible tant que initState() n'est pas
    // terminé : didChangeDependencies() est le premier endroit sûr pour
    // le lire. Le flag garde le geste "une seule fois à l'ouverture",
    // malgré les appels multiples possibles de ce callback.
    if (_orientationInitialized) return;
    _orientationInitialized = true;
    _isTablet = MediaQuery.of(context).size.shortestSide >= _tabletShortestSide;
    // Ventilation du budget : seul un téléphone (pas assez de largeur en
    // portrait) a besoin de lever temporairement le verrou portrait par
    // défaut pour basculer en paysage.
    if (!_isTablet) allowLandscapeOnMobile();
  }

  @override
  void dispose() {
    if (!_isTablet) lockPortraitOnMobile();
    super.dispose();
  }

  Future<void> _save() async {
    String id;
    if (_selectedId == null) {
      id = await widget.repository.saveNew(_data);
      setState(() => _selectedId = id);
    } else {
      id = _selectedId!;
      await widget.repository.updateSnapshot(id, _data);
    }
    widget.onSaved(id);
    if (!mounted) return;
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: const shadcn.Text('Budget sauvegardé'),
          subtitle: shadcn.Text(
            '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          ),
        ),
      ),
    );
  }

  Future<void> _downloadChartImage() async {
    try {
      final boundary =
          _sankeyKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List bytes = byteData.buffer.asUint8List();

      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer le graphique',
        fileName: 'flux-budgetaire.png',
        bytes: bytes,
      );
      if (savePath == null) return;

      final path = savePath.toLowerCase().endsWith('.png')
          ? savePath
          : '$savePath.png';
      await File(path).writeAsBytes(bytes);
    } catch (e) {
      // ignore: avoid_print
      print('Erreur export image : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le graphique de flux (Sankey) a besoin de largeur pour rester
    // lisible : sur téléphone tenu en portrait, on suggère la bascule en
    // paysage plutôt que d'essayer de le comprimer. Une tablette a déjà
    // assez de largeur en portrait, donc pas de suggestion à lui imposer.
    // Les fenêtres desktop sont toujours plus larges que hautes (taille
    // minimale imposée), donc cette condition ne se déclenche jamais en
    // dehors d'un vrai téléphone.
    if (!_isTablet &&
        MediaQuery.of(context).orientation == Orientation.portrait) {
      return const _LandscapeSuggestion();
    }
    return AnimatedBuilder(
      animation: widget.amountVisibility,
      builder: (context, _) =>
          _buildContent(context, widget.amountVisibility.hidden),
    );
  }

  Widget _buildContent(BuildContext context, bool hidden) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Tabs(
              index: _tabIndex,
              onChanged: (value) => setState(() => _tabIndex = value),
              children: const [
                TabItem(child: shadcn.Text('Revenus')),
                TabItem(child: shadcn.Text('Investissements')),
                TabItem(child: shadcn.Text('Dépenses')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sélection directe plutôt qu'IndexedStack : celui-ci réserve la
          // hauteur du plus grand des 3 onglets même quand l'onglet actif
          // est plus court, ce qui décollait le texte/graphique du dessous
          // d'un écart variable. La donnée vit dans _data (pas dans l'état
          // interne des cartes), donc rien n'est perdu en changeant d'onglet.
          [
            _RevenuesCard(
              revenues: _data.revenues,
              onChanged: (revenues) =>
                  setState(() => _data = _data.copyWith(revenues: revenues)),
            ),
            _CategoriesCard(
              categories: _data.investmentCategories,
              itemIdPrefix: 'investment',
              onChanged: (cats) => setState(
                () => _data = _data.copyWith(investmentCategories: cats),
              ),
            ),
            _CategoriesCard(
              categories: _data.expenseCategories,
              itemIdPrefix: 'expense',
              onChanged: (cats) => setState(
                () => _data = _data.copyWith(expenseCategories: cats),
              ),
            ),
          ][_tabIndex],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: shadcn.Text.rich(
                TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    const TextSpan(text: "Votre taux d'épargne est de "),
                    TextSpan(
                      text: '${_data.savingsRate.round()} %',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' (taux d\'épargne possible : '),
                    TextSpan(
                      text: '${_data.possibleSavingsRate.round()} %',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '). Vous avez un revenu total de '),
                    TextSpan(
                      text: displayEuros(_data.totalRevenues, hidden),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ', des dépenses de '),
                    TextSpan(
                      text: displayEuros(_data.totalExpenses, hidden),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' et investissez '),
                    TextSpan(
                      text: displayEuros(_data.totalInvestments, hidden),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' tous les mois, il vous reste '),
                    TextSpan(
                      text: displayEuros(_data.balance, hidden),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const TextSpan(text: ' disponible.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              IconButton.ghost(
                icon: const Icon(LucideIcons.download),
                onPressed: _downloadChartImage,
              ),
              const SizedBox(width: 8),
              PrimaryButton(
                onPressed: _save,
                leading: const Icon(LucideIcons.save),
                child: const shadcn.Text('Sauvegarder'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _sankeyKey,
            child: BudgetSankeyChart(data: _data, hidden: hidden),
          ),
        ],
      ),
    );
  }
}

class _LandscapeSuggestion extends StatelessWidget {
  const _LandscapeSuggestion();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.rotateCcw,
              size: 32,
              color: Theme.of(context).colorScheme.mutedForeground,
            ),
            const SizedBox(height: 16),
            shadcn.Text(
              "Utilisez l'application en mode paysage pour une meilleure lisibilité",
              textAlign: TextAlign.center,
            ).muted(),
          ],
        ),
      ),
    );
  }
}

/// Historique des budgets, réutilisé en colonne fixe (desktop, à côté de
/// l'éditeur) et en page pleine largeur avec recherche (mobile, avant de
/// pousser vers l'éditeur).
class _BudgetHistoryColumn extends StatefulWidget {
  final ValueListenable<List<BudgetSnapshot>> history;
  final String? selectedId;
  final ValueChanged<BudgetSnapshot> onSelect;
  final VoidCallback onNew;
  final ValueChanged<String> onDelete;
  final void Function(String id, String name) onRename;
  final bool showSearch;

  const _BudgetHistoryColumn({
    required this.history,
    required this.selectedId,
    required this.onSelect,
    required this.onNew,
    required this.onDelete,
    required this.onRename,
    this.showSearch = false,
  });

  @override
  State<_BudgetHistoryColumn> createState() => _BudgetHistoryColumnState();
}

class _BudgetHistoryColumnState extends State<_BudgetHistoryColumn> {
  String? _editingId;
  final TextEditingController _editController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _startRename(BudgetSnapshot snapshot) {
    _editController.text = snapshot.displayName;
    setState(() => _editingId = snapshot.id);
  }

  void _commitRename(String id) {
    final name = _editController.text.trim();
    if (name.isNotEmpty) widget.onRename(id, name);
    setState(() => _editingId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: shadcn.Text('Budgets ventilés').semiBold()),
            IconButton.ghost(
              icon: const Icon(LucideIcons.filePlus),
              onPressed: widget.onNew,
            ),
          ],
        ),
        if (widget.showSearch) ...[
          const SizedBox(height: 8),
          TextField(
            placeholder: const shadcn.Text('Rechercher un budget...'),
            features: const [
              InputFeature.leading(Icon(LucideIcons.search, size: 16)),
            ],
            onChanged: (value) => setState(() => _query = value),
          ),
        ],
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 4),
        Expanded(
          child: ValueListenableBuilder<List<BudgetSnapshot>>(
            valueListenable: widget.history,
            builder: (context, snapshots, _) {
              final query = _query.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? snapshots
                  : snapshots
                        .where(
                          (s) => s.displayName.toLowerCase().contains(query),
                        )
                        .toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: shadcn.Text(
                    snapshots.isEmpty
                        ? 'Aucun budget sauvegardé.'
                        : 'Aucun résultat.',
                  ).muted().small(),
                );
              }
              return ListView.builder(
                // Sans padding explicite, ListView hérite automatiquement
                // du padding de sécurité (MediaQuery, encoche/Dynamic
                // Island) en haut de la liste : un grand vide qui donne
                // l'impression qu'un budget manque. L'AppBar gère déjà la
                // zone de sécurité au-dessus, donc ce padding est superflu.
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final snapshot = filtered[i];
                  final selected = snapshot.id == widget.selectedId;
                  final theme = Theme.of(context);
                  final isEditing = _editingId == snapshot.id;

                  if (isEditing) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextField(
                        controller: _editController,
                        autofocus: true,
                        onSubmitted: (_) => _commitRename(snapshot.id),
                        placeholder: const shadcn.Text('Nom du budget'),
                      ),
                    );
                  }

                  return GestureDetector(
                    onTap: () => widget.onSelect(snapshot),
                    child: Container(
                      color: selected
                          ? theme.colorScheme.accent
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                shadcn.Text(
                                  snapshot.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                shadcn.Text(
                                  formatDateDdMmYyyy(snapshot.savedAt),
                                ).muted().small(),
                              ],
                            ),
                          ),
                          IconButton.ghost(
                            icon: const Icon(LucideIcons.pencil, size: 14),
                            onPressed: () => _startRename(snapshot),
                          ),
                          IconButton.ghost(
                            icon: const Icon(LucideIcons.trash2, size: 14),
                            onPressed: () => widget.onDelete(snapshot.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.plus,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          shadcn.Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _RevenuesCard extends StatelessWidget {
  final List<BudgetItem> revenues;
  final ValueChanged<List<BudgetItem>> onChanged;

  const _RevenuesCard({required this.revenues, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < revenues.length; i++)
          Padding(
            key: ValueKey(revenues[i].id),
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      initialValue: revenues[i].name,
                      placeholder: const shadcn.Text('Nom du revenu'),
                      border: Border.all(color: Colors.transparent),
                      onChanged: (value) => onChanged([
                        for (var j = 0; j < revenues.length; j++)
                          if (j == i)
                            revenues[j].copyWith(name: value)
                          else
                            revenues[j],
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      initialValue: revenues[i].amount == 0
                          ? ''
                          : revenues[i].amount.toStringAsFixed(0),
                      placeholder: const shadcn.Text('Montant'),
                      border: Border.all(color: Colors.transparent),
                      textAlign: TextAlign.end,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final amount = parseDecimal(value) ?? 0;
                        onChanged([
                          for (var j = 0; j < revenues.length; j++)
                            if (j == i)
                              revenues[j].copyWith(amount: amount)
                            else
                              revenues[j],
                        ]);
                      },
                    ),
                  ),
                  IconButton.ghost(
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    onPressed: () => onChanged([
                      for (var j = 0; j < revenues.length; j++)
                        if (j != i) revenues[j],
                    ]),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        _AddLink(
          label: 'Ajouter une source de revenu',
          onTap: () => onChanged([
            ...revenues,
            BudgetItem(id: generateItemId('revenue'), name: '', amount: 0),
          ]),
        ),
      ],
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  final List<BudgetCategory> categories;
  final String itemIdPrefix;
  final ValueChanged<List<BudgetCategory>> onChanged;

  const _CategoriesCard({
    required this.categories,
    required this.itemIdPrefix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var catIdx = 0; catIdx < categories.length; catIdx++)
          Padding(
            key: ValueKey(categories[catIdx].id),
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedContainer(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    initialValue: categories[catIdx].name,
                    placeholder: const shadcn.Text('Catégorie'),
                    border: Border.all(color: Colors.transparent),
                    onChanged: (value) {
                      final updated = [...categories];
                      updated[catIdx] = updated[catIdx].copyWith(name: value);
                      onChanged(updated);
                    },
                  ),
                  for (final item in categories[catIdx].items)
                    Padding(
                      key: ValueKey(item.id),
                      padding: const EdgeInsets.only(top: 6, left: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              initialValue: item.name,
                              placeholder: const shadcn.Text('Nom'),
                              border: Border.all(color: Colors.transparent),
                              onChanged: (value) {
                                final updated = [...categories];
                                updated[catIdx] = updated[catIdx].copyWith(
                                  items: [
                                    for (final i in updated[catIdx].items)
                                      if (i.id == item.id)
                                        i.copyWith(name: value)
                                      else
                                        i,
                                  ],
                                );
                                onChanged(updated);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              initialValue: item.amount == 0
                                  ? ''
                                  : item.amount.toStringAsFixed(0),
                              placeholder: const shadcn.Text('Montant'),
                              border: Border.all(color: Colors.transparent),
                              textAlign: TextAlign.end,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                final amount = parseDecimal(value) ?? 0;
                                final updated = [...categories];
                                updated[catIdx] = updated[catIdx].copyWith(
                                  items: [
                                    for (final i in updated[catIdx].items)
                                      if (i.id == item.id)
                                        i.copyWith(amount: amount)
                                      else
                                        i,
                                  ],
                                );
                                onChanged(updated);
                              },
                            ),
                          ),
                          IconButton.ghost(
                            icon: const Icon(LucideIcons.trash2, size: 14),
                            onPressed: () {
                              final updated = [...categories];
                              updated[catIdx] = updated[catIdx].copyWith(
                                items: updated[catIdx].items
                                    .where((i) => i.id != item.id)
                                    .toList(),
                              );
                              onChanged(updated);
                            },
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 24),
                    child: _AddLink(
                      label: 'Ajouter',
                      onTap: () {
                        final updated = [...categories];
                        updated[catIdx] = updated[catIdx].copyWith(
                          items: [
                            ...updated[catIdx].items,
                            BudgetItem(
                              id: generateItemId(itemIdPrefix),
                              name: '',
                              amount: 0,
                            ),
                          ],
                        );
                        onChanged(updated);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        _AddLink(
          label: 'Ajouter une catégorie',
          onTap: () =>
              onChanged([...categories, BudgetCategory(name: '', items: [])]),
        ),
      ],
    );
  }
}

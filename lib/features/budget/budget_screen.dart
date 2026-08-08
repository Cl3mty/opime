import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/date_format.dart';
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import 'budget_models.dart';
import 'budget_repository.dart';
import 'budget_sankey.dart';

class BudgetScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;
  const BudgetScreen({super.key, required this.vaultPath, required this.amountVisibility});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late BudgetRepository _repo;

  final ValueNotifier<List<BudgetSnapshot>> _history = ValueNotifier([]);
  String? _selectedId;
  BudgetData _data = BudgetData.empty();
  bool _loading = true;
  int _tabIndex = 0;
  int _loadGeneration = 0;

  final GlobalKey _sankeyKey = GlobalKey();

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
      _data = BudgetData.empty();
      _loading = true;
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
    final list = await _repo.listAll();
    if (!mounted || generation != _loadGeneration) return;
    _history.value = list;
    if (list.isNotEmpty) {
      _selectedId = list.first.id;
      _data = list.first.data;
    }
    setState(() => _loading = false);
  }

  Future<void> _refreshHistory() async {
    _history.value = await _repo.listAll();
  }

  Future<void> _selectSnapshot(BudgetSnapshot snapshot) async {
    setState(() {
      _selectedId = snapshot.id;
      _data = snapshot.data;
    });
  }

  void _newBudget() {
    setState(() {
      _selectedId = null;
      _data = BudgetData.empty();
    });
  }

  Future<void> _deleteSnapshot(String id) async {
    await _repo.deleteSnapshot(id);
    if (_selectedId == id) _newBudget();
    await _refreshHistory();
  }

  Future<void> _renameSnapshot(String id, String name) async {
    await _repo.renameSnapshot(id, name);
    await _refreshHistory();
  }

  Future<void> _save() async {
    if (_selectedId == null) {
      final id = await _repo.saveNew(_data);
      setState(() => _selectedId = id);
    } else {
      await _repo.updateSnapshot(_selectedId!, _data);
    }
    await _refreshHistory();
    if (!mounted) return;
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: const shadcn.Text('Budget sauvegardé'),
          subtitle: shadcn.Text('${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}'),
        ),
      ),
    );
  }

  Future<void> _downloadChartImage() async {
    try {
      final boundary =
          _sankeyKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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

      final path = savePath.toLowerCase().endsWith('.png') ? savePath : '$savePath.png';
      await File(path).writeAsBytes(bytes);
    } catch (e) {
      // ignore: avoid_print
      print('Erreur export image : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return AnimatedBuilder(
      animation: widget.amountVisibility,
      builder: (context, _) => _buildContent(context, widget.amountVisibility.hidden),
    );
  }

  Widget _buildContent(BuildContext context, bool hidden) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FrostedCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 260,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _BudgetHistoryColumn(
                  history: _history,
                  selectedId: _selectedId,
                  onSelect: _selectSnapshot,
                  onNew: _newBudget,
                  onDelete: _deleteSnapshot,
                  onRename: _renameSnapshot,
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: SingleChildScrollView(
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
                    IndexedStack(
                      index: _tabIndex,
                      children: [
                        _RevenuesCard(
                          revenues: _data.revenues,
                          onChanged: (revenues) => setState(() => _data = _data.copyWith(revenues: revenues)),
                        ),
                        _CategoriesCard(
                          categories: _data.investmentCategories,
                          itemIdPrefix: 'investment',
                          onChanged: (cats) => setState(() => _data = _data.copyWith(investmentCategories: cats)),
                        ),
                        _CategoriesCard(
                          categories: _data.expenseCategories,
                          itemIdPrefix: 'expense',
                          onChanged: (cats) => setState(() => _data = _data.copyWith(expenseCategories: cats)),
                        ),
                      ],
                    ),
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
                              TextSpan(text: '${_data.savingsRate.round()} %', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' (taux d\'épargne possible : '),
                              TextSpan(text: '${_data.possibleSavingsRate.round()} %', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: '). Vous avez un revenu total de '),
                              TextSpan(text: displayEuros(_data.totalRevenues, hidden), style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ', des dépenses de '),
                              TextSpan(text: displayEuros(_data.totalExpenses, hidden), style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' et investissez '),
                              TextSpan(text: displayEuros(_data.totalInvestments, hidden), style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' tous les mois, il vous reste '),
                              TextSpan(
                                text: displayEuros(_data.balance, hidden),
                                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetHistoryColumn extends StatefulWidget {
  final ValueNotifier<List<BudgetSnapshot>> history;
  final String? selectedId;
  final ValueChanged<BudgetSnapshot> onSelect;
  final VoidCallback onNew;
  final ValueChanged<String> onDelete;
  final void Function(String id, String name) onRename;

  const _BudgetHistoryColumn({
    required this.history,
    required this.selectedId,
    required this.onSelect,
    required this.onNew,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_BudgetHistoryColumn> createState() => _BudgetHistoryColumnState();
}

class _BudgetHistoryColumnState extends State<_BudgetHistoryColumn> {
  String? _editingId;
  final TextEditingController _editController = TextEditingController();

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
            Expanded(child: shadcn.Text('Budgets').semiBold()),
            IconButton.ghost(
              icon: const Icon(LucideIcons.filePlus),
              onPressed: widget.onNew,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 4),
        Expanded(
          child: ValueListenableBuilder<List<BudgetSnapshot>>(
            valueListenable: widget.history,
            builder: (context, snapshots, _) {
              if (snapshots.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: shadcn.Text('Aucun budget sauvegardé.').muted().small(),
                );
              }
              return ListView.builder(
                itemCount: snapshots.length,
                itemBuilder: (context, i) {
                  final snapshot = snapshots[i];
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
                      color: selected ? theme.colorScheme.accent : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                shadcn.Text(formatDateDdMmYyyy(snapshot.savedAt)).muted().small(),
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
          Icon(LucideIcons.plus, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          shadcn.Text(label, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
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
                          if (j == i) revenues[j].copyWith(name: value) else revenues[j],
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      initialValue: revenues[i].amount == 0 ? '' : revenues[i].amount.toStringAsFixed(0),
                      placeholder: const shadcn.Text('Montant'),
                      border: Border.all(color: Colors.transparent),
                      textAlign: TextAlign.end,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final amount = double.tryParse(value) ?? 0;
                        onChanged([
                          for (var j = 0; j < revenues.length; j++)
                            if (j == i) revenues[j].copyWith(amount: amount) else revenues[j],
                        ]);
                      },
                    ),
                  ),
                  IconButton.ghost(
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    onPressed: () => onChanged([for (var j = 0; j < revenues.length; j++) if (j != i) revenues[j]]),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        _AddLink(
          label: 'Ajouter une source de revenu',
          onTap: () => onChanged([...revenues, BudgetItem(id: generateItemId('revenue'), name: '', amount: 0)]),
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
                                updated[catIdx] = updated[catIdx].copyWith(items: [
                                  for (final i in updated[catIdx].items)
                                    if (i.id == item.id) i.copyWith(name: value) else i,
                                ]);
                                onChanged(updated);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              initialValue: item.amount == 0 ? '' : item.amount.toStringAsFixed(0),
                              placeholder: const shadcn.Text('Montant'),
                              border: Border.all(color: Colors.transparent),
                              textAlign: TextAlign.end,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                final amount = double.tryParse(value) ?? 0;
                                final updated = [...categories];
                                updated[catIdx] = updated[catIdx].copyWith(items: [
                                  for (final i in updated[catIdx].items)
                                    if (i.id == item.id) i.copyWith(amount: amount) else i,
                                ]);
                                onChanged(updated);
                              },
                            ),
                          ),
                          IconButton.ghost(
                            icon: const Icon(LucideIcons.trash2, size: 14),
                            onPressed: () {
                              final updated = [...categories];
                              updated[catIdx] = updated[catIdx].copyWith(
                                items: updated[catIdx].items.where((i) => i.id != item.id).toList(),
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
                        updated[catIdx] = updated[catIdx].copyWith(items: [
                          ...updated[catIdx].items,
                          BudgetItem(id: generateItemId(itemIdPrefix), name: '', amount: 0),
                        ]);
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
          onTap: () => onChanged([...categories, BudgetCategory(name: '', items: [])]),
        ),
      ],
    );
  }
}
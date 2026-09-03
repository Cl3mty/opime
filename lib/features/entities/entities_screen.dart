import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart' show formatEuros, parseDecimal;
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../investments/confirm_delete_dialog.dart' show confirmDelete;
import 'entities_models.dart';
import 'entities_repository.dart';

/// Écran "Entités" (holdings, sociétés commerciales, SCI, comptes pro) —
/// atteint uniquement en cliquant la catégorie "Entités professionnelles"
/// du Dashboard (voir `entities_patrimoine_adapter.dart`, réservée à un
/// coffre-fort professionnel), pas de nav dédiée. Chaque entité porte son
/// propre petit bilan et un pourcentage de détention ; le total affiché en
/// tête EST inclus dans le patrimoine net global (Dashboard/Analyses) — voir
/// la doc de tête de `entities_models.dart`.
class EntitiesScreen extends StatefulWidget {
  final String vaultPath;

  const EntitiesScreen({super.key, required this.vaultPath});

  @override
  State<EntitiesScreen> createState() => _EntitiesScreenState();
}

class _EntitiesScreenState extends State<EntitiesScreen> {
  late final EntityRepository _repo;
  bool _loading = true;
  bool _loadError = false;
  List<BusinessEntity> _entities = [];

  @override
  void initState() {
    super.initState();
    _repo = EntityRepository(widget.vaultPath);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final all = await _repo.listAll();
      if (!mounted) return;
      setState(() {
        _entities = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = true;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({BusinessEntity? existing}) async {
    final result = await showEntityEditorDialog(context, existing: existing);
    if (result == null) return;
    await _repo.saveEntity(result);
    await _load();
  }

  Future<void> _delete(BusinessEntity entity) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer "${entity.name}" ?',
      message:
          'Cette entité et son petit bilan seront définitivement supprimés.',
    );
    if (!confirmed) return;
    await _repo.deleteEntity(entity.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError) {
      return LoadErrorView(
        message:
            'Impossible de charger les entités. Vérifiez que le dossier '
            'Coffre-fort est accessible.',
        onRetry: _load,
      );
    }

    final sorted = [..._entities]
      ..sort((a, b) => b.ownedNetValue.compareTo(a.ownedNetValue));
    final total = _entities.fold<double>(0, (sum, e) => sum + e.ownedNetValue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              shadcn.Text('Entités').x2Large().bold(),
              PrimaryButton(
                onPressed: () => _openEditor(),
                leading: const Icon(LucideIcons.plus),
                child: const shadcn.Text('Ajouter une entité'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FrostedCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shadcn.Text(
                    'Valeur nette détenue via les entités professionnelles',
                  ).muted().small(),
                  const SizedBox(height: 4),
                  shadcn.Text(formatEuros(total)).x2Large().bold(),
                  const SizedBox(height: 4),
                  shadcn.Text(
                    'Inclus dans votre patrimoine net (Tableau de bord, '
                    'Analyses).',
                  ).muted().xSmall(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (sorted.isEmpty)
            shadcn.Text(
              'Aucune entité pour l\'instant — ajoute un holding, une '
              'société commerciale, une SCI ou un compte pro.',
            ).muted().small()
          else
            for (final entity in sorted) ...[
              _EntityCard(
                entity: entity,
                onTap: () => _openEditor(existing: entity),
                onDelete: () => _delete(entity),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _EntityCard extends StatelessWidget {
  final BusinessEntity entity;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EntityCard({
    required this.entity,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shadcn.Text(entity.name).large().medium(),
                    const SizedBox(height: 2),
                    shadcn.Text(
                      '${entity.type.label} · ${_formatPercent(entity.ownershipPercent)} % détenu',
                    ).muted().small(),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  shadcn.Text(
                    formatEuros(entity.ownedNetValue),
                  ).large().semiBold(),
                  shadcn.Text(
                    'sur ${formatEuros(entity.netValue)} net',
                  ).muted().xSmall(),
                ],
              ),
              const SizedBox(width: 8),
              IconButton.ghost(
                icon: const Icon(LucideIcons.trash2, size: 16),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPercent(double value) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toString();
}

/// Ouvre l'éditeur (création si [existing] est `null`, édition sinon) —
/// retourne l'entité prête à être sauvegardée, ou `null` si annulé.
Future<BusinessEntity?> showEntityEditorDialog(
  BuildContext context, {
  BusinessEntity? existing,
}) {
  return showDialog<BusinessEntity>(
    context: context,
    builder: (context) => _EntityEditorDialog(existing: existing),
  );
}

class _EntityEditorDialog extends StatefulWidget {
  final BusinessEntity? existing;
  const _EntityEditorDialog({this.existing});

  @override
  State<_EntityEditorDialog> createState() => _EntityEditorDialogState();
}

class _EntityEditorDialogState extends State<_EntityEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _percentController;
  late EntityType _type;
  late List<EntityLine> _assets;
  late List<EntityLine> _liabilities;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _percentController = TextEditingController(
      text: (existing?.ownershipPercent ?? 100).toString(),
    );
    _type = existing?.type ?? EntityType.societeCommerciale;
    _assets = [...(existing?.assets ?? const [])];
    _liabilities = [...(existing?.liabilities ?? const [])];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  void _addLine(List<EntityLine> lines) {
    setState(
      () => lines.add(
        EntityLine(id: generateEntityLineId(), label: '', amount: 0),
      ),
    );
  }

  void _removeLine(List<EntityLine> lines, String id) {
    setState(() => lines.removeWhere((l) => l.id == id));
  }

  void _updateLine(
    List<EntityLine> lines,
    String id, {
    String? label,
    double? amount,
  }) {
    final idx = lines.indexWhere((l) => l.id == id);
    if (idx == -1) return;
    setState(
      () => lines[idx] = lines[idx].copyWith(label: label, amount: amount),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Le nom est obligatoire.');
      return;
    }
    final percent = parseDecimal(_percentController.text) ?? 100;
    Navigator.of(context).pop(
      BusinessEntity(
        id: widget.existing?.id ?? generateEntityId(),
        name: name,
        type: _type,
        ownershipPercent: percent.clamp(0, 100),
        assets: _assets.where((l) => l.label.trim().isNotEmpty).toList(),
        liabilities: _liabilities
            .where((l) => l.label.trim().isNotEmpty)
            .toList(),
      ),
    );
  }

  Widget _buildLinesEditor(String title, List<EntityLine> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            shadcn.Text(title).medium().small(),
            IconButton.ghost(
              key: ValueKey('add_line_$title'),
              icon: const Icon(LucideIcons.plus, size: 14),
              onPressed: () => _addLine(lines),
            ),
          ],
        ),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: ValueKey('${line.id}-label'),
                    initialValue: line.label,
                    placeholder: const shadcn.Text('Libellé'),
                    onChanged: (v) => _updateLine(lines, line.id, label: v),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: ValueKey('${line.id}-amount'),
                    initialValue: line.amount == 0 ? '' : line.amount.toString(),
                    placeholder: const shadcn.Text('Montant (€)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => _updateLine(
                      lines,
                      line.id,
                      amount: parseDecimal(v) ?? 0,
                    ),
                  ),
                ),
                IconButton.ghost(
                  icon: const Icon(LucideIcons.x, size: 14),
                  onPressed: () => _removeLine(lines, line.id),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shadcn.Text(
                    isEditing ? 'Modifier l\'entité' : 'Nouvelle entité',
                  ).large().semiBold(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    placeholder: const shadcn.Text(
                      'Nom (ex : Holding Dupont)',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  const shadcn.Text('Type').muted().small(),
                  const SizedBox(height: 6),
                  Select<EntityType>(
                    value: _type,
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                    itemBuilder: (context, v) => shadcn.Text(v.label),
                    popup: (context) => SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final v in EntityType.values)
                            SelectItemButton(
                              value: v,
                              child: shadcn.Text(v.label),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _percentController,
                    placeholder: const shadcn.Text('% détenu'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLinesEditor('Actifs', _assets),
                  const SizedBox(height: 12),
                  _buildLinesEditor('Passifs', _liabilities),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    shadcn.Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.destructive,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      PrimaryButton(
                        onPressed: _save,
                        child: const shadcn.Text('Enregistrer'),
                      ),
                      const SizedBox(width: 8),
                      OutlineButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const shadcn.Text('Annuler'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

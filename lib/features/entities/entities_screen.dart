import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart' show formatEuros, parseDecimal;
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../../l10n/app_localizations.dart';
import '../investments/confirm_delete_dialog.dart' show confirmDelete;
import '../investments/investments_models.dart' show InvestmentAccount;
import '../investments/investments_repository.dart';
import '../investments/patrimoine_refresh_controller.dart';
import '../liabilities/liabilities_models.dart' show Liability;
import '../liabilities/liabilities_repository.dart';
import 'entities_models.dart';
import 'entities_patrimoine_adapter.dart' show entityNetValue;
import 'entities_repository.dart';
import 'entity_detail_screen.dart';
import 'entity_ownership_summary.dart';
import 'entity_structure_diagram.dart';

/// Valeur sentinelle du sélecteur "Détenue par" (`_EntityEditorDialog`) :
/// aucune entité parente, l'entité est détenue directement par
/// l'utilisateur (`BusinessEntity.parentEntityId` reste `null`) — distincte
/// de `null` lui-même, qu'un `Select<String>` ne peut pas porter comme
/// valeur sélectionnée (même motif que `complete_patrimoine_dialog.dart`'s
/// `_noCustomOtherCategoryValue`).
const _noParentValue = '__none__';

/// Écran "Entités" (holdings, sociétés commerciales, SCI) — pas de nav
/// dédiée : atteint depuis le Dashboard via son bouton "Gérer les
/// entités" (toujours visible, y compris avant la toute première entité —
/// voir `dashboard_screen.dart`'s section entités). Chaque entité est une
/// simple identité (nom, type, % de détention, éventuel lien vers un
/// holding) — sa valeur vient de ses VRAIS comptes/passifs
/// (`InvestmentAccount`/`Liability.entityId`, voir `entity_detail_screen
/// .dart`), pas d'un bilan libre saisi ici. Le total affiché en tête EST
/// inclus dans le patrimoine net global (Dashboard/Analyses) — voir la doc
/// de tête de `entities_models.dart`.
class EntitiesScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;
  final PatrimoineRefreshController patrimoineRefreshController;
  final String profileName;

  const EntitiesScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
    required this.patrimoineRefreshController,
    required this.profileName,
  });

  @override
  State<EntitiesScreen> createState() => _EntitiesScreenState();
}

class _EntitiesScreenState extends State<EntitiesScreen> {
  late final EntityRepository _repo;
  late final InvestmentsRepository _accountsRepo;
  late final LiabilitiesRepository _liabilitiesRepo;
  bool _loading = true;
  bool _loadError = false;
  List<BusinessEntity> _entities = [];
  List<InvestmentAccount> _accounts = [];
  List<Liability> _liabilities = [];

  /// Entité affichée en plein écran (voir `EntityDetailScreen`) — `null`
  /// tant qu'on est sur la liste. Même principe "en local" que les autres
  /// écrans de détail de l'app (voir `real_category_detail_screen.dart`).
  BusinessEntity? _openEntity;

  @override
  void initState() {
    super.initState();
    _repo = EntityRepository(widget.vaultPath);
    _accountsRepo = InvestmentsRepository(widget.vaultPath);
    _liabilitiesRepo = LiabilitiesRepository(widget.vaultPath);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final entities = await _repo.listAll();
      final accounts = await _accountsRepo.listAll();
      final liabilities = await _liabilitiesRepo.listAll();
      if (!mounted) return;
      setState(() {
        _entities = entities;
        _accounts = accounts.where((a) => a.entityId != null).toList();
        _liabilities = liabilities.where((l) => l.entityId != null).toList();
        _loading = false;
        // L'entité ouverte a pu être supprimée/renommée pendant qu'on la
        // consultait (ex : modifiée depuis ailleurs) — resynchronise la
        // référence plutôt que de garder une copie figée.
        final openId = _openEntity?.id;
        _openEntity = openId == null
            ? null
            : entities.where((e) => e.id == openId).firstOrNull;
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
    final result = await showEntityEditorDialog(
      context,
      existing: existing,
      allEntities: _entities,
    );
    if (result == null) return;
    await _repo.saveEntity(result);
    await _load();
  }

  Future<void> _delete(BusinessEntity entity) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDelete(
      context,
      title: l10n.liabilities_delete_confirm_title(entity.name),
      message: l10n.entities_delete_confirm_message,
    );
    if (!confirmed) return;
    await _repo.deleteEntity(entity.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError) {
      return LoadErrorView(
        message: l10n.entities_load_error,
        onRetry: _load,
      );
    }

    final openEntity = _openEntity;
    if (openEntity != null) {
      return EntityDetailScreen(
        key: ValueKey(openEntity.id),
        vaultPath: widget.vaultPath,
        entity: openEntity,
        amountVisibility: widget.amountVisibility,
        patrimoineRefreshController: widget.patrimoineRefreshController,
        profileName: widget.profileName,
        onBack: () => setState(() => _openEntity = null),
      );
    }

    final effectivePercents = effectiveOwnershipPercents(_entities);
    final netValueByEntity = {
      for (final e in _entities)
        e.id: entityNetValue(e.id, _accounts, _liabilities),
    };
    final total = _entities.fold<double>(
      0,
      (sum, e) => sum + effectiveOwnedNetValue(
        e.id,
        netValueByEntity[e.id] ?? 0,
        effectivePercents,
      ),
    );
    // Indentation à plat seulement (pas d'arbre visuel profond) : voir la
    // doc de [orderedEntityHierarchy].
    final ordered = orderedEntityHierarchy(
      _entities,
      compareSiblings: (a, b) => (netValueByEntity[b.id] ?? 0).compareTo(
        netValueByEntity[a.id] ?? 0,
      ),
    );
    final entitiesById = {for (final e in _entities) e.id: e};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              shadcn.Text(l10n.nav_entities).x2Large().bold(),
              PrimaryButton(
                onPressed: () => _openEditor(),
                leading: const Icon(LucideIcons.plus),
                child: shadcn.Text(l10n.entities_add_button),
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
                    l10n.entities_total_net_value_label,
                  ).muted().small(),
                  const SizedBox(height: 4),
                  shadcn.Text(formatEuros(total)).x2Large().bold(),
                  const SizedBox(height: 4),
                  shadcn.Text(
                    l10n.entities_included_in_net_worth_hint,
                  ).muted().xSmall(),
                ],
              ),
            ),
          ),
          if (_entities.isNotEmpty) ...[
            const SizedBox(height: 24),
            FrostedCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shadcn.Text(l10n.entities_structure_title).medium(),
                    const SizedBox(height: 12),
                    EntityStructureDiagram(
                      entities: _entities,
                      selfLabel: l10n.entities_myself_label,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (ordered.isEmpty)
            shadcn.Text(l10n.entities_empty_list_hint).muted().small()
          else
            for (final (entity, depth) in ordered) ...[
              Padding(
                padding: EdgeInsets.only(left: depth * 24.0),
                child: _EntityCard(
                  entity: entity,
                  entitiesById: entitiesById,
                  netValue: netValueByEntity[entity.id] ?? 0,
                  effectivePercent: effectivePercents[entity.id] ?? 100,
                  onTap: () => setState(() => _openEntity = entity),
                  onEdit: () => _openEditor(existing: entity),
                  onDelete: () => _delete(entity),
                ),
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

  /// Toutes les entités du coffre-fort, par id — pour résoudre le nom du
  /// (ou des) propriétaire(s) de [entity] (voir `entityOwnershipSummary`).
  final Map<String, BusinessEntity> entitiesById;

  /// Valeur nette propre de l'entité (ses comptes moins ses passifs), avant
  /// pondération par [effectivePercent] — voir `entityNetValue` dans
  /// `entities_patrimoine_adapter.dart`.
  final double netValue;

  /// Part réellement détenue par l'utilisateur une fois toute la chaîne de
  /// liens de possession prise en compte (voir `effectiveOwnershipPercents`
  /// dans `entities_models.dart`) — n'affiche un second pourcentage que
  /// quand elle diffère du total des parts directement enregistrées (voir
  /// `entityOwnershipIsDiluted`).
  final double effectivePercent;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntityCard({
    required this.entity,
    required this.entitiesById,
    required this.netValue,
    required this.effectivePercent,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diluted = entityOwnershipIsDiluted(entity, effectivePercent);
    final ownershipLine =
        '${entity.type.label} · '
        '${entityOwnershipSummary(l10n, entity, entitiesById)}'
        '${diluted ? ' · ${l10n.entities_card_diluted_suffix(_formatPercent(effectivePercent))}' : ''}';
    return FrostedCard(
      // Distingue la carte de la liste du reste de l'écran, notamment du
      // schéma de structure (`EntityStructureDiagram`, non tapable) qui
      // reprend aussi le nom de l'entité — sans ça, `find.text(entity.name)`
      // devient ambigu dès qu'une entité existe (voir les tests).
      key: ValueKey('entity_list_card_${entity.id}'),
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
                    shadcn.Text(ownershipLine).muted().small(),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  shadcn.Text(
                    formatEuros(netValue * effectivePercent / 100),
                  ).large().semiBold(),
                  shadcn.Text(
                    l10n.entities_card_net_total(formatEuros(netValue)),
                  ).muted().xSmall(),
                ],
              ),
              const SizedBox(width: 8),
              IconButton.ghost(
                icon: const Icon(LucideIcons.pencil, size: 16),
                onPressed: onEdit,
              ),
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
/// retourne l'entité prête à être sauvegardée, ou `null` si annulé. Édite
/// seulement l'identité de l'entité (nom, type, % de détention, lien vers
/// un holding) — ses comptes/passifs se gèrent depuis `EntityDetailScreen`,
/// pas ici. [allEntities] (les autres entités déjà créées) peuple le
/// sélecteur "Détenue par" — [existing] elle-même et ses descendantes en
/// sont exclues pour ne jamais permettre de créer un cycle de possession.
Future<BusinessEntity?> showEntityEditorDialog(
  BuildContext context, {
  BusinessEntity? existing,
  required List<BusinessEntity> allEntities,
}) {
  return showDialog<BusinessEntity>(
    context: context,
    builder: (context) => _EntityEditorDialog(
      existing: existing,
      allEntities: allEntities,
    ),
  );
}

class _EntityEditorDialog extends StatefulWidget {
  final BusinessEntity? existing;
  final List<BusinessEntity> allEntities;
  const _EntityEditorDialog({this.existing, required this.allEntities});

  @override
  State<_EntityEditorDialog> createState() => _EntityEditorDialogState();
}

/// Un rang de la liste de parts éditée par [_EntityEditorDialogState] — pas
/// encore un [OwnershipStake] : le champ % reste un [TextEditingController]
/// tant que l'utilisateur tape, converti seulement à la sauvegarde (voir
/// [_EntityEditorDialogState._save]).
class _StakeFormRow {
  String? ownerId;
  final TextEditingController percentController;

  _StakeFormRow({this.ownerId, required String percentText})
    : percentController = TextEditingController(text: percentText);
}

/// Un rang éditable de la structure de détention : qui possède cette part
/// ("Moi-même" ou une autre entité) et à quel %. Une ligne "Ne comptez pas
/// la valeur..." apparaît sous chaque part indirecte (voir
/// `entities_dilution_note`) — répétée par ligne plutôt qu'une seule fois
/// pour l'ensemble, pour rester rattachée au propriétaire qu'elle concerne.
class _StakeRowFields extends StatelessWidget {
  final _StakeFormRow row;
  final List<BusinessEntity> eligibleParents;

  /// `null` masque le bouton de suppression — la dernière part restante ne
  /// peut pas être retirée (une entité doit toujours avoir au moins un
  /// propriétaire, voir `_EntityEditorDialogState.build`).
  final VoidCallback? onRemove;

  /// Redessine le dialogue au changement de propriétaire (l'indice de la
  /// note de dilution et le texte d'exemple du champ % en dépendent) — le
  /// `TextEditingController` du %, lui, n'a pas besoin de `setState` pour
  /// se redessiner.
  final VoidCallback onChanged;

  const _StakeRowFields({
    required this.row,
    required this.eligibleParents,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ownerName = row.ownerId == null
        ? null
        : eligibleParents.where((e) => e.id == row.ownerId).firstOrNull?.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Select<String>(
                value: row.ownerId ?? _noParentValue,
                onChanged: (v) {
                  row.ownerId = v == _noParentValue ? null : v;
                  onChanged();
                },
                itemBuilder: (context, v) => shadcn.Text(
                  v == _noParentValue
                      ? l10n.entities_owned_by_self
                      : eligibleParents
                                .where((e) => e.id == v)
                                .firstOrNull
                                ?.name ??
                            v,
                ),
                popup: (context) => SelectPopup(
                  items: SelectItemList(
                    children: [
                      SelectItemButton(
                        value: _noParentValue,
                        child: shadcn.Text(l10n.entities_owned_by_self),
                      ),
                      for (final parent in eligibleParents)
                        SelectItemButton(
                          value: parent.id,
                          child: shadcn.Text(parent.name),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: row.percentController,
                placeholder: shadcn.Text(
                  row.ownerId == null
                      ? l10n.entities_percent_direct_hint
                      : l10n.entities_percent_via_parent_hint(ownerName ?? ''),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              IconButton.ghost(
                icon: const Icon(LucideIcons.x, size: 14),
                onPressed: onRemove,
              ),
            ],
          ],
        ),
        if (row.ownerId != null) ...[
          const SizedBox(height: 4),
          shadcn.Text(
            l10n.entities_dilution_note(
              ownerName ?? l10n.entities_parent_company_fallback,
            ),
          ).muted().xSmall(),
        ],
      ],
    );
  }
}

class _EntityEditorDialogState extends State<_EntityEditorDialog> {
  late final TextEditingController _nameController;
  late EntityType _type;
  late List<_StakeFormRow> _stakeRows;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _type = existing?.type ?? EntityType.societeCommerciale;
    final stakes = existing?.stakes;
    _stakeRows = stakes != null && stakes.isNotEmpty
        ? [
            for (final stake in stakes)
              _StakeFormRow(
                ownerId: stake.ownerId,
                percentText: _formatPercent(stake.percent),
              ),
          ]
        // Nouvelle entité : une seule part par défaut, détenue directement
        // à 100 % — le cas de loin le plus courant, l'utilisateur ajoute
        // une détention mixte lui-même au besoin (voir [_addStakeRow]).
        : [_StakeFormRow(ownerId: null, percentText: '100')];
  }

  /// Entités éligibles comme propriétaire (n'importe quel rang de la liste
  /// de parts) : ni l'entité en cours d'édition elle-même, ni l'une de ses
  /// descendantes (sinon lien circulaire).
  List<BusinessEntity> get _eligibleParents {
    final existingId = widget.existing?.id;
    final excluded = existingId == null
        ? const <String>{}
        : {existingId, ...descendantEntityIds(existingId, widget.allEntities)};
    return widget.allEntities.where((e) => !excluded.contains(e.id)).toList();
  }

  void _addStakeRow() {
    setState(
      () => _stakeRows.add(_StakeFormRow(ownerId: null, percentText: '')),
    );
  }

  void _removeStakeRow(int index) {
    setState(() {
      _stakeRows.removeAt(index).percentController.dispose();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final row in _stakeRows) {
      row.percentController.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context).entities_name_required_error,
      );
      return;
    }
    final stakes = [
      for (final row in _stakeRows)
        OwnershipStake(
          ownerId: row.ownerId,
          percent: (parseDecimal(row.percentController.text) ?? 0).clamp(
            0,
            100,
          ),
        ),
    ];
    Navigator.of(context).pop(
      BusinessEntity(
        id: widget.existing?.id ?? generateEntityId(),
        name: name,
        type: _type,
        stakes: stakes,
      ),
    );
  }

  String _formatPercent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                    isEditing
                        ? l10n.entities_editor_edit_title
                        : l10n.entities_editor_new_title,
                  ).large().semiBold(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    placeholder: shadcn.Text(l10n.entities_name_hint),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  shadcn.Text(l10n.entities_type_label).muted().small(),
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
                  shadcn.Text(l10n.entities_owned_by_label).muted().small(),
                  const SizedBox(height: 6),
                  for (var i = 0; i < _stakeRows.length; i++) ...[
                    _StakeRowFields(
                      row: _stakeRows[i],
                      eligibleParents: _eligibleParents,
                      onRemove: _stakeRows.length > 1
                          ? () => _removeStakeRow(i)
                          : null,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlineButton(
                    onPressed: _addStakeRow,
                    leading: const Icon(LucideIcons.plus, size: 14),
                    child: shadcn.Text(l10n.entities_add_stake_button),
                  ),
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
                        child: shadcn.Text(l10n.common_save),
                      ),
                      const SizedBox(width: 8),
                      OutlineButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: shadcn.Text(l10n.common_cancel),
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

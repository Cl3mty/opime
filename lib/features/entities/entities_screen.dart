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

/// Valeur sentinelle du sélecteur "Détenue par" (`_EntityEditorDialog`) :
/// aucune entité parente, l'entité est détenue directement par
/// l'utilisateur (`BusinessEntity.parentEntityId` reste `null`) — distincte
/// de `null` lui-même, qu'un `Select<String>` ne peut pas porter comme
/// valeur sélectionnée (même motif que `complete_patrimoine_dialog.dart`'s
/// `_noCustomOtherCategoryValue`).
const _noParentValue = '__none__';

/// Écran "Entités" (holdings, sociétés commerciales, SCI, comptes pro) —
/// atteint uniquement en cliquant la catégorie "Entités professionnelles"
/// du Dashboard (voir `entities_patrimoine_adapter.dart`, réservée à un
/// coffre-fort professionnel), pas de nav dédiée. Chaque entité est une
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
    // Hiérarchie à plat : chaque entité de tête (sans parent) suivie
    // immédiatement de toutes ses descendantes (indentées) — pas d'arbre
    // visuel profond, juste assez pour rendre les liens holding/filiale
    // lisibles sans complexifier l'écran.
    final byParent = <String?, List<BusinessEntity>>{};
    for (final entity in _entities) {
      (byParent[entity.parentEntityId] ??= []).add(entity);
    }
    for (final group in byParent.values) {
      group.sort(
        (a, b) => (netValueByEntity[b.id] ?? 0).compareTo(
          netValueByEntity[a.id] ?? 0,
        ),
      );
    }
    final ordered = <(BusinessEntity, int)>[];
    void addWithChildren(BusinessEntity entity, int depth) {
      ordered.add((entity, depth));
      for (final child in byParent[entity.id] ?? const <BusinessEntity>[]) {
        addWithChildren(child, depth + 1);
      }
    }

    for (final root in byParent[null] ?? const <BusinessEntity>[]) {
      addWithChildren(root, 0);
    }

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
          const SizedBox(height: 24),
          if (ordered.isEmpty)
            shadcn.Text(l10n.entities_empty_list_hint).muted().small()
          else
            for (final (entity, depth) in ordered) ...[
              Padding(
                padding: EdgeInsets.only(left: depth * 24.0),
                child: _EntityCard(
                  entity: entity,
                  netValue: netValueByEntity[entity.id] ?? 0,
                  parentName: entity.parentEntityId == null
                      ? null
                      : _entities
                            .where((e) => e.id == entity.parentEntityId)
                            .firstOrNull
                            ?.name,
                  effectivePercent:
                      effectivePercents[entity.id] ?? entity.ownershipPercent,
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

  /// Valeur nette propre de l'entité (ses comptes moins ses passifs), avant
  /// pondération par [effectivePercent] — voir `entityNetValue` dans
  /// `entities_patrimoine_adapter.dart`.
  final double netValue;

  /// Nom de l'entité parente si [entity] lui est liée (`null` sinon —
  /// entité détenue directement par l'utilisateur).
  final String? parentName;

  /// Part réellement détenue par l'utilisateur une fois toute la chaîne de
  /// liens de possession prise en compte (voir `effectiveOwnershipPercents`
  /// dans `entities_models.dart`) — n'affiche un second pourcentage que
  /// quand il diffère du % local (lien direct).
  final double effectivePercent;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntityCard({
    required this.entity,
    required this.netValue,
    required this.parentName,
    required this.effectivePercent,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diluted = (effectivePercent - entity.ownershipPercent).abs() > 0.01;
    final ownershipLine = parentName == null
        ? l10n.entities_card_ownership_direct(
            entity.type.label,
            _formatPercent(entity.ownershipPercent),
          )
        : l10n.entities_card_ownership_via_parent(
                entity.type.label,
                _formatPercent(entity.ownershipPercent),
                parentName!,
              ) +
              (diluted
                  ? ' · '
                        '${l10n.entities_card_diluted_suffix(_formatPercent(effectivePercent))}'
                  : '');
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

class _EntityEditorDialogState extends State<_EntityEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _percentController;
  late EntityType _type;
  late String? _parentEntityId;
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
    _parentEntityId = existing?.parentEntityId;
  }

  /// Entités éligibles comme parent : ni l'entité en cours d'édition
  /// elle-même, ni l'une de ses descendantes (sinon lien circulaire).
  List<BusinessEntity> get _eligibleParents {
    final existingId = widget.existing?.id;
    final excluded = existingId == null
        ? const <String>{}
        : {existingId, ...descendantEntityIds(existingId, widget.allEntities)};
    return widget.allEntities.where((e) => !excluded.contains(e.id)).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _percentController.dispose();
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
    final percent = parseDecimal(_percentController.text) ?? 100;
    Navigator.of(context).pop(
      BusinessEntity(
        id: widget.existing?.id ?? generateEntityId(),
        name: name,
        type: _type,
        ownershipPercent: percent.clamp(0, 100),
        parentEntityId: _parentEntityId,
      ),
    );
  }

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
                  Select<String>(
                    value: _parentEntityId ?? _noParentValue,
                    onChanged: (v) => setState(
                      () => _parentEntityId = v == _noParentValue ? null : v,
                    ),
                    itemBuilder: (context, v) => shadcn.Text(
                      v == _noParentValue
                          ? l10n.entities_owned_by_self
                          : _eligibleParents
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
                          for (final parent in _eligibleParents)
                            SelectItemButton(
                              value: parent.id,
                              child: shadcn.Text(parent.name),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _percentController,
                    placeholder: shadcn.Text(
                      _parentEntityId == null
                          ? l10n.entities_percent_direct_hint
                          : l10n.entities_percent_via_parent_hint(
                              _eligibleParents
                                      .where((e) => e.id == _parentEntityId)
                                      .firstOrNull
                                      ?.name ??
                                  '',
                            ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  if (_parentEntityId != null) ...[
                    const SizedBox(height: 6),
                    shadcn.Text(
                      l10n.entities_dilution_note(
                        _eligibleParents
                                .where((e) => e.id == _parentEntityId)
                                .firstOrNull
                                ?.name ??
                            l10n.entities_parent_company_fallback,
                      ),
                    ).muted().xSmall(),
                  ],
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

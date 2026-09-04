import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../../core/money_format.dart';
import '../../../core/ui/frosted_card.dart';
import '../../../core/ui/opime_date_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../confirm_delete_dialog.dart';
import 'rent_models.dart';

/// Suggestions de catégorie proposées à la saisie (voir [WorkItem.category])
/// — un simple raccourci qui remplit le champ, pas une liste fermée : le
/// champ reste un texte libre pour ne pas bloquer sur un poste imprévu.
/// Traduites (contrairement à `kRealEstateDocumentCategories`) : rien ne
/// compare cette valeur ailleurs dans le code, cliquer une suggestion se
/// contente d'insérer son texte tel quel dans le champ libre.
List<String> workItemCategorySuggestions(AppLocalizations l10n) => [
  l10n.real_estate_work_category_structural,
  l10n.real_estate_work_category_plumbing,
  l10n.real_estate_work_category_electrical,
  l10n.real_estate_work_category_paint,
  l10n.real_estate_work_category_furniture,
  l10n.real_estate_work_category_other,
];

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Section "Travaux" d'un bien immobilier — postes de rénovation/entretien
/// (voir [WorkItem]), plus récents en premier, avec le montant total en
/// tête (alimente le coût total du projet utilisé par la rentabilité).
class WorkItemsSection extends StatelessWidget {
  final List<WorkItem> workItems;
  final Future<void> Function(WorkItem item) onAdd;
  final Future<void> Function(WorkItem item) onDelete;

  const WorkItemsSection({
    super.key,
    required this.workItems,
    required this.onAdd,
    required this.onDelete,
  });

  List<WorkItem> get _sorted =>
      [...workItems]..sort((a, b) => b.date.compareTo(a.date));

  double get _total => workItems.fold(0.0, (sum, w) => sum + w.amount);

  Future<void> _openAddDialog(BuildContext context) async {
    final item = await showDialog<WorkItem>(
      context: context,
      builder: (context) => const _AddWorkItemDialog(),
    );
    if (item != null) await onAdd(item);
  }

  Future<void> _confirmAndDelete(BuildContext context, WorkItem item) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDelete(
      context,
      title: l10n.real_estate_delete_work_item_title(item.label),
      message: l10n.real_estate_delete_work_item_message,
    );
    if (!confirmed) return;
    await onDelete(item);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sorted = _sorted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            shadcn.Text(l10n.real_estate_work_items_title).large().medium(),
            const Spacer(),
            Builder(
              builder: (context) => GestureDetector(
                onTap: () => _openAddDialog(context),
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
                      l10n.real_estate_add_work_item_button,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (workItems.isNotEmpty) ...[
          const SizedBox(height: 4),
          shadcn.Text(
            l10n.real_estate_work_items_total_label(
              displayEuros(_total, false),
            ),
          ).muted().small(),
        ],
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          shadcn.Text(l10n.real_estate_no_work_items_yet).muted().small()
        else
          for (final item in sorted) ...[
            _WorkItemRow(
              item: item,
              onDelete: () => _confirmAndDelete(context, item),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _WorkItemRow extends StatelessWidget {
  final WorkItem item;
  final VoidCallback onDelete;

  const _WorkItemRow({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      shadcn.Text(item.label).small(),
                      if (item.category != null) ...[
                        const SizedBox(width: 6),
                        OutlineBadge(
                          child: shadcn.Text(item.category!).xSmall(),
                        ),
                      ],
                    ],
                  ),
                  if (item.note != null)
                    shadcn.Text(item.note!).muted().xSmall(),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                shadcn.Text(displayEuros(item.amount, false)).small(),
                shadcn.Text(_formatDate(item.date)).muted().xSmall(),
              ],
            ),
            IconButton.ghost(
              icon: const Icon(LucideIcons.trash2, size: 14),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWorkItemDialog extends StatefulWidget {
  const _AddWorkItemDialog();

  @override
  State<_AddWorkItemDialog> createState() => _AddWorkItemDialogState();
}

class _AddWorkItemDialogState extends State<_AddWorkItemDialog> {
  final _labelController = TextEditingController();
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _date = DateTime.now();

  @override
  void dispose() {
    _labelController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _commit() {
    final label = _labelController.text.trim();
    final amount = parseDecimal(_amountController.text);
    final date = _date;
    if (label.isEmpty || amount == null || amount <= 0 || date == null) {
      return;
    }
    Navigator.of(context).pop(
      WorkItem(
        label: label,
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        amount: amount,
        date: date,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(l10n.real_estate_add_work_item_title)
                    .large()
                    .semiBold(),
                const SizedBox(height: 12),
                shadcn.Text(l10n.real_estate_work_item_label_field)
                    .muted()
                    .xSmall(),
                const SizedBox(height: 4),
                TextField(
                  controller: _labelController,
                  placeholder: shadcn.Text(
                    l10n.real_estate_work_item_label_hint,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                shadcn.Text(
                  l10n.real_estate_work_item_category_optional_label,
                ).muted().xSmall(),
                const SizedBox(height: 4),
                TextField(controller: _categoryController),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final suggestion in workItemCategorySuggestions(l10n))
                      GestureDetector(
                        onTap: () => setState(
                          () => _categoryController.text = suggestion,
                        ),
                        child: OutlineBadge(
                          child: shadcn.Text(suggestion).xSmall(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                shadcn.Text(l10n.real_estate_work_item_amount_label)
                    .muted()
                    .xSmall(),
                const SizedBox(height: 4),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                shadcn.Text(l10n.common_date).muted().xSmall(),
                const SizedBox(height: 4),
                OpimeDatePicker(
                  value: _date,
                  onChanged: (date) => setState(() => _date = date),
                ),
                const SizedBox(height: 12),
                shadcn.Text(
                  l10n.real_estate_note_optional_label,
                ).muted().xSmall(),
                const SizedBox(height: 4),
                TextField(controller: _noteController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    PrimaryButton(
                      onPressed: _commit,
                      child: shadcn.Text(l10n.common_add),
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
    );
  }
}

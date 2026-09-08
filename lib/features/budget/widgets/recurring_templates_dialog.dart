import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/ui/frosted_card.dart';
import '../../../l10n/app_localizations.dart';
import '../budget_recurring_templates_models.dart';
import '../budget_recurring_templates_repository.dart';
import '../budget_tracking_models.dart';

/// Gestion des lignes récurrentes d'une section du suivi de budget (ex :
/// "FACTURES") — liste les templates déjà enregistrés (suppression par
/// ligne), permet d'en ajouter un nouveau (nom + montant), et applique le
/// tout au mois actuellement affiché via [onApply] en une fois
/// ("Appliquer maintenant"). Ouvert en `showDialog` **direct** depuis
/// l'écran (jamais imbriqué dans une autre popup déjà ouverte) — le popup
/// `showDropdown`/`Select` de shadcn_flutter échoue ("No DrawerOverlay
/// found") quand il est niché dans une popup existante, une limitation déjà
/// rencontrée ailleurs dans l'app ; cette boîte de dialogue reste donc
/// volontairement un simple `showDialog` de premier niveau, sans dropdown
/// imbriqué.
Future<void> showRecurringTemplatesDialog(
  BuildContext context, {
  required String vaultPath,
  required BudgetSection section,
  required String sectionTitle,
  required List<TrackingItem> currentItems,
  required String idPrefix,
  required ValueChanged<List<TrackingItem>> onApply,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _RecurringTemplatesDialog(
      vaultPath: vaultPath,
      section: section,
      sectionTitle: sectionTitle,
      currentItems: currentItems,
      idPrefix: idPrefix,
      onApply: onApply,
    ),
  );
}

class _RecurringTemplatesDialog extends StatefulWidget {
  final String vaultPath;
  final BudgetSection section;
  final String sectionTitle;
  final List<TrackingItem> currentItems;
  final String idPrefix;
  final ValueChanged<List<TrackingItem>> onApply;

  const _RecurringTemplatesDialog({
    required this.vaultPath,
    required this.section,
    required this.sectionTitle,
    required this.currentItems,
    required this.idPrefix,
    required this.onApply,
  });

  @override
  State<_RecurringTemplatesDialog> createState() =>
      _RecurringTemplatesDialogState();
}

class _RecurringTemplatesDialogState extends State<_RecurringTemplatesDialog> {
  late final BudgetRecurringTemplatesRepository _repo =
      BudgetRecurringTemplatesRepository(widget.vaultPath);
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  List<RecurringTemplate> _templates = [];
  bool _loading = true;

  /// Numéro d'appel de [_load] le plus récent — un appel plus ancien (ex :
  /// celui d'[initState], jamais attendu) peut résoudre APRÈS un appel plus
  /// récent (déclenché par [_add]/[_remove]) et écraserait sinon son
  /// résultat avec des données périmées. Seul le résultat du dernier appel
  /// en date est appliqué à l'état.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final all = await _repo.load();
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _templates = all.where((t) => t.section == widget.section).toList();
      _loading = false;
    });
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (name.isEmpty || amount == null) return;
    await _repo.add(
      RecurringTemplate(name: name, amount: amount, section: widget.section),
    );
    _nameController.clear();
    _amountController.clear();
    await _load();
  }

  Future<void> _remove(String id) async {
    await _repo.remove(id);
    await _load();
  }

  void _applyNow() {
    final existingNames = widget.currentItems
        .map((i) => i.name.trim().toLowerCase())
        .toSet();
    final toAdd = _templates.where(
      (t) => !existingNames.contains(t.name.trim().toLowerCase()),
    );
    widget.onApply([
      ...widget.currentItems,
      for (final t in toAdd)
        TrackingItem(
          id: generateTrackingItemId(widget.idPrefix),
          name: t.name,
          budget: t.amount,
          realite: 0,
          category: t.category,
        ),
    ]);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(
                  l10n.budget_recurring_templates_dialog_title(
                    widget.sectionTitle,
                  ),
                ).semiBold(),
                const SizedBox(height: 4),
                shadcn.Text(
                  l10n.budget_recurring_templates_dialog_subtitle,
                ).muted().small(),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_templates.isEmpty)
                  shadcn.Text(l10n.budget_recurring_templates_empty).muted()
                else
                  for (final template in _templates)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: shadcn.Text(template.name)),
                          shadcn.Text(
                            '${template.amount.toStringAsFixed(2)} €',
                          ).muted(),
                          IconButton.ghost(
                            icon: const Icon(LucideIcons.trash2, size: 14),
                            onPressed: () => _remove(template.id),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        placeholder: shadcn.Text(l10n.common_name),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _amountController,
                        placeholder: shadcn.Text(
                          l10n.budget_amount_placeholder,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.ghost(
                      icon: const Icon(LucideIcons.plus, size: 16),
                      onPressed: _add,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    PrimaryButton(
                      onPressed: _templates.isEmpty ? null : _applyNow,
                      child: shadcn.Text(
                        l10n.budget_recurring_templates_apply_now,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlineButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: shadcn.Text(l10n.common_close),
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

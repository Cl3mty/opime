import 'dart:typed_data';

import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../../core/money_format.dart';
import '../../../core/ui/frosted_card.dart';
import '../../../core/ui/opime_date_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../confirm_delete_dialog.dart';
import 'quittance_pdf_builder.dart';
import 'rent_models.dart';

// Reste en français : mécanisme de formatage de date (même famille que
// `frenchMonths` dans `core/date_format.dart`), hors périmètre de la
// traduction de texte d'UI — voir le rapport de traduction pour le détail.
const _monthLabels = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

String _monthYearLabel(DateTime date) => '${_monthLabels[date.month - 1]} '
    '${date.year}';

DateTime _lastDayOfMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0);

/// Section "Loyers" d'un bien immobilier loué — historique des périodes
/// (voir [RentPeriod]), plus récentes en premier. Marquer une période payée
/// ouvre une petite confirmation (montant réellement perçu, date de
/// paiement) plutôt qu'un simple booléen : un paiement partiel ou tardif
/// reste courant.
class RentPeriodsSection extends StatelessWidget {
  final List<RentPeriod> rentPeriods;
  final Future<void> Function(RentPeriod period) onAdd;
  final Future<void> Function(RentPeriod period) onUpdate;
  final Future<void> Function(RentPeriod period) onDelete;

  final String propertyLabel;
  final String? propertyAddress;
  final String landlordName;

  /// Reçoit les octets déjà générés (voir [buildQuittancePdfBytes]) —
  /// charge à l'appelant de proposer l'enregistrement (`FilePicker
  /// .saveFile`) et de l'ajouter aux documents du bien (catégorie
  /// "Quittance"), qui nécessitent tous deux un accès dont cette section
  /// ne dispose pas (`BuildContext` d'enregistrement de fichier,
  /// persistance sur le compte) — voir `InvestmentDetailView
  /// ._downloadQuittance`.
  final Future<void> Function(RentPeriod period, Uint8List pdfBytes)
  onDownloadQuittance;

  const RentPeriodsSection({
    super.key,
    required this.rentPeriods,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.propertyLabel,
    this.propertyAddress,
    required this.landlordName,
    required this.onDownloadQuittance,
  });

  List<RentPeriod> get _sorted =>
      [...rentPeriods]..sort((a, b) => b.periodStart.compareTo(a.periodStart));

  Future<void> _openAddDialog(BuildContext context) async {
    final period = await showDialog<RentPeriod>(
      context: context,
      builder: (context) => const _AddRentPeriodDialog(),
    );
    if (period != null) await onAdd(period);
  }

  Future<void> _togglePaid(BuildContext context, RentPeriod period) async {
    if (period.isPaid) {
      await onUpdate(period.copyWith(amountPaid: null, paidAt: null));
      return;
    }
    final result = await showDialog<({double amountPaid, DateTime paidAt})>(
      context: context,
      builder: (context) => _MarkPaidDialog(period: period),
    );
    if (result == null) return;
    await onUpdate(
      period.copyWith(amountPaid: result.amountPaid, paidAt: result.paidAt),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, RentPeriod period) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDelete(
      context,
      title: l10n.real_estate_delete_rent_period_title,
      message: l10n.real_estate_delete_rent_period_message(
        _monthYearLabel(period.periodStart),
      ),
    );
    if (!confirmed) return;
    await onDelete(period);
  }

  Future<void> _downloadQuittance(RentPeriod period) async {
    final bytes = await buildQuittancePdfBytes(
      period: period,
      propertyLabel: propertyLabel,
      propertyAddress: propertyAddress,
      landlordName: landlordName,
      generatedAt: DateTime.now(),
    );
    await onDownloadQuittance(period, bytes);
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
            shadcn.Text(l10n.real_estate_rent_periods_title).large().medium(),
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
                      l10n.real_estate_add_rent_period_button,
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
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          shadcn.Text(l10n.real_estate_no_rent_periods_yet).muted().small()
        else
          for (final period in sorted) ...[
            _RentPeriodRow(
              period: period,
              onTogglePaid: () => _togglePaid(context, period),
              onDelete: () => _confirmAndDelete(context, period),
              onDownloadQuittance: () => _downloadQuittance(period),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _RentPeriodRow extends StatelessWidget {
  final RentPeriod period;
  final VoidCallback onTogglePaid;
  final VoidCallback onDelete;
  final VoidCallback onDownloadQuittance;

  const _RentPeriodRow({
    required this.period,
    required this.onTogglePaid,
    required this.onDelete,
    required this.onDownloadQuittance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                  shadcn.Text(_monthYearLabel(period.periodStart)).small(),
                  if (period.tenantName != null)
                    shadcn.Text(period.tenantName!).muted().xSmall(),
                  if (period.note != null)
                    shadcn.Text(period.note!).muted().xSmall(),
                ],
              ),
            ),
            shadcn.Text(displayEuros(period.amountDue, false)).small(),
            const SizedBox(width: 12),
            OutlineButton(
              onPressed: onTogglePaid,
              size: ButtonSize.small,
              leading: Icon(
                period.isPaid ? LucideIcons.checkCheck : LucideIcons.clock,
                size: 14,
                color: period.isPaid
                    ? const Color(0xFF22C55E)
                    : theme.colorScheme.mutedForeground,
              ),
              child: shadcn.Text(
                period.isPaid
                    ? l10n.real_estate_rent_paid
                    : l10n.real_estate_rent_unpaid,
              ).xSmall(),
            ),
            // Une quittance n'a de sens qu'une fois le paiement réellement
            // reçu (voir `RentPeriod.isPaid`) — pas de bouton pour une
            // période encore impayée.
            if (period.isPaid)
              IconButton.ghost(
                icon: const Icon(LucideIcons.fileDown, size: 14),
                onPressed: onDownloadQuittance,
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

class _AddRentPeriodDialog extends StatefulWidget {
  const _AddRentPeriodDialog();

  @override
  State<_AddRentPeriodDialog> createState() => _AddRentPeriodDialogState();
}

class _AddRentPeriodDialogState extends State<_AddRentPeriodDialog> {
  DateTime? _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _amountController = TextEditingController();
  final _tenantController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _tenantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _commit() {
    final month = _month;
    final amount = parseDecimal(_amountController.text);
    if (month == null || amount == null || amount <= 0) return;
    Navigator.of(context).pop(
      RentPeriod(
        periodStart: DateTime(month.year, month.month, 1),
        periodEnd: _lastDayOfMonth(month),
        amountDue: amount,
        tenantName: _tenantController.text.trim().isEmpty
            ? null
            : _tenantController.text.trim(),
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
                shadcn.Text(
                  l10n.real_estate_add_rent_period_button,
                ).large().semiBold(),
                const SizedBox(height: 12),
                shadcn.Text(l10n.real_estate_month_label).muted().xSmall(),
                const SizedBox(height: 4),
                OpimeDatePicker(
                  value: _month,
                  onChanged: (date) => setState(() => _month = date),
                ),
                const SizedBox(height: 12),
                shadcn.Text(l10n.real_estate_amount_due_label).muted().xSmall(),
                const SizedBox(height: 4),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                shadcn.Text(
                  l10n.real_estate_tenant_optional_label,
                ).muted().xSmall(),
                const SizedBox(height: 4),
                TextField(controller: _tenantController),
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

class _MarkPaidDialog extends StatefulWidget {
  final RentPeriod period;

  const _MarkPaidDialog({required this.period});

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  late final _amountController = TextEditingController(
    text: _formatNumber(widget.period.amountDue),
  );
  DateTime? _paidAt = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  static String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  void _commit() {
    final amount = parseDecimal(_amountController.text);
    final paidAt = _paidAt;
    if (amount == null || amount <= 0 || paidAt == null) return;
    Navigator.of(context).pop((amountPaid: amount, paidAt: paidAt));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(
                  l10n.real_estate_mark_period_paid_title(
                    _monthYearLabel(widget.period.periodStart),
                  ),
                ).large().semiBold(),
                const SizedBox(height: 12),
                shadcn.Text(
                  l10n.real_estate_amount_received_label,
                ).muted().xSmall(),
                const SizedBox(height: 4),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                shadcn.Text(l10n.real_estate_payment_date_label).muted().xSmall(),
                const SizedBox(height: 4),
                OpimeDatePicker(
                  value: _paidAt,
                  onChanged: (date) => setState(() => _paidAt = date),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    PrimaryButton(
                      onPressed: _commit,
                      child: shadcn.Text(l10n.common_confirm),
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

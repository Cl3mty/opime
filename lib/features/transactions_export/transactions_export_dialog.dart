import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/ui/frosted_card.dart';
import '../../core/ui/toggle_button_style.dart';
import '../../l10n/app_localizations.dart';
import '../investments/investments_models.dart';
import '../investments/investments_repository.dart';
import 'transactions_export_csv.dart';
import 'transactions_export_data.dart';
import 'transactions_export_json.dart';

enum _ExportFormat { csv, json }

/// Ouvre le dialogue de sélection des comptes à inclure dans l'export des
/// transactions, puis, si l'utilisateur confirme, génère le fichier
/// (JSON ou CSV) et propose son enregistrement via `file_picker`. Même
/// convention d'appel/de séquence que `showPatrimoineExportDialog`.
Future<void> showTransactionsExportDialog(
  BuildContext context, {
  required String vaultPath,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TransactionsExportDialog(vaultPath: vaultPath),
  );
}

class _TransactionsExportDialog extends StatefulWidget {
  final String vaultPath;

  const _TransactionsExportDialog({required this.vaultPath});

  @override
  State<_TransactionsExportDialog> createState() =>
      _TransactionsExportDialogState();
}

class _TransactionsExportDialogState
    extends State<_TransactionsExportDialog> {
  bool _loading = true;
  bool _generating = false;

  // Granularité compte, pas investissement : une transaction isolée n'a pas
  // vraiment de sens à sélectionner seule pour cet export (contrairement au
  // patrimoine, où une ligne = un montant qu'on veut ou non montrer dans un
  // rapport ponctuel) — voir la doc de tête du dossier.
  List<InvestmentAccount> _accounts = const [];
  final Set<String> _selectedAccountIds = {};
  _ExportFormat _format = _ExportFormat.csv;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await InvestmentsRepository(widget.vaultPath).listAll();
    // Un compte sans aucune transaction n'a rien à exporter — pas la peine
    // de l'afficher dans la sélection (contrairement à l'export patrimoine,
    // où un compte vide reste une ligne "0 €" légitime à inclure).
    final withTransactions = [
      for (final account in all)
        if (account.investments.any((i) => i.transactions.isNotEmpty))
          account,
    ];
    if (!mounted) return;
    setState(() {
      _accounts = withTransactions;
      _selectedAccountIds
        ..clear()
        ..addAll(withTransactions.map((a) => a.id));
      _loading = false;
    });
  }

  int _transactionCount(InvestmentAccount account) => account.investments
      .fold(0, (sum, i) => sum + i.transactions.length);

  void _setSelected(String accountId, bool selected) {
    setState(() {
      if (selected) {
        _selectedAccountIds.add(accountId);
      } else {
        _selectedAccountIds.remove(accountId);
      }
    });
  }

  void _selectAll(bool selected) {
    setState(() {
      if (selected) {
        _selectedAccountIds
          ..clear()
          ..addAll(_accounts.map((a) => a.id));
      } else {
        _selectedAccountIds.clear();
      }
    });
  }

  bool get _hasSelection => _selectedAccountIds.isNotEmpty;

  Future<void> _generate() async {
    setState(() => _generating = true);
    final l10n = AppLocalizations.of(context);
    try {
      final rows = buildTransactionExportRows(
        _accounts,
        selectedAccountIds: _selectedAccountIds,
      );
      final isJson = _format == _ExportFormat.json;
      final content = isJson
          ? buildTransactionsExportJson(rows)
          : buildTransactionsExportCsv(rows);
      final bytes = Uint8List.fromList(utf8.encode(content));
      final now = DateTime.now();
      final ext = isJson ? 'json' : 'csv';
      final fileName =
          'transactions-${now.year}${_pad2(now.month)}${_pad2(now.day)}'
          '.$ext';
      final savePath = await FilePicker.saveFile(
        dialogTitle: l10n.transactions_export_save_dialog_title,
        fileName: fileName,
        bytes: bytes,
      );
      if (savePath == null) {
        if (mounted) setState(() => _generating = false);
        return;
      }
      final path = savePath.toLowerCase().endsWith('.$ext')
          ? savePath
          : '$savePath.$ext';
      await File(path).writeAsBytes(bytes);
      if (!mounted) return;
      _showToast(
        title: l10n.transactions_export_success_title,
        subtitle: l10n.transactions_export_success_subtitle(path),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      _showToast(
        title: l10n.transactions_export_failed_title,
        subtitle: l10n.transactions_export_failed_subtitle(e.toString()),
      );
    }
  }

  void _showToast({required String title, required String subtitle}) {
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: shadcn.Text(title),
          subtitle: shadcn.Text(subtitle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _loading
                ? const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildFormatToggle(),
        const SizedBox(height: 12),
        if (_accounts.isEmpty)
          shadcn.Text(AppLocalizations.of(context).transactions_export_empty)
              .muted()
              .small()
        else
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final a in _accounts) _buildAccountRow(a)],
              ),
            ),
          ),
        const SizedBox(height: 16),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              shadcn.Text(l10n.transactions_export_title).large().semiBold(),
              shadcn.Text(l10n.transactions_export_subtitle).muted().small(),
            ],
          ),
        ),
        IconButton.ghost(
          icon: const Icon(LucideIcons.x, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildFormatToggle() {
    return ButtonGroup(
      children: [
        SelectedButton(
          value: _format == _ExportFormat.csv,
          selectedStyle: const ButtonStyle.primary(),
          style: toggleUnselectedStyle(context),
          onChanged: (_) => setState(() => _format = _ExportFormat.csv),
          child: const shadcn.Text('CSV'),
        ),
        SelectedButton(
          value: _format == _ExportFormat.json,
          selectedStyle: const ButtonStyle.primary(),
          style: toggleUnselectedStyle(context),
          onChanged: (_) => setState(() => _format = _ExportFormat.json),
          child: const shadcn.Text('JSON'),
        ),
      ],
    );
  }

  Widget _buildAccountRow(InvestmentAccount account) {
    final count = _transactionCount(account);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                shadcn.Text(account.name).small(),
                if (account.bankName != null)
                  shadcn.Text(account.bankName!).muted().xSmall(),
              ],
            ),
          ),
          shadcn.Text(
            AppLocalizations.of(context).transactions_export_transaction_count(count),
          ).muted().xSmall(),
          const SizedBox(width: 8),
          Checkbox(
            state: _selectedAccountIds.contains(account.id)
                ? CheckboxState.checked
                : CheckboxState.unchecked,
            onChanged: (s) =>
                _setSelected(account.id, s == CheckboxState.checked),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        TextButton(
          onPressed: () => _selectAll(true),
          child: shadcn.Text(l10n.transactions_export_select_all),
        ),
        TextButton(
          onPressed: () => _selectAll(false),
          child: shadcn.Text(l10n.transactions_export_deselect_all),
        ),
        const Spacer(),
        PrimaryButton(
          onPressed: _hasSelection && !_generating ? _generate : null,
          leading: _generating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.arrowDownToLine),
          child: shadcn.Text(l10n.navigation_export_tooltip),
        ),
      ],
    );
  }
}

String _pad2(int value) => value.toString().padLeft(2, '0');

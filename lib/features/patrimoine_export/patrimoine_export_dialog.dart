import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import '../../l10n/app_localizations.dart';
import '../dashboard/patrimoine_models.dart';
import '../investments/investments_repository.dart';
import '../investments/real_patrimoine_adapter.dart'
    show buildAllRealCategoriesByAccount;
import '../liabilities/liabilities_models.dart';
import '../liabilities/liabilities_repository.dart';
import 'patrimoine_export_data.dart';
import 'patrimoine_pdf_builder.dart';

/// Ouvre le dialogue de sélection "tout ou partie de mon patrimoine", puis,
/// si l'utilisateur confirme, génère le PDF et propose son enregistrement
/// via `file_picker`. Même convention d'appel que
/// `showCompletePatrimoineDialog`.
Future<void> showPatrimoineExportDialog(
  BuildContext context, {
  required String vaultPath,
  required String profileName,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _PatrimoineExportDialog(
      vaultPath: vaultPath,
      profileName: profileName,
    ),
  );
}

class _PatrimoineExportDialog extends StatefulWidget {
  final String vaultPath;
  final String profileName;

  const _PatrimoineExportDialog({
    required this.vaultPath,
    required this.profileName,
  });

  @override
  State<_PatrimoineExportDialog> createState() =>
      _PatrimoineExportDialogState();
}

class _PatrimoineExportDialogState extends State<_PatrimoineExportDialog> {
  bool _loading = true;
  bool _generating = false;

  List<PatrimoineCategory> _categories = const [];
  List<Liability> _liabilities = const [];

  final Set<String> _selectedAssetKeys = {};
  final Set<String> _selectedLiabilityIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Un compte/passif rattaché à une entité professionnelle (`entityId`
    // non nul) est hors du patrimoine personnel exporté ici — même filtre
    // que `dashboard_screen.dart`/`analyses_data_loader.dart`.
    final accounts = (await InvestmentsRepository(widget.vaultPath).listAll())
        .where((a) => a.entityId == null)
        .toList();
    final liabilities =
        (await LiabilitiesRepository(widget.vaultPath).listAll())
            .where((l) => l.entityId == null)
            .toList();
    // Prix historiques jamais utilisés par cet arbre "par compte" (voir
    // `real_patrimoine_adapter.dart` : `_buildAccountLeaf`/`_buildLeaf` ne
    // s'appuient que sur `Investment.marketValue`/`lastPrice`) — la carte
    // vide évite une lecture disque inutile pour un export instantané.
    final categories =
        buildAllRealCategoriesByAccount(accounts, const {}, widget.vaultPath)
            .where((c) => c.accounts.isNotEmpty)
            .toList();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _liabilities = liabilities;
      _selectedAssetKeys
        ..clear()
        ..addAll(_allAssetKeys(categories));
      _selectedLiabilityIds
        ..clear()
        ..addAll(liabilities.map((l) => l.id));
      _loading = false;
    });
  }

  static Iterable<String> _accountKeys(PatrimoineAccount account) {
    if (account.investments.isEmpty) return [exportAssetKey(account.id!)];
    return [
      for (final investment in account.investments)
        exportAssetKey(account.id!, investment.id!),
    ];
  }

  static Iterable<String> _categoryKeys(PatrimoineCategory category) => [
    for (final account in category.accounts) ..._accountKeys(account),
  ];

  static Iterable<String> _allAssetKeys(List<PatrimoineCategory> categories) => [
    for (final category in categories) ..._categoryKeys(category),
  ];

  CheckboxState _stateFor(Iterable<String> keys) {
    final total = keys.length;
    if (total == 0) return CheckboxState.unchecked;
    final selectedCount = keys.where(_selectedAssetKeys.contains).length;
    if (selectedCount == 0) return CheckboxState.unchecked;
    if (selectedCount == total) return CheckboxState.checked;
    return CheckboxState.indeterminate;
  }

  void _setKeys(Iterable<String> keys, bool selected) {
    setState(() {
      if (selected) {
        _selectedAssetKeys.addAll(keys);
      } else {
        _selectedAssetKeys.removeAll(keys);
      }
    });
  }

  void _selectAllAssets(bool selected) =>
      _setKeys(_allAssetKeys(_categories), selected);

  void _selectAllLiabilities(bool selected) {
    setState(() {
      if (selected) {
        _selectedLiabilityIds.addAll(_liabilities.map((l) => l.id));
      } else {
        _selectedLiabilityIds.clear();
      }
    });
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    final l10n = AppLocalizations.of(context);
    try {
      final data = buildPatrimoineExportData(
        profileName: widget.profileName,
        generatedAt: DateTime.now(),
        assetCategories: _categories,
        selectedAssetKeys: _selectedAssetKeys,
        liabilities: _liabilities,
        selectedLiabilityIds: _selectedLiabilityIds,
      );
      final bytes = await buildPatrimoinePdfBytes(data);
      final now = DateTime.now();
      final fileName =
          'patrimoine-${now.year}${_pad2(now.month)}${_pad2(now.day)}.pdf';
      final savePath = await FilePicker.saveFile(
        dialogTitle: l10n.patrimoine_export_save_dialog_title,
        fileName: fileName,
        bytes: bytes,
      );
      if (savePath == null) {
        if (mounted) setState(() => _generating = false);
        return;
      }
      final path = savePath.toLowerCase().endsWith('.pdf')
          ? savePath
          : '$savePath.pdf';
      await File(path).writeAsBytes(bytes);
      if (!mounted) return;
      _showToast(
        title: l10n.transactions_export_success_title,
        subtitle: l10n.patrimoine_export_success_subtitle(path),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      _showToast(
        title: l10n.transactions_export_failed_title,
        subtitle: l10n.patrimoine_export_failed_subtitle(e.toString()),
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

  bool get _hasSelection =>
      _selectedAssetKeys.isNotEmpty || _selectedLiabilityIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
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
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final category in _categories) ...[
                  _buildCategorySection(category),
                  const SizedBox(height: 16),
                ],
                if (_liabilities.isNotEmpty) _buildLiabilitiesSection(),
              ],
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
              shadcn.Text(l10n.patrimoine_export_title).large().semiBold(),
              shadcn.Text(l10n.patrimoine_export_subtitle).muted().small(),
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

  Widget _buildCategorySection(PatrimoineCategory category) {
    final keys = _categoryKeys(category).toList();
    final state = _stateFor(keys);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(category.icon, size: 16, color: category.color),
            const SizedBox(width: 8),
            Expanded(child: shadcn.Text(category.label).semiBold().small()),
            Checkbox(
              state: state,
              onChanged: (s) => _setKeys(keys, s == CheckboxState.checked),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final account in category.accounts) _buildAccountRow(account),
      ],
    );
  }

  Widget _buildAccountRow(PatrimoineAccount account) {
    final keys = _accountKeys(account).toList();
    final hasNested = account.investments.isNotEmpty;
    final state = _stateFor(keys);
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: shadcn.Text(account.name).small(),
              ),
              shadcn.Text(formatEuros(account.valeur)).muted().xSmall(),
              const SizedBox(width: 8),
              Checkbox(
                state: state,
                onChanged: (s) => _setKeys(keys, s == CheckboxState.checked),
              ),
            ],
          ),
          if (hasNested)
            for (final investment in account.investments)
              _buildInvestmentRow(account, investment),
        ],
      ),
    );
  }

  Widget _buildInvestmentRow(
    PatrimoineAccount account,
    PatrimoineAccount investment,
  ) {
    final key = exportAssetKey(account.id!, investment.id!);
    final selected = _selectedAssetKeys.contains(key);
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Expanded(
            child: shadcn.Text(investment.name).muted().xSmall(),
          ),
          shadcn.Text(formatEuros(investment.valeur)).muted().xSmall(),
          const SizedBox(width: 8),
          Checkbox(
            state: selected ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: (s) =>
                _setKeys([key], s == CheckboxState.checked),
          ),
        ],
      ),
    );
  }

  Widget _buildLiabilitiesSection() {
    final byType = <LiabilityType, List<Liability>>{};
    for (final liability in _liabilities) {
      byType.putIfAbsent(liability.type, () => []).add(liability);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.landmark, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: shadcn.Text(
                AppLocalizations.of(context).nav_liabilities,
              ).semiBold().small(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final entry in byType.entries) _buildLiabilityTypeGroup(entry),
      ],
    );
  }

  Widget _buildLiabilityTypeGroup(
    MapEntry<LiabilityType, List<Liability>> entry,
  ) {
    final ids = entry.value.map((l) => l.id).toSet();
    final selectedCount = ids.where(_selectedLiabilityIds.contains).length;
    final state = selectedCount == 0
        ? CheckboxState.unchecked
        : selectedCount == ids.length
        ? CheckboxState.checked
        : CheckboxState.indeterminate;
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: shadcn.Text(entry.key.label).small()),
              Checkbox(
                state: state,
                onChanged: (s) => setState(() {
                  if (s == CheckboxState.checked) {
                    _selectedLiabilityIds.addAll(ids);
                  } else {
                    _selectedLiabilityIds.removeAll(ids);
                  }
                }),
              ),
            ],
          ),
          for (final liability in entry.value)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Row(
                children: [
                  Expanded(
                    child: shadcn.Text(liability.name).muted().xSmall(),
                  ),
                  shadcn.Text(
                    formatEuros(liability.remainingBalance),
                  ).muted().xSmall(),
                  const SizedBox(width: 8),
                  Checkbox(
                    state: _selectedLiabilityIds.contains(liability.id)
                        ? CheckboxState.checked
                        : CheckboxState.unchecked,
                    onChanged: (s) => setState(() {
                      if (s == CheckboxState.checked) {
                        _selectedLiabilityIds.add(liability.id);
                      } else {
                        _selectedLiabilityIds.remove(liability.id);
                      }
                    }),
                  ),
                ],
              ),
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
          onPressed: () {
            _selectAllAssets(true);
            _selectAllLiabilities(true);
          },
          child: shadcn.Text(l10n.transactions_export_select_all),
        ),
        TextButton(
          onPressed: () {
            _selectAllAssets(false);
            _selectAllLiabilities(false);
          },
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
          child: shadcn.Text(l10n.patrimoine_export_generate_pdf),
        ),
      ],
    );
  }
}

String _pad2(int value) => value.toString().padLeft(2, '0');

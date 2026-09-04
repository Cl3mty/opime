import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:opime/l10n/app_localizations.dart';
import '../../../core/ui/frosted_card.dart';
import '../investments_models.dart';
import '../investments_repository.dart';

/// Ouvre la fusion d'une position dans une autre du MÊME compte — pour
/// corriger une erreur de saisie (le même titre entré deux fois sous des
/// libellés/ISIN différents, ex: un fonds renommé par le teneur de compte
/// entre deux relevés) plutôt qu'un vrai mouvement financier. Toutes les
/// transactions de [sourceInvestment] sont déplacées telles quelles
/// (mêmes dates/quantités/prix, aucun recalcul) vers la position choisie,
/// ses documents suivent, puis [sourceInvestment] est retirée du compte.
/// Contrairement à un arbitrage (qui vend au cours du marché et réalise
/// une plus/moins-value bien réelle), aucune vente n'a lieu ici : c'est une
/// correction de données, pas une opération financière — voir
/// `transfer_arbitrage_dialog.dart` pour ce dernier cas.
Future<void> showMergeInvestmentDialog(
  BuildContext context, {
  required String vaultPath,
  required InvestmentAccount account,
  required Investment sourceInvestment,
  required Future<void> Function() onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _MergeInvestmentDialog(
      vaultPath: vaultPath,
      account: account,
      sourceInvestment: sourceInvestment,
      onChanged: onChanged,
    ),
  );
}

class _MergeInvestmentDialog extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final Investment sourceInvestment;
  final Future<void> Function() onChanged;

  const _MergeInvestmentDialog({
    required this.vaultPath,
    required this.account,
    required this.sourceInvestment,
    required this.onChanged,
  });

  @override
  State<_MergeInvestmentDialog> createState() =>
      _MergeInvestmentDialogState();
}

class _MergeInvestmentDialogState extends State<_MergeInvestmentDialog> {
  late final InvestmentsRepository _repo;
  String? _destSelection;

  List<Investment> get _candidates => [
    for (final i in widget.account.investments)
      if (i.id != widget.sourceInvestment.id) i,
  ];

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    final candidates = _candidates;
    _destSelection = candidates.isEmpty ? null : candidates.first.id;
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

  Future<void> _commit() async {
    final l10n = AppLocalizations.of(context);
    final destId = _destSelection;
    if (destId == null) {
      _showToast(
        title: l10n.investments_merge_impossible_title,
        subtitle: l10n.investments_merge_choose_destination_message,
      );
      return;
    }
    final destination = _candidates.firstWhere((i) => i.id == destId);
    final updatedDestination = destination.copyWith(
      transactions: [
        ...destination.transactions,
        ...widget.sourceInvestment.transactions,
      ],
      documents: [...destination.documents, ...widget.sourceInvestment.documents],
    );
    final updatedAccount = widget.account.copyWith(
      investments: [
        for (final i in widget.account.investments)
          if (i.id != widget.sourceInvestment.id)
            (i.id == updatedDestination.id ? updatedDestination : i),
      ],
    );

    try {
      await _repo.saveAccount(updatedAccount);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        title: l10n.investments_merge_impossible_title,
        subtitle: l10n.investments_save_error('$e'),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final candidates = _candidates;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: shadcn.Text(
                          l10n.investments_merge_dialog_title(
                            widget.sourceInvestment.label,
                          ),
                        ).large().semiBold(),
                      ),
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  shadcn.Text(
                    l10n.investments_merge_dialog_description(
                      widget.sourceInvestment.label,
                    ),
                  ).muted().xSmall(),
                  const SizedBox(height: 16),
                  if (candidates.isEmpty)
                    shadcn.Text(
                      l10n.investments_merge_no_other_position_message,
                    ).muted().small()
                  else ...[
                    shadcn.Text(l10n.investments_merge_target_label).muted().xSmall(),
                    const SizedBox(height: 4),
                    Select<String>(
                      value: _destSelection,
                      constraints: const BoxConstraints(minWidth: 260),
                      onChanged: (v) => setState(() => _destSelection = v),
                      itemBuilder: (context, value) => shadcn.Text(
                        candidates.firstWhere((i) => i.id == value).label,
                      ),
                      popup: (context) => SelectPopup(
                        items: SelectItemList(
                          children: [
                            for (final investment in candidates)
                              SelectItemButton(
                                value: investment.id,
                                child: shadcn.Text(investment.label),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      PrimaryButton(
                        onPressed: candidates.isEmpty ? null : _commit,
                        child: shadcn.Text(l10n.investments_merge_submit_button),
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

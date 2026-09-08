/// Point d'entrée UI de l'import d'un relevé IBKR : sélection du fichier CSV,
/// aperçu du résultat du parsing avant toute écriture, puis sauvegarde.
library;

import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/date_format.dart';
import '../../../core/ui/frosted_card.dart';
import '../../../l10n/app_localizations.dart';
import '../investments_models.dart';
import '../investments_repository.dart';
import 'ibkr_import_service.dart';
import 'ibkr_statement_parser.dart';

/// Ouvre le sélecteur de fichier, parse le CSV choisi, affiche un aperçu du
/// résultat (comptes de transactions par catégorie, avertissements) et,
/// après confirmation, sauvegarde le compte fusionné. N'écrit rien tant que
/// l'utilisateur n'a pas confirmé l'aperçu. Ne fait rien si l'utilisateur
/// annule la sélection du fichier.
Future<void> showIbkrImportDialog(
  BuildContext context, {
  required String vaultPath,
  required InvestmentAccount account,
  required VoidCallback onImported,
}) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    withData: true,
  );
  final file = result?.files.singleOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return;

  final content = utf8.decode(bytes, allowMalformed: true);
  final parsed = parseIbkrStatement(content);
  final plan = buildIbkrImportPlan(account, parsed);

  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _IbkrImportPreviewDialog(summary: plan.summary),
  );
  if (confirmed != true) return;

  await InvestmentsRepository(vaultPath).saveAccount(plan.mergedAccount);
  onImported();
}

class _IbkrImportPreviewDialog extends StatelessWidget {
  final IbkrImportSummary summary;

  const _IbkrImportPreviewDialog({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <(String, int)>[
      (l10n.investments_ibkr_row_security_trades, summary.securityTradesAdded),
      (
        l10n.investments_ibkr_row_currency_conversions,
        summary.currencyConversionsAdded,
      ),
      (l10n.investments_ibkr_row_dividends, summary.dividendsAdded),
      (
        l10n.investments_ibkr_row_withholding_tax,
        summary.withholdingTaxAdded,
      ),
      (l10n.investments_ibkr_row_fees, summary.feesAdded),
      (l10n.investments_ibkr_row_deposits, summary.depositsAdded),
      (l10n.investments_ibkr_row_withdrawals, summary.withdrawalsAdded),
      (l10n.investments_ibkr_row_other_flows, summary.otherFlowsAdded),
    ].where((row) => row.$2 > 0).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(l10n.investments_ibkr_import_dialog_title)
                    .large()
                    .semiBold(),
                const SizedBox(height: 4),
                if (summary.periodStart != null && summary.periodEnd != null)
                  shadcn.Text(
                    l10n.investments_ibkr_period_label(
                      formatDateDdMmYyyy(summary.periodStart!),
                      formatDateDdMmYyyy(summary.periodEnd!),
                    ),
                  ).muted().small(),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rows.isEmpty)
                          shadcn.Text(
                            l10n.investments_ibkr_empty_state,
                          ).small()
                        else ...[
                          for (final row in rows)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 3,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  shadcn.Text(row.$1).small(),
                                  shadcn.Text('${row.$2}').small().semiBold(),
                                ],
                              ),
                            ),
                          if (summary.duplicatesSkipped > 0) ...[
                            const SizedBox(height: 8),
                            shadcn.Text(
                              l10n.investments_ibkr_duplicates_skipped(
                                summary.duplicatesSkipped,
                              ),
                            ).muted().xSmall(),
                          ],
                        ],
                        if (summary.warnings.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          shadcn.Text(
                            l10n.investments_ibkr_warnings_title,
                          ).semiBold().xSmall(),
                          const SizedBox(height: 6),
                          for (final warning in summary.warnings)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: shadcn.Text('• $warning').muted().xSmall(),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    PrimaryButton(
                      onPressed: summary.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(true),
                      child: shadcn.Text(l10n.investments_ibkr_import_button),
                    ),
                    const SizedBox(width: 8),
                    OutlineButton(
                      onPressed: () => Navigator.of(context).pop(false),
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

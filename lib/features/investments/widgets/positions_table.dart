import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/performance_amount.dart';
import '../currency_format.dart';
import '../investments_models.dart';

const _colWidth = 96.0;

/// Table des positions d'un compte Actions & Fonds — une ligne par
/// investissement (Nom, Quantité, PRU, Cours, Valeur, +/-value), reprenant
/// les mêmes colonnes que le tableau générique de catégorie
/// (`category_detail_screen.dart`'s `_AccountLine`) pour une cohérence
/// visuelle avec le reste de l'app. Cliquer une ligne ouvre le détail de la
/// position — voir `stock_account/position_detail_dialog.dart`.
class PositionsTable extends StatelessWidget {
  final InvestmentAccount account;
  final bool hidden;
  final ValueChanged<Investment> onTap;

  const PositionsTable({
    super.key,
    required this.account,
    required this.hidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (account.investments.isEmpty) {
      return shadcn.Text('Aucune position pour l\'instant.').muted().small();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SizedBox()),
            const _HeaderCell('Quantité'),
            const _HeaderCell('PRU'),
            const _HeaderCell('Cours'),
            const _HeaderCell('Valeur'),
            const _HeaderCell('+/- value'),
            const SizedBox(width: 20),
          ],
        ),
        for (final investment in account.investments) ...[
          Container(height: 1, color: theme.colorScheme.border),
          _PositionLine(
            investment: investment,
            account: account,
            hidden: hidden,
            onTap: () => onTap(investment),
          ),
        ],
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _colWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: shadcn.Text(label).muted().xSmall(),
      ),
    );
  }
}

class _PositionLine extends StatelessWidget {
  final Investment investment;
  final InvestmentAccount account;
  final bool hidden;
  final VoidCallback onTap;

  const _PositionLine({
    required this.investment,
    required this.account,
    required this.hidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = investment.effectiveMarketValue ?? investment.investedAmount;
    final gain = investment.unrealizedGain;
    final gainPercent = gain != null && investment.investedAmount != 0
        ? gain / investment.investedAmount * 100
        : null;
    final crossClass =
        investment.assetClass != null &&
        investment.assetClass != account.assetClass;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    shadcn.Text(investment.label).medium().small(),
                    if (!investment.isCurrency)
                      shadcn.Text(investment.isin).muted().xSmall(),
                    if (crossClass)
                      shadcn.Text(
                        investment.assetClass!.label,
                        style: TextStyle(color: theme.colorScheme.primary),
                      ).xSmall(),
                  ],
                ),
              ),
              SizedBox(
                width: _colWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: shadcn.Text(
                    formatQuantity(
                      investment.quantityHeld,
                      investment.assetClass ?? account.assetClass,
                    ),
                  ).small(),
                ),
              ),
              SizedBox(
                width: _colWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: shadcn.Text(
                    investment.isCurrency
                        ? investment.pru.toStringAsFixed(4)
                        : displayEuros(investment.pru, hidden),
                  ).small(),
                ),
              ),
              SizedBox(
                width: _colWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: investment.lastPrice == null
                      ? shadcn.Text('—').small()
                      : shadcn.Text(
                          investmentLastPriceDisplay(
                            account,
                            investment,
                            hidden: hidden,
                          ),
                        ).small(),
                ),
              ),
              SizedBox(
                width: _colWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: shadcn.Text(displayEuros(value, hidden)).small(),
                ),
              ),
              SizedBox(
                width: _colWidth,
                child: gain == null
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: shadcn.Text('—').small(),
                      )
                    : PerformanceAmount(
                        euros: gain,
                        percent: gainPercent,
                        hidden: hidden,
                      ),
              ),
              SizedBox(
                width: 20,
                child: Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

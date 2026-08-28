import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/performance_amount.dart';
import '../currency_format.dart';
import '../investments_models.dart';
import 'transaction_widgets.dart' show ExcludedFromPatrimoineBadge;

const _colWidth = 96.0;

/// Table des positions d'un compte Actions & Fonds — une ligne par
/// investissement (Nom, Quantité, PRU, Cours, Valeur, +/-value), reprenant
/// les mêmes colonnes que le tableau générique de catégorie
/// (`category_detail_screen.dart`'s `_AccountLine`) pour une cohérence
/// visuelle avec le reste de l'app. Cliquer une ligne ouvre le détail de la
/// position — voir `stock_account/position_detail_dialog.dart`. Les
/// positions à quantité nulle (soldées) s'affichent séparément, dans un
/// second tableau "Anciennes positions" sous les positions ouvertes.
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

  /// Une position à quantité nulle (entièrement vendue, transférée ou
  /// arbitrée vers un autre titre) n'a plus de détention actuelle — même
  /// seuil que `real_patrimoine_adapter.dart` (`quantityHeld <= 0`), avec
  /// une petite marge contre les résidus de virgule flottante d'une somme
  /// de transactions qui devrait s'annuler exactement (voir
  /// `Transaction.toJson`, qui ne les arrondit plus à la sauvegarde).
  static const _closedThreshold = 1e-9;

  @override
  Widget build(BuildContext context) {
    if (account.investments.isEmpty) {
      return shadcn.Text('Aucune position pour l\'instant.').muted().small();
    }
    final active = [
      for (final i in account.investments)
        if (i.quantityHeld > _closedThreshold) i,
    ];
    final closed = [
      for (final i in account.investments)
        if (i.quantityHeld <= _closedThreshold) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isNotEmpty)
          _PositionsSubTable(
            investments: active,
            account: account,
            hidden: hidden,
            onTap: onTap,
          )
        else
          shadcn.Text('Aucune position ouverte pour l\'instant.').muted().small(),
        // Historique des positions soldées (vente totale, transfert ou
        // arbitrage vers un autre titre) — gardé visible mais nettement
        // séparé des positions réellement détenues aujourd'hui, pour ne pas
        // les confondre dans les totaux affichés au-dessus de ce tableau.
        if (closed.isNotEmpty) ...[
          const SizedBox(height: 28),
          shadcn.Text('Anciennes positions').muted().xSmall(),
          const SizedBox(height: 8),
          _PositionsSubTable(
            investments: closed,
            account: account,
            hidden: hidden,
            onTap: onTap,
          ),
        ],
      ],
    );
  }
}

/// Un tableau positions (en-tête + lignes) — [PositionsTable] en affiche
/// deux instances : les positions ouvertes, puis (si non vide) les
/// anciennes positions soldées.
class _PositionsSubTable extends StatelessWidget {
  final List<Investment> investments;
  final InvestmentAccount account;
  final bool hidden;
  final ValueChanged<Investment> onTap;

  const _PositionsSubTable({
    required this.investments,
    required this.account,
    required this.hidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          ],
        ),
        for (final investment in investments) ...[
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
    final value = investment.displayValue;
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: shadcn.Text(
                            investment.label,
                          ).medium().small(),
                        ),
                        if (investment.excludedFromPatrimoine) ...[
                          const SizedBox(width: 6),
                          const ExcludedFromPatrimoineBadge(),
                        ],
                      ],
                    ),
                    if (!investment.isCurrency &&
                        !isGeneratedIdentifier(investment.isin))
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
                  child: investment.lastPrice != null
                      ? shadcn.Text(
                          investmentLastPriceDisplay(
                            account,
                            investment,
                            hidden: hidden,
                          ),
                        ).small()
                      // Sans cours de marché (ex : un objet "Autres"), le
                      // cours estimé à la main par l'utilisateur (voir
                      // [Investment.manualPrice]) prend le relais.
                      : investment.manualPrice != null
                      ? shadcn.Text(
                          displayEuros(investment.manualPrice!, hidden),
                        ).small()
                      : shadcn.Text('—').small(),
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
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/performance_amount.dart';
import '../../dashboard/patrimoine_models.dart' show DashboardPeriod;
import '../confirm_delete_dialog.dart';
import '../currency_format.dart';
import '../investments_models.dart';
import '../investments_repository.dart';
import '../leveraged_position.dart';
import '../real_patrimoine_adapter.dart'
    show periodReturnFor, periodValueChangeFor;
import '../yahoo_finance_client.dart' show PricePoint;
import 'leveraged_position_dialog.dart';
import 'transaction_widgets.dart' show ExcludedFromPatrimoineBadge;

const _colWidth = 96.0;
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _orange = Color(0xFFF97316);

/// Table des positions d'un compte Actions & Fonds — une ligne par
/// investissement (Nom, Quantité, PRU, Cours, Valeur, +/-value), reprenant
/// les mêmes colonnes que le tableau générique de catégorie
/// (`category_detail_screen.dart`'s `_AccountLine`) pour une cohérence
/// visuelle avec le reste de l'app. Cliquer une ligne ouvre le détail de la
/// position — voir `stock_account/position_detail_dialog.dart`.
///
/// Trois sections empilées, dans cet ordre : positions ouvertes, positions
/// à effet de levier ([InvestmentAccount.leveragedPositions], Actions &
/// Fonds/Crypto uniquement), puis "Anciennes positions" (quantité nulle —
/// vendue, transférée ou arbitrée) tout en bas, l'historique consulté le
/// moins souvent. Le levier reste une section de ce même onglet "Positions"
/// plutôt qu'un onglet séparé : même principe que les anciennes positions,
/// une section distincte plutôt qu'une navigation à part pour un concept
/// qui reste "une position du compte".
class PositionsTable extends StatelessWidget {
  final InvestmentAccount account;
  final bool hidden;
  final ValueChanged<Investment> onTap;
  final String vaultPath;
  final Future<void> Function() onChanged;

  /// Restreint les positions affichées à ce sous-ensemble de
  /// [account.investments] (ex : uniquement les parts de SCPI d'un contrat
  /// d'assurance vie, vues depuis la catégorie Immobilier — voir
  /// `accountAcceptsCrossClassInvestment`). `null` (défaut) : toutes les
  /// positions du compte, comportement inchangé. Masque aussi la section
  /// "Positions à effet de levier" (voir [_showLeveragedSection]) : une
  /// position à effet de levier compte toujours pour la classe propre du
  /// compte, jamais pour une classe cross-class restreinte ici. N'affecte
  /// jamais [account] lui-même — les écritures (ex : suppression d'une
  /// position à effet de levier) continuent de partir de la liste complète.
  final List<Investment>? visibleInvestments;

  /// Période affichée pour les colonnes "Évolution"/"+/- value" (positions
  /// spot uniquement — voir la doc de classe pour la section levier, hors
  /// périmètre). Voir `StockAccountScreen._periodIndex`.
  final DashboardPeriod period;

  /// Historique de cours en cache de chaque investissement — voir
  /// `StockAccountScreen.priceHistories`, transmis tel quel pour calculer
  /// [period]/[periodValueChangeFor] sans nouvelle E/S.
  final Map<String, List<PricePoint>> priceHistories;

  const PositionsTable({
    super.key,
    required this.account,
    required this.hidden,
    required this.onTap,
    required this.vaultPath,
    required this.onChanged,
    this.visibleInvestments,
    required this.period,
    required this.priceHistories,
  });

  /// Une position à quantité nulle (entièrement vendue, transférée ou
  /// arbitrée vers un autre titre) n'a plus de détention actuelle — même
  /// seuil que `real_patrimoine_adapter.dart` (`quantityHeld <= 0`), avec
  /// une petite marge contre les résidus de virgule flottante d'une somme
  /// de transactions qui devrait s'annuler exactement (voir
  /// `Transaction.toJson`, qui ne les arrondit plus à la sauvegarde).
  static const _closedThreshold = 1e-9;

  /// Positions à effet de levier (perpétuels crypto, marge) — voir
  /// `leveraged_position.dart` : uniquement pour ces deux classes, qui
  /// couvrent tout ce sur quoi l'utilisateur trade sur marge aujourd'hui.
  bool get _showLeveragedSection =>
      visibleInvestments == null &&
      (account.assetClass == AssetClass.actionsEtFonds ||
          account.assetClass == AssetClass.crypto);

  @override
  Widget build(BuildContext context) {
    final investments = visibleInvestments ?? account.investments;
    final active = [
      for (final i in investments)
        if (i.quantityHeld > _closedThreshold) i,
    ];
    final closed = [
      for (final i in investments)
        if (i.quantityHeld <= _closedThreshold) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (investments.isEmpty)
          shadcn.Text('Aucune position pour l\'instant.').muted().small()
        else if (active.isNotEmpty)
          _PositionsSubTable(
            investments: active,
            account: account,
            hidden: hidden,
            onTap: onTap,
            period: period,
            priceHistories: priceHistories,
          )
        else
          shadcn.Text('Aucune position ouverte pour l\'instant.').muted().small(),
        // Ordre volontaire : positions ouvertes, puis positions à effet de
        // levier, puis anciennes positions en dernier — l'historique soldé
        // est ce qu'on consulte le moins souvent, il reste donc tout en bas.
        if (_showLeveragedSection) ...[
          const SizedBox(height: 28),
          _LeveragedPositionsSection(
            account: account,
            hidden: hidden,
            vaultPath: vaultPath,
            onChanged: onChanged,
          ),
        ],
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
            period: period,
            priceHistories: priceHistories,
          ),
        ],
      ],
    );
  }
}

/// Section "Positions à effet de levier" du bas de l'onglet Positions —
/// tableau des positions ouvertes, puis (si non vide) un second tableau
/// "Positions fermées", même disposition que [PositionsTable] pour le spot.
/// Remplace l'ancien onglet dédié `LeveragedPositionsTab` : garder ce
/// concept comme une section de l'onglet Positions plutôt qu'une
/// navigation à part, cohérent avec "une position à effet de levier reste
/// une position du compte".
class _LeveragedPositionsSection extends StatelessWidget {
  final InvestmentAccount account;
  final bool hidden;
  final String vaultPath;
  final Future<void> Function() onChanged;

  const _LeveragedPositionsSection({
    required this.account,
    required this.hidden,
    required this.vaultPath,
    required this.onChanged,
  });

  Future<void> _deletePosition(
    BuildContext context,
    LeveragedPosition position,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer "${position.market}" ?',
      message: 'Cette position sera définitivement supprimée. Cette action '
          'est irréversible.',
    );
    if (!confirmed) return;
    final updatedAccount = account.copyWith(
      leveragedPositions: [
        for (final p in account.leveragedPositions)
          if (p.id != position.id) p,
      ],
    );
    await InvestmentsRepository(vaultPath).saveAccount(updatedAccount);
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final open = [
      for (final p in account.leveragedPositions)
        if (p.isOpen) p,
    ];
    final closed = [
      for (final p in account.leveragedPositions)
        if (!p.isOpen) p,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            shadcn.Text('Positions à effet de levier').muted().xSmall(),
            const Spacer(),
            GestureDetector(
              onTap: () => showLeveragedPositionDialog(
                context,
                vaultPath: vaultPath,
                account: account,
                onChanged: onChanged,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.plus,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  shadcn.Text(
                    'Ajouter une position',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ).xSmall(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (open.isEmpty && closed.isEmpty)
          shadcn.Text(
            'Aucune position à effet de levier pour l\'instant.',
          ).muted().small()
        else if (open.isNotEmpty)
          _LeveragedPositionsSubTable(
            positions: open,
            account: account,
            hidden: hidden,
            vaultPath: vaultPath,
            onChanged: onChanged,
            onDelete: (p) => _deletePosition(context, p),
          ),
        if (closed.isNotEmpty) ...[
          const SizedBox(height: 20),
          shadcn.Text('Positions fermées').muted().xSmall(),
          const SizedBox(height: 8),
          _LeveragedPositionsSubTable(
            positions: closed,
            account: account,
            hidden: hidden,
            vaultPath: vaultPath,
            onChanged: onChanged,
            onDelete: (p) => _deletePosition(context, p),
          ),
        ],
      ],
    );
  }
}

/// Un tableau positions à effet de levier (en-tête + lignes) — colonnes
/// adaptées à ce que ce modèle porte en plus du spot (sens/levier, marge,
/// PnL en ROE %) plutôt que de réutiliser les colonnes de
/// [_PositionsSubTable], qui ne correspondent pas (pas de PRU/quantité au
/// même sens pour une position sur marge).
class _LeveragedPositionsSubTable extends StatelessWidget {
  final List<LeveragedPosition> positions;
  final InvestmentAccount account;
  final bool hidden;
  final String vaultPath;
  final Future<void> Function() onChanged;
  final ValueChanged<LeveragedPosition> onDelete;

  const _LeveragedPositionsSubTable({
    required this.positions,
    required this.account,
    required this.hidden,
    required this.vaultPath,
    required this.onChanged,
    required this.onDelete,
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
            const _HeaderCell('Taille'),
            const _HeaderCell('Entrée'),
            const _HeaderCell('Cours'),
            const _HeaderCell('Montant'),
            const _HeaderCell('PnL (ROE)'),
            const SizedBox(width: 32),
          ],
        ),
        for (final position in positions) ...[
          Container(height: 1, color: theme.colorScheme.border),
          _LeveragedPositionLine(
            position: position,
            account: account,
            hidden: hidden,
            vaultPath: vaultPath,
            onChanged: onChanged,
            onDelete: () => onDelete(position),
          ),
        ],
      ],
    );
  }
}

class _LeveragedPositionLine extends StatelessWidget {
  final LeveragedPosition position;
  final InvestmentAccount account;
  final bool hidden;
  final String vaultPath;
  final Future<void> Function() onChanged;
  final VoidCallback onDelete;

  const _LeveragedPositionLine({
    required this.position,
    required this.account,
    required this.hidden,
    required this.vaultPath,
    required this.onChanged,
    required this.onDelete,
  });

  void _openMenu(BuildContext anchorContext) {
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 200),
        child: DropdownMenu(
          children: [
            if (position.isOpen) ...[
              MenuButton(
                leading: const Icon(LucideIcons.refreshCw, size: 14),
                child: const shadcn.Text('Actualiser'),
                onPressed: (_) => showRefreshLeveragedPositionDialog(
                  context,
                  vaultPath: vaultPath,
                  account: account,
                  position: position,
                  onChanged: onChanged,
                ),
              ),
              MenuButton(
                leading: const Icon(LucideIcons.pencil, size: 14),
                child: const shadcn.Text('Modifier'),
                onPressed: (_) => showLeveragedPositionDialog(
                  context,
                  vaultPath: vaultPath,
                  account: account,
                  existing: position,
                  onChanged: onChanged,
                ),
              ),
              MenuButton(
                leading: const Icon(LucideIcons.flagOff, size: 14),
                child: const shadcn.Text('Clôturer'),
                onPressed: (_) => showCloseLeveragedPositionDialog(
                  context,
                  vaultPath: vaultPath,
                  account: account,
                  position: position,
                  onChanged: onChanged,
                ),
              ),
            ],
            MenuButton(
              leading: const Icon(LucideIcons.trash2, size: 14),
              child: const shadcn.Text('Supprimer'),
              onPressed: (_) => onDelete(),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final pnl = position.pnl;
    final roe = position.roePercent;
    final leverageLabel = position.leverage == position.leverage.roundToDouble()
        ? position.leverage.toStringAsFixed(0)
        : position.leverage.toString();
    final liqDistance = position.liquidationDistancePercent;
    // Proche de la liquidation (<10 %) : rouge. Vigilance (<25 %) : orange.
    // Au-delà, ou pas de cours/prix de liquidation connu : neutre (pas de
    // couleur), voir `leveraged_position_card.dart` pour le même seuillage.
    final liqColor = liqDistance == null
        ? null
        : liqDistance < 10
        ? _red
        : liqDistance < 25
        ? _orange
        : _green;

    return Padding(
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
                    shadcn.Text(position.market).medium().small(),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (position.side == PositionSide.long
                                    ? _green
                                    : _red)
                                .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: shadcn.Text(
                        '${position.side.label} ${leverageLabel}x',
                        style: TextStyle(
                          color: position.side == PositionSide.long
                              ? _green
                              : _red,
                          fontWeight: FontWeight.w600,
                        ),
                      ).xSmall(),
                    ),
                    if (!position.isOpen) ...[
                      const SizedBox(width: 6),
                      shadcn.Text('Fermée').muted().xSmall(),
                    ],
                  ],
                ),
                if (position.isOpen &&
                    position.effectiveLiquidationPrice != null)
                  shadcn.Text(
                    'Liquidation : '
                    '${displayEuros(position.effectiveLiquidationPrice!, hidden)}',
                    style: liqColor == null ? null : TextStyle(color: liqColor),
                  ).xSmall(),
              ],
            ),
          ),
          SizedBox(
            width: _colWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: shadcn.Text(_formatNumber(position.size)).small(),
            ),
          ),
          SizedBox(
            width: _colWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: shadcn.Text(
                displayEuros(position.entryPriceInEur, hidden),
              ).small(),
            ),
          ),
          SizedBox(
            width: _colWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  (position.isOpen ? position.markPrice : position.closePrice) ==
                      null
                  ? shadcn.Text('—').small()
                  : shadcn.Text(
                      displayEuros(
                        (position.isOpen
                            ? position.markPrice
                            : position.closePrice)!,
                        hidden,
                      ),
                    ).small(),
            ),
          ),
          SizedBox(
            width: _colWidth,
            child: Align(
              alignment: Alignment.centerRight,
              // Montant de la position au cours de référence courant
              // (taille × mark price, ou prix de clôture si fermée) —
              // retombe sur le montant à l'entrée sans cours connu.
              child: shadcn.Text(
                displayEuros(
                  position.notionalValue ?? position.entryNotionalValue,
                  hidden,
                ),
              ).small(),
            ),
          ),
          SizedBox(
            width: _colWidth,
            child: PerformanceAmount(euros: pnl, percent: roe, hidden: hidden),
          ),
          SizedBox(
            width: 32,
            child: Builder(
              builder: (context) => IconButton.ghost(
                icon: const Icon(LucideIcons.ellipsisVertical, size: 16),
                onPressed: () => _openMenu(context),
              ),
            ),
          ),
        ],
      ),
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
  final DashboardPeriod period;
  final Map<String, List<PricePoint>> priceHistories;

  const _PositionsSubTable({
    required this.investments,
    required this.account,
    required this.hidden,
    required this.onTap,
    required this.period,
    required this.priceHistories,
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
            const _HeaderCell('Évolution'),
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
            period: period,
            priceHistories: priceHistories,
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
  final DashboardPeriod period;
  final Map<String, List<PricePoint>> priceHistories;

  const _PositionLine({
    required this.investment,
    required this.account,
    required this.hidden,
    required this.onTap,
    required this.period,
    required this.priceHistories,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = investment.displayValue;
    final change = periodValueChangeFor([investment], priceHistories, period);
    final pnl = periodReturnFor([investment], priceHistories, period);
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
                child: PerformanceAmount(
                  euros: change.euros,
                  percent: change.percent,
                  hidden: hidden,
                ),
              ),
              SizedBox(
                width: _colWidth,
                child: PerformanceAmount(
                  euros: pnl.euros,
                  percent: pnl.percent,
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

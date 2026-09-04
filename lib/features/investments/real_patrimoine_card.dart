import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import '../dashboard/patrimoine_models.dart'
    show DashboardPeriod, NetWorthPoint, PatrimoineCategory;
import '../dashboard/widgets/net_worth_chart.dart';
import '../dashboard/widgets/patrimoine_chart_widgets.dart';
import '../../l10n/app_localizations.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Carte "Patrimoine" pour les données réelles : sélection multiple de
/// classes d'actif empilées, bascule Patrimoine net/brut — à partir de
/// l'historique par classe reconstruit par `real_patrimoine_adapter.dart`,
/// borné à la période sélectionnée (voir [actifsHistoryFor], appelé à
/// chaque changement d'onglet — une même grille de dates commune à toutes
/// les classes pour pouvoir les empiler) et du capital restant dû total des
/// passifs réels ([totalPassifHistoryFor],
/// `liabilities/real_passifs_adapter.dart`'s `totalBalanceOnGrid`).
///
/// "Patrimoine brut" empile uniquement les classes d'actif sélectionnées ;
/// "Patrimoine net" affiche une courbe dorée unique qui vaut à chaque
/// instant la somme des actifs moins la somme des passifs (la sélection
/// multi-classes n'a pas d'effet dans ce mode). La règle est dans
/// `buildPatrimoineChartData`, dans `patrimoine_chart_widgets.dart`.
class RealPatrimoineCard extends StatefulWidget {
  final List<PatrimoineCategory> actifs;
  final Map<String, List<NetWorthPoint>> Function(DashboardPeriod)
  actifsHistoryFor;
  final List<NetWorthPoint> Function(DashboardPeriod) totalPassifHistoryFor;
  final bool hidden;

  /// Période affichée par le graphique — contrôlée par le parent
  /// (`dashboard_screen.dart`) plutôt que gardée en état interne, pour que
  /// les cartes "Actifs"/"Passifs" du Dashboard (`CategoryBreakdownCard`)
  /// puissent suivre la même période sans sélecteur propre.
  final int periodIndex;
  final ValueChanged<int> onPeriodChanged;

  const RealPatrimoineCard({
    super.key,
    required this.actifs,
    required this.actifsHistoryFor,
    required this.totalPassifHistoryFor,
    required this.hidden,
    required this.periodIndex,
    required this.onPeriodChanged,
  });

  @override
  State<RealPatrimoineCard> createState() => _RealPatrimoineCardState();
}

class _RealPatrimoineCardState extends State<RealPatrimoineCard> {
  PatrimoineKind _kind = PatrimoineKind.net;
  // Seules les classes à valeur strictement positive sont sélectionnables
  // pour le patrimoine brut (voir `CategoryMultiSelect`/`ChartLayer.selectable`).
  late Set<String> _selectedIds = {
    for (final c in widget.actifs)
      if (c.montant > 0) c.id,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final period = DashboardPeriod.values[widget.periodIndex];
    final actifsHistoryById = widget.actifsHistoryFor(period);

    final chartData = buildPatrimoineChartData(
      kind: _kind,
      allLayers: [
        for (final c in widget.actifs)
          ChartLayer(id: c.id, label: c.label, color: c.color),
      ],
      allSeries: [
        for (final c in widget.actifs) actifsHistoryById[c.id] ?? const [],
      ],
      selectedIds: _selectedIds,
      passifSeries: widget.totalPassifHistoryFor(period),
    );
    final totalPoints = chartData.totalPoints;

    final changePercent = changePercentFor(totalPoints);
    final absoluteChange = totalPoints.length < 2
        ? 0.0
        : totalPoints.last.value - totalPoints.first.value;
    final positive = absoluteChange >= 0;
    final changeColor = positive ? _green : _red;

    // Aucun investissement nulle part (vs. simplement pas assez de points
    // pour la sélection/période courante, couvert plus bas par
    // [EmptySelectionAmount]) : message dédié, mais uniquement à la place
    // du montant/graphique — le titre, la sélection de classes et les
    // onglets de période restent utilisables pour tout le monde.
    final hasAnyData = actifsHistoryById.values.any((h) => h.isNotEmpty);

    return FrostedCard(
      expand: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 620;
                final title = PatrimoineTitleRow(
                  kind: _kind,
                  onChanged: (k) => setState(() => _kind = k),
                );
                final controls = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_kind == PatrimoineKind.brut)
                      CategoryMultiSelect(
                        options: [
                          for (final c in widget.actifs)
                            ChartLayer(
                              id: c.id,
                              label: c.label,
                              color: c.color,
                              // Classe à valeur nulle : visible mais non
                              // sélectionnable dans le patrimoine brut.
                              selectable: c.montant > 0,
                            ),
                        ],
                        selectedIds: _selectedIds,
                        onChanged: (ids) => setState(() => _selectedIds = ids),
                      ),
                  ],
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), controls],
                  );
                }
                return Row(children: [title, const Spacer(), controls]);
              },
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Le montant + variation ne s'affichent qu'une fois les
                // données disponibles (voir plus bas, même garde que
                // l'ancien état vide du graphique) — le sélecteur de
                // période, lui, reste toujours utilisable pour changer de
                // période même sans donnée sur celle affichée actuellement.
                Expanded(
                  child: totalPoints.length < 2
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            shadcn.Text(
                              displayEuros(
                                totalPoints.last.value,
                                widget.hidden,
                              ),
                            ).x2Large().bold(),
                            const SizedBox(height: 4),
                            PeriodChangeRow(
                              absoluteChange:
                                  totalPoints.last.value -
                                  totalPoints.first.value,
                              changePercent: changePercent,
                              hidden: widget.hidden,
                              color: changeColor,
                              icon: positive
                                  ? LucideIcons.trendingUp
                                  : LucideIcons.trendingDown,
                            ),
                          ],
                        ),
                ),
                PeriodTabs(
                  labels: [for (final p in DashboardPeriod.values) p.label],
                  index: widget.periodIndex,
                  onChanged: widget.onPeriodChanged,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: totalPoints.length < 2
                  ? Center(
                      child: hasAnyData
                          ? const EmptySelectionAmount()
                          : shadcn.Text(
                              l10n.investments_no_data_yet,
                            ).muted().small(),
                    )
                  : StackedNetWorthChart(
                      dates: chartData.dates,
                      layers: chartData.layers,
                      layerValues: chartData.layerValues,
                      cumulativeTop: chartData.cumulativeTop,
                      hidden: widget.hidden,
                      gridColor: theme.colorScheme.border,
                      textColor: theme.colorScheme.mutedForeground,
                      markerColor: theme.colorScheme.primary,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

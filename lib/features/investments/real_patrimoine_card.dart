import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import '../dashboard/dashboard_dummy_data.dart'
    show NetWorthPoint, PatrimoineCategory;
import '../dashboard/widgets/net_worth_chart.dart';
import '../dashboard/widgets/patrimoine_chart_widgets.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Carte "Patrimoine" pour les données réelles : même fonctionnalité que
/// [PatrimoineCard] (démo) — sélection multiple de classes d'actif
/// empilées, bascule Patrimoine net/brut, bascule Valeur/Performance — à
/// partir de l'historique par classe reconstruit par
/// `real_patrimoine_adapter.dart` (une même grille de dates commune à
/// toutes les classes, voir `sharedDateGrid`/`categoryHistoryOnGrid`, pour
/// pouvoir les empiler) et du capital restant dû total des passifs réels
/// (`liabilities/real_passifs_adapter.dart`'s `totalBalanceOnGrid`).
///
/// "Patrimoine brut" empile uniquement les classes d'actif sélectionnées ;
/// "Patrimoine net" affiche une courbe dorée unique qui vaut à chaque
/// instant la somme des actifs moins la somme des passifs (la sélection
/// multi-classes n'a pas d'effet dans ce mode). La règle est partagée avec
/// la carte de démo via `buildPatrimoineChartData` dans
/// `patrimoine_chart_widgets.dart`.
class RealPatrimoineCard extends StatefulWidget {
  final List<PatrimoineCategory> actifs;
  final Map<String, List<NetWorthPoint>> actifsHistoryById;
  final List<NetWorthPoint> totalPassifHistory;
  final bool hidden;

  const RealPatrimoineCard({
    super.key,
    required this.actifs,
    required this.actifsHistoryById,
    required this.totalPassifHistory,
    required this.hidden,
  });

  @override
  State<RealPatrimoineCard> createState() => _RealPatrimoineCardState();
}

class _RealPatrimoineCardState extends State<RealPatrimoineCard> {
  int _periodIndex = 5;
  PatrimoineKind _kind = PatrimoineKind.net;
  PatrimoineValueMode _valueMode = PatrimoineValueMode.valeur;
  // Seules les classes à valeur strictement positive sont sélectionnables
  // pour le patrimoine brut (voir `CategoryMultiSelect`/`ChartLayer.selectable`).
  late Set<String> _selectedIds = {
    for (final c in widget.actifs)
      if (c.montant > 0) c.id,
  };

  List<NetWorthPoint> _sliceForDays(List<NetWorthPoint> points, int days) {
    if (points.isEmpty) return points;
    if (days >= points.length) return points;
    final start = (points.length - days).clamp(0, points.length - 2);
    return points.sublist(start);
  }

  double _changePercentFor(List<NetWorthPoint> points) {
    if (points.length < 2 || points.first.value == 0) return 0;
    return (points.last.value - points.first.value) / points.first.value * 100;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final periodDays = dashboardPeriods[_periodIndex].$2;

    final chartData = buildPatrimoineChartData(
      kind: _kind,
      allLayers: [
        for (final c in widget.actifs)
          ChartLayer(id: c.id, label: c.label, color: c.color),
      ],
      allSeries: [
        for (final c in widget.actifs)
          _sliceForDays(
            widget.actifsHistoryById[c.id] ?? const [],
            periodDays,
          ),
      ],
      selectedIds: _selectedIds,
      passifSeries: _sliceForDays(widget.totalPassifHistory, periodDays),
    );
    final totalPoints = chartData.totalPoints;

    final changePercent = _changePercentFor(totalPoints);
    final positive = changePercent >= 0;
    final changeColor = positive ? _green : _red;
    final performance = _valueMode == PatrimoineValueMode.performance;

    final formatValue = performance
        ? (double v) => displayPercent(v)
        : (double v) => displayEuros(v, widget.hidden);

    // Aucun investissement nulle part (vs. simplement pas assez de points
    // pour la sélection/période courante, couvert plus bas par
    // [EmptySelectionAmount]) : message dédié, mais uniquement à la place
    // du montant/graphique — le titre, la sélection de classes et les
    // onglets de période restent utilisables pour tout le monde.
    final hasAnyData = widget.actifsHistoryById.values.any((h) => h.isNotEmpty);

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
                    ValueModeToggle(
                      mode: _valueMode,
                      onChanged: (m) => setState(() => _valueMode = m),
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
            PeriodTabs(
              labels: [for (final p in dashboardPeriods) p.$1],
              index: _periodIndex,
              onChanged: (i) => setState(() => _periodIndex = i),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: totalPoints.length < 2
                  ? Center(
                      child: hasAnyData
                          ? const EmptySelectionAmount()
                          : shadcn.Text(
                              'Pas encore de données.',
                            ).muted().small(),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (performance)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                positive
                                    ? LucideIcons.trendingUp
                                    : LucideIcons.trendingDown,
                                size: 20,
                                color: changeColor,
                              ),
                              const SizedBox(width: 6),
                              shadcn.Text(
                                displayPercent(changePercent),
                                style: TextStyle(color: changeColor),
                              ).x2Large().bold(),
                            ],
                          )
                        else
                          shadcn.Text(
                            displayEuros(totalPoints.last.value, widget.hidden),
                          ).x2Large().bold(),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              positive
                                  ? LucideIcons.trendingUp
                                  : LucideIcons.trendingDown,
                              size: 14,
                              color: changeColor,
                            ),
                            const SizedBox(width: 4),
                            shadcn.Text(
                              performance
                                  ? displayEuros(
                                      totalPoints.last.value -
                                          totalPoints.first.value,
                                      widget.hidden,
                                    )
                                  : displayPercent(changePercent),
                              style: TextStyle(
                                color: changeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ).small(),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: performance
                              ? NetWorthChart(
                                  points: rebaseToPercent(totalPoints),
                                  formatValue: formatValue,
                                  axisLabelFormat: (v) => displayPercent(v),
                                  lineColor: theme.colorScheme.primary,
                                  gridColor: theme.colorScheme.border,
                                  textColor: theme.colorScheme.mutedForeground,
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
          ],
        ),
      ),
    );
  }
}

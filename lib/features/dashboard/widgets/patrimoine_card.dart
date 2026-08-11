import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/frosted_card.dart';
import '../dashboard_dummy_data.dart';
import 'net_worth_chart.dart';
import 'patrimoine_chart_widgets.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Carte "Patrimoine" : montant total (net ou brut, au choix), filtrable
/// par une sélection multiple de classes d'actif, affichable en valeur ou
/// en performance sur la période sélectionnée. En mode Valeur, les classes
/// sélectionnées sont affichées en aires empilées (chaque bande au
/// pro rata de son importance), la hauteur cumulée totale se lisant
/// directement en ordonnée. Contrôles et graphique empilé partagés avec
/// `RealPatrimoineCard` via `patrimoine_chart_widgets.dart`.
class PatrimoineCard extends StatefulWidget {
  final DashboardSampleData data;
  final bool hidden;

  const PatrimoineCard({super.key, required this.data, required this.hidden});

  @override
  State<PatrimoineCard> createState() => _PatrimoineCardState();
}

class _PatrimoineCardState extends State<PatrimoineCard> {
  int _periodIndex = 5;
  PatrimoineKind _kind = PatrimoineKind.net;
  PatrimoineValueMode _valueMode = PatrimoineValueMode.valeur;
  Set<String> _selectedFilterIds = {
    for (final f in dashboardAssetFilters) f.id,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gross = _kind == PatrimoineKind.brut;
    final periodDays = dashboardPeriods[_periodIndex].$2;

    final chartData = buildPatrimoineChartData(
      kind: _kind,
      allLayers: [
        for (final f in dashboardAssetFilters)
          ChartLayer(id: f.id, label: f.label, color: f.color),
      ],
      allSeries: [
        for (final f in dashboardAssetFilters)
          widget.data.sliceForDays(
            widget.data.seriesFor(f.id, gross: gross),
            periodDays,
          ),
      ],
      selectedIds: _selectedFilterIds,
      netSeriesOverride: _kind == PatrimoineKind.net
          ? widget.data.sliceForDays(widget.data.netWorthHistory, periodDays)
          : null,
    );
    final totalPoints = chartData.totalPoints;

    final changePercent = widget.data.changePercentFor(totalPoints);
    final positive = changePercent >= 0;
    final changeColor = positive ? _green : _red;
    final performance = _valueMode == PatrimoineValueMode.performance;

    final formatValue = performance
        ? (double v) => displayPercent(v)
        : (double v) => displayEuros(v, widget.hidden);

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
                          for (final f in dashboardAssetFilters)
                            ChartLayer(
                              id: f.id,
                              label: f.label,
                              color: f.color,
                            ),
                        ],
                        selectedIds: _selectedFilterIds,
                        onChanged: (ids) =>
                            setState(() => _selectedFilterIds = ids),
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
            if (totalPoints.length < 2)
              const EmptySelectionAmount()
            else ...[
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
                            totalPoints.last.value - totalPoints.first.value,
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
            ],
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
    );
  }
}

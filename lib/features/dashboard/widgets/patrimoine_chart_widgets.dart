import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../patrimoine_models.dart';
import 'net_worth_chart.dart';

/// Une couche sélectionnable/empilable dans la carte "Patrimoine" : un
/// point coloré en légende, une bande empilée du même nom dans le
/// graphique — utilisé par `RealPatrimoineCard`
/// (`features/investments/real_patrimoine_card.dart`, classes d'actif
/// réelles) pour réutiliser les mêmes contrôles et le même graphique sans
/// coupler ce fichier au module Investissements.
class ChartLayer {
  final String id;
  final String label;
  final Color color;

  /// `false` quand la classe d'actif correspondante n'est pas sélectionnable
  /// pour l'affichage (valeur strictement positive requise) — l'entrée
  /// reste visible dans [CategoryMultiSelect] mais est grisée et
  /// désactivée, voir `SelectItemButton.enabled`.
  final bool selectable;

  const ChartLayer({
    required this.id,
    required this.label,
    required this.color,
    this.selectable = true,
  });
}

enum PatrimoineKind { net, brut }

/// Titre "Patrimoine net"/"Patrimoine brut" avec bascule et infobulle sur
/// TWR/MWR.
class PatrimoineTitleRow extends StatelessWidget {
  final PatrimoineKind kind;
  final ValueChanged<PatrimoineKind> onChanged;

  const PatrimoineTitleRow({
    super.key,
    required this.kind,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Select<PatrimoineKind>(
          value: kind,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          itemBuilder: (context, value) => shadcn.Text(
            value == PatrimoineKind.net ? 'Patrimoine net' : 'Patrimoine brut',
          ).semiBold().large(),
          popup: (context) => SelectPopup(
            items: SelectItemList(
              children: [
                SelectItemButton(
                  value: PatrimoineKind.net,
                  child: const shadcn.Text('Patrimoine net'),
                ),
                SelectItemButton(
                  value: PatrimoineKind.brut,
                  child: const shadcn.Text('Patrimoine brut'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          tooltip: (context) => const TooltipContainer(
            child: SizedBox(
              width: 260,
              child: shadcn.Text(
                'Rendement calculé en tenant compte du montant et de la '
                'date de chaque versement (méthode MWR) : il reflète le '
                'rendement réellement perçu.',
              ),
            ),
          ),
          child: Icon(
            LucideIcons.info,
            size: 15,
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// Sélection multiple parmi [options] : une case peut être cochée/décochée
/// librement, avec un point coloré en légende — même couleur que la bande
/// empilée correspondante dans [StackedNetWorthChart]. Quand toutes les
/// couches sont sélectionnées, l'ancre affiche "Tout" plutôt que la liste
/// des libellés.
class CategoryMultiSelect extends StatelessWidget {
  final List<ChartLayer> options;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const CategoryMultiSelect({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
  });

  static Iterable<String>? _toggle(
    Iterable<String>? oldValue,
    Object? newValue,
    bool selected,
  ) {
    if (newValue == null) return oldValue;
    final current = (oldValue ?? const <String>[]).toSet();
    if (selected) {
      current.add(newValue as String);
    } else {
      current.remove(newValue);
    }
    return current.isEmpty ? null : current;
  }

  static bool _isSelected(Iterable<String>? value, Object? test) {
    if (value == null || test == null) return false;
    return value.contains(test);
  }

  bool _isSelectable(Object? id) {
    for (final option in options) {
      if (option.id == id) return option.selectable;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Select<Iterable<String>>(
      value: selectedIds,
      canUnselect: true,
      autoClosePopover: false,
      constraints: const BoxConstraints(minWidth: 180),
      // Une classe non sélectionnable ne peut jamais être ajoutée à la
      // sélection (le bouton popup est en plus désactivé, voir plus bas) —
      // sa désélection reste possible si elle y figurait déjà.
      valueSelectionHandler: (oldValue, newValue, selected) {
        if (selected && !_isSelectable(newValue)) return oldValue;
        return _toggle(oldValue, newValue, selected);
      },
      valueSelectionPredicate: _isSelected,
      onChanged: (next) {
        if (next == null || next.isEmpty) return;
        onChanged(next.toSet());
      },
      itemBuilder: (context, value) {
        final ids = value.toSet();
        if (ids.length == options.length) {
          return shadcn.Text('Tout').small();
        }
        final labels = [
          for (final o in options)
            if (ids.contains(o.id)) o.label,
        ];
        return shadcn.Text(
          labels.length <= 2 ? labels.join(', ') : '${labels.length} classes',
        ).small();
      },
      popup: (context) => SelectPopup(
        items: SelectItemList(
          children: [
            for (final o in options)
              SelectItemButton(
                value: o.id,
                enabled: o.selectable,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: o.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    shadcn.Text(o.label),
                    if (!o.selectable) ...[
                      const SizedBox(width: 6),
                      shadcn.Text('(vide)').muted().xSmall(),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptySelectionAmount extends StatelessWidget {
  const EmptySelectionAmount({super.key});

  @override
  Widget build(BuildContext context) {
    return shadcn.Text(
      'Pas assez de données sur cette période',
    ).muted().small();
  }
}

/// Plus-value en % entre le premier et le dernier point d'une période —
/// `null` s'il n'y a pas assez de points ou si le point de départ est
/// négatif ou nul : diviser par une valeur de départ non positive
/// produirait un pourcentage sans signification, même quand la variation
/// absolue (`last.value - first.value`) est parfaitement lisible et
/// positive (ex : un patrimoine net qui repart d'une valeur négative en
/// tout début d'historique — un prêt souscrit avant que les actifs
/// n'existent encore). Voir [PeriodChangeRow], qui affiche ce pourcentage
/// sans jamais s'en servir pour la couleur/icône de tendance (dérivées de
/// la variation absolue, toujours définie) — et [isExtremeChangePercent],
/// qui signale (sans le masquer) le cas où le point de départ est si
/// petit devant l'écart final que ce pourcentage n'a plus rien d'un
/// "rendement" lisible.
double? changePercentFor(List<NetWorthPoint> points) {
  if (points.length < 2) return null;
  final first = points.first.value;
  if (first <= 0) return null;
  return (points.last.value - first) / first * 100;
}

/// `true` quand [percent] est démesuré au point de ne plus représenter un
/// "rendement" lisible — typiquement "Tout" sur une catégorie dont la
/// toute première transaction est minime : un versement ultérieur, même
/// modeste, y apparaît comme une hausse de plusieurs milliers de %, alors
/// qu'il s'agit surtout de capital ajouté, pas de plus-value. Les
/// affichages de pourcentage de période (voir [PeriodChangeRow],
/// [ExtremePercentLabel]) continuent de l'afficher (pas de valeur plus
/// honnête à montrer à la place — l'évolution en euros seule perdrait
/// l'information de sens) mais en couleur plus transparente, avec une
/// explication au survol, plutôt que de le laisser passer pour un taux
/// normal ou de le masquer entièrement.
bool isExtremeChangePercent(double percent) => percent.abs() > 1000;

/// Texte "+X,XX %"/"-X,XX %" — même traitement que la partie "(±X %)" de
/// [PeriodChangeRow] pour un pourcentage affiché seul (pas accolé à un
/// montant en euros) : couleur pleine tant que [percent] reste plausible,
/// plus transparente avec une explication au survol quand
/// [isExtremeChangePercent] est vrai. Utilisé par exemple par "Mes
/// meilleures performances" (`top_assets_row.dart`), dont chaque carte
/// n'affiche le pourcentage qu'en complément du montant, pas dans le même
/// texte.
class ExtremePercentLabel extends StatelessWidget {
  final double percent;
  final Color color;
  final TextStyle? style;

  const ExtremePercentLabel({
    super.key,
    required this.percent,
    required this.color,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final extreme = isExtremeChangePercent(percent);
    final positive = percent >= 0;
    final label = shadcn.Text(
      '${positive ? '+' : ''}${percent.toStringAsFixed(2)} %',
      style: (style ?? const TextStyle()).copyWith(
        color: extreme ? color.withValues(alpha: 0.45) : color,
      ),
    );
    if (!extreme) return label;
    return Tooltip(
      tooltip: (context) => const TooltipContainer(
        child: SizedBox(
          width: 260,
          child: shadcn.Text(
            'Pourcentage énorme car la période démarre avec un montant '
            'très faible (ex : toute première transaction minime) — '
            'l\'essentiel de la hausse vient surtout de versements '
            'ajoutés depuis, pas d\'une vraie plus-value.',
          ),
        ),
      ),
      child: label,
    );
  }
}

/// Ligne "+1 234 € (+4,56 %)" affichée sous le montant total — évolution
/// absolue puis relative sur la période sélectionnée (les onglets de
/// [PeriodTabs]). Le texte omet la parenthèse quand [changePercent] est
/// `null` (voir [changePercentFor]) plutôt que d'afficher un pourcentage
/// trompeur ; quand il est démesuré (voir [isExtremeChangePercent]), seule
/// la partie "(±X %)" passe en couleur plus transparente (le montant en
/// euros garde sa couleur pleine) — avec une explication au survol —
/// plutôt que de le laisser passer pour un taux normal ou de le masquer
/// entièrement. [color]/[icon] restent au choix de l'appelant — toujours
/// dérivés du signe de [absoluteChange], jamais de [changePercent] — pour
/// rester cohérents avec les constantes `_green`/`_red` déjà définies
/// localement dans chaque carte.
class PeriodChangeRow extends StatelessWidget {
  final double absoluteChange;
  final double? changePercent;
  final bool hidden;
  final Color color;
  final IconData icon;

  const PeriodChangeRow({
    super.key,
    required this.absoluteChange,
    required this.changePercent,
    required this.hidden,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final percent = changePercent;
    final euroText = displayEuros(absoluteChange, hidden);
    final baseStyle = Theme.of(
      context,
    ).typography.small.copyWith(color: color, fontWeight: FontWeight.w600);

    Widget label;
    var extreme = false;
    if (percent == null) {
      label = shadcn.Text(euroText, style: baseStyle);
    } else {
      extreme = isExtremeChangePercent(percent);
      label = RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: euroText),
            TextSpan(
              text: ' (${displayPercent(percent)})',
              style: extreme
                  ? baseStyle.copyWith(color: color.withValues(alpha: 0.45))
                  : null,
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        extreme
            ? Tooltip(
                tooltip: (context) => const TooltipContainer(
                  child: SizedBox(
                    width: 260,
                    child: shadcn.Text(
                      'Pourcentage énorme car la période démarre avec un '
                      'montant très faible (ex : toute première '
                      'transaction minime) — l\'essentiel de la hausse '
                      'vient surtout de versements ajoutés depuis, pas '
                      'd\'une vraie plus-value.',
                    ),
                  ),
                ),
                child: label,
              )
            : label,
      ],
    );
  }
}

/// Couleur de la courbe "Patrimoine net" — le doré d'accent du thème
/// (`_accent` dans `app/theme.dart`, identique en clair et en sombre),
/// pas une couleur orangée indépendante comme avant.
const netWorthColor = Color(0xFFF4BE7E);

/// Données prêtes à l'emploi pour [StackedNetWorthChart] (mode Valeur),
/// résultant de la sélection Patrimoine net/brut.
class PatrimoineChartData {
  final List<DateTime> dates;
  final List<ChartLayer> layers;
  final List<List<double>> layerValues;
  final List<List<double>> cumulativeTop;
  final List<NetWorthPoint> totalPoints;

  const PatrimoineChartData({
    required this.dates,
    required this.layers,
    required this.layerValues,
    required this.cumulativeTop,
    required this.totalPoints,
  });
}

/// Règle métier commune aux cartes Patrimoine pour le mode Valeur :
///  - **Patrimoine net** : une seule courbe dorée "Patrimoine net" qui vaut
///    à chaque instant la somme des actifs moins la somme des passifs. La
///    sélection multi-classes n'a pas d'effet dans ce mode — toutes les
///    classes sont toujours incluses. Une courbe nette prédéfinie peut être
///    fournie via [netSeriesOverride] plutôt que d'être dérivée par
///    soustraction, si l'appelant en dispose déjà.
///  - **Patrimoine brut** : uniquement les actifs sélectionnés, empilés
///    dans leurs couleurs respectives — les passifs n'apparaissent jamais.
///
/// Les classes sans historique sur la période sont écartées des deux modes.
PatrimoineChartData buildPatrimoineChartData({
  required PatrimoineKind kind,
  required List<ChartLayer> allLayers,
  required List<List<NetWorthPoint>> allSeries,
  required Set<String> selectedIds,
  List<NetWorthPoint>? passifSeries,
  List<NetWorthPoint>? netSeriesOverride,
}) {
  final net = kind == PatrimoineKind.net;

  // Séries sources : toutes les classes d'actif pour le net, uniquement la
  // sélection pour le brut.
  final assetEntries = <(ChartLayer, List<NetWorthPoint>)>[
    for (var i = 0; i < allLayers.length; i++)
      if (net || selectedIds.contains(allLayers[i].id))
        (allLayers[i], allSeries[i]),
  ]..removeWhere((entry) => entry.$2.isEmpty);

  final pointCount = assetEntries.isEmpty ? 0 : assetEntries.first.$2.length;
  final dates = <DateTime>[
    for (final point in assetEntries.isEmpty
        ? const <NetWorthPoint>[]
        : assetEntries.first.$2)
      point.date,
  ];

  // Pile cumulative des actifs (la base de la première couche est zéro).
  final assetCumulativeTop = List<List<double>>.generate(
    assetEntries.length,
    (_) => List<double>.filled(pointCount, 0.0),
  );
  for (var li = 0; li < assetEntries.length; li++) {
    for (var i = 0; i < pointCount; i++) {
      assetCumulativeTop[li][i] =
          (li == 0 ? 0.0 : assetCumulativeTop[li - 1][i]) +
          assetEntries[li].$2[i].value;
    }
  }

  if (net) {
    // Une seule courbe dorée : la somme des actifs moins la somme des
    // passifs à chaque instant — ou la série nette fournie telle quelle.
    final netSeries = netSeriesOverride ??
        <NetWorthPoint>[
          for (var i = 0; i < pointCount; i++)
            NetWorthPoint(
              dates[i],
              (assetCumulativeTop.isEmpty ? 0.0 : assetCumulativeTop.last[i]) -
                  (passifSeries != null && passifSeries.length == pointCount
                      ? passifSeries[i].value
                      : 0.0),
            ),
        ];
    return PatrimoineChartData(
      dates: [for (final point in netSeries) point.date],
      layers: const [
        ChartLayer(
          id: '_patrimoine_net',
          label: 'Patrimoine net',
          color: netWorthColor,
        ),
      ],
      layerValues: [
        [for (final point in netSeries) point.value],
      ],
      cumulativeTop: [
        [for (final point in netSeries) point.value],
      ],
      totalPoints: netSeries,
    );
  }

  // Brut : les actifs sélectionnés empilés dans leurs couleurs, sans passifs.
  return PatrimoineChartData(
    dates: dates,
    layers: [for (final entry in assetEntries) entry.$1],
    layerValues: [
      for (final entry in assetEntries) [for (final p in entry.$2) p.value],
    ],
    cumulativeTop: assetCumulativeTop,
    totalPoints: [
      for (var i = 0; i < pointCount; i++)
        NetWorthPoint(
          dates[i],
          assetCumulativeTop.isEmpty ? 0 : assetCumulativeTop.last[i],
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Graphique empilé (mode Valeur) : toutes les courbes cumulées restent
// visibles dans leur couleur. La zone d'une couche est strictement comprise
// entre sa courbe et celle de la couche située juste en dessous.
// ---------------------------------------------------------------------------

class StackedNetWorthChart extends StatefulWidget {
  final List<DateTime> dates;
  final List<ChartLayer> layers;
  final List<List<double>> layerValues;
  final List<List<double>> cumulativeTop;
  final bool hidden;
  final Color gridColor;
  final Color textColor;
  final Color markerColor;

  const StackedNetWorthChart({
    super.key,
    required this.dates,
    required this.layers,
    required this.layerValues,
    required this.cumulativeTop,
    required this.hidden,
    required this.gridColor,
    required this.textColor,
    required this.markerColor,
  });

  @override
  State<StackedNetWorthChart> createState() => _StackedNetWorthChartState();
}

class _StackedNetWorthChartState extends State<StackedNetWorthChart> {
  int? _hoveredIndex;

  void _updateHover(Offset localPosition, double width) {
    final count = widget.dates.length;
    if (count < 2) return;
    final plotWidth = math.max(1.0, width - chartLeftAxisWidth);
    final fraction = ((localPosition.dx - chartLeftAxisWidth) / plotWidth)
        .clamp(0.0, 1.0);
    final index = (fraction * (count - 1)).round().clamp(0, count - 1);
    if (index != _hoveredIndex) setState(() => _hoveredIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dates.length < 2 || widget.layers.isEmpty) {
      return const Center(child: EmptySelectionAmount());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onHover: (event) => _updateHover(event.localPosition, size.width),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: GestureDetector(
            onPanDown: (d) => _updateHover(d.localPosition, size.width),
            onPanUpdate: (d) => _updateHover(d.localPosition, size.width),
            onPanEnd: (_) => setState(() => _hoveredIndex = null),
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _StackedChartPainter(
                    dates: widget.dates,
                    layers: widget.layers,
                    cumulativeTop: widget.cumulativeTop,
                    hidden: widget.hidden,
                    gridColor: widget.gridColor,
                    textColor: widget.textColor,
                    markerColor: widget.markerColor,
                    hoveredIndex: _hoveredIndex,
                  ),
                ),
                if (_hoveredIndex != null)
                  Positioned(
                    left: _tooltipLeft(size.width),
                    top: 0,
                    child: IgnorePointer(
                      child: _StackedChartTooltip(
                        date: widget.dates[_hoveredIndex!],
                        layers: widget.layers,
                        valuesAtIndex: [
                          for (final layer in widget.layerValues)
                            layer[_hoveredIndex!],
                        ],
                        total: widget.cumulativeTop.last[_hoveredIndex!],
                        hidden: widget.hidden,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _tooltipLeft(double width) {
    if (_hoveredIndex == null || widget.dates.length < 2) return 0;
    final plotWidth = math.max(1.0, width - chartLeftAxisWidth);
    final x =
        chartLeftAxisWidth +
        plotWidth * (_hoveredIndex! / (widget.dates.length - 1));
    return (x - 100).clamp(0.0, math.max(0.0, width - 200));
  }
}

class _StackedChartTooltip extends StatelessWidget {
  final DateTime date;
  final List<ChartLayer> layers;
  final List<double> valuesAtIndex;
  final double total;
  final bool hidden;

  const _StackedChartTooltip({
    required this.date,
    required this.layers,
    required this.valuesAtIndex,
    required this.total,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.card.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              shadcn.Text(formatChartTooltipDate(date)).muted().xSmall(),
              shadcn.Text(
                displayEuros(total, hidden),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ).small(),
              const SizedBox(height: 6),
              for (var i = 0; i < layers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: layers[i].color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      shadcn.Text(layers[i].label).muted().xSmall(),
                      const SizedBox(width: 8),
                      shadcn.Text(
                        displayEuros(valuesAtIndex[i], hidden),
                      ).xSmall(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StackedChartPainter extends CustomPainter {
  final List<DateTime> dates;
  final List<ChartLayer> layers;
  final List<List<double>> cumulativeTop;
  final bool hidden;
  final Color gridColor;
  final Color textColor;
  final Color markerColor;
  final int? hoveredIndex;

  _StackedChartPainter({
    required this.dates,
    required this.layers,
    required this.cumulativeTop,
    required this.hidden,
    required this.gridColor,
    required this.textColor,
    required this.markerColor,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomAxisHeight = 20.0;
    final chartWidth = math.max(0.0, size.width - chartLeftAxisWidth);
    final chartHeight = math.max(0.0, size.height - bottomAxisHeight);
    final pointCount = dates.length;
    // L'échelle doit contenir chaque courbe — pas seulement le total — afin
    // que les lignes des couches inférieures ne soient jamais coupées. La
    // base de la première couche est 0, elle doit donc figurer dans la plage.
    final chartValues = <double>[
      0,
      for (final series in cumulativeTop) ...series,
    ];
    final maxValue = chartValues.reduce(math.max);
    final minValue = chartValues.reduce(math.min);
    final range = (maxValue - minValue).abs() < 1 ? 1.0 : maxValue - minValue;

    const topMargin = 8.0;
    final plotHeight = math.max(0.0, chartHeight - topMargin);

    double xFor(int i) =>
        chartLeftAxisWidth + chartWidth * (i / (pointCount - 1));
    double yFor(double value) =>
        topMargin + plotHeight - ((value - minValue) / range) * plotHeight;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topMargin + plotHeight * (i / 2);
      drawDashedLine(
        canvas,
        Offset(chartLeftAxisWidth, y),
        Offset(chartLeftAxisWidth + chartWidth, y),
        gridPaint,
      );
      drawAxisLabel(
        canvas,
        displayEurosCompact(maxValue - (maxValue - minValue) * (i / 2), hidden),
        y,
        textColor,
      );
    }

    // Dessiner tous les dégradés avant les traits : aucune aire ne masque la
    // courbe colorée d'une autre couche.
    for (var li = 0; li < layers.length; li++) {
      final fillPath = Path();
      for (var i = 0; i < pointCount; i++) {
        final point = Offset(xFor(i), yFor(cumulativeTop[li][i]));
        if (i == 0) {
          fillPath.moveTo(point.dx, point.dy);
        } else {
          fillPath.lineTo(point.dx, point.dy);
        }
      }
      // Referme la bande sur la courbe de la couche précédente. Pour la
      // première couche, la courbe située "en dessous" est le bas du
      // graphique (valeur minimale) — pas la ligne zéro : quand le
      // patrimoine net est négatif (passifs supérieurs aux actifs), la
      // ligne zéro passe au-dessus de la courbe et la bande (donc le
      // dégradé, plus opaque en haut) se retrouverait au-dessus d'elle.
      for (var i = pointCount - 1; i >= 0; i--) {
        final lowerValue = li == 0 ? minValue : cumulativeTop[li - 1][i];
        fillPath.lineTo(xFor(i), yFor(lowerValue));
      }
      fillPath.close();
      // La couleur est la plus présente près de sa courbe, puis devient de
      // plus en plus transparente vers la courbe inférieure.
      final bounds = fillPath.getBounds();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, bounds.top),
            Offset(0, bounds.bottom),
            [
              layers[li].color.withValues(alpha: 0.42),
              layers[li].color.withValues(alpha: 0.05),
            ],
          ),
      );
    }

    // Puis toutes les courbes, dans leur couleur respective.
    for (var li = 0; li < layers.length; li++) {
      final strokePath = Path();
      for (var i = 0; i < pointCount; i++) {
        final point = Offset(xFor(i), yFor(cumulativeTop[li][i]));
        if (i == 0) {
          strokePath.moveTo(point.dx, point.dy);
        } else {
          strokePath.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        strokePath,
        Paint()
          ..color = layers[li].color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    drawDateLabel(
      canvas,
      dates.first,
      xFor(0),
      chartHeight,
      TextAlign.left,
      textColor,
    );
    drawDateLabel(
      canvas,
      dates[pointCount ~/ 2],
      xFor(pointCount ~/ 2),
      chartHeight,
      TextAlign.center,
      textColor,
    );
    drawDateLabel(
      canvas,
      dates.last,
      xFor(pointCount - 1),
      chartHeight,
      TextAlign.right,
      textColor,
    );

    if (hoveredIndex != null) {
      final x = xFor(hoveredIndex!);
      final dashPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      drawDashedLine(canvas, Offset(x, 0), Offset(x, chartHeight), dashPaint);
      for (var li = 0; li < layers.length; li++) {
        final point = Offset(x, yFor(cumulativeTop[li][hoveredIndex!]));
        canvas.drawCircle(point, 4, Paint()..color = layers[li].color);
        canvas.drawCircle(
          point,
          4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StackedChartPainter oldDelegate) {
    return oldDelegate.dates != dates ||
        oldDelegate.cumulativeTop != cumulativeTop ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

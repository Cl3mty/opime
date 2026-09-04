import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../l10n/app_localizations.dart';
import 'budget_tracking_models.dart';
import 'sankey_diagram.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Palette cyclique pour distinguer chaque source de revenu quand il y en
/// a plusieurs — même principe que `BudgetSankeyChart` (`budget_sankey.dart`).
const _revenuePalette = [
  Color(0xFF22C55E),
  Color(0xFF16A34A),
  Color(0xFF4ADE80),
  Color(0xFF15803D),
  Color(0xFF86EFAC),
  Color(0xFF166534),
];

/// Flux réel du mois suivi (Suivi des budgets, `budget_tracking_screen.dart`) :
/// Revenus (une branche par source si plusieurs, même principe que
/// `BudgetSankeyChart`) → une branche par catégorie de la page (Factures,
/// Dépenses, Invest/Épargne, Projets, Dettes) → catégorisation par poste
/// pour Factures/Dépenses (seules à proposer un [TrackingItem.category] sur
/// cet écran, voir `_CategoryCard`), poste directement pour les 3 autres.
/// Basé sur les montants Réalité (l'argent effectivement suivi ce mois-ci),
/// pas Budget — construit ses [SankeyNode]/[SankeyLink] puis délègue la
/// mise en page/le rendu à [SankeyDiagram] (moteur partagé avec
/// `BudgetSankeyChart`).
class BudgetTrackingSankeyChart extends StatelessWidget {
  final BudgetTrackingMonth data;
  final bool hidden;

  const BudgetTrackingSankeyChart({
    super.key,
    required this.data,
    this.hidden = false,
  });

  double _realiteSum(List<TrackingItem> items) =>
      items.fold(0.0, (sum, i) => sum + i.realite);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalRevenues = _realiteSum(data.revenues);
    final buckets = [
      data.factures,
      data.depenses,
      data.investEpargnes,
      data.projets,
      data.dettes,
    ];
    final hasAnyFlow =
        totalRevenues > 0 || buckets.any((b) => _realiteSum(b) > 0);

    if (!hasAnyFlow) {
      return SankeyDiagram(
        nodes: const [],
        links: const [],
        hidden: hidden,
        emptyMessage: l10n.budget_tracking_sankey_empty_message,
      );
    }

    final accent = Theme.of(context).colorScheme.primary;
    final nodes = <SankeyNode>[];
    final links = <SankeyLink>[];

    // Même logique que `BudgetSankeyChart` : plusieurs revenus deviennent
    // chacun leur propre branche fusionnant dans "Revenus", un seul revenu
    // n'ajoute pas de colonne inutile.
    final positiveRevenues = [
      for (final r in data.revenues)
        if (r.realite > 0) r,
    ];
    final fanOutRevenues = positiveRevenues.length > 1;
    final revenueColumnOffset = fanOutRevenues ? 1 : 0;
    final bucketColumn = 1 + revenueColumnOffset;

    // Si les 5 catégories de sorties dépassent les revenus (budget en
    // déficit), le nœud "Revenus" doit rester assez grand pour laisser
    // passer ces sorties (voir `minValue`) sans jamais faire croire, dans
    // son libellé, que les revenus valent ce montant plus élevé — d'où
    // `displayValue`/`deficit`, voir leur doc dans `sankey_diagram.dart`.
    final totalOut = buckets.fold(0.0, (sum, b) => sum + _realiteSum(b));
    final revenusNode = SankeyNode(
      label: l10n.budget_tab_revenues,
      column: revenueColumnOffset,
      color: _green,
      minValue: totalRevenues,
      displayValue: totalRevenues,
      deficit: totalOut > totalRevenues ? totalOut - totalRevenues : 0,
    );
    nodes.add(revenusNode);

    if (fanOutRevenues) {
      for (var i = 0; i < positiveRevenues.length; i++) {
        final revenue = positiveRevenues[i];
        final revenueNode = SankeyNode(
          label: revenue.name.isEmpty
              ? l10n.budget_sankey_revenue_fallback
              : revenue.name,
          column: 0,
          color: _revenuePalette[i % _revenuePalette.length],
        );
        nodes.add(revenueNode);
        links.add(
          SankeyLink(
            source: revenueNode,
            target: revenusNode,
            value: revenue.realite,
          ),
        );
      }
    }

    void addCategorizedBucket(
      String label,
      List<TrackingItem> items,
      Color color,
    ) {
      final total = _realiteSum(items);
      if (total <= 0) return;
      final bucketNode = SankeyNode(
        label: label,
        column: bucketColumn,
        color: color,
      );
      nodes.add(bucketNode);
      links.add(
        SankeyLink(source: revenusNode, target: bucketNode, value: total),
      );

      final byCategory = <String, List<TrackingItem>>{};
      for (final item in items) {
        if (item.realite <= 0) continue;
        final key = item.category.isEmpty
            ? l10n.budget_sankey_uncategorized
            : item.category;
        byCategory.putIfAbsent(key, () => []).add(item);
      }
      for (final entry in byCategory.entries) {
        final sum = _realiteSum(entry.value);
        final catNode = SankeyNode(
          label: entry.key,
          column: bucketColumn + 1,
          color: color,
        );
        nodes.add(catNode);
        links.add(SankeyLink(source: bucketNode, target: catNode, value: sum));
        for (final item in entry.value) {
          final itemNode = SankeyNode(
            label: item.name.isEmpty ? label : item.name,
            column: bucketColumn + 2,
            color: color,
          );
          nodes.add(itemNode);
          links.add(
            SankeyLink(source: catNode, target: itemNode, value: item.realite),
          );
        }
      }
    }

    void addFlatBucket(String label, List<TrackingItem> items, Color color) {
      final total = _realiteSum(items);
      if (total <= 0) return;
      final bucketNode = SankeyNode(
        label: label,
        column: bucketColumn,
        color: color,
      );
      nodes.add(bucketNode);
      links.add(
        SankeyLink(source: revenusNode, target: bucketNode, value: total),
      );
      for (final item in items) {
        if (item.realite <= 0) continue;
        final itemNode = SankeyNode(
          label: item.name.isEmpty ? label : item.name,
          column: bucketColumn + 1,
          color: color,
        );
        nodes.add(itemNode);
        links.add(
          SankeyLink(source: bucketNode, target: itemNode, value: item.realite),
        );
      }
    }

    // Seules Factures et Dépenses proposent une catégorisation par poste
    // dans Suivi (voir `_CategoryCard`) : les autres branches restent à
    // plat, un poste directement relié à sa catégorie de la page.
    addCategorizedBucket(l10n.budget_bucket_factures, data.factures, _red);
    addCategorizedBucket(l10n.budget_tab_expenses, data.depenses, _red);
    addFlatBucket(
      l10n.budget_bucket_invest_epargne,
      data.investEpargnes,
      accent,
    );
    addFlatBucket(l10n.nav_projects, data.projets, _red);
    addFlatBucket(l10n.budget_bucket_dettes, data.dettes, _red);

    return SankeyDiagram(nodes: nodes, links: links, hidden: hidden);
  }
}

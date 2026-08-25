import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'budget_models.dart';
import 'sankey_diagram.dart';

/// Palette cyclique pour distinguer chaque source de revenu quand il y en
/// a plusieurs (voir [BudgetSankeyChart]) — variations de vert, cohérentes
/// avec la couleur "revenus" déjà utilisée pour le nœud agrégé et les
/// autres graphiques du budget.
const _revenuePalette = [
  Color(0xFF22C55E),
  Color(0xFF16A34A),
  Color(0xFF4ADE80),
  Color(0xFF15803D),
  Color(0xFF86EFAC),
  Color(0xFF166534),
];

/// Ventilation du budget prévisionnel (`budget_screen.dart`) en diagramme
/// de flux : Revenus (une branche par source si plusieurs) → Dépenses/
/// Investissements → catégorie → poste — construit ses [SankeyNode]/
/// [SankeyLink] depuis [BudgetData] puis délègue la mise en page/le rendu
/// à [SankeyDiagram] (moteur partagé avec `BudgetTrackingSankeyChart`, voir
/// `budget_tracking_sankey.dart`).
class BudgetSankeyChart extends StatelessWidget {
  final BudgetData data;
  final bool hidden;
  const BudgetSankeyChart({super.key, required this.data, this.hidden = false});

  @override
  Widget build(BuildContext context) {
    final totalRevenues = data.totalRevenues;
    final totalExpenses = data.totalExpenses;
    final totalInvestments = data.totalInvestments;

    if (totalRevenues == 0 && totalExpenses == 0 && totalInvestments == 0) {
      return SankeyDiagram(
        nodes: const [],
        links: const [],
        hidden: hidden,
        emptyMessage:
            'Ajoute des revenus, dépenses ou investissements pour voir le '
            'flux.',
      );
    }

    final green = const Color(0xFF22C55E);
    final red = const Color(0xFFEF4444);
    final accent = Theme.of(context).colorScheme.primary;

    final nodes = <SankeyNode>[];
    final links = <SankeyLink>[];

    // Plusieurs revenus (salaire + freelance + loyers perçus...) : chacun
    // devient sa propre branche, fusionnant dans le nœud "Revenus" agrégé
    // — une colonne de plus tout à gauche, plutôt qu'un seul revenu
    // muet qui ne montrerait jamais d'où vient l'argent. Un seul revenu
    // (le cas courant) garde le graphique tel qu'avant : une branche de
    // plus n'apporterait rien de plus qu'un doublon du nœud "Revenus".
    final positiveRevenues = [
      for (final r in data.revenues)
        if (r.amount > 0) r,
    ];
    final fanOutRevenues = positiveRevenues.length > 1;
    final revenueColumnOffset = fanOutRevenues ? 1 : 0;

    // Pas de nœud "Disponible" séparé : un versement non dépensé/investi
    // ne va nulle part d'autre que rester dans "Revenus", qui porte donc
    // déjà tout ce que "Disponible" représenterait — une colonne de plus
    // ne ferait que répéter le même montant sans ajouter d'information.
    //
    // Si les dépenses + investissements dépassent les revenus (budget en
    // déficit), le nœud "Revenus" doit rester assez grand pour laisser
    // passer ces sorties (voir `minValue`) sans jamais faire croire, dans
    // son libellé, que les revenus valent ce montant plus élevé — d'où
    // `displayValue`/`deficit`, qui gardent le vrai montant des revenus
    // affiché, avec le déficit signalé à part.
    final totalOut = totalExpenses + totalInvestments;
    final revenusNode = SankeyNode(
      label: 'Revenus',
      column: revenueColumnOffset,
      color: green,
      minValue: totalRevenues,
      displayValue: totalRevenues,
      deficit: totalOut > totalRevenues ? totalOut - totalRevenues : 0,
    );
    nodes.add(revenusNode);

    if (fanOutRevenues) {
      for (var i = 0; i < positiveRevenues.length; i++) {
        final revenue = positiveRevenues[i];
        final revenueNode = SankeyNode(
          label: revenue.name.isEmpty ? 'Revenu' : revenue.name,
          column: 0,
          color: _revenuePalette[i % _revenuePalette.length],
        );
        nodes.add(revenueNode);
        links.add(
          SankeyLink(
            source: revenueNode,
            target: revenusNode,
            value: revenue.amount,
          ),
        );
      }
    }

    if (totalExpenses > 0) {
      final depensesNode = SankeyNode(
        label: 'Dépenses',
        column: 1 + revenueColumnOffset,
        color: red,
      );
      nodes.add(depensesNode);
      links.add(
        SankeyLink(
          source: revenusNode,
          target: depensesNode,
          value: totalExpenses,
        ),
      );

      for (final category in data.expenseCategories) {
        final sum = category.items.fold<double>(0, (s, i) => s + i.amount);
        if (sum <= 0) continue;
        final catNode = SankeyNode(
          label: category.name.isEmpty ? 'Sans catégorie' : category.name,
          column: 2 + revenueColumnOffset,
          color: red,
        );
        nodes.add(catNode);
        links.add(SankeyLink(source: depensesNode, target: catNode, value: sum));
        for (final item in category.items) {
          if (item.amount <= 0) continue;
          final itemNode = SankeyNode(
            label: item.name.isEmpty ? 'Dépense' : item.name,
            column: 3 + revenueColumnOffset,
            color: red,
          );
          nodes.add(itemNode);
          links.add(
            SankeyLink(source: catNode, target: itemNode, value: item.amount),
          );
        }
      }
    }

    if (totalInvestments > 0) {
      final investNode = SankeyNode(
        label: 'Investissements',
        column: 1 + revenueColumnOffset,
        color: accent,
      );
      nodes.add(investNode);
      links.add(
        SankeyLink(
          source: revenusNode,
          target: investNode,
          value: totalInvestments,
        ),
      );

      for (final category in data.investmentCategories) {
        final sum = category.items.fold<double>(0, (s, i) => s + i.amount);
        if (sum <= 0) continue;
        final catNode = SankeyNode(
          label: category.name.isEmpty ? 'Sans catégorie' : category.name,
          column: 2 + revenueColumnOffset,
          color: accent,
        );
        nodes.add(catNode);
        links.add(SankeyLink(source: investNode, target: catNode, value: sum));
        for (final item in category.items) {
          if (item.amount <= 0) continue;
          final itemNode = SankeyNode(
            label: item.name.isEmpty ? 'Investissement' : item.name,
            column: 3 + revenueColumnOffset,
            color: accent,
          );
          nodes.add(itemNode);
          links.add(
            SankeyLink(source: catNode, target: itemNode, value: item.amount),
          );
        }
      }
    }

    return SankeyDiagram(nodes: nodes, links: links, hidden: hidden);
  }
}

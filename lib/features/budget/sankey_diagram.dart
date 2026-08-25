import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors, Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';

/// Nœud générique d'un diagramme de flux (Sankey) — appartient à une
/// [column] (position horizontale), avec une couleur et un [minValue]
/// (plancher pour [value], voir sa doc). [value]/[x0]/[x1]/[y0]/[y1] sont
/// calculés par [SankeyDiagram] lors de la mise en page ; ne pas les
/// renseigner soi-même à la construction.
class SankeyNode {
  final String label;
  final int column;
  final Color color;

  /// Plancher pour [value] — utile pour un nœud racine (ex : "Revenus")
  /// dont le montant se déduirait sinon uniquement de ses liens
  /// entrants/sortants : sans rien de catégorisé en aval ni plusieurs
  /// sources en amont, il afficherait un nœud invisible (hauteur nulle)
  /// plutôt que le vrai montant total. Sert aussi, à l'inverse, à garder
  /// le nœud assez grand pour que des sorties supérieures à ce montant
  /// (budget en déficit, voir [deficit]) ne débordent pas visuellement de
  /// sa hauteur.
  final double minValue;

  /// Montant à afficher dans le libellé du nœud, si différent de [value]
  /// (calculée par la mise en page à partir des flux entrants/sortants,
  /// voir [SankeyDiagram._layout]). Nécessaire pour un nœud comme
  /// "Revenus" : quand les sorties dépassent les revenus (budget en
  /// déficit), [value] doit rester égale aux sorties pour que leurs liens
  /// tiennent dans le nœud sans déborder — mais le libellé, lui, doit
  /// toujours annoncer le vrai montant des revenus, jamais celui, plus
  /// grand et trompeur, des sorties. `null` (par défaut) affiche [value]
  /// tel quel.
  final double? displayValue;

  /// Portion de [value] non couverte par [displayValue] (ex : des
  /// dépenses supérieures aux revenus du mois) — signalée dans le libellé
  /// du nœud plutôt que laissée invisible dans un nœud simplement plus
  /// haut que son montant annoncé. `0` (par défaut) : aucun déficit.
  final double deficit;

  double value = 0;
  double x0 = 0, x1 = 0, y0 = 0, y1 = 0;

  SankeyNode({
    required this.label,
    required this.column,
    required this.color,
    this.minValue = 0,
    this.displayValue,
    this.deficit = 0,
  });
}

class SankeyLink {
  final SankeyNode source;
  final SankeyNode target;
  final double value;
  double sourceY = 0;
  double targetY = 0;
  double thickness = 0;

  SankeyLink({required this.source, required this.target, required this.value});
}

/// Moteur de mise en page et de rendu d'un diagramme de flux (Sankey),
/// partagé entre `BudgetSankeyChart` (ventilation du budget prévisionnel,
/// `budget_sankey.dart`) et `BudgetTrackingSankeyChart` (flux réel du mois
/// suivi, `budget_tracking_sankey.dart`) : chacun construit ses propres
/// [SankeyNode]/[SankeyLink] depuis son propre modèle de données, puis
/// délègue ici la disposition par colonne et le dessin des courbes — évite
/// de dupliquer ce moteur entre les deux écrans.
class SankeyDiagram extends StatelessWidget {
  final List<SankeyNode> nodes;
  final List<SankeyLink> links;
  final bool hidden;
  final String emptyMessage;

  const SankeyDiagram({
    super.key,
    required this.nodes,
    required this.links,
    required this.hidden,
    this.emptyMessage = 'Pas encore de données pour ce flux.',
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return SizedBox(
        height: 280,
        child: Center(child: shadcn.Text(emptyMessage).muted()),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final canvasHeight = _layout(nodes, links, width);
        return SizedBox(
          width: width,
          height: canvasHeight,
          child: CustomPaint(
            painter: _SankeyPainter(
              nodes: nodes,
              links: links,
              canvasWidth: width,
              hidden: hidden,
            ),
          ),
        );
      },
    );
  }

  double _layout(List<SankeyNode> nodes, List<SankeyLink> links, double width) {
    const nodeWidth = 10.0;
    const nodePadding = 15.0;
    const pixelsPerEuro = 0.10;

    final maxColumn = nodes
        .map((n) => n.column)
        .reduce((a, b) => a > b ? a : b);
    final columnCount = maxColumn + 1;
    final columnGap =
        (width - nodeWidth) / (columnCount > 1 ? columnCount - 1 : 1);

    for (final node in nodes) {
      final outgoing = links
          .where((l) => l.source == node)
          .fold<double>(0, (s, l) => s + l.value);
      final incoming = links
          .where((l) => l.target == node)
          .fold<double>(0, (s, l) => s + l.value);
      final inferred = outgoing > 0 ? outgoing : incoming;
      node.value = inferred > node.minValue ? inferred : node.minValue;
    }

    final columns = <int, List<SankeyNode>>{};
    for (final node in nodes) {
      columns.putIfAbsent(node.column, () => []).add(node);
    }

    double maxColumnHeight = 300;
    for (final colNodes in columns.values) {
      final totalValue = colNodes.fold<double>(0, (s, n) => s + n.value);
      final colHeight =
          totalValue * pixelsPerEuro + nodePadding * (colNodes.length - 1);
      if (colHeight > maxColumnHeight) maxColumnHeight = colHeight;
    }
    final canvasHeight = maxColumnHeight + nodePadding * 2;

    for (final entry in columns.entries) {
      final col = entry.key;
      final colNodes = entry.value;
      final totalHeight =
          colNodes.fold<double>(0, (s, n) => s + n.value) * pixelsPerEuro +
          nodePadding * (colNodes.length - 1);
      var y = (canvasHeight - totalHeight) / 2;
      final x0 = col * columnGap;
      for (final node in colNodes) {
        node.x0 = x0;
        node.x1 = x0 + nodeWidth;
        node.y0 = y;
        node.y1 = y + node.value * pixelsPerEuro;
        y = node.y1 + nodePadding;
      }
    }

    final sourceCursor = <SankeyNode, double>{};
    final targetCursor = <SankeyNode, double>{};
    for (final link in links) {
      final linkHeight = link.value * pixelsPerEuro;
      link.thickness = linkHeight;

      final so = sourceCursor[link.source] ?? link.source.y0;
      link.sourceY = so + linkHeight / 2;
      sourceCursor[link.source] = so + linkHeight;

      final to = targetCursor[link.target] ?? link.target.y0;
      link.targetY = to + linkHeight / 2;
      targetCursor[link.target] = to + linkHeight;
    }

    return canvasHeight;
  }
}

class _SankeyPainter extends CustomPainter {
  final List<SankeyNode> nodes;
  final List<SankeyLink> links;
  final double canvasWidth;
  final bool hidden;

  static const double _linkGap = 6.0;
  static const double _cornerRadius = 3.0;
  static const double _curvature = 0.55;

  _SankeyPainter({
    required this.nodes,
    required this.links,
    required this.canvasWidth,
    required this.hidden,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      final sourceX = link.source.x1 + _linkGap;
      final targetX = link.target.x0 - _linkGap;
      final sourceY = link.sourceY;
      final targetY = link.targetY;
      final halfWidth = link.thickness / 2;

      final xi = targetX - sourceX;
      final c1 = sourceX + xi * _curvature;
      final c2 = sourceX + xi * (1 - _curvature);

      final path = Path()
        ..moveTo(sourceX, sourceY - halfWidth)
        ..cubicTo(
          c1,
          sourceY - halfWidth,
          c2,
          targetY - halfWidth,
          targetX,
          targetY - halfWidth,
        )
        ..lineTo(targetX, targetY + halfWidth)
        ..cubicTo(
          c2,
          targetY + halfWidth,
          c1,
          sourceY + halfWidth,
          sourceX,
          sourceY + halfWidth,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()..color = link.source.color.withValues(alpha: 0.35),
      );
    }

    for (final node in nodes) {
      final rect = Rect.fromLTRB(node.x0, node.y0, node.x1, node.y1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(_cornerRadius)),
        Paint()..color = node.color,
      );

      // [displayValue] prime toujours sur [value] : ce dernier peut être
      // artificiellement plus grand (budget en déficit) pour que les
      // liens sortants du nœud tiennent dans sa hauteur, mais le libellé
      // doit annoncer le vrai montant du nœud, jamais celui, gonflé, des
      // flux qu'il n'a fait que faire transiter.
      final hasDeficit = node.deficit > 0;
      final label = hasDeficit
          ? '${node.label} : ${displayEuros(node.displayValue ?? node.value, hidden)} '
                '(déficit de ${displayEuros(node.deficit, hidden)})'
          : '${node.label} : ${displayEuros(node.displayValue ?? node.value, hidden)}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: hasDeficit ? const Color(0xFF991B1B) : const Color(0xFF1A1A1A),
            fontSize: 12,
            fontWeight: hasDeficit ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const hPad = 8.0, vPad = 4.0;
      final pillW = tp.width + hPad * 2;
      final pillH = tp.height + vPad * 2;
      final isOut = node.x1 + 140 > canvasWidth;
      final pillX = isOut ? node.x0 - 8 - pillW : node.x1 + 8;
      final pillY = (node.y0 + node.y1) / 2 - pillH / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pillX, pillY, pillW, pillH),
          Radius.circular(pillH / 2),
        ),
        Paint()
          ..color = hasDeficit
              ? const Color(0xFFFEE2E2).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.92),
      );
      tp.paint(canvas, Offset(pillX + hPad, pillY + vPad));
    }
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter oldDelegate) => true;
}

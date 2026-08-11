import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../../core/money_format.dart';
import 'budget_models.dart';

class _FlowNode {
  final String label;
  final int column;
  final Color color;
  double value = 0;
  double x0 = 0, x1 = 0, y0 = 0, y1 = 0;
  _FlowNode({required this.label, required this.column, required this.color});
}

class _FlowLink {
  final _FlowNode source;
  final _FlowNode target;
  final double value;
  double sourceY = 0;
  double targetY = 0;
  double thickness = 0;
  _FlowLink({required this.source, required this.target, required this.value});
}

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
      return const SizedBox(
        height: 280,
        child: Center(
          child: Text(
            'Ajoute des revenus, dépenses ou investissements pour voir le flux.',
          ),
        ),
      );
    }

    final green = const Color(0xFF22C55E);
    final red = const Color(0xFFEF4444);
    final accent = Theme.of(context).colorScheme.primary;

    final nodes = <_FlowNode>[];
    final links = <_FlowLink>[];

    final revenusNode = _FlowNode(label: 'Revenus', column: 0, color: green);
    final disponibleNode = _FlowNode(
      label: 'Disponible',
      column: 1,
      color: green,
    );
    nodes.addAll([revenusNode, disponibleNode]);

    if (totalRevenues > 0) {
      links.add(
        _FlowLink(
          source: revenusNode,
          target: disponibleNode,
          value: totalRevenues,
        ),
      );
    }

    if (totalExpenses > 0) {
      final depensesNode = _FlowNode(label: 'Dépenses', column: 2, color: red);
      nodes.add(depensesNode);
      links.add(
        _FlowLink(
          source: disponibleNode,
          target: depensesNode,
          value: totalExpenses,
        ),
      );

      for (final category in data.expenseCategories) {
        final sum = category.items.fold<double>(0, (s, i) => s + i.amount);
        if (sum <= 0) continue;
        final catNode = _FlowNode(
          label: category.name.isEmpty ? 'Sans catégorie' : category.name,
          column: 3,
          color: red,
        );
        nodes.add(catNode);
        links.add(_FlowLink(source: depensesNode, target: catNode, value: sum));
        for (final item in category.items) {
          if (item.amount <= 0) continue;
          final itemNode = _FlowNode(
            label: item.name.isEmpty ? 'Dépense' : item.name,
            column: 4,
            color: red,
          );
          nodes.add(itemNode);
          links.add(
            _FlowLink(source: catNode, target: itemNode, value: item.amount),
          );
        }
      }
    }

    if (totalInvestments > 0) {
      final investNode = _FlowNode(
        label: 'Investissements',
        column: 2,
        color: accent,
      );
      nodes.add(investNode);
      links.add(
        _FlowLink(
          source: disponibleNode,
          target: investNode,
          value: totalInvestments,
        ),
      );

      for (final category in data.investmentCategories) {
        final sum = category.items.fold<double>(0, (s, i) => s + i.amount);
        if (sum <= 0) continue;
        final catNode = _FlowNode(
          label: category.name.isEmpty ? 'Sans catégorie' : category.name,
          column: 3,
          color: accent,
        );
        nodes.add(catNode);
        links.add(_FlowLink(source: investNode, target: catNode, value: sum));
        for (final item in category.items) {
          if (item.amount <= 0) continue;
          final itemNode = _FlowNode(
            label: item.name.isEmpty ? 'Investissement' : item.name,
            column: 4,
            color: accent,
          );
          nodes.add(itemNode);
          links.add(
            _FlowLink(source: catNode, target: itemNode, value: item.amount),
          );
        }
      }
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

  double _layout(List<_FlowNode> nodes, List<_FlowLink> links, double width) {
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
      node.value = outgoing > 0 ? outgoing : incoming;
    }

    final columns = <int, List<_FlowNode>>{};
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

    final sourceCursor = <_FlowNode, double>{};
    final targetCursor = <_FlowNode, double>{};
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
  final List<_FlowNode> nodes;
  final List<_FlowLink> links;
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

      final label = '${node.label} : ${displayEuros(node.value, hidden)}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 12,
            fontWeight: FontWeight.w500,
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
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      tp.paint(canvas, Offset(pillX + hPad, pillY + vPad));
    }
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter oldDelegate) => true;
}

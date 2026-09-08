import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'entities_models.dart';

const _selfNodeId = '__self__';
const _nodeWidth = 150.0;
const _nodeHeight = 56.0;
const _hGap = 20.0;
const _vGap = 52.0;

class _DiagramNode {
  final String id;
  final String label;
  final String? sublabel;
  final bool isSelf;

  /// `null` pour la racine "Moi-même" (pas d'entité, pas de part entrante).
  /// Sinon, l'entité réelle — ses [BusinessEntity.stakes] (potentiellement
  /// plusieurs : une entité peut être détenue en partie directement, en
  /// partie via une ou plusieurs autres) pilotent les lignes dessinées par
  /// [_DiagramLinesPainter], indépendamment de [children] (qui ne reflète
  /// que le propriétaire PRINCIPAL, pour la mise en page — voir
  /// [primaryOwnerId]).
  final BusinessEntity? entity;
  int depth = 0;

  /// Abscisse en "slot" entiers (une feuille = un slot, un nœud interne =
  /// la moyenne des slots de ses enfants) — convertie en pixels par
  /// l'appelant, voir [EntityStructureDiagram._centerOf].
  double x = 0;
  final List<_DiagramNode> children = [];

  _DiagramNode({
    required this.id,
    required this.label,
    this.sublabel,
    this.isSelf = false,
    this.entity,
  });
}

/// Schéma de la structure de détention d'un coffre-fort : "Moi-même" à la
/// racine, chaque entité reliée à CHACUN de ses propriétaires (voir
/// [BusinessEntity.stakes] — une entité peut être détenue en partie
/// directement par l'utilisateur et en partie via une ou plusieurs autres
/// entités, comme un actionnariat mixte réel) par une ligne étiquetée du %
/// détenu sur CE lien précis. La dilution jusqu'à l'utilisateur (ex.
/// filiale à 50 % d'un holding détenu à 80 %) se lit en suivant la chaîne
/// de lignes plutôt qu'un unique pourcentage déjà calculé (celui-là reste
/// affiché sur chaque `_EntityCard`, voir `entities_screen.dart`).
///
/// La MISE EN PAGE (qui est sous qui à l'écran) suit uniquement le
/// propriétaire PRINCIPAL de chaque entité ([primaryOwnerId] — celui à la
/// part la plus élevée) : une entité à détention mixte n'a qu'UNE position
/// dans l'arbre, mais peut recevoir plusieurs lignes entrantes (une par
/// part). Layout par niveaux fait à la main (profondeur → ligne, ordre des
/// feuilles → colonne) : aucune librairie de diagramme en arbre n'est
/// présente dans ce projet (tous les graphiques existants sont des
/// `CustomPainter` maison, voir `dashboard/widgets/net_worth_chart.dart`
/// et consorts) — même approche ici, `CustomPaint` pour les traits,
/// `Positioned` pour les boîtes. Défile horizontalement au besoin (many
/// entités de tête, ou arbre large).
class EntityStructureDiagram extends StatelessWidget {
  final List<BusinessEntity> entities;
  final String selfLabel;

  const EntityStructureDiagram({
    super.key,
    required this.entities,
    required this.selfLabel,
  });

  _DiagramNode _buildTree() {
    final byId = {for (final e in entities) e.id: e};
    // Une entité prise dans un cycle de propriétaire PRINCIPAL (JSON
    // modifié à la main — l'UI de l'éditeur l'empêche déjà, voir
    // `_eligibleParents`) est raccrochée directement à la racine plutôt
    // que de faire planter la mise en page ou boucler à l'infini — même
    // garde-fou que [effectiveOwnershipPercents], mais appliqué ici au
    // seul propriétaire principal (la mise en page reste un arbre, même
    // si les lignes dessinées, elles, forment un graphe).
    bool isCyclic(String id) {
      final visited = <String>{};
      String? current = id;
      while (current != null) {
        if (!visited.add(current)) return true;
        current = primaryOwnerId(byId[current]!);
      }
      return false;
    }

    final childrenByParentId = <String, List<BusinessEntity>>{};
    for (final entity in entities) {
      final parentId = primaryOwnerId(entity);
      final effectiveParentId =
          (parentId != null && byId.containsKey(parentId) && !isCyclic(entity.id))
          ? parentId
          : _selfNodeId;
      (childrenByParentId[effectiveParentId] ??= []).add(entity);
    }

    final root = _DiagramNode(id: _selfNodeId, label: selfLabel, isSelf: true);
    void build(_DiagramNode parentNode) {
      for (final entity in childrenByParentId[parentNode.id] ?? const []) {
        final node = _DiagramNode(
          id: entity.id,
          label: entity.name,
          sublabel: entity.type.label,
          entity: entity,
        )..depth = parentNode.depth + 1;
        parentNode.children.add(node);
        build(node);
      }
    }

    build(root);
    return root;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final root = _buildTree();

    var nextLeafSlot = 0;
    void assignX(_DiagramNode node) {
      if (node.children.isEmpty) {
        node.x = nextLeafSlot.toDouble();
        nextLeafSlot++;
        return;
      }
      for (final child in node.children) {
        assignX(child);
      }
      node.x =
          node.children.map((c) => c.x).reduce((a, b) => a + b) /
          node.children.length;
    }

    assignX(root);

    var maxDepth = 0;
    final allNodes = <_DiagramNode>[];
    void collect(_DiagramNode node) {
      allNodes.add(node);
      if (node.depth > maxDepth) maxDepth = node.depth;
      for (final child in node.children) {
        collect(child);
      }
    }

    collect(root);
    final nodesById = {for (final node in allNodes) node.id: node};

    final width = nextLeafSlot * (_nodeWidth + _hGap) + _hGap;
    final height = (maxDepth + 1) * (_nodeHeight + _vGap) + _vGap;

    Offset centerOf(_DiagramNode node) => Offset(
      _hGap + node.x * (_nodeWidth + _hGap) + _nodeWidth / 2,
      _vGap / 2 + node.depth * (_nodeHeight + _vGap) + _nodeHeight / 2,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            CustomPaint(
              size: Size(width, height),
              painter: _DiagramLinesPainter(
                nodes: allNodes,
                nodesById: nodesById,
                centerOf: centerOf,
                lineColor: theme.colorScheme.border,
                labelColor: theme.colorScheme.mutedForeground,
                labelBackground: theme.colorScheme.background,
              ),
            ),
            for (final node in allNodes)
              Positioned(
                left: centerOf(node).dx - _nodeWidth / 2,
                top: centerOf(node).dy - _nodeHeight / 2,
                width: _nodeWidth,
                height: _nodeHeight,
                child: _DiagramNodeBox(node: node),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiagramNodeBox extends StatelessWidget {
  final _DiagramNode node;

  const _DiagramNodeBox({required this.node});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: node.isSelf
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: node.isSelf
              ? theme.colorScheme.primary
              : theme.colorScheme.border,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          shadcn.Text(
            node.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ).small().medium(),
          if (node.sublabel != null)
            shadcn.Text(
              node.sublabel!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ).muted().xSmall(),
        ],
      ),
    );
  }
}

class _DiagramLinesPainter extends CustomPainter {
  final List<_DiagramNode> nodes;
  final Map<String, _DiagramNode> nodesById;
  final Offset Function(_DiagramNode) centerOf;
  final Color lineColor;
  final Color labelColor;
  final Color labelBackground;

  _DiagramLinesPainter({
    required this.nodes,
    required this.nodesById,
    required this.centerOf,
    required this.lineColor,
    required this.labelColor,
    required this.labelBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Une ligne par PART (voir `BusinessEntity.stakes`), pas par nœud de la
    // mise en page : une entité à détention mixte reçoit ainsi une ligne
    // de chacun de ses propriétaires, même celui qui n'a pas déterminé sa
    // position dans l'arbre (voir la doc de tête de [EntityStructureDiagram]).
    for (final node in nodes) {
      final entity = node.entity;
      if (entity == null) continue;
      for (final stake in entity.stakes) {
        final ownerNode = nodesById[stake.ownerId ?? _selfNodeId];
        if (ownerNode == null) continue; // Référence orpheline (JSON corrompu).
        final from = centerOf(ownerNode);
        final to = centerOf(node);
        // Coude à mi-hauteur entre les deux niveaux plutôt qu'une ligne
        // droite en diagonale : plus lisible dès que plusieurs lignes
        // partent d'un même nœud ou convergent vers un même nœud.
        final elbowY = (from.dy + to.dy) / 2;
        final path = Path()
          ..moveTo(from.dx, from.dy + _nodeHeight / 2)
          ..lineTo(from.dx, elbowY)
          ..lineTo(to.dx, elbowY)
          ..lineTo(to.dx, to.dy - _nodeHeight / 2);
        canvas.drawPath(path, linePaint);

        final textPainter = TextPainter(
          text: TextSpan(
            text: '${_formatPercent(stake.percent)} %',
            style: TextStyle(color: labelColor, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelTopLeft = Offset(
          to.dx - textPainter.width / 2,
          elbowY - textPainter.height - 2,
        );
        canvas.drawRect(
          (labelTopLeft - const Offset(3, 1)) &
              Size(textPainter.width + 6, textPainter.height + 2),
          Paint()..color = labelBackground,
        );
        textPainter.paint(canvas, labelTopLeft);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DiagramLinesPainter oldDelegate) => true;
}

String _formatPercent(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

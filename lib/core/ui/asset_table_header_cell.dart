import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

/// Explication brève de chaque colonne des tableaux d'actifs (comptes,
/// catégories, positions — voir [AssetTableHeaderCell]), affichée au survol
/// de son en-tête. Un seul point de vérité pour ce texte, réutilisé par
/// `category_breakdown_card.dart`, `category_detail_screen.dart` et
/// `positions_table.dart`, qui affichent tous les mêmes colonnes — plutôt
/// que 3 copies risquant de diverger avec le temps.
const assetTableColumnExplanations = <String, String>{
  'Valeur': 'Valeur actuelle de la ligne.',
  'Évolution':
      'Variation de valeur sur la période sélectionnée, versements et '
      'retraits compris.',
  '+/- value':
      'Performance réelle sur la période, hors effet des versements et '
      'retraits.',
  'PRU': 'Prix de Revient Unitaire : coût moyen par unité actuellement '
      'détenue.',
  'Quantité': 'Nombre d\'unités actuellement détenues.',
  'Cours': 'Dernier cours de marché connu, en euros.',
  // Sous-tableau des positions à effet de levier
  // (`positions_table.dart`'s `_LeveragedPositionsSubTable`).
  'Taille': 'Taille de la position, en unités du sous-jacent.',
  'Entrée': 'Prix d\'entrée de la position, converti en euros.',
  'Montant': 'Valeur notionnelle de la position (marge engagée + PnL '
      'latent).',
  'PnL (ROE)':
      'Gain ou perte latent, en % de la marge engagée (Return on Equity).',
};

/// Cellule d'en-tête d'un tableau d'actifs — même rendu qu'un simple
/// libellé aligné à droite, avec en plus une bulle d'explication au survol
/// quand [assetTableColumnExplanations] en connaît une pour [label] (sinon
/// le texte reste nu, silencieusement, plutôt que d'exiger une entrée pour
/// chaque colonne existante ou future). Factorise ce que
/// `category_breakdown_card.dart`, `category_detail_screen.dart` et
/// `positions_table.dart` reproduisaient chacun à l'identique — même
/// principe que [PerformanceAmount] côté cellules de valeur.
class AssetTableHeaderCell extends StatelessWidget {
  final String label;
  final double width;

  const AssetTableHeaderCell(this.label, {super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final text = shadcn.Text(label).muted().xSmall();
    final explanation = assetTableColumnExplanations[label];
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: explanation == null
            ? text
            : Tooltip(
                tooltip: (context) => TooltipContainer(
                  child: SizedBox(width: 220, child: shadcn.Text(explanation)),
                ),
                child: text,
              ),
      ),
    );
  }
}

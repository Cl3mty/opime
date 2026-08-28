import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/date_format.dart';
import '../../../core/money_format.dart';
import '../../../core/ui/frosted_card.dart';
import '../../../core/ui/opime_date_picker.dart';
import '../../../core/ui/toggle_button_style.dart';
import '../currency_format.dart';
import '../documents_section.dart';
import '../investments_models.dart';
import '../transaction_price_currency.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _orange = Color(0xFFF97316);

/// Part de l'espace flexible de la ligne (voir [TransactionRow.build])
/// allouée au groupe étiquette de type + nom de la position + commentaire,
/// contre [_dateFlex] pour la date centrée qui suit — proportions plutôt que
/// des largeurs fixes en pixels : les colonnes restent alignées d'une ligne
/// à l'autre quel que soit le contenu, un `Expanded` prenant toujours la
/// même part de l'espace disponible indépendamment de la longueur de son
/// contenu.
const _leftGroupFlex = 5;
const _dateFlex = 2;

/// Largeur maximale (mais pas fixe : le nom garde sa largeur naturelle en
/// dessous) du nom de la position au sein du groupe de gauche
/// ([_leftGroupFlex]) — un plafond généreux, jamais atteint en pratique,
/// simple garde-fou contre un libellé extrême. Le nom n'est volontairement
/// PAS un `Flexible`/`Expanded` : seul le commentaire qui le suit
/// ([Transaction.note], dans un `Expanded`) absorbe l'espace restant et se
/// réduit (`overflow: TextOverflow.ellipsis`) si besoin — jamais le nom, et
/// jamais le commentaire non plus quand la ligne a assez de place pour les
/// deux (voir [TransactionRow.build]).
const _positionLabelMaxWidth = 260.0;

/// Largeurs fixes des colonnes de fin de ligne (calcul quantité × prix +
/// montant collés ensemble, bouton documents) — comme
/// [_leftGroupFlex]/[_dateFlex] ci-dessus, mais en pixels plutôt qu'en part
/// de l'espace flexible : ces colonnes affichent un contenu de longueur
/// variable d'une transaction à l'autre (des chiffres différents), qui doit
/// rester `Expanded`-neutre pour ne pas décaler le partage de l'espace
/// flexible entre le groupe de gauche et la date d'une ligne à l'autre (voir
/// [TransactionRow.build]). PARTAGÉE avec [ArbitrageTransactionRow] à
/// dessein — une valeur différente entre les deux types de ligne décale la
/// colonne de date de l'un par rapport à l'autre dans une même liste (ex :
/// `account_transactions_tab.dart`, qui les mélange), même si chacun garde
/// individuellement ses colonnes alignées ligne à ligne.
const _amountsGroupWidth = 320.0;
const _documentsIconWidth = 32.0;

/// Étiquette de type de transaction ("Achat", "Vente", "Dividende"...) —
/// extraite en widget partagé entre les deux mises en page de
/// [TransactionRow.build] (seule dans sa case, ou collée au nom de la
/// position).
class _TransactionKindBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TransactionKindBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: shadcn.Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ).xSmall(),
    );
  }
}

/// Petite étiquette "libellé + valeur" (ex : "Quantité détenue" / "12
/// unités") — utilisée pour les statistiques d'un investissement, sur sa
/// propre page (`investment_detail_screen.dart`) comme dans la popup de
/// détail d'une position "Actions & Fonds"
/// (`stock_account/position_detail_dialog.dart`).
class InvestmentStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const InvestmentStatChip({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              shadcn.Text(label).muted().xSmall(),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ],
          ),
          shadcn.Text(value).medium(),
        ],
      ),
    );
  }
}

/// Petit badge affiché à côté du "Dernier cours" quand
/// [Investment.isPriceFresh] — le cours affiché vient bien du dernier
/// rafraîchissement du jour, pas d'un cache potentiellement daté (voir
/// `price_refresh_service.dart`).
class FreshPriceBadge extends StatelessWidget {
  const FreshPriceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlineBadge(
      leading: const Icon(
        LucideIcons.circleCheck,
        size: 10,
        color: Colors.green,
      ),
      child: shadcn.Text('à jour').xSmall(),
    );
  }
}

/// Pendant de [FreshPriceBadge] pour un "Cours estimé" saisi à la main
/// ([Investment.manualPrice]) plutôt que récupéré automatiquement — même
/// forme de badge, mais sans connotation "à jour" (une estimation manuelle
/// n'a pas de fraîcheur attendue) : au survol, indique simplement depuis
/// quand cette valeur date ([Investment.manualPriceAt]).
class ManualPriceBadge extends StatelessWidget {
  final DateTime updatedAt;

  const ManualPriceBadge({super.key, required this.updatedAt});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: (context) => TooltipContainer(
        child: shadcn.Text('Estimé le ${formatDateDdMmYyyy(updatedAt)}'),
      ),
      child: OutlineBadge(
        leading: Icon(
          LucideIcons.pencilLine,
          size: 10,
          color: Theme.of(context).colorScheme.mutedForeground,
        ),
        child: shadcn.Text('manuel').xSmall(),
      ),
    );
  }
}

/// Petit badge affiché à côté d'un investissement ou d'un compte quand
/// [Investment.excludedFromPatrimoine]/[InvestmentAccount.excludedFromPatrimoine]
/// — il reste visible partout avec sa vraie valeur (page de catégorie,
/// compte, Analyses...) ; seuls les agrégats globaux du Dashboard
/// ("Patrimoine net/brut", carte Allocation) l'ignorent, ce que ce badge
/// rappelle.
class ExcludedFromPatrimoineBadge extends StatelessWidget {
  const ExcludedFromPatrimoineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlineBadge(
      leading: Icon(
        LucideIcons.eyeOff,
        size: 10,
        color: theme.colorScheme.mutedForeground,
      ),
      child: shadcn.Text('Hors patrimoine global').xSmall().muted(),
    );
  }
}

/// Une ligne de transaction (achat/vente/dividende...) avec menu "⋮"
/// modifier/supprimer — utilisée par la page d'un investissement
/// (`investment_detail_screen.dart`) comme par l'onglet "Transactions" d'un
/// compte Actions & Fonds (`stock_account/account_transactions_tab.dart`).
///
/// [positionLabel], quand renseigné, affiche le nom de la position en tête
/// de ligne — nécessaire dès qu'une liste de transactions mélange plusieurs
/// positions (l'onglet "Transactions" d'un compte), inutile sur la page
/// d'une position unique.
class TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final bool hidden;
  final bool displayTotalOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Classe d'actif effective de l'investissement porteur : sert à formater
  /// la quantité (entière pour les pièces/lingots de métaux précieux).
  final AssetClass assetClass;

  /// Nom de la position porteuse, affiché en tête de ligne — `null` quand
  /// la liste ne montre déjà que les transactions d'une seule position.
  final String? positionLabel;

  /// Documents rattachés à cette transaction (pièces justificatives des
  /// métaux précieux et "autres") — affiche un bouton de consultation
  /// quand la liste est non vide.
  final List<VaultDocument> documents;

  /// Chemin du vault pour ouvrir les fichiers depuis [showDocumentViewDialog]
  /// — inutilisé (et `null`) quand [documents] est vide.
  final String? vaultPath;

  /// `true` (défaut) centre la date dans sa colonne — proprement, tant
  /// qu'aucune ligne de la liste n'a de commentaire (voir [Transaction.note])
  /// à côté de son actif : le groupe de gauche reste alors compact et
  /// prévisible, la date au centre du reste de la ligne a un sens visuel.
  /// Dès qu'au moins une ligne de la liste porte un commentaire, ce groupe
  /// de gauche s'élargit de façon variable d'une ligne à l'autre — centrer
  /// la date dans l'espace restant donnerait alors une colonne qui semble
  /// mal alignée plutôt que centrée. L'appelant, seul à connaître
  /// l'ensemble des transactions affichées (pas seulement celle-ci), doit
  /// passer `false` dans ce cas — la date retombe alors sur un alignement à
  /// gauche, comme avant l'introduction des commentaires.
  final bool centerDate;

  /// Largeur réservée à la case "quantité × prix / montant", par défaut
  /// [_amountsGroupWidth] — partagée avec [ArbitrageTransactionRow] pour
  /// garder les dates alignées quand les deux se mélangent dans une même
  /// liste (`account_transactions_tab.dart`). Un appelant qui n'affiche
  /// JAMAIS de ligne fusionnée à côté (ex : `position_detail_dialog.dart`,
  /// une popup nettement plus étroite qu'une page pleine largeur) peut
  /// réduire cette valeur : l'alignement inter-lignes n'a alors de sens
  /// qu'au sein de sa propre liste, pas besoin de réserver la même largeur
  /// que le calcul à deux jambes d'un arbitrage.
  final double amountsGroupWidth;

  const TransactionRow({
    super.key,
    required this.transaction,
    required this.hidden,
    this.displayTotalOnly = false,
    required this.assetClass,
    this.positionLabel,
    required this.onEdit,
    required this.onDelete,
    this.documents = const [],
    this.vaultPath,
    this.centerDate = true,
    this.amountsGroupWidth = _amountsGroupWidth,
  });

  void _openMenu(BuildContext anchorContext) {
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180),
        child: DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.pencil, size: 14),
              child: const shadcn.Text('Modifier'),
              onPressed: (_) => onEdit(),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.trash2, size: 14),
              child: const shadcn.Text('Supprimer'),
              onPressed: (_) => onDelete(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Un arbitrage n'est ni un simple achat ni une simple vente — sa vente
    // comme son achat forment une seule opération de bascule d'un titre à
    // l'autre, colorée à part (orange) pour ne pas se lire comme une perte
    // (rouge) sur sa jambe de vente.
    final color = transaction.type == TransactionType.arbitrage
        ? _orange
        : transaction.isBuy
        ? _green
        : _red;
    final note = transaction.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Étiquette de type + nom de la position (si la liste mélange
            // plusieurs positions) + commentaire (si renseigné, voir
            // [Transaction.note]) collés les uns aux autres (pas chacun
            // dans sa propre case à largeur fixe, sans quoi un libellé
            // court comme "Achat" laisserait un grand vide avant le
            // suivant) — le GROUPE entier occupe une part fixe de l'espace
            // disponible ([_leftGroupFlex], contre [_dateFlex] pour la date
            // qui suit) plutôt qu'une largeur fixe en pixels : les colonnes
            // restent alignées d'une ligne à l'autre quel que soit le
            // contenu. À l'intérieur, seul le commentaire est un `Expanded` :
            // il absorbe l'espace qui reste une fois le nom affiché à sa
            // largeur naturelle (plafonnée par prudence, voir
            // [_positionLabelMaxWidth]), et ne se réduit donc que si la
            // ligne n'a vraiment plus la place pour les deux — jamais avant.
            Expanded(
              flex: _leftGroupFlex,
              child: Row(
                children: [
                  _TransactionKindBadge(
                    label: transaction.displayLabel,
                    color: color,
                  ),
                  if (positionLabel != null) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _positionLabelMaxWidth,
                      ),
                      child: shadcn.Text(
                        positionLabel!,
                        overflow: TextOverflow.ellipsis,
                      ).small().medium(),
                    ),
                  ],
                  if (hasNote) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: shadcn.Text(
                        note,
                        overflow: TextOverflow.ellipsis,
                      ).muted().xSmall(),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: _dateFlex,
              child: Align(
                alignment: centerDate ? Alignment.center : Alignment.centerLeft,
                // `maxLines`/`overflow` : une date ne doit jamais passer à
                // la ligne (casserait la hauteur de toute la ligne) même si
                // sa colonne venait à manquer de place — tronquer est un
                // dégât moindre, voir [amountsGroupWidth].
                child: shadcn.Text(
                  _formatDate(transaction.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ).small(),
              ),
            ),
            // Calcul (quantité × prix) et montant collés l'un à l'autre,
            // tout à droite — une seule case à largeur fixe pour les deux
            // ([_amountsGroupWidth], même raison que [_documentsIconWidth] :
            // garder le partage de l'espace flexible constant d'une ligne à
            // l'autre) plutôt qu'une par élément, sans quoi l'espace inutilisé
            // d'une case trop large pour son contenu s'intercalerait entre
            // les deux au lieu de rester group à gauche de l'ensemble.
            SizedBox(
              width: amountsGroupWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!displayTotalOnly) ...[
                    Flexible(
                      child: shadcn.Text(
                        '${formatQuantity(transaction.quantity, assetClass)} × '
                        '${transaction.currency == 'EUR' ? displayEuros(transaction.unitPrice, hidden) : formatPriceInCurrency(transaction.unitPrice, transaction.currency, hidden: hidden)}',
                        overflow: TextOverflow.ellipsis,
                      ).muted().xSmall(),
                    ),
                    const SizedBox(width: 12),
                  ],
                  shadcn.Text(
                    displayEuros(transaction.amount, hidden),
                  ).medium(),
                ],
              ),
            ),
            // Largeur toujours réservée (bouton affiché ou non) : sans ça,
            // une ligne avec documents et une ligne sans décaleraient la
            // part d'espace libre allouée au groupe de gauche/à la date qui
            // le précèdent (voir [_documentsIconWidth]).
            SizedBox(
              width: _documentsIconWidth,
              child: documents.isEmpty || vaultPath == null
                  ? null
                  // Consultation rapide des pièces justificatives de la
                  // transaction (métaux précieux et "autres") — l'ajout et
                  // la suppression restent sur le formulaire d'édition, voir
                  // `showDocumentViewDialog`.
                  : Tooltip(
                      tooltip: (context) => TooltipContainer(
                        child: shadcn.Text(
                          '${documents.length} document'
                          '${documents.length > 1 ? 's' : ''} rattaché'
                          '${documents.length > 1 ? 's' : ''} — consulter',
                        ),
                      ),
                      child: IconButton.ghost(
                        icon: Icon(LucideIcons.paperclip, size: 15),
                        onPressed: () => showDocumentViewDialog(
                          context,
                          vaultPath: vaultPath!,
                          documents: documents,
                        ),
                      ),
                    ),
            ),
            Builder(
              builder: (context) => IconButton.ghost(
                icon: const Icon(LucideIcons.ellipsisVertical, size: 16),
                onPressed: () => _openMenu(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// Une ligne FUSIONNÉE pour un arbitrage — remplace les deux
/// [TransactionRow] (vente source, achat destination) qu'on obtiendrait
/// sinon dans une liste mélangeant plusieurs positions du même compte
/// (`account_transactions_tab.dart` : un arbitrage reste toujours au sein
/// d'un compte, voir `transfer_arbitrage_dialog.dart`, donc ses deux jambes
/// y apparaissent forcément ensemble). Un transfert, lui, déplace un titre
/// vers un AUTRE compte : ses deux jambes ne cohabitent jamais dans la même
/// liste, pas de fusion possible ni utile pour lui. Sur la page d'une seule
/// position (`investment_detail_screen.dart`), on ne voit de toute façon
/// qu'une seule jambe à la fois : pas de fusion là non plus.
class ArbitrageTransactionRow extends StatelessWidget {
  final Investment sellInvestment;
  final Transaction sellTransaction;
  final AssetClass sellAssetClass;
  final Investment buyInvestment;
  final Transaction buyTransaction;
  final AssetClass buyAssetClass;
  final bool hidden;

  /// Modifie les DEUX transactions ensemble (voir `edit_arbitrage_dialog.dart`)
  /// — jamais chacune séparément : un formulaire d'édition générique ignore
  /// `type`/`linkedTransactionId` de l'autre jambe et détacherait
  /// silencieusement la paire à l'enregistrement.
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Documents rattachés à la jambe de vente — seule jambe où
  /// `transfer_arbitrage_dialog.dart` permet d'en attacher (voir sa doc de
  /// tête).
  final List<VaultDocument> documents;
  final String? vaultPath;
  final bool centerDate;

  const ArbitrageTransactionRow({
    super.key,
    required this.sellInvestment,
    required this.sellTransaction,
    required this.sellAssetClass,
    required this.buyInvestment,
    required this.buyTransaction,
    required this.buyAssetClass,
    required this.hidden,
    required this.onEdit,
    required this.onDelete,
    this.documents = const [],
    this.vaultPath,
    this.centerDate = true,
  });

  void _openMenu(BuildContext anchorContext) {
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 200),
        child: DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.pencil, size: 14),
              child: const shadcn.Text('Modifier l\'arbitrage'),
              onPressed: (_) => onEdit(),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.trash2, size: 14),
              child: const shadcn.Text('Supprimer'),
              onPressed: (_) => onDelete(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    // Égaux par construction (voir `transfer_arbitrage_dialog.dart`'s
    // `_commitArbitrage` : la quantité achetée est dérivée du produit de la
    // vente) — un seul montant à afficher plutôt que deux.
    final amount = sellTransaction.amount;
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: _leftGroupFlex,
              child: Row(
                children: [
                  const _TransactionKindBadge(label: 'Arbitrage', color: _orange),
                  const SizedBox(width: 8),
                  Flexible(
                    child: shadcn.Text(
                      '${sellInvestment.label} → ${buyInvestment.label}',
                      overflow: TextOverflow.ellipsis,
                    ).small().medium(),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: _dateFlex,
              child: Align(
                alignment: centerDate ? Alignment.center : Alignment.centerLeft,
                child: shadcn.Text(
                  _formatDate(sellTransaction.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ).small(),
              ),
            ),
            SizedBox(
              width: _amountsGroupWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: shadcn.Text(
                      'Vendu ${formatQuantity(sellTransaction.quantity, sellAssetClass)} × '
                      '${displayEuros(sellTransaction.unitPrice, hidden)} → '
                      'Acheté ${formatQuantity(buyTransaction.quantity, buyAssetClass)} × '
                      '${displayEuros(buyTransaction.unitPrice, hidden)}',
                      overflow: TextOverflow.ellipsis,
                    ).muted().xSmall(),
                  ),
                  const SizedBox(width: 12),
                  shadcn.Text(displayEuros(amount, hidden)).medium(),
                ],
              ),
            ),
            SizedBox(
              width: _documentsIconWidth,
              child: documents.isEmpty || vaultPath == null
                  ? null
                  : Tooltip(
                      tooltip: (context) => TooltipContainer(
                        child: shadcn.Text(
                          '${documents.length} document'
                          '${documents.length > 1 ? 's' : ''} rattaché'
                          '${documents.length > 1 ? 's' : ''} — consulter',
                        ),
                      ),
                      child: IconButton.ghost(
                        icon: Icon(LucideIcons.paperclip, size: 15),
                        onPressed: () => showDocumentViewDialog(
                          context,
                          vaultPath: vaultPath!,
                          documents: documents,
                        ),
                      ),
                    ),
            ),
            Builder(
              builder: (context) => IconButton.ghost(
                icon: const Icon(LucideIcons.ellipsisVertical, size: 16),
                onPressed: () => _openMenu(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lien "+ Ajouter une transaction" — utilisé sur la page d'un
/// investissement et dans les positions/transactions d'un compte Actions &
/// Fonds.
class AddTransactionButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const AddTransactionButton({
    super.key,
    required this.onTap,
    this.label = 'Ajouter une transaction',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.plus,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          shadcn.Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

/// Formulaire d'ajout/édition d'une transaction (achat/vente, date,
/// quantité, prix, devise) — utilisé par la page d'un investissement
/// (`investment_detail_screen.dart`) et par les dialogs de transaction d'un
/// compte Actions & Fonds.
class TransactionForm extends StatelessWidget {
  final bool isBuy;
  final DateTime? date;
  final TextEditingController quantityController;
  final TextEditingController priceController;

  /// Commentaire libre et facultatif (ex : "Renforcement position", "Achat
  /// suite au dividende") — affiché sur [TransactionRow] à côté du nom de
  /// l'actif, en plus petit et plus clair (voir [Transaction.note]), jamais
  /// utilisé dans les calculs.
  final TextEditingController noteController;

  final ValueChanged<bool> onIsBuyChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final VoidCallback onCreate;
  final VoidCallback onCancel;
  final String submitLabel;

  /// Libellé du champ [quantityController] — "Quantité" par défaut,
  /// `Montant (€)`/`Montant (<devise>)` pour une position en devise (voir
  /// `InvestmentDetailView`'s `_quantityFieldLabel`).
  final String quantityLabel;

  /// Libellé du champ [priceController] — "Prix unitaire" par défaut,
  /// "Cours de la paire de devise" pour une position en devise (voir
  /// `InvestmentDetailView`'s `_priceFieldLabel`).
  final String priceLabel;

  /// `false` masque entièrement le champ [priceController] — une position
  /// en devise tenue en euros n'a pas de taux de change à saisir (voir
  /// `InvestmentDetailView`'s `_isEurCurrency`).
  final bool showPriceField;

  /// `true` affiche le sélecteur de devise à côté du champ prix (voir
  /// `InvestmentDetailView`'s `_showCurrencySelector`) — faux pour une
  /// position en devise, dont le "prix" est déjà le taux en euros.
  final bool showCurrencySelector;

  /// Contrôleur devise/taux du formulaire (voir
  /// `transaction_price_currency.dart`) — utilisé quand [showCurrencySelector]
  /// pour résoudre le taux et afficher la zone de rappel/conversion.
  final TransactionPriceCurrencyController? priceCurrencyController;

  /// Section "Documents" scopée à cette transaction (voir
  /// `DocumentsSection`'s `fixedTransactionId`) — `null` pour une
  /// transaction en cours de création (pas encore d'id persisté auquel
  /// rattacher un document) ou hors métaux précieux.
  final Widget? documentsSection;

  /// Date de déblocage d'un versement PEG/PEE, calculée par défaut (voir
  /// [pegPeeUnlockDateFor]) dès la saisie de la date de transaction, mais
  /// modifiable pour couvrir un déblocage anticipé (voir
  /// [Transaction.manualUnlockDate]). `null` hors PEG/PEE, pour une vente
  /// (seuls les versements se débloquent), ou tant qu'aucune date de
  /// transaction n'est choisie.
  final DateTime? unlockDate;

  /// Renseigné uniquement quand [unlockDate] a un sens à afficher — sa
  /// présence conditionne l'affichage du champ (voir [unlockDate]).
  /// Appelé à chaque modification manuelle de la date de déblocage.
  final ValueChanged<DateTime?>? onUnlockDateChanged;

  const TransactionForm({
    super.key,
    required this.isBuy,
    required this.date,
    required this.quantityController,
    required this.priceController,
    required this.noteController,
    this.submitLabel = 'Ajouter la transaction',
    this.quantityLabel = 'Quantité',
    this.priceLabel = 'Prix unitaire',
    this.showPriceField = true,
    this.showCurrencySelector = false,
    this.priceCurrencyController,
    required this.onIsBuyChanged,
    required this.onDateChanged,
    required this.onCreate,
    required this.onCancel,
    this.documentsSection,
    this.unlockDate,
    this.onUnlockDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ButtonGroup(
                  children: [
                    SelectedButton(
                      value: isBuy,
                      selectedStyle: const ButtonStyle.primary(),
                      style: toggleUnselectedStyle(context),
                      onChanged: (_) => onIsBuyChanged(true),
                      child: const shadcn.Text('Achat'),
                    ),
                    SelectedButton(
                      value: !isBuy,
                      selectedStyle: const ButtonStyle.primary(),
                      style: toggleUnselectedStyle(context),
                      onChanged: (_) => onIsBuyChanged(false),
                      child: const shadcn.Text('Vente'),
                    ),
                  ],
                ),
                OpimeDatePicker(
                  value: date,
                  onChanged: onDateChanged,
                  placeholder: const shadcn.Text('Date'),
                ),
              ],
            ),
            if (onUnlockDateChanged != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  shadcn.Text('Débloqué le').muted().xSmall(),
                  const SizedBox(width: 8),
                  OpimeDatePicker(
                    value: unlockDate,
                    onChanged: onUnlockDateChanged,
                    placeholder: const shadcn.Text('Date de déblocage'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    placeholder: shadcn.Text(quantityLabel),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                if (showPriceField) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      placeholder: shadcn.Text(priceLabel),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  if (showCurrencySelector &&
                      priceCurrencyController != null) ...[
                    const SizedBox(width: 8),
                    TransactionPriceCurrencySelect(
                      controller: priceCurrencyController!,
                    ),
                  ],
                ],
              ],
            ),
            if (showCurrencySelector && priceCurrencyController != null)
              TransactionFxRateArea(
                controller: priceCurrencyController!,
                quantityController: quantityController,
                priceController: priceController,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              placeholder: const shadcn.Text('Commentaire (facultatif)'),
            ),
            if (documentsSection != null) ...[
              const SizedBox(height: 16),
              documentsSection!,
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                PrimaryButton(
                  onPressed: onCreate,
                  child: shadcn.Text(submitLabel),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  onPressed: onCancel,
                  child: const shadcn.Text('Annuler'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

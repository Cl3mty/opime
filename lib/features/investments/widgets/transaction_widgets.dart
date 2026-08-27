import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/frosted_card.dart';
import '../../../core/ui/toggle_button_style.dart';
import '../currency_format.dart';
import '../documents_section.dart';
import '../investments_models.dart';
import '../transaction_price_currency.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Largeur réservée à l'étiquette de type de transaction ("Achat", "Vente",
/// "Dividende", "Conversion de devise"...) dans [TransactionRow] — sans
/// largeur fixe, la date qui suit (voir [Transaction.displayLabel]) se
/// décale d'une ligne à l'autre selon la longueur du libellé, empêchant les
/// dates de tout le tableau de s'aligner verticalement. Dimensionnée pour
/// le plus long libellé existant ("Conversion de devise", voir
/// [TransactionType.label]).
const _kindBadgeWidth = 156.0;

/// Largeur réservée au groupe étiquette de type + nom de la position
/// (`positionLabel`), quand la liste mélange plusieurs positions (onglet
/// "Transactions" d'un compte) — même raison que [_kindBadgeWidth] pris
/// seul, appliquée cette fois au groupe entier (les deux sont collés l'un
/// à l'autre, voir [TransactionRow.build]). Un nom trop long est
/// simplement tronqué (`overflow: TextOverflow.ellipsis`) plutôt que de
/// décaler la suite de la ligne.
const _leftGroupWidth = 320.0;

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
    final color = transaction.isBuy ? _green : _red;
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (positionLabel == null)
              SizedBox(
                width: _kindBadgeWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _TransactionKindBadge(
                    label: transaction.displayLabel,
                    color: color,
                  ),
                ),
              )
            else
              // Étiquette de type et nom de la position collés l'un à
              // l'autre (pas chacun dans sa propre case à largeur fixe,
              // sans quoi un libellé court comme "Achat" laisserait un
              // grand vide avant le nom) — mais le GROUPE des deux garde
              // une largeur totale fixe, comme [_kindBadgeWidth] seul dans
              // l'autre branche : sans ça, la date qui suit (alignée à
              // gauche dans son propre `Expanded`, donc dépendante
              // uniquement de ce qui la précède) se décalerait d'une ligne
              // à l'autre selon la longueur combinée des deux.
              SizedBox(
                width: _leftGroupWidth,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TransactionKindBadge(
                      label: transaction.displayLabel,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: shadcn.Text(
                        positionLabel!,
                        overflow: TextOverflow.ellipsis,
                      ).small().medium(),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 12),
            Expanded(child: shadcn.Text(_formatDate(transaction.date)).small()),
            if (!displayTotalOnly) ...[
              shadcn.Text(
                '${formatQuantity(transaction.quantity, assetClass)} × '
                '${transaction.currency == 'EUR' ? displayEuros(transaction.unitPrice, hidden) : formatPriceInCurrency(transaction.unitPrice, transaction.currency, hidden: hidden)}',
              ).muted().xSmall(),
              const SizedBox(width: 12),
            ],
            shadcn.Text(displayEuros(transaction.amount, hidden)).medium(),
            if (documents.isNotEmpty && vaultPath != null) ...[
              const SizedBox(width: 4),
              // Consultation rapide des pièces justificatives de la
              // transaction (métaux précieux et "autres") — l'ajout et la
              // suppression restent sur le formulaire d'édition, voir
              // `showDocumentViewDialog`.
              Tooltip(
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
            ],
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
                DatePicker(
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
                  DatePicker(
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

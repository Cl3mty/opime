import 'dart:typed_data';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart' show parseDecimal;
import '../../../core/ui/frosted_card.dart';
import '../confirm_delete_dialog.dart';
import '../document_storage.dart';
import '../documents_section.dart';
import '../investments_models.dart';
import '../investments_repository.dart';
import '../transaction_price_currency.dart';
import 'add_transaction_dialog.dart';
import 'edit_arbitrage_dialog.dart';
import 'transaction_widgets.dart';

/// Une paire vente/achat d'arbitrage regroupée — voir
/// `_AccountTransactionsTabState`'s `_rows`.
class _ArbitragePair {
  final (Investment, Transaction) sell;
  final (Investment, Transaction) buy;

  const _ArbitragePair({required this.sell, required this.buy});
}

/// Onglet "Transactions" d'un compte Actions & Fonds : historique
/// chronologique (plus récent en premier) de toutes les transactions du
/// compte, toutes positions confondues — contrairement à l'ancienne "page
/// actif" (`investment_detail_screen.dart`), dont l'historique était scopé
/// à une seule position. Le "+" ouvre [showAddTransactionDialog], seul
/// point d'entrée pour ajouter une transaction (position existante ou
/// nouvelle).
class AccountTransactionsTab extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final bool hidden;
  final Future<void> Function() onChanged;

  const AccountTransactionsTab({
    super.key,
    required this.vaultPath,
    required this.account,
    required this.hidden,
    required this.onChanged,
  });

  @override
  State<AccountTransactionsTab> createState() => _AccountTransactionsTabState();
}

class _AccountTransactionsTabState extends State<AccountTransactionsTab> {
  late InvestmentsRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
  }

  @override
  void didUpdateWidget(covariant AccountTransactionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) {
      _repo = InvestmentsRepository(widget.vaultPath);
    }
  }

  /// Même règle que `position_detail_dialog.dart`'s
  /// `_usesTransactionScopedDocuments` : métaux précieux, "Autres" et
  /// Actions & Fonds peuvent rattacher un document à une transaction
  /// précise plutôt qu'au compte dans son ensemble.
  bool _usesTransactionScopedDocuments(Investment investment) {
    final effectiveClass = investment.assetClass ?? widget.account.assetClass;
    return effectiveClass == AssetClass.metauxPrecieux ||
        effectiveClass == AssetClass.autres ||
        effectiveClass == AssetClass.actionsEtFonds;
  }

  List<(Investment, Transaction)> get _allTransactions {
    final list = <(Investment, Transaction)>[
      for (final investment in widget.account.investments)
        for (final txn in investment.transactions) (investment, txn),
    ];
    list.sort((a, b) => b.$2.date.compareTo(a.$2.date));
    return list;
  }

  /// [_allTransactions], mais avec chaque paire d'arbitrage (vente +
  /// achat liés — voir [Transaction.linkedTransactionId]) regroupée en un
  /// seul [_ArbitragePair] plutôt que deux entrées séparées : un arbitrage
  /// reste toujours au sein d'un même compte (voir `transfer_arbitrage_dialog.dart`),
  /// ses deux jambes apparaissent donc forcément toutes les deux dans cette
  /// liste — inutile de les afficher comme deux lignes distinctes, voir
  /// [ArbitrageTransactionRow]. Un transfert, lui, a sa contrepartie dans un
  /// AUTRE compte : jamais les deux dans cette même liste, jamais fusionné.
  List<Object> get _rows {
    final all = _allTransactions;
    final byTransactionId = {for (final pair in all) pair.$2.id: pair};
    final consumed = <String>{};
    final rows = <Object>[];
    for (final pair in all) {
      final (_, txn) = pair;
      if (consumed.contains(txn.id)) continue;
      final linkedId = txn.linkedTransactionId;
      final linked = txn.type == TransactionType.arbitrage && linkedId != null
          ? byTransactionId[linkedId]
          : null;
      if (linked != null) {
        consumed.add(txn.id);
        consumed.add(linked.$2.id);
        rows.add(
          _ArbitragePair(
            sell: txn.isBuy ? linked : pair,
            buy: txn.isBuy ? pair : linked,
          ),
        );
      } else {
        rows.add(pair);
      }
    }
    return rows;
  }

  Future<void> _saveInvestment(Investment updated) async {
    final updatedAccount = widget.account.copyWith(
      investments: [
        for (final i in widget.account.investments)
          if (i.id == updated.id) updated else i,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    await widget.onChanged();
  }

  Future<void> _deleteTransaction(
    Investment investment,
    Transaction transaction,
  ) async {
    // Une moitié de transfert/arbitrage (voir `Transaction.linkedTransactionId`)
    // n'a de sens qu'en paire : la supprimer sans sa contrepartie laisserait
    // une position déséquilibrée (ex : un titre "arrivé" nulle part) sur
    // l'autre compte/position, une erreur silencieuse difficile à repérer.
    final linkedId = transaction.linkedTransactionId;
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer cette transaction ?',
      message: linkedId == null
          ? 'Cette action est irréversible et modifiera la quantité '
                'détenue et le PRU de "${investment.label}".'
          : 'Cette transaction fait partie d\'un transfert/arbitrage : sa '
                'contrepartie sera aussi supprimée. Cette action est '
                'irréversible et modifiera la quantité détenue et le PRU '
                'des deux positions concernées.',
    );
    if (!confirmed) return;
    final orphanedDocuments = [
      for (final d in investment.documents)
        if (d.transactionId == transaction.id) d,
    ];
    for (final document in orphanedDocuments) {
      await DocumentStorage(widget.vaultPath).delete(document);
    }
    await _saveInvestment(
      investment.copyWith(
        transactions: [
          for (final t in investment.transactions)
            if (t.id != transaction.id) t,
        ],
        documents: [
          for (final d in investment.documents)
            if (d.transactionId != transaction.id) d,
        ],
      ),
    );
    if (linkedId != null) await _repo.deleteTransaction(linkedId);
  }

  @override
  Widget build(BuildContext context) {
    final all = _allTransactions;
    final rows = _rows;
    // Voir `TransactionRow.centerDate` : la date ne reste centrée que tant
    // qu'aucune transaction affichée (toutes positions confondues, cet
    // onglet les mélange) ne porte de commentaire.
    final centerDate = !all.any((pair) => pair.$2.hasNote);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: AddTransactionButton(
            onTap: () => showAddTransactionDialog(
              context,
              vaultPath: widget.vaultPath,
              account: widget.account,
              onChanged: widget.onChanged,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          shadcn.Text('Aucune transaction pour l\'instant.').muted().small(),
        for (final row in rows) ...[
          if (row is _ArbitragePair)
            ArbitrageTransactionRow(
              sellInvestment: row.sell.$1,
              sellTransaction: row.sell.$2,
              sellAssetClass: row.sell.$1.assetClass ?? widget.account.assetClass,
              buyInvestment: row.buy.$1,
              buyTransaction: row.buy.$2,
              buyAssetClass: row.buy.$1.assetClass ?? widget.account.assetClass,
              hidden: widget.hidden,
              onEdit: () => _showEditArbitrageDialog(row),
              // Une seule confirmation/cascade pour la paire, peu importe la
              // jambe passée : voir `_deleteTransaction`'s `linkedId`.
              onDelete: () => _deleteTransaction(row.sell.$1, row.sell.$2),
              // Documents rattachés uniquement à la jambe de vente — voir
              // `ArbitrageTransactionRow`'s doc de tête.
              documents: _usesTransactionScopedDocuments(row.sell.$1)
                  ? [
                      for (final d in row.sell.$1.documents)
                        if (d.transactionId == row.sell.$2.id) d,
                    ]
                  : const [],
              vaultPath: _usesTransactionScopedDocuments(row.sell.$1)
                  ? widget.vaultPath
                  : null,
              centerDate: centerDate,
            )
          else if (row case (Investment investment, Transaction txn))
            TransactionRow(
              transaction: txn,
              hidden: widget.hidden,
              assetClass: investment.assetClass ?? widget.account.assetClass,
              positionLabel: investment.label,
              onEdit: () => _showEditTransactionDialog(investment, txn),
              onDelete: () => _deleteTransaction(investment, txn),
              // Métaux précieux, "Autres" et Actions & Fonds peuvent porter
              // des documents scopés à la transaction, comme sur la popup de
              // détail de la position — voir `position_detail_dialog.dart`'s
              // `_usesTransactionScopedDocuments`.
              documents: _usesTransactionScopedDocuments(investment)
                  ? [
                      for (final d in investment.documents)
                        if (d.transactionId == txn.id) d,
                    ]
                  : const [],
              vaultPath: _usesTransactionScopedDocuments(investment)
                  ? widget.vaultPath
                  : null,
              centerDate: centerDate,
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Future<void> _showEditTransactionDialog(
    Investment investment,
    Transaction transaction,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => _EditTransactionDialog(
        vaultPath: widget.vaultPath,
        account: widget.account,
        investment: investment,
        transaction: transaction,
        onSave: _saveInvestment,
      ),
    );
  }

  Future<void> _showEditArbitrageDialog(_ArbitragePair pair) {
    return showEditArbitrageDialog(
      context,
      vaultPath: widget.vaultPath,
      account: widget.account,
      sellInvestment: pair.sell.$1,
      sellTransaction: pair.sell.$2,
      buyInvestment: pair.buy.$1,
      buyTransaction: pair.buy.$2,
      onChanged: widget.onChanged,
    );
  }
}

/// Popup d'édition d'une transaction existante depuis l'onglet
/// "Transactions" — la position porteuse est fixe (on ne déplace pas une
/// transaction d'une position à l'autre), contrairement à
/// [showAddTransactionDialog] qui permet d'en choisir une nouvelle.
class _EditTransactionDialog extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final Investment investment;
  final Transaction transaction;
  final Future<void> Function(Investment updated) onSave;

  const _EditTransactionDialog({
    required this.vaultPath,
    required this.account,
    required this.investment,
    required this.transaction,
    required this.onSave,
  });

  @override
  State<_EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<_EditTransactionDialog> {
  late bool _isBuy;
  late DateTime? _date;

  /// Date de déblocage saisie à la main, initialisée depuis
  /// [Transaction.manualUnlockDate] (voir [_unlockDate]) — `null` tant
  /// qu'elle n'a pas été modifiée, auquel cas la date par défaut s'applique.
  DateTime? _unlockDateOverride;

  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _noteController;
  late final TransactionPriceCurrencyController _priceCurrencyController;

  /// Copie locale de l'investissement, tenue à jour après chaque ajout/
  /// suppression de document — [widget.investment] ne change pas tant que
  /// cette popup reste ouverte (elle n'est pas reconstruite en même temps
  /// que l'onglet parent), donc relire ses documents à jour nécessite cet
  /// état propre, comme `position_detail_dialog.dart`'s `_investment`.
  late Investment _investment;

  /// Même règle que `_AccountTransactionsTabState`'s
  /// `_usesTransactionScopedDocuments` et
  /// `position_detail_dialog.dart`'s équivalent : métaux précieux, "Autres"
  /// et Actions & Fonds peuvent rattacher un document à une transaction
  /// précise.
  bool get _usesTransactionScopedDocuments {
    final effectiveClass =
        widget.investment.assetClass ?? widget.account.assetClass;
    return effectiveClass == AssetClass.metauxPrecieux ||
        effectiveClass == AssetClass.autres ||
        effectiveClass == AssetClass.actionsEtFonds;
  }

  /// Le champ de date de déblocage a-t-il un sens pour cette transaction —
  /// PEG/PEE et achat uniquement.
  bool get _unlockDateApplicable {
    if (!_isBuy) return false;
    final envelope = widget.account.envelope;
    return envelope == AccountEnvelope.peg || envelope == AccountEnvelope.pee;
  }

  /// Date de déblocage affichée/éditable : [_unlockDateOverride] si
  /// renseignée, sinon la date par défaut calculée depuis [_date] (voir
  /// [pegPeeUnlockDateFor]). `null` hors PEG/PEE, pour une vente, ou sans
  /// date choisie.
  DateTime? get _unlockDate {
    if (!_unlockDateApplicable) return null;
    if (_unlockDateOverride != null) return _unlockDateOverride;
    final date = _date;
    return date == null ? null : pegPeeUnlockDateFor(date);
  }

  bool get _isCurrency =>
      isCurrencyInvestment(widget.account, widget.investment);

  bool get _isEurCurrency =>
      _isCurrency && widget.investment.isin.trim().toUpperCase() == 'EUR';

  bool get _showCurrencySelector => !_isEurCurrency && !_isCurrency;

  String get _quantityFieldLabel {
    if (!_isCurrency) return 'Quantité';
    return _isEurCurrency
        ? 'Montant (€)'
        : 'Montant (${widget.investment.isin})';
  }

  String get _priceFieldLabel =>
      _isCurrency ? 'Cours de la paire de devise' : 'Prix unitaire';

  String get _txnCurrency =>
      _isCurrency ? 'EUR' : _priceCurrencyController.currency;

  double? get _txnFxRateToEur =>
      _txnCurrency == 'EUR' ? 1.0 : _priceCurrencyController.resolvedRate;

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void initState() {
    super.initState();
    _investment = widget.investment;
    _isBuy = widget.transaction.isBuy;
    _date = widget.transaction.date;
    _unlockDateOverride = widget.transaction.manualUnlockDate;
    _quantityController = TextEditingController(
      text: _formatNumber(widget.transaction.quantity),
    );
    _priceController = TextEditingController(
      text: _formatNumber(widget.transaction.unitPrice),
    );
    _noteController = TextEditingController(
      text: widget.transaction.note ?? '',
    );
    _priceCurrencyController = TransactionPriceCurrencyController(
      vaultPath: widget.vaultPath,
    );
    _priceCurrencyController.loadFrom(widget.transaction);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    _priceCurrencyController.dispose();
    super.dispose();
  }

  /// [_noteController]'s text, ou `null` s'il est vide (voir
  /// [Transaction.note] — jamais une chaîne vide persistée).
  String? get _noteOrNull {
    final text = _noteController.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _commit() async {
    final date = _date;
    final quantity = parseDecimal(_quantityController.text);
    final price = _isEurCurrency ? 1.0 : parseDecimal(_priceController.text);
    final currency = _txnCurrency;
    final fxRateToEur = _txnFxRateToEur;
    // Un objet "Autres" peut avoir été reçu en cadeau (prix d'achat 0) —
    // voir `position_detail_dialog.dart`'s équivalent pour le raisonnement
    // complet.
    final effectiveClass =
        widget.investment.assetClass ?? widget.account.assetClass;
    final invalidPrice =
        price == null ||
        price < 0 ||
        (price == 0 && effectiveClass != AssetClass.autres);
    if (date == null ||
        quantity == null ||
        quantity <= 0 ||
        invalidPrice ||
        fxRateToEur == null ||
        fxRateToEur <= 0) {
      return;
    }
    final updatedTransaction = Transaction(
      id: widget.transaction.id,
      date: date,
      isBuy: _isBuy,
      quantity: quantity,
      unitPrice: price,
      currency: currency,
      fxRateToEur: fxRateToEur,
      manualUnlockDate: _unlockDateOverride,
      note: _noteOrNull,
      // Ni l'un ni l'autre n'est éditable depuis ce formulaire générique —
      // les omettre les réinitialiserait à `null` silencieusement,
      // détachant une transaction de dépôt/dividende/transfert/arbitrage de
      // sa nature ou de sa contrepartie sans aucun avertissement.
      type: widget.transaction.type,
      linkedTransactionId: widget.transaction.linkedTransactionId,
    );
    // Repart de `_investment` (pas `widget.investment`) : un document ajouté
    // ou supprimé pendant cette édition (voir `_addDocument`/
    // `_deleteDocument`) a déjà mis à jour cet état local, à ne pas perdre
    // en écrasant `documents` avec sa valeur d'ouverture de la popup.
    await widget.onSave(
      _investment.copyWith(
        transactions: [
          for (final t in _investment.transactions)
            if (t.id == widget.transaction.id) updatedTransaction else t,
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Ajoute un document rattaché à cette transaction — possible même après
  /// coup, sans repasser par sa création (voir `TransactionForm`'s
  /// `documentsSection`).
  Future<void> _addDocument(
    String fileName,
    Uint8List bytes,
    String? transactionId,
    String? name,
  ) async {
    final document = VaultDocument(
      fileName: fileName,
      note: name,
      transactionId: transactionId,
    );
    await DocumentStorage(widget.vaultPath).save(document, bytes);
    final updated = _investment.copyWith(
      documents: [..._investment.documents, document],
    );
    await widget.onSave(updated);
    if (!mounted) return;
    setState(() => _investment = updated);
  }

  Future<void> _deleteDocument(VaultDocument document) async {
    await DocumentStorage(widget.vaultPath).delete(document);
    final updated = _investment.copyWith(
      documents: [
        for (final d in _investment.documents)
          if (d.id != document.id) d,
      ],
    );
    await widget.onSave(updated);
    if (!mounted) return;
    setState(() => _investment = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: shadcn.Text(
                          'Modifier la transaction — ${widget.investment.label}',
                        ).large().semiBold(),
                      ),
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TransactionForm(
                    isBuy: _isBuy,
                    date: _date,
                    quantityController: _quantityController,
                    priceController: _priceController,
                    noteController: _noteController,
                    quantityLabel: _quantityFieldLabel,
                    priceLabel: _priceFieldLabel,
                    showPriceField: !_isEurCurrency,
                    showCurrencySelector: _showCurrencySelector,
                    priceCurrencyController: _priceCurrencyController,
                    onIsBuyChanged: (v) => setState(() => _isBuy = v),
                    onDateChanged: (d) => setState(() => _date = d),
                    unlockDate: _unlockDate,
                    onUnlockDateChanged: _unlockDateApplicable
                        ? (d) => setState(() => _unlockDateOverride = d)
                        : null,
                    onCreate: _commit,
                    onCancel: () => Navigator.of(context).pop(),
                    submitLabel: 'Enregistrer',
                    documentsSection: _usesTransactionScopedDocuments
                        ? DocumentsSection(
                            vaultPath: widget.vaultPath,
                            documents: [
                              for (final d in _investment.documents)
                                if (d.transactionId == widget.transaction.id) d,
                            ],
                            fixedTransactionId: widget.transaction.id,
                            quantityAssetClass: widget.investment.assetClass,
                            onAdd: _addDocument,
                            onDelete: _deleteDocument,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

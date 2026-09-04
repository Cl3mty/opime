import 'dart:typed_data';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../l10n/app_localizations.dart';
import '../../../core/money_format.dart' show displayEuros, parseDecimal;
import '../../../core/ui/frosted_card.dart';
import '../../../core/ui/opime_date_picker.dart';
import '../document_storage.dart';
import '../documents_section.dart';
import '../investments_models.dart';
import '../investments_repository.dart';
import 'investment_edit_form.dart' show InvestmentIdentityFields;

const _newPositionValue = '__new__';

/// Ouvre le dialogue de transfert d'un titre — le même titre déplacé du
/// compte [sourceAccount] vers un autre compte du vault, PRU conservé (la
/// vente sur le compte source et l'achat sur le compte destination
/// utilisent tous deux le PRU actuel de [sourceInvestment], jamais le cours
/// du marché) : aucune plus/moins-value n'est réalisée ni perdue par le
/// transfert lui-même. Voir [showArbitrageDialog] pour changer de titre
/// plutôt que de compte.
Future<void> showTransferDialog(
  BuildContext context, {
  required String vaultPath,
  required InvestmentAccount sourceAccount,
  required Investment sourceInvestment,
  required Future<void> Function() onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TransferArbitrageDialog(
      mode: _Mode.transfer,
      vaultPath: vaultPath,
      sourceAccount: sourceAccount,
      sourceInvestment: sourceInvestment,
      onChanged: onChanged,
    ),
  );
}

/// Ouvre le dialogue d'arbitrage d'un titre — vente de [sourceInvestment]
/// au cours du marché (réalise sa plus/moins-value latente) suivie de
/// l'achat d'un autre titre avec le produit exact de la vente, au sein du
/// même compte [sourceAccount] (sens strict du terme en assurance-vie/PER,
/// changer de support à l'intérieur d'un même contrat). Voir
/// [showTransferDialog] pour déplacer le même titre vers un autre compte.
Future<void> showArbitrageDialog(
  BuildContext context, {
  required String vaultPath,
  required InvestmentAccount sourceAccount,
  required Investment sourceInvestment,
  required Future<void> Function() onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TransferArbitrageDialog(
      mode: _Mode.arbitrage,
      vaultPath: vaultPath,
      sourceAccount: sourceAccount,
      sourceInvestment: sourceInvestment,
      onChanged: onChanged,
    ),
  );
}

enum _Mode { transfer, arbitrage }

/// Cours en euros du dernier prix connu de [investment], ou son estimation
/// manuelle à défaut — même calcul que `real_patrimoine_adapter.dart`'s
/// `_lastPriceToEur` (privée à ce fichier, dupliquée ici plutôt
/// qu'exportée : un seul appelant en dehors de ce fichier n'en justifie pas
/// le partage). Sert de valeur par défaut au prix de vente d'un arbitrage.
double? _lastPriceToEur(Investment investment) {
  final lastPrice = investment.lastPrice;
  if (lastPrice != null) return lastPrice * (investment.lastFxRateToEur ?? 1.0);
  return investment.manualPrice;
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

/// Arrondi à 4 décimales pour l'AFFICHAGE seul (jamais pour la quantité
/// réellement enregistrée dans la transaction, voir [_commitArbitrage]) —
/// une division comme `(quantité * prix) / prix` produit typiquement un
/// double avec 12+ décimales bruyantes (ex: `9.138997158782999`), illisible
/// dans le texte d'aide "quantité achetée".
double _roundForDisplay(double value) => (value * 10000).round() / 10000;

String _accountLabel(InvestmentAccount account) => account.bankName != null
    ? '${account.bankName} — ${account.name}'
    : account.name;

class _TransferArbitrageDialog extends StatefulWidget {
  final _Mode mode;
  final String vaultPath;
  final InvestmentAccount sourceAccount;
  final Investment sourceInvestment;
  final Future<void> Function() onChanged;

  const _TransferArbitrageDialog({
    required this.mode,
    required this.vaultPath,
    required this.sourceAccount,
    required this.sourceInvestment,
    required this.onChanged,
  });

  @override
  State<_TransferArbitrageDialog> createState() =>
      _TransferArbitrageDialogState();
}

class _TransferArbitrageDialogState extends State<_TransferArbitrageDialog> {
  late final InvestmentsRepository _repo;

  /// Copie locale du compte source, mise à jour à chaque document ajouté/
  /// retiré (voir [_addDocument]) — comme `add_transaction_dialog.dart`'s
  /// `_account`, la popup n'est pas reconstruite par le parent tant qu'elle
  /// est ouverte, contrairement à `widget.sourceAccount` qui reste figé sur
  /// l'état au moment de l'ouverture.
  late InvestmentAccount _sourceAccountState;

  /// Ids pré-générés des deux jambes de l'opération — permet d'attacher des
  /// documents (voir [_addDocument]) à la position source avant même que
  /// les transactions n'existent ; ils en deviennent les ids réels à la
  /// validation ([_commitTransfer]/[_commitArbitrage]).
  late final String _sellId;
  late final String _buyId;

  DateTime? _date;
  late final TextEditingController _quantityController;
  late final TextEditingController _sellPriceController;

  /// Prix d'achat de la position destination — uniquement en mode
  /// arbitrage (transfert : même titre, même prix des deux côtés, voir
  /// [_sellPriceController]).
  final _buyPriceController = TextEditingController();

  final _isinController = TextEditingController();
  final _labelController = TextEditingController();

  /// Comptes du vault (mode transfert uniquement — sert le sélecteur de
  /// compte destination). Vide et non chargé en mode arbitrage, qui reste
  /// toujours dans [InvestmentAccount] `sourceAccount`.
  List<InvestmentAccount> _allAccounts = [];
  bool _loadingAccounts = false;

  /// Compte destination choisi (mode transfert) — `null` tant qu'aucun
  /// autre compte n'est disponible/choisi.
  String? _destAccountId;

  /// Id de la position destination choisie, ou [_newPositionValue] pour en
  /// créer une nouvelle.
  late String _destSelection;

  bool get _isTransfer => widget.mode == _Mode.transfer;

  /// Comptes du vault autres que celui de la position source — seuls
  /// éligibles comme destination d'un transfert.
  List<InvestmentAccount> get _otherAccounts => [
    for (final a in _allAccounts)
      if (a.id != widget.sourceAccount.id) a,
  ];

  InvestmentAccount? get _destAccount {
    if (!_isTransfer) return _sourceAccountState;
    final id = _destAccountId;
    if (id == null) return null;
    for (final a in _allAccounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Positions parmi lesquelles choisir la destination — celles du compte
  /// destination (transfert) ou du compte source hors position elle-même
  /// (arbitrage, on ne peut pas arbitrer un titre vers lui-même).
  List<Investment> get _destCandidates {
    final account = _destAccount;
    if (account == null) return const [];
    return [
      for (final i in account.investments)
        if (i.id != widget.sourceInvestment.id) i,
    ];
  }

  /// Position source à jour — porte les documents déjà attachés (voir
  /// [_addDocument]), contrairement à `widget.sourceInvestment` qui reste
  /// figé sur l'état de l'ouverture du dialogue.
  Investment get _currentSourceInvestment {
    for (final i in _sourceAccountState.investments) {
      if (i.id == widget.sourceInvestment.id) return i;
    }
    return widget.sourceInvestment;
  }

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    _sourceAccountState = widget.sourceAccount;
    _sellId = generateInvestmentId('txn');
    _buyId = generateInvestmentId('txn');
    final today = DateTime.now();
    _date = DateTime(today.year, today.month, today.day);
    _quantityController = TextEditingController(
      text: _formatNumber(widget.sourceInvestment.quantityHeld),
    );
    _sellPriceController = TextEditingController(
      text: _formatNumber(
        _isTransfer
            ? widget.sourceInvestment.pru
            : (_lastPriceToEur(widget.sourceInvestment) ?? 0),
      ),
    );
    _destSelection = _newPositionValue;
    if (_isTransfer) {
      _loadingAccounts = true;
      _loadAccounts();
    } else {
      _prefillNewPositionFields();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _sellPriceController.dispose();
    _buyPriceController.dispose();
    _isinController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _repo.listAll();
    if (!mounted) return;
    setState(() {
      _allAccounts = accounts;
      _loadingAccounts = false;
    });
    final others = _otherAccounts;
    if (others.isNotEmpty) _selectDestAccount(others.first.id);
  }

  /// Bascule de compte destination (transfert) : présélectionne une
  /// position existante de même ISIN dans ce compte si elle existe, sinon
  /// "+ Nouvelle position" avec l'identité du titre source reprise.
  void _selectDestAccount(String accountId) {
    setState(() {
      _destAccountId = accountId;
      final account = _destAccount;
      final match = account?.investments.where(
        (i) => i.isin == widget.sourceInvestment.isin,
      );
      _destSelection = (match != null && match.isNotEmpty)
          ? match.first.id
          : _newPositionValue;
      if (_destSelection == _newPositionValue) _prefillNewPositionFields();
    });
  }

  void _prefillNewPositionFields() {
    if (_isTransfer) {
      _isinController.text = widget.sourceInvestment.isin;
      _labelController.text = widget.sourceInvestment.label;
    }
  }

  bool get _isNewDestPosition => _destSelection == _newPositionValue;

  Investment? get _selectedDestInvestment {
    if (_isNewDestPosition) return null;
    for (final i in _destCandidates) {
      if (i.id == _destSelection) return i;
    }
    return null;
  }

  /// Construit la position destination (existante mise à jour, ou nouvelle
  /// créée) avec [buyTransaction] ajoutée — commun aux deux modes.
  Investment? _buildDestInvestment(
    InvestmentAccount destAccount,
    Transaction buyTransaction,
  ) {
    final existing = _selectedDestInvestment;
    if (existing != null) {
      return existing.copyWith(
        transactions: [...existing.transactions, buyTransaction],
      );
    }
    final rawIsin = _isinController.text.trim();
    final isin =
        identifierOptionsFor(
              destAccount.assetClass,
              accountEnvelope: destAccount.envelope,
            ) ==
            null
        ? rawIsin.toUpperCase()
        : rawIsin;
    final label = _labelController.text.trim();
    final identifierRequired = !isinOptionalFor(
      destAccount.assetClass,
      accountEnvelope: destAccount.envelope,
    );
    if ((identifierRequired && isin.isEmpty) || label.isEmpty) return null;
    return Investment(
      isin: isin.isNotEmpty ? isin : placeholderIsinFor(destAccount.assetClass),
      label: label,
      transactions: [buyTransaction],
      // Reprend la classe effective de la position source (ex : un ETC or
      // logé dans un CTO) — pertinent seulement pour un transfert, une
      // position d'arbitrage étant un titre distinct sans lien de classe
      // avec la source.
      assetClass: _isTransfer ? widget.sourceInvestment.assetClass : null,
    );
  }

  InvestmentAccount _accountWithInvestment(
    InvestmentAccount account,
    Investment updated, {
    bool isNew = false,
  }) {
    return account.copyWith(
      investments: [
        for (final i in account.investments)
          if (i.id == updated.id) updated else i,
        if (isNew) updated,
      ],
    );
  }

  /// Ajoute un document justificatif (confirmation de transfert/arbitrage,
  /// avis d'opéré...) — toujours rattaché à la position SOURCE, avec
  /// [_sellId] comme id de transaction : elle existe déjà (contrairement à
  /// une éventuelle nouvelle position destination), donc pas besoin du
  /// mécanisme d'attente utilisé par `add_transaction_dialog.dart` pour une
  /// position pas encore créée. Persisté immédiatement, comme partout
  /// ailleurs dans l'app — le document survit même si le transfert/
  /// arbitrage n'est jamais validé.
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
    final updatedInvestment = _currentSourceInvestment.copyWith(
      documents: [..._currentSourceInvestment.documents, document],
    );
    final updatedAccount = _accountWithInvestment(
      _sourceAccountState,
      updatedInvestment,
    );
    await _repo.saveAccount(updatedAccount);
    if (!mounted) return;
    setState(() => _sourceAccountState = updatedAccount);
  }

  Future<void> _deleteDocument(VaultDocument document) async {
    await DocumentStorage(widget.vaultPath).delete(document);
    final updatedInvestment = _currentSourceInvestment.copyWith(
      documents: [
        for (final d in _currentSourceInvestment.documents)
          if (d.id != document.id) d,
      ],
    );
    final updatedAccount = _accountWithInvestment(
      _sourceAccountState,
      updatedInvestment,
    );
    await _repo.saveAccount(updatedAccount);
    if (!mounted) return;
    setState(() => _sourceAccountState = updatedAccount);
  }

  /// Message expliquant pourquoi la validation a échoué — évalué seulement
  /// quand elle échoue, sur les mêmes variables potentiellement nulles que
  /// le garde-fou de [_commitTransfer] (qui, lui, reste une condition
  /// unique : c'est ce qui permet à l'analyseur de promouvoir `quantity`/
  /// `price`/`destAccount` en non-nuls dans le reste de la méthode une fois
  /// la validation passée).
  String _transferValidationError(
    AppLocalizations l10n, {
    required double? quantity,
    required double? price,
    required InvestmentAccount? destAccount,
  }) {
    if (quantity == null || quantity <= 0) {
      return l10n.investments_error_quantity_must_be_positive;
    }
    if (quantity > widget.sourceInvestment.quantityHeld + 1e-9) {
      return l10n.investments_error_quantity_exceeds_sellable(
        _formatNumber(quantity),
        _formatNumber(widget.sourceInvestment.quantityHeld),
      );
    }
    if (price == null || price <= 0) {
      return l10n.investments_error_pru_must_be_positive;
    }
    if (destAccount == null) {
      return l10n.investments_error_dest_account_required;
    }
    return l10n.investments_error_date_required;
  }

  Future<void> _commitTransfer() async {
    final l10n = AppLocalizations.of(context);
    final date = _date;
    final quantity = parseDecimal(_quantityController.text);
    final price = parseDecimal(_sellPriceController.text);
    final destAccount = _destAccount;
    if (date == null ||
        quantity == null ||
        quantity <= 0 ||
        quantity > widget.sourceInvestment.quantityHeld + 1e-9 ||
        price == null ||
        price <= 0 ||
        destAccount == null) {
      _showToast(
        title: l10n.investments_transfer_impossible_title,
        subtitle: _transferValidationError(
          l10n,
          quantity: quantity,
          price: price,
          destAccount: destAccount,
        ),
      );
      return;
    }

    final sellTransaction = Transaction(
      id: _sellId,
      date: date,
      isBuy: false,
      quantity: quantity,
      unitPrice: price,
      type: TransactionType.transfer,
      linkedTransactionId: _buyId,
    );
    final buyTransaction = Transaction(
      id: _buyId,
      date: date,
      isBuy: true,
      quantity: quantity,
      unitPrice: price,
      type: TransactionType.transfer,
      linkedTransactionId: _sellId,
    );

    final updatedDestInvestment = _buildDestInvestment(
      destAccount,
      buyTransaction,
    );
    if (updatedDestInvestment == null) {
      _showToast(
        title: l10n.investments_transfer_impossible_title,
        subtitle: l10n.investments_error_new_position_fields_required,
      );
      return;
    }

    final updatedSourceInvestment = _currentSourceInvestment.copyWith(
      transactions: [
        ..._currentSourceInvestment.transactions,
        sellTransaction,
      ],
    );
    final updatedSourceAccount = _accountWithInvestment(
      _sourceAccountState,
      updatedSourceInvestment,
    );
    final updatedDestAccount = _accountWithInvestment(
      destAccount,
      updatedDestInvestment,
      isNew: _isNewDestPosition,
    );

    try {
      await _repo.saveAccount(updatedSourceAccount);
      await _repo.saveAccount(updatedDestAccount);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        title: l10n.investments_transfer_impossible_title,
        subtitle: l10n.investments_save_error(e.toString()),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onChanged();
  }

  /// Voir [_transferValidationError] : même principe, évalué seulement sur
  /// l'échec du garde-fou unique de [_commitArbitrage].
  String _arbitrageValidationError(
    AppLocalizations l10n, {
    required double? quantity,
    required double? sellPrice,
    required double? buyPrice,
  }) {
    if (quantity == null || quantity <= 0) {
      return l10n.investments_error_quantity_must_be_positive;
    }
    if (quantity > widget.sourceInvestment.quantityHeld + 1e-9) {
      return l10n.investments_error_quantity_exceeds_sellable(
        _formatNumber(quantity),
        _formatNumber(widget.sourceInvestment.quantityHeld),
      );
    }
    if (sellPrice == null || sellPrice <= 0) {
      return l10n.investments_error_sell_price_must_be_positive;
    }
    if (buyPrice == null || buyPrice <= 0) {
      return l10n.investments_error_buy_price_must_be_positive;
    }
    return l10n.investments_error_date_required;
  }

  Future<void> _commitArbitrage() async {
    final l10n = AppLocalizations.of(context);
    final date = _date;
    final quantity = parseDecimal(_quantityController.text);
    final sellPrice = parseDecimal(_sellPriceController.text);
    final buyPrice = parseDecimal(_buyPriceController.text);
    if (date == null ||
        quantity == null ||
        quantity <= 0 ||
        quantity > widget.sourceInvestment.quantityHeld + 1e-9 ||
        sellPrice == null ||
        sellPrice <= 0 ||
        buyPrice == null ||
        buyPrice <= 0) {
      _showToast(
        title: l10n.investments_arbitrage_impossible_title,
        subtitle: _arbitrageValidationError(
          l10n,
          quantity: quantity,
          sellPrice: sellPrice,
          buyPrice: buyPrice,
        ),
      );
      return;
    }
    // Quantité achetée dérivée du produit de la vente, jamais saisie
    // directement : garantit que l'arbitrage ne fait ni apport ni retrait
    // de cash, propriété qui le définit (voir la doc de tête du fichier).
    final destQuantity = (quantity * sellPrice) / buyPrice;

    final sellTransaction = Transaction(
      id: _sellId,
      date: date,
      isBuy: false,
      quantity: quantity,
      unitPrice: sellPrice,
      type: TransactionType.arbitrage,
      linkedTransactionId: _buyId,
    );
    final buyTransaction = Transaction(
      id: _buyId,
      date: date,
      isBuy: true,
      quantity: destQuantity,
      unitPrice: buyPrice,
      type: TransactionType.arbitrage,
      linkedTransactionId: _sellId,
    );

    final updatedDestInvestment = _buildDestInvestment(
      _sourceAccountState,
      buyTransaction,
    );
    if (updatedDestInvestment == null) {
      _showToast(
        title: l10n.investments_arbitrage_impossible_title,
        subtitle: l10n.investments_error_new_position_fields_required,
      );
      return;
    }

    final updatedSourceInvestment = _currentSourceInvestment.copyWith(
      transactions: [
        ..._currentSourceInvestment.transactions,
        sellTransaction,
      ],
    );

    final updatedAccount = _sourceAccountState.copyWith(
      investments: [
        for (final i in _sourceAccountState.investments)
          if (i.id == updatedSourceInvestment.id)
            updatedSourceInvestment
          else if (i.id == updatedDestInvestment.id)
            updatedDestInvestment
          else
            i,
        if (_isNewDestPosition) updatedDestInvestment,
      ],
    );

    try {
      await _repo.saveAccount(updatedAccount);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        title: l10n.investments_arbitrage_impossible_title,
        subtitle: l10n.investments_save_error(e.toString()),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onChanged();
  }

  /// Retour visible sur toute validation refusée ou erreur d'enregistrement
  /// — sans ça, un `PrimaryButton.onPressed` pointant vers une méthode
  /// async échoue silencieusement au moindre souci (le `Future` rejeté
  /// n'est jamais attendu par le framework), laissant l'utilisateur sans
  /// aucun indice sur la raison du blocage.
  void _showToast({required String title, required String subtitle}) {
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: shadcn.Text(title),
          subtitle: shadcn.Text(subtitle),
        ),
      ),
    );
  }

  Widget _labeledField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(label).muted().xSmall(),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildDestinationPicker(List<Investment> candidates) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(l10n.investments_field_position).muted().xSmall(),
        const SizedBox(height: 4),
        Select<String>(
          value: _destSelection,
          constraints: const BoxConstraints(minWidth: 260),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _destSelection = v;
              if (_isNewDestPosition) _prefillNewPositionFields();
            });
          },
          itemBuilder: (context, value) => shadcn.Text(
            value == _newPositionValue
                ? l10n.investments_new_position_option
                : candidates.firstWhere((i) => i.id == value).label,
          ),
          popup: (context) => SelectPopup(
            items: SelectItemList(
              children: [
                for (final investment in candidates)
                  SelectItemButton(
                    value: investment.id,
                    child: shadcn.Text(investment.label),
                  ),
                SelectItemButton(
                  value: _newPositionValue,
                  child: shadcn.Text(l10n.investments_new_position_option),
                ),
              ],
            ),
          ),
        ),
        if (_isNewDestPosition) ...[
          const SizedBox(height: 12),
          InvestmentIdentityFields(
            assetClass:
                _destAccount?.assetClass ?? widget.sourceAccount.assetClass,
            accountEnvelope:
                _destAccount?.envelope ?? widget.sourceAccount.envelope,
            isinController: _isinController,
            labelController: _labelController,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                          _isTransfer
                              ? l10n.investments_transfer_title(
                                  widget.sourceInvestment.label,
                                )
                              : l10n.investments_arbitrage_title(
                                  widget.sourceInvestment.label,
                                ),
                        ).large().semiBold(),
                      ),
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  shadcn.Text(
                    _isTransfer
                        ? l10n.investments_transfer_description
                        : l10n.investments_arbitrage_description,
                  ).muted().xSmall(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _labeledField(
                          l10n.investments_field_quantity,
                          _quantityController,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _labeledField(
                          _isTransfer
                              ? l10n.investments_field_pru_kept
                              : l10n.investments_field_sell_price,
                          _sellPriceController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  shadcn.Text(l10n.common_date).muted().xSmall(),
                  const SizedBox(height: 4),
                  OpimeDatePicker(
                    value: _date,
                    onChanged: (d) => setState(() => _date = d),
                  ),
                  const SizedBox(height: 16),
                  if (_isTransfer) ...[
                    if (_loadingAccounts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_otherAccounts.isEmpty)
                      shadcn.Text(
                        l10n.investments_no_other_account_for_transfer,
                      ).muted().small()
                    else ...[
                      shadcn.Text(
                        l10n.investments_field_dest_account,
                      ).muted().xSmall(),
                      const SizedBox(height: 4),
                      Select<String>(
                        value: _destAccountId,
                        constraints: const BoxConstraints(minWidth: 260),
                        onChanged: (v) {
                          if (v != null) _selectDestAccount(v);
                        },
                        itemBuilder: (context, value) => shadcn.Text(
                          _accountLabel(
                            _otherAccounts.firstWhere((a) => a.id == value),
                          ),
                        ),
                        popup: (context) => SelectPopup(
                          items: SelectItemList(
                            children: [
                              for (final account in _otherAccounts)
                                SelectItemButton(
                                  value: account.id,
                                  child: shadcn.Text(_accountLabel(account)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDestinationPicker(_destCandidates),
                    ],
                  ] else ...[
                    _buildDestinationPicker(_destCandidates),
                    const SizedBox(height: 12),
                    _labeledField(
                      l10n.investments_field_dest_buy_price,
                      _buyPriceController,
                    ),
                    const SizedBox(height: 4),
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _quantityController,
                        _sellPriceController,
                        _buyPriceController,
                      ]),
                      builder: (context, _) {
                        final quantity = parseDecimal(_quantityController.text);
                        final sellPrice = parseDecimal(
                          _sellPriceController.text,
                        );
                        final buyPrice = parseDecimal(_buyPriceController.text);
                        final amount = (quantity != null && sellPrice != null)
                            ? quantity * sellPrice
                            : null;
                        final destQuantity =
                            (amount != null && buyPrice != null && buyPrice > 0)
                            ? amount / buyPrice
                            : null;
                        return shadcn.Text(
                          amount == null
                              ? l10n.investments_amount_obtained_placeholder
                              : destQuantity == null
                              ? l10n.investments_amount_obtained_value(
                                  displayEuros(amount, false),
                                )
                              : l10n.investments_amount_obtained_with_bought_quantity(
                                  displayEuros(amount, false),
                                  _formatNumber(
                                    _roundForDisplay(destQuantity),
                                  ),
                                ),
                        ).muted().xSmall();
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  DocumentsSection(
                    vaultPath: widget.vaultPath,
                    // Toujours rattachés à la position source (voir
                    // [_addDocument]) — un seul justificatif décrit
                    // l'opération dans son ensemble, pas la peine de le
                    // dupliquer côté destination.
                    documents: [
                      for (final d in _currentSourceInvestment.documents)
                        if (d.transactionId == _sellId) d,
                    ],
                    fixedTransactionId: _sellId,
                    quantityAssetClass:
                        widget.sourceInvestment.assetClass ??
                        widget.sourceAccount.assetClass,
                    onAdd: _addDocument,
                    onDelete: _deleteDocument,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      PrimaryButton(
                        onPressed: _isTransfer
                            ? _commitTransfer
                            : _commitArbitrage,
                        child: shadcn.Text(
                          _isTransfer
                              ? l10n.investments_transfer_button
                              : l10n.investments_arbitrage_button,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlineButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: shadcn.Text(l10n.common_cancel),
                      ),
                    ],
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

import 'dart:typed_data';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart';
import '../../../core/ui/copyable_identifier.dart';
import '../../../core/ui/frosted_card.dart';
import '../../../core/ui/toggle_button_style.dart';
import '../confirm_delete_dialog.dart';
import '../currency_format.dart';
import '../document_storage.dart';
import '../documents_section.dart';
import '../investments_models.dart';
import '../investments_repository.dart';
import '../performance_calculator.dart';
import '../price_history_repository.dart';
import '../transaction_price_currency.dart';
import '../yahoo_finance_client.dart' show PricePoint;
import 'investment_edit_form.dart';
import 'transaction_widgets.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

enum _PerfMode { twr, mwr }

/// Ouvre la popup de détail d'une position d'un compte Actions & Fonds —
/// remplace l'ancienne "page actif" (`investment_detail_screen.dart`,
/// toujours utilisée par les autres classes d'actif) pour ce compte :
/// identifiants, quantité/PRU/cours, bascule TWR/MWR, historique complet
/// des transactions de cette position avec ajout/édition/suppression, et
/// édition ISIN/libellé/style de fonds.
Future<void> showPositionDetailDialog(
  BuildContext context, {
  required String vaultPath,
  required InvestmentAccount account,
  required Investment investment,
  required bool hidden,
  required Future<void> Function() onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _PositionDetailDialog(
      vaultPath: vaultPath,
      account: account,
      investment: investment,
      hidden: hidden,
      onChanged: onChanged,
    ),
  );
}

class _PositionDetailDialog extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final Investment investment;
  final bool hidden;
  final Future<void> Function() onChanged;

  const _PositionDetailDialog({
    required this.vaultPath,
    required this.account,
    required this.investment,
    required this.hidden,
    required this.onChanged,
  });

  @override
  State<_PositionDetailDialog> createState() => _PositionDetailDialogState();
}

class _PositionDetailDialogState extends State<_PositionDetailDialog> {
  late InvestmentsRepository _repo;

  /// Copie locale de la position — une popup n'est pas reconstruite par le
  /// parent après une mutation (contrairement à une page embarquée dans
  /// l'arbre de widgets) : on met à jour cet état local à chaque
  /// sauvegarde pour refléter le changement immédiatement, en plus de
  /// prévenir le parent via [InvestmentDetailView.onChanged] (equivalent
  /// ici `widget.onChanged`) pour qu'il recharge une fois la popup fermée.
  late Investment _investment;
  List<PricePoint> _priceHistory = [];
  _PerfMode _perfMode = _PerfMode.twr;

  bool _creating = false;
  String? _editingTransactionId;
  bool _newIsBuy = true;
  DateTime? _newDate;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  late final TransactionPriceCurrencyController _priceCurrencyController;

  bool _editingInvestment = false;
  final _editIsinController = TextEditingController();
  final _editLabelController = TextEditingController();
  FundStyle? _editFundStyle;

  @override
  void initState() {
    super.initState();
    _investment = widget.investment;
    _repo = InvestmentsRepository(widget.vaultPath);
    _priceCurrencyController = TransactionPriceCurrencyController(
      vaultPath: widget.vaultPath,
    );
    _newDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _loadPriceHistory();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _priceCurrencyController.dispose();
    _editIsinController.dispose();
    _editLabelController.dispose();
    super.dispose();
  }

  Future<void> _loadPriceHistory() async {
    final history = await PriceHistoryRepository(
      widget.vaultPath,
    ).load(_investment.isin);
    if (!mounted) return;
    setState(() => _priceHistory = history);
  }

  /// Classe d'actif effective de la position (la sienne si renseignée —
  /// ex : un ETC or/argent logé dans ce CTO — sinon celle du compte).
  AssetClass get _effectiveClass =>
      _investment.assetClass ?? widget.account.assetClass;

  bool get _isRealIsin =>
      !_isCurrency &&
      (_effectiveClass == AssetClass.actionsEtFonds ||
          _effectiveClass == AssetClass.privateEquity);

  /// Métaux précieux et "Autres" : chaque document doit être rattaché à la
  /// transaction précise qu'il justifie — seul cas pertinent ici est un ETC
  /// or/argent logé dans ce compte (voir `investments_models.dart`'s
  /// `isMetalEtc`), l'immense majorité des positions d'un compte Actions &
  /// Fonds n'ont pas de documents scopés à la transaction.
  bool get _usesTransactionScopedDocuments =>
      _effectiveClass == AssetClass.metauxPrecieux ||
      _effectiveClass == AssetClass.autres;

  bool get _isCurrency => isCurrencyInvestment(widget.account, _investment);

  bool get _isEurCurrency =>
      _isCurrency && _investment.isin.trim().toUpperCase() == 'EUR';

  bool get _showCurrencySelector => !_isEurCurrency && !_isCurrency;

  String get _quantityFieldLabel => _isCurrency
      ? (_isEurCurrency ? 'Montant (€)' : 'Montant (${_investment.isin})')
      : 'Quantité';

  String get _priceFieldLabel =>
      _isCurrency ? 'Cours de la paire de devise' : 'Prix unitaire';

  String get _txnCurrency =>
      _isCurrency ? 'EUR' : _priceCurrencyController.currency;

  double? get _txnFxRateToEur =>
      _txnCurrency == 'EUR' ? 1.0 : _priceCurrencyController.resolvedRate;

  Future<void> _saveInvestment(Investment updated) async {
    final updatedAccount = widget.account.copyWith(
      investments: [
        for (final i in widget.account.investments)
          if (i.id == updated.id) updated else i,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    if (!mounted) return;
    setState(() => _investment = updated);
    await widget.onChanged();
  }

  Future<void> _commitCreateTransaction() async {
    final date = _newDate;
    final quantity = parseDecimal(_quantityController.text);
    final price = _isEurCurrency ? 1.0 : parseDecimal(_priceController.text);
    final currency = _txnCurrency;
    final fxRateToEur = _txnFxRateToEur;
    if (date == null ||
        quantity == null ||
        quantity <= 0 ||
        price == null ||
        price <= 0 ||
        fxRateToEur == null ||
        fxRateToEur <= 0) {
      return;
    }
    await _saveInvestment(
      _investment.copyWith(
        transactions: [
          ..._investment.transactions,
          Transaction(
            date: date,
            isBuy: _newIsBuy,
            quantity: quantity,
            unitPrice: price,
            currency: currency,
            fxRateToEur: fxRateToEur,
          ),
        ],
      ),
    );
    _quantityController.clear();
    _priceController.clear();
    setState(() => _creating = false);
  }

  void _startEdit(Transaction transaction) {
    setState(() {
      _creating = false;
      _editingTransactionId = transaction.id;
      _newIsBuy = transaction.isBuy;
      _newDate = transaction.date;
      _quantityController.text = _formatNumber(transaction.quantity);
      _priceController.text = _formatNumber(transaction.unitPrice);
    });
    _priceCurrencyController.loadFrom(transaction);
  }

  void _cancelEdit() {
    _quantityController.clear();
    _priceController.clear();
    _priceCurrencyController.reset();
    setState(() => _editingTransactionId = null);
  }

  Future<void> _commitEditTransaction() async {
    final id = _editingTransactionId;
    final date = _newDate;
    final quantity = parseDecimal(_quantityController.text);
    final price = _isEurCurrency ? 1.0 : parseDecimal(_priceController.text);
    final currency = _txnCurrency;
    final fxRateToEur = _txnFxRateToEur;
    if (id == null ||
        date == null ||
        quantity == null ||
        quantity <= 0 ||
        price == null ||
        price <= 0 ||
        fxRateToEur == null ||
        fxRateToEur <= 0) {
      return;
    }
    final updatedTransaction = Transaction(
      id: id,
      date: date,
      isBuy: _newIsBuy,
      quantity: quantity,
      unitPrice: price,
      currency: currency,
      fxRateToEur: fxRateToEur,
    );
    await _saveInvestment(
      _investment.copyWith(
        transactions: [
          for (final t in _investment.transactions)
            if (t.id == id) updatedTransaction else t,
        ],
      ),
    );
    _quantityController.clear();
    _priceController.clear();
    setState(() => _editingTransactionId = null);
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer cette transaction ?',
      message:
          'Cette action est irréversible et modifiera la quantité détenue '
          'et le PRU de cette position.',
    );
    if (!confirmed) return;
    final orphanedDocuments = [
      for (final d in _investment.documents)
        if (d.transactionId == transaction.id) d,
    ];
    for (final document in orphanedDocuments) {
      await DocumentStorage(widget.vaultPath).delete(document);
    }
    await _saveInvestment(
      _investment.copyWith(
        transactions: [
          for (final t in _investment.transactions)
            if (t.id != transaction.id) t,
        ],
        documents: [
          for (final d in _investment.documents)
            if (d.transactionId != transaction.id) d,
        ],
      ),
    );
  }

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
    await _saveInvestment(
      _investment.copyWith(documents: [..._investment.documents, document]),
    );
  }

  Future<void> _deleteDocument(VaultDocument document) async {
    await DocumentStorage(widget.vaultPath).delete(document);
    await _saveInvestment(
      _investment.copyWith(
        documents: [
          for (final d in _investment.documents)
            if (d.id != document.id) d,
        ],
      ),
    );
  }

  bool get _canDelete => _investment.transactions.isEmpty;

  Future<void> _deleteInvestment() async {
    if (!_canDelete) return;
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer "${_investment.label}" ?',
      message: 'Cette position sera définitivement supprimée.',
    );
    if (!confirmed) return;
    final updatedAccount = widget.account.copyWith(
      investments: [
        for (final i in widget.account.investments)
          if (i.id != _investment.id) i,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onChanged();
  }

  void _startEditInvestment() {
    setState(() {
      _editingInvestment = true;
      _editIsinController.text = _investment.isin;
      _editLabelController.text = _investment.label;
      _editFundStyle = _investment.fundStyle;
    });
  }

  Future<void> _commitEditInvestment() async {
    final rawIsin = _editIsinController.text.trim();
    final isin =
        identifierOptionsFor(
              _effectiveClass,
              accountEnvelope: widget.account.envelope,
            ) ==
            null
        ? rawIsin.toUpperCase()
        : rawIsin;
    final label = _editLabelController.text.trim();
    if (isin.isEmpty || label.isEmpty) return;
    final isinChanged = isin != _investment.isin;
    await _saveInvestment(
      Investment(
        id: _investment.id,
        isin: isin,
        label: label,
        transactions: _investment.transactions,
        symbol: isinChanged ? null : _investment.symbol,
        lastPrice: isinChanged ? null : _investment.lastPrice,
        lastPriceDate: isinChanged ? null : _investment.lastPriceDate,
        quoteCurrency: isinChanged ? null : _investment.quoteCurrency,
        lastFxRateToEur: isinChanged ? null : _investment.lastFxRateToEur,
        priceUnavailable: isinChanged ? null : _investment.priceUnavailable,
        assetClass: _investment.assetClass,
        fundStyle: _editFundStyle,
        documents: _investment.documents,
      ),
    );
    setState(() => _editingInvestment = false);
  }

  void _openInvestmentMenu(BuildContext anchorContext) {
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 240),
        child: DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.pencil, size: 14),
              child: const shadcn.Text('Modifier'),
              onPressed: (_) => _startEditInvestment(),
            ),
            MenuButton(
              enabled: _canDelete,
              leading: const Icon(LucideIcons.trash2, size: 14),
              trailing: _canDelete
                  ? null
                  : const shadcn.Text(
                      'Supprime d\'abord ses transactions',
                    ).muted().xSmall(),
              child: const shadcn.Text('Supprimer la position'),
              onPressed: (_) => _deleteInvestment(),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final investment = _investment;
    final hasPrice = investment.marketValue != null;
    final displayValue =
        investment.effectiveMarketValue ?? investment.investedAmount;

    PerformanceResult? performance;
    if (hasPrice) {
      performance = _perfMode == _PerfMode.mwr
          ? calculateMwr(
              transactions: investment.transactions,
              currentValue: investment.marketValue!,
              asOf: DateTime.now(),
            )
          : calculateTwr(
              transactions: investment.transactions,
              priceHistory: _priceHistory,
              currentValue: investment.marketValue!,
              asOf: DateTime.now(),
            );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
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
                        child: shadcn.Text(investment.label).large().semiBold(),
                      ),
                      Builder(
                        builder: (context) => IconButton.ghost(
                          icon: const Icon(
                            LucideIcons.ellipsisVertical,
                            size: 18,
                          ),
                          onPressed: () => _openInvestmentMenu(context),
                        ),
                      ),
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_editingInvestment)
                    InvestmentEditForm(
                      assetClass: _effectiveClass,
                      accountEnvelope: widget.account.envelope,
                      isinController: _editIsinController,
                      labelController: _editLabelController,
                      fundStyle: _editFundStyle,
                      onFundStyleChanged: (style) =>
                          setState(() => _editFundStyle = style),
                      onSave: _commitEditInvestment,
                      onCancel: () =>
                          setState(() => _editingInvestment = false),
                    )
                  else ...[
                    if (!_isCurrency) ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          CopyableIdentifier(
                            value: investment.isin,
                            toastTitle: _isRealIsin
                                ? 'ISIN copié'
                                : 'Identifiant copié',
                          ),
                          if (investment.symbol != null &&
                              investment.symbol!.isNotEmpty)
                            CopyableIdentifier(
                              value: investment.symbol!,
                              toastTitle: 'Ticker copié',
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    shadcn.Text(
                      displayEuros(displayValue, widget.hidden),
                    ).x2Large().bold(),
                    if (!_isCurrency && investment.fundStyle != null) ...[
                      const SizedBox(height: 4),
                      shadcn.Text(investment.fundStyle!.label).muted().small(),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      InvestmentStatChip(
                        label: 'Quantité détenue',
                        value: formatQuantity(
                          investment.quantityHeld,
                          _effectiveClass,
                        ),
                      ),
                      InvestmentStatChip(
                        label: 'PRU',
                        value: _isCurrency
                            ? '${investment.pru.toStringAsFixed(4)} €'
                            : displayEuros(investment.pru, widget.hidden),
                      ),
                      if (hasPrice)
                        InvestmentStatChip(
                          label: 'Dernier cours',
                          value: investmentLastPriceDisplay(
                            widget.account,
                            investment,
                            hidden: widget.hidden,
                          ),
                          trailing: investment.isPriceFresh
                              ? const FreshPriceBadge()
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (hasPrice) ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ButtonGroup(
                          children: [
                            SelectedButton(
                              value: _perfMode == _PerfMode.twr,
                              selectedStyle: const ButtonStyle.primary(),
                              style: toggleUnselectedStyle(context),
                              onChanged: (_) =>
                                  setState(() => _perfMode = _PerfMode.twr),
                              child: const shadcn.Text('TWR'),
                            ),
                            SelectedButton(
                              value: _perfMode == _PerfMode.mwr,
                              selectedStyle: const ButtonStyle.primary(),
                              style: toggleUnselectedStyle(context),
                              onChanged: (_) =>
                                  setState(() => _perfMode = _PerfMode.mwr),
                              child: const shadcn.Text('MWR'),
                            ),
                          ],
                        ),
                        if (performance != null)
                          shadcn.Text(
                            performance.annualized
                                ? '${displayPercent(performance.rate * 100)} / an'
                                : '${displayPercent(performance.rate * 100)} depuis '
                                      'le début',
                            style: TextStyle(
                              color: performance.rate >= 0 ? _green : _red,
                              fontWeight: FontWeight.w600,
                            ),
                          ).medium()
                        else
                          shadcn.Text(
                            'Pas assez d\'historique de cours pour ce calcul.',
                          ).muted().xSmall(),
                      ],
                    ),
                  ] else
                    shadcn.Text(
                      investment.priceUnavailable == true
                          ? 'Cours introuvable sur Yahoo Finance pour '
                                '« ${investment.isin} ».'
                          : 'Cours en temps réel pas encore disponible : la '
                                'valorisation ci-dessus correspond au montant '
                                'net investi.',
                    ).muted().xSmall(),
                  const SizedBox(height: 24),
                  const shadcn.Text('Transactions').large().medium(),
                  const SizedBox(height: 12),
                  for (final txn in investment.transactions.reversed) ...[
                    if (txn.id == _editingTransactionId)
                      TransactionForm(
                        isBuy: _newIsBuy,
                        date: _newDate,
                        quantityController: _quantityController,
                        priceController: _priceController,
                        quantityLabel: _quantityFieldLabel,
                        priceLabel: _priceFieldLabel,
                        showPriceField: !_isEurCurrency,
                        showCurrencySelector: _showCurrencySelector,
                        priceCurrencyController: _priceCurrencyController,
                        onIsBuyChanged: (v) => setState(() => _newIsBuy = v),
                        onDateChanged: (d) => setState(() => _newDate = d),
                        onCreate: _commitEditTransaction,
                        onCancel: _cancelEdit,
                        submitLabel: 'Enregistrer',
                        documentsSection: _usesTransactionScopedDocuments
                            ? DocumentsSection(
                                vaultPath: widget.vaultPath,
                                documents: [
                                  for (final d in investment.documents)
                                    if (d.transactionId == txn.id) d,
                                ],
                                fixedTransactionId: txn.id,
                                quantityAssetClass: investment.assetClass,
                                onAdd: _addDocument,
                                onDelete: _deleteDocument,
                              )
                            : null,
                      )
                    else
                      TransactionRow(
                        transaction: txn,
                        hidden: widget.hidden,
                        assetClass: _effectiveClass,
                        onEdit: () => _startEdit(txn),
                        onDelete: () => _deleteTransaction(txn),
                        documents: _usesTransactionScopedDocuments
                            ? [
                                for (final d in investment.documents)
                                  if (d.transactionId == txn.id) d,
                              ]
                            : const [],
                        vaultPath: _usesTransactionScopedDocuments
                            ? widget.vaultPath
                            : null,
                      ),
                    const SizedBox(height: 8),
                  ],
                  if (investment.transactions.isEmpty)
                    shadcn.Text(
                      'Aucune transaction pour l\'instant.',
                    ).muted().small(),
                  const SizedBox(height: 8),
                  if (_creating)
                    TransactionForm(
                      isBuy: _newIsBuy,
                      date: _newDate,
                      quantityController: _quantityController,
                      priceController: _priceController,
                      quantityLabel: _quantityFieldLabel,
                      priceLabel: _priceFieldLabel,
                      showPriceField: !_isEurCurrency,
                      showCurrencySelector: _showCurrencySelector,
                      priceCurrencyController: _priceCurrencyController,
                      onIsBuyChanged: (v) => setState(() => _newIsBuy = v),
                      onDateChanged: (d) => setState(() => _newDate = d),
                      onCreate: _commitCreateTransaction,
                      onCancel: () => setState(() => _creating = false),
                    )
                  else
                    AddTransactionButton(
                      onTap: () => setState(() {
                        _editingTransactionId = null;
                        _newIsBuy = true;
                        _newDate = DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        );
                        _quantityController.clear();
                        _priceController.clear();
                        _priceCurrencyController.reset();
                        _creating = true;
                      }),
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

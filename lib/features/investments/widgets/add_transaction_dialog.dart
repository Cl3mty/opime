import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart' show parseDecimal;
import '../../../core/ui/frosted_card.dart';
import '../investments_models.dart';
import '../investments_repository.dart';
import '../transaction_price_currency.dart';
import 'investment_edit_form.dart';
import 'transaction_widgets.dart';

const _newPositionValue = '__new__';

/// Ouvre la popup unifiée d'ajout de transaction d'un compte Actions &
/// Fonds — choix d'une position existante ou création d'une nouvelle,
/// puis saisie de la transaction (achat/vente, date, quantité, prix).
/// Déclenchée par le "+" en haut de l'onglet "Transactions" de
/// `stock_account_screen.dart` : seul point d'entrée pour ajouter à la
/// fois une position et sa première transaction, plutôt que deux flux
/// séparés comme sur l'ancienne page compte générique.
Future<void> showAddTransactionDialog(
  BuildContext context, {
  required String vaultPath,
  required InvestmentAccount account,
  required Future<void> Function() onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _AddTransactionDialog(
      vaultPath: vaultPath,
      account: account,
      onChanged: onChanged,
    ),
  );
}

class _AddTransactionDialog extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final Future<void> Function() onChanged;

  const _AddTransactionDialog({
    required this.vaultPath,
    required this.account,
    required this.onChanged,
  });

  @override
  State<_AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<_AddTransactionDialog> {
  late InvestmentsRepository _repo;

  /// Id de la position sélectionnée, ou [_newPositionValue] pour créer une
  /// nouvelle position — pas de position existante à sélectionner par
  /// défaut sur un compte encore vide.
  late String _selection;
  final _isinController = TextEditingController();
  final _labelController = TextEditingController();

  bool _isBuy = true;
  DateTime? _date;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  late final TransactionPriceCurrencyController _priceCurrencyController;

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    _priceCurrencyController = TransactionPriceCurrencyController(
      vaultPath: widget.vaultPath,
    );
    _date = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _selection = widget.account.investments.isEmpty
        ? _newPositionValue
        : widget.account.investments.first.id;
  }

  @override
  void dispose() {
    _isinController.dispose();
    _labelController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _priceCurrencyController.dispose();
    super.dispose();
  }

  bool get _isNewPosition => _selection == _newPositionValue;

  Investment? get _selectedInvestment {
    if (_isNewPosition) return null;
    for (final investment in widget.account.investments) {
      if (investment.id == _selection) return investment;
    }
    return null;
  }

  bool get _isCurrency {
    final investment = _selectedInvestment;
    return investment != null &&
        isCurrencyInvestment(widget.account, investment);
  }

  bool get _isEurCurrency =>
      _isCurrency && _selectedInvestment!.isin.trim().toUpperCase() == 'EUR';

  bool get _showCurrencySelector => !_isEurCurrency && !_isCurrency;

  String get _quantityFieldLabel {
    if (!_isCurrency) return 'Quantité';
    final isin = _selectedInvestment!.isin;
    return _isEurCurrency ? 'Montant (€)' : 'Montant ($isin)';
  }

  String get _priceFieldLabel =>
      _isCurrency ? 'Cours de la paire de devise' : 'Prix unitaire';

  String get _txnCurrency =>
      _isCurrency ? 'EUR' : _priceCurrencyController.currency;

  double? get _txnFxRateToEur =>
      _txnCurrency == 'EUR' ? 1.0 : _priceCurrencyController.resolvedRate;

  Future<void> _commit() async {
    final date = _date;
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
    final transaction = Transaction(
      date: date,
      isBuy: _isBuy,
      quantity: quantity,
      unitPrice: price,
      currency: currency,
      fxRateToEur: fxRateToEur,
    );

    Investment updatedInvestment;
    if (_isNewPosition) {
      // Une valeur choisie dans une liste déroulante (voir
      // `identifierOptionsFor`) garde sa casse d'origine (ex : "Livret A")
      // plutôt que d'être mise en majuscules comme un ISIN saisi librement.
      final rawIsin = _isinController.text.trim();
      final isin =
          identifierOptionsFor(
                widget.account.assetClass,
                accountEnvelope: widget.account.envelope,
              ) ==
              null
          ? rawIsin.toUpperCase()
          : rawIsin;
      final label = _labelController.text.trim();
      if (isin.isEmpty || label.isEmpty) return;
      updatedInvestment = Investment(
        isin: isin,
        label: label,
        transactions: [transaction],
      );
    } else {
      final existing = _selectedInvestment;
      if (existing == null) return;
      updatedInvestment = existing.copyWith(
        transactions: [...existing.transactions, transaction],
      );
    }

    final updatedAccount = widget.account.copyWith(
      investments: [
        for (final i in widget.account.investments)
          if (i.id == updatedInvestment.id) updatedInvestment else i,
        if (_isNewPosition) updatedInvestment,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onChanged();
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
                          'Ajouter une transaction',
                        ).large().semiBold(),
                      ),
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  shadcn.Text('Position').muted().xSmall(),
                  const SizedBox(height: 4),
                  Select<String>(
                    value: _selection,
                    constraints: const BoxConstraints(minWidth: 260),
                    onChanged: (v) {
                      if (v != null) setState(() => _selection = v);
                    },
                    itemBuilder: (context, value) => shadcn.Text(
                      value == _newPositionValue
                          ? '+ Nouvelle position'
                          : widget.account.investments
                                .firstWhere((i) => i.id == value)
                                .label,
                    ),
                    popup: (context) => SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final investment in widget.account.investments)
                            SelectItemButton(
                              value: investment.id,
                              child: shadcn.Text(investment.label),
                            ),
                          const SelectItemButton(
                            value: _newPositionValue,
                            child: shadcn.Text('+ Nouvelle position'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isNewPosition) ...[
                    const SizedBox(height: 12),
                    InvestmentIdentityFields(
                      assetClass: widget.account.assetClass,
                      accountEnvelope: widget.account.envelope,
                      isinController: _isinController,
                      labelController: _labelController,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TransactionForm(
                    isBuy: _isBuy,
                    date: _date,
                    quantityController: _quantityController,
                    priceController: _priceController,
                    quantityLabel: _quantityFieldLabel,
                    priceLabel: _priceFieldLabel,
                    showPriceField: !_isEurCurrency,
                    showCurrencySelector: _showCurrencySelector,
                    priceCurrencyController: _priceCurrencyController,
                    onIsBuyChanged: (v) => setState(() => _isBuy = v),
                    onDateChanged: (d) => setState(() => _date = d),
                    onCreate: _commit,
                    onCancel: () => Navigator.of(context).pop(),
                    submitLabel: 'Ajouter la transaction',
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

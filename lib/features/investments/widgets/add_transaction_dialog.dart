import 'dart:typed_data';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart' show parseDecimal;
import '../../../core/ui/frosted_card.dart';
import '../document_storage.dart';
import '../documents_section.dart';
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

  /// Copie locale du compte, mise à jour à chaque document ajouté/retiré
  /// (voir [_addDocument]) — la popup n'est pas reconstruite par le parent
  /// tant qu'elle est ouverte, contrairement à [widget.account] qui reste
  /// figé sur l'état au moment de l'ouverture.
  late InvestmentAccount _account;

  /// Id de la position sélectionnée, ou [_newPositionValue] pour créer une
  /// nouvelle position — pas de position existante à sélectionner par
  /// défaut sur un compte encore vide.
  late String _selection;
  final _isinController = TextEditingController();
  final _labelController = TextEditingController();

  bool _isBuy = true;
  DateTime? _date;

  /// Date de déblocage saisie à la main pour ce versement, en substitution
  /// de la date par défaut (voir [_unlockDate]) — `null` tant que
  /// l'utilisateur n'a pas modifié le champ, auquel cas la date par défaut
  /// s'applique. Une fois renseignée, reste figée indépendamment des
  /// modifications ultérieures de [_date] (voir [Transaction.manualUnlockDate]).
  DateTime? _unlockDateOverride;

  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  late final TransactionPriceCurrencyController _priceCurrencyController;

  /// Id pré-généré de la transaction en cours de création — permet
  /// d'attacher des documents (voir [_addDocument]) à une position déjà
  /// existante avant même que la transaction ne soit créée ; il en devient
  /// l'id réel à la validation ([_commit]). Régénéré à chaque changement de
  /// position sélectionnée, les documents déjà attachés à l'ancien id étant
  /// alors nettoyés (voir [_cleanupPendingDocuments]) — pas de notion de
  /// "transaction en cours" pour une nouvelle position, qui n'existe pas
  /// encore.
  String? _pendingTransactionId;

  /// Documents déjà importés pour une toute nouvelle position, avant même
  /// que l'[Investment] existe pour les porter (voir [_addDocument]) — les
  /// octets sont déjà écrits sur disque ([DocumentStorage]), seuls les
  /// métadonnées ([VaultDocument]) attendent ici la création de
  /// l'investissement à la validation ([_commit]), qui les y rattache
  /// d'un coup. Toujours vide hors nouvelle position.
  List<VaultDocument> _pendingNewPositionDocuments = [];

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    _account = widget.account;
    _priceCurrencyController = TransactionPriceCurrencyController(
      vaultPath: widget.vaultPath,
    );
    _date = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _selection = _account.investments.isEmpty
        ? _newPositionValue
        : _account.investments.first.id;
    if (_usesTransactionScopedDocuments) {
      _pendingTransactionId = generateInvestmentId('txn');
    }
  }

  @override
  void dispose() {
    _isinController.dispose();
    _labelController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    _priceCurrencyController.dispose();
    super.dispose();
  }

  bool get _isNewPosition => _selection == _newPositionValue;

  Investment? get _selectedInvestment {
    if (_isNewPosition) return null;
    for (final investment in _account.investments) {
      if (investment.id == _selection) return investment;
    }
    return null;
  }

  /// Même règle que `position_detail_dialog.dart`'s
  /// `_usesTransactionScopedDocuments` — s'applique aussi à une toute
  /// nouvelle position (voir [_pendingNewPositionDocuments], qui prend le
  /// relais de [Investment.documents] tant qu'elle n'existe pas encore).
  bool get _usesTransactionScopedDocuments =>
      _effectiveClass == AssetClass.metauxPrecieux ||
      _effectiveClass == AssetClass.autres ||
      _effectiveClass == AssetClass.actionsEtFonds;

  /// Classe effective de la position concernée — la sienne si elle existe
  /// déjà, sinon celle du compte pour une toute nouvelle position (créée
  /// dans la classe du compte, sans sélecteur séparé ici).
  AssetClass get _effectiveClass =>
      _selectedInvestment?.assetClass ?? _account.assetClass;

  /// Le champ de date de déblocage a-t-il un sens pour ce versement — PEG/PEE
  /// et achat uniquement (seuls les versements se débloquent).
  bool get _unlockDateApplicable {
    if (!_isBuy) return false;
    final envelope = _account.envelope;
    return envelope == AccountEnvelope.peg || envelope == AccountEnvelope.pee;
  }

  /// Date de déblocage affichée/éditable : [_unlockDateOverride] si
  /// l'utilisateur l'a modifiée, sinon la date par défaut calculée depuis
  /// [_date] (voir [pegPeeUnlockDateFor]). `null` hors PEG/PEE, pour une
  /// vente, ou tant qu'aucune date de transaction n'est choisie.
  DateTime? get _unlockDate {
    if (!_unlockDateApplicable) return null;
    if (_unlockDateOverride != null) return _unlockDateOverride;
    final date = _date;
    return date == null ? null : pegPeeUnlockDateFor(date);
  }

  Future<void> _selectPosition(String value) async {
    await _cleanupPendingDocuments();
    if (!mounted) return;
    setState(() => _selection = value);
    if (_usesTransactionScopedDocuments) {
      setState(() => _pendingTransactionId = generateInvestmentId('txn'));
    } else {
      _pendingTransactionId = null;
    }
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
    // Toute nouvelle position : pas encore d'[Investment] où le rattacher —
    // les octets sont déjà sur disque, seules les métadonnées patientent
    // (voir [_pendingNewPositionDocuments]) jusqu'à la création à [_commit].
    final investment = _selectedInvestment;
    if (investment == null) {
      setState(
        () => _pendingNewPositionDocuments = [
          ..._pendingNewPositionDocuments,
          document,
        ],
      );
      return;
    }
    final updatedInvestment = investment.copyWith(
      documents: [...investment.documents, document],
    );
    final updatedAccount = _account.copyWith(
      investments: [
        for (final i in _account.investments)
          if (i.id == updatedInvestment.id) updatedInvestment else i,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    if (!mounted) return;
    setState(() => _account = updatedAccount);
  }

  Future<void> _deleteDocument(VaultDocument document) async {
    await DocumentStorage(widget.vaultPath).delete(document);
    final investment = _selectedInvestment;
    if (investment == null) {
      setState(
        () => _pendingNewPositionDocuments = [
          for (final d in _pendingNewPositionDocuments)
            if (d.id != document.id) d,
        ],
      );
      return;
    }
    final updatedInvestment = investment.copyWith(
      documents: [
        for (final d in investment.documents)
          if (d.id != document.id) d,
      ],
    );
    final updatedAccount = _account.copyWith(
      investments: [
        for (final i in _account.investments)
          if (i.id == updatedInvestment.id) updatedInvestment else i,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    if (!mounted) return;
    setState(() => _account = updatedAccount);
  }

  /// Retire du disque les documents attachés à [_pendingTransactionId] —
  /// appelé avant de changer de position sélectionnée ou d'abandonner la
  /// création, pour ne pas les laisser orphelins d'une transaction qui
  /// n'existera jamais.
  Future<void> _cleanupPendingDocuments() async {
    final pendingId = _pendingTransactionId;
    if (pendingId == null) return;
    final investment = _selectedInvestment;
    if (investment == null) {
      if (_pendingNewPositionDocuments.isEmpty) return;
      for (final document in _pendingNewPositionDocuments) {
        await DocumentStorage(widget.vaultPath).delete(document);
      }
      if (!mounted) return;
      setState(() => _pendingNewPositionDocuments = []);
      return;
    }
    final orphaned = [
      for (final d in investment.documents)
        if (d.transactionId == pendingId) d,
    ];
    if (orphaned.isEmpty) return;
    for (final document in orphaned) {
      await DocumentStorage(widget.vaultPath).delete(document);
    }
    final updatedInvestment = investment.copyWith(
      documents: [
        for (final d in investment.documents)
          if (d.transactionId != pendingId) d,
      ],
    );
    final updatedAccount = _account.copyWith(
      investments: [
        for (final i in _account.investments)
          if (i.id == updatedInvestment.id) updatedInvestment else i,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    if (!mounted) return;
    setState(() => _account = updatedAccount);
  }

  Future<void> _cancel() async {
    await _cleanupPendingDocuments();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  bool get _isCurrency {
    final investment = _selectedInvestment;
    return investment != null && isCurrencyInvestment(_account, investment);
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
    // sans quoi la plus-value serait infinie plutôt que simplement non
    // définie (voir `Investment`'s `pru`/`unrealizedGain`, déjà tolérants à
    // un montant investi nul, et `PerformanceAmount`, qui masque le
    // pourcentage plutôt que d'afficher "0 %" trompeur).
    final invalidPrice =
        price == null ||
        price < 0 ||
        (price == 0 && _effectiveClass != AssetClass.autres);
    if (date == null ||
        quantity == null ||
        quantity <= 0 ||
        invalidPrice ||
        fxRateToEur == null ||
        fxRateToEur <= 0) {
      return;
    }
    final transaction = Transaction(
      id: _usesTransactionScopedDocuments ? _pendingTransactionId : null,
      date: date,
      isBuy: _isBuy,
      quantity: quantity,
      unitPrice: price,
      currency: currency,
      fxRateToEur: fxRateToEur,
      manualUnlockDate: _unlockDateOverride,
      note: _noteOrNull,
    );

    Investment updatedInvestment;
    if (_isNewPosition) {
      // Une valeur choisie dans une liste déroulante (voir
      // `identifierOptionsFor`) garde sa casse d'origine (ex : "Livret A")
      // plutôt que d'être mise en majuscules comme un ISIN saisi librement.
      final rawIsin = _isinController.text.trim();
      final isin =
          identifierOptionsFor(
                _account.assetClass,
                accountEnvelope: _account.envelope,
              ) ==
              null
          ? rawIsin.toUpperCase()
          : rawIsin;
      final label = _labelController.text.trim();
      // Comme `complete_patrimoine_dialog.dart`'s `_commitCreateInvestment` :
      // un objet "Autres" ou un fonds PEE/PEG/PER n'a pas toujours de vrai
      // identifiant financier à exiger (voir [isinOptionalFor]) — un
      // identifiant est généré si laissé vide.
      final identifierRequired = !isinOptionalFor(
        _account.assetClass,
        accountEnvelope: _account.envelope,
      );
      if ((identifierRequired && isin.isEmpty) || label.isEmpty) return;
      updatedInvestment = Investment(
        isin: isin.isNotEmpty ? isin : placeholderIsinFor(_account.assetClass),
        label: label,
        transactions: [transaction],
        // Documents déjà importés avant que cet investissement n'existe —
        // voir [_pendingNewPositionDocuments].
        documents: _pendingNewPositionDocuments,
      );
    } else {
      final existing = _selectedInvestment;
      if (existing == null) return;
      updatedInvestment = existing.copyWith(
        transactions: [...existing.transactions, transaction],
      );
    }

    final updatedAccount = _account.copyWith(
      investments: [
        for (final i in _account.investments)
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
                        onPressed: _cancel,
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
                      if (v != null) _selectPosition(v);
                    },
                    itemBuilder: (context, value) => shadcn.Text(
                      value == _newPositionValue
                          ? '+ Nouvelle position'
                          : _account.investments
                                .firstWhere((i) => i.id == value)
                                .label,
                    ),
                    popup: (context) => SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final investment in _account.investments)
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
                      assetClass: _account.assetClass,
                      accountEnvelope: _account.envelope,
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
                    noteController: _noteController,
                    quantityLabel: _quantityFieldLabel,
                    priceLabel: _priceFieldLabel,
                    showPriceField: !_isEurCurrency,
                    showCurrencySelector: _showCurrencySelector,
                    priceCurrencyController: _priceCurrencyController,
                    onIsBuyChanged: (v) => setState(() => _isBuy = v),
                    onDateChanged: (d) => setState(() => _date = d),
                    onCreate: _commit,
                    onCancel: _cancel,
                    submitLabel: 'Ajouter la transaction',
                    unlockDate: _unlockDate,
                    onUnlockDateChanged: _unlockDateApplicable
                        ? (d) => setState(() => _unlockDateOverride = d)
                        : null,
                    documentsSection: _usesTransactionScopedDocuments
                        ? DocumentsSection(
                            vaultPath: widget.vaultPath,
                            // Nouvelle position : rien dans
                            // `Investment.documents` puisqu'elle n'existe
                            // pas encore — voir
                            // [_pendingNewPositionDocuments].
                            documents: _selectedInvestment == null
                                ? _pendingNewPositionDocuments
                                : [
                                    for (final d
                                        in _selectedInvestment!.documents)
                                      if (d.transactionId ==
                                          _pendingTransactionId)
                                        d,
                                  ],
                            fixedTransactionId: _pendingTransactionId,
                            quantityAssetClass:
                                _selectedInvestment?.assetClass ??
                                _account.assetClass,
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

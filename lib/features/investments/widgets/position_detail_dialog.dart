import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/date_format.dart';
import '../../../core/money_format.dart';
import '../../../core/ui/copyable_identifier.dart';
import '../../../core/ui/frosted_card.dart';
import '../../../core/ui/toggle_button_style.dart';
import '../autres_photo_avatar.dart';
import '../autres_photo_repository.dart';
import '../confirm_delete_dialog.dart';
import '../currency_data.dart' show kKnownStablecoins;
import '../currency_format.dart';
import '../document_storage.dart';
import '../documents_section.dart';
import '../investment_reestimate_dialog.dart';
import '../investments_models.dart';
import '../investments_repository.dart';
import '../performance_calculator.dart';
import '../price_history_repository.dart';
import '../transaction_price_currency.dart';
import '../yahoo_finance_client.dart' show PricePoint;
import 'investment_edit_form.dart';
import 'merge_investment_dialog.dart';
import 'transaction_widgets.dart';
import 'transfer_arbitrage_dialog.dart';

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

  /// Id pré-généré de la transaction en cours de création, quand
  /// [_usesTransactionScopedDocuments] — permet d'attacher des documents
  /// (voir [_addDocument]) à une transaction qui n'existe pas encore : ils
  /// sont rattachés à cet id, qui devient l'id réel de la transaction une
  /// fois créée ([_commitCreateTransaction]). Si la création est annulée,
  /// [_cleanupPendingDocuments] retire les documents devenus orphelins.
  String? _pendingTransactionId;
  String? _editingTransactionId;
  bool _newIsBuy = true;
  DateTime? _newDate;

  /// Date de déblocage saisie à la main pour la transaction en cours de
  /// création/édition (voir [_unlockDate]) — `null` tant qu'elle n'a pas été
  /// modifiée, auquel cas la date par défaut s'applique. Réinitialisée en
  /// tête de chaque nouvelle création/édition (voir [_startEdit], le bouton
  /// "Ajouter une transaction") et depuis [Transaction.manualUnlockDate]
  /// pour reprendre une transaction déjà éditée avec un déblocage anticipé.
  DateTime? _newUnlockDateOverride;

  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  late final TransactionPriceCurrencyController _priceCurrencyController;

  bool _editingInvestment = false;
  final _editIsinController = TextEditingController();
  final _editLabelController = TextEditingController();
  FundStyle? _editFundStyle;

  /// Photo importée par l'utilisateur pour un objet "Autres" (voir
  /// `autres_photo_repository.dart`) — `null` tant qu'aucune n'a été
  /// importée, auquel cas l'avatar affiche des initiales. Non chargée pour
  /// les autres classes d'actif.
  String? _autresPhotoPath;

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
    if (_effectiveClass == AssetClass.autres) _loadAutresPhoto();
  }

  Future<void> _loadAutresPhoto() async {
    final path = await AutresPhotoRepository(
      widget.vaultPath,
    ).photoPathFor(_investment.id);
    if (!mounted) return;
    setState(() => _autresPhotoPath = path);
  }

  Future<void> _importAutresPhoto() async {
    final result = await FilePicker.pickFiles(withData: true);
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final path = await AutresPhotoRepository(
      widget.vaultPath,
    ).importPhoto(_investment.id, bytes, sourceName: file.name);
    if (path == null || !mounted) return;
    setState(() => _autresPhotoPath = path);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _noteController.dispose();
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

  /// "Autres" (aucune source de cours automatique), ou "Actions & Fonds"
  /// détenu en PEE/PEG/PER (fonds interne à l'entreprise ou au contrat sans
  /// ISIN public — voir [isinOptionalFor]) : ces cas peuvent estimer leur
  /// cours à la main ([Investment.manualPrice]) faute de cours de marché.
  bool get _allowsManualCours =>
      _effectiveClass == AssetClass.autres ||
      (_effectiveClass == AssetClass.actionsEtFonds &&
          (widget.account.envelope == AccountEnvelope.peg ||
              widget.account.envelope == AccountEnvelope.pee ||
              widget.account.envelope == AccountEnvelope.per));

  /// `true` pour une SCPI logée dans un compte Actions & Fonds/assurance
  /// vie (voir `accountAcceptsCrossClassInvestment`) exactement comme pour
  /// un bien immobilier natif (`investment_detail_screen.dart`'s
  /// équivalent) : pas de prix unitaire/devise à saisir (un seul montant
  /// total), et sa valeur se réestime au m² plutôt que par un cours de
  /// marché.
  bool get _isImmobilier => _effectiveClass == AssetClass.immobilier;

  bool get _isRealIsin =>
      !_isCurrency &&
      (_effectiveClass == AssetClass.actionsEtFonds ||
          _effectiveClass == AssetClass.privateEquity);

  /// Le champ de date de déblocage a-t-il un sens pour cette transaction
  /// (création comme édition, toutes deux pilotées par `_newDate`/
  /// `_newIsBuy`) — PEG/PEE et achat uniquement.
  bool get _unlockDateApplicable {
    if (!_newIsBuy) return false;
    final envelope = widget.account.envelope;
    return envelope == AccountEnvelope.peg || envelope == AccountEnvelope.pee;
  }

  /// Date de déblocage affichée/éditable : [_newUnlockDateOverride] si
  /// renseignée, sinon la date par défaut calculée depuis [_newDate] (voir
  /// [pegPeeUnlockDateFor]). `null` hors PEG/PEE, pour une vente, ou sans
  /// date choisie.
  DateTime? get _unlockDate {
    if (!_unlockDateApplicable) return null;
    if (_newUnlockDateOverride != null) return _newUnlockDateOverride;
    final date = _newDate;
    return date == null ? null : pegPeeUnlockDateFor(date);
  }

  /// Métaux précieux, "Autres" et Actions & Fonds : chaque document peut
  /// être rattaché à la transaction précise qu'il justifie (ex : avis
  /// d'opéré, confirmation de virement) plutôt qu'au compte dans son
  /// ensemble.
  bool get _usesTransactionScopedDocuments =>
      _effectiveClass == AssetClass.metauxPrecieux ||
      _effectiveClass == AssetClass.autres ||
      _effectiveClass == AssetClass.actionsEtFonds;

  bool get _isCurrency => isCurrencyInvestment(widget.account, _investment);

  bool get _isEurCurrency =>
      _isCurrency && _investment.isin.trim().toUpperCase() == 'EUR';

  bool get _showCurrencySelector =>
      !_isEurCurrency && !_isImmobilier && !_isCurrency;

  String get _quantityFieldLabel {
    if (_isImmobilier) return 'Montant total (€)';
    if (_isCurrency) {
      return _isEurCurrency ? 'Montant (€)' : 'Montant (${_investment.isin})';
    }
    return 'Quantité';
  }

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
    final quantity = _isImmobilier
        ? 1.0
        : parseDecimal(_quantityController.text);
    final price = _isImmobilier
        ? parseDecimal(_quantityController.text)
        : _isEurCurrency
        ? 1.0
        : parseDecimal(_priceController.text);
    final currency = _txnCurrency;
    final fxRateToEur = _txnFxRateToEur;
    // Un objet "Autres" peut avoir été reçu en cadeau (prix d'achat 0) —
    // voir [_allowsManualCours]'s doc et `add_transaction_dialog.dart`'s
    // équivalent pour le raisonnement complet (sans quoi la plus-value
    // serait infinie plutôt que masquée par `PerformanceAmount`).
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
    await _saveInvestment(
      _investment.copyWith(
        transactions: [
          ..._investment.transactions,
          Transaction(
            id: _usesTransactionScopedDocuments ? _pendingTransactionId : null,
            date: date,
            isBuy: _newIsBuy,
            quantity: quantity,
            unitPrice: price,
            currency: currency,
            fxRateToEur: fxRateToEur,
            manualUnlockDate: _newUnlockDateOverride,
            note: _noteOrNull,
          ),
        ],
      ),
    );
    _quantityController.clear();
    _priceController.clear();
    _noteController.clear();
    setState(() {
      _creating = false;
      _pendingTransactionId = null;
      _newUnlockDateOverride = null;
    });
  }

  /// [_noteController]'s text, ou `null` s'il est vide (voir
  /// [Transaction.note] — jamais une chaîne vide persistée).
  String? get _noteOrNull {
    final text = _noteController.text.trim();
    return text.isEmpty ? null : text;
  }

  /// Retire du disque les documents attachés à une création de transaction
  /// abandonnée ([_pendingTransactionId]) — sans ça, ils resteraient
  /// rattachés pour toujours à un id de transaction qui n'existera jamais.
  Future<void> _cleanupPendingDocuments() async {
    final pendingId = _pendingTransactionId;
    if (pendingId == null) return;
    final orphaned = [
      for (final d in _investment.documents)
        if (d.transactionId == pendingId) d,
    ];
    if (orphaned.isEmpty) return;
    for (final document in orphaned) {
      await DocumentStorage(widget.vaultPath).delete(document);
    }
    await _saveInvestment(
      _investment.copyWith(
        documents: [
          for (final d in _investment.documents)
            if (d.transactionId != pendingId) d,
        ],
      ),
    );
  }

  Future<void> _cancelCreate() async {
    await _cleanupPendingDocuments();
    if (!mounted) return;
    setState(() {
      _creating = false;
      _pendingTransactionId = null;
    });
  }

  void _startEdit(Transaction transaction) {
    setState(() {
      _creating = false;
      _editingTransactionId = transaction.id;
      _newIsBuy = transaction.isBuy;
      _newDate = transaction.date;
      _newUnlockDateOverride = transaction.manualUnlockDate;
      _quantityController.text = _formatNumber(
        _isImmobilier ? transaction.amount : transaction.quantity,
      );
      _priceController.text = _isImmobilier
          ? ''
          : _formatNumber(transaction.unitPrice);
      _noteController.text = transaction.note ?? '';
    });
    _priceCurrencyController.loadFrom(
      currency: transaction.currency,
      fxRateToEur: transaction.fxRateToEur,
    );
  }

  void _cancelEdit() {
    _quantityController.clear();
    _priceController.clear();
    _noteController.clear();
    _priceCurrencyController.reset();
    setState(() {
      _editingTransactionId = null;
      _newUnlockDateOverride = null;
    });
  }

  Future<void> _commitEditTransaction() async {
    final id = _editingTransactionId;
    final date = _newDate;
    final quantity = _isImmobilier
        ? 1.0
        : parseDecimal(_quantityController.text);
    final price = _isImmobilier
        ? parseDecimal(_quantityController.text)
        : _isEurCurrency
        ? 1.0
        : parseDecimal(_priceController.text);
    final currency = _txnCurrency;
    final fxRateToEur = _txnFxRateToEur;
    // Voir `_commitCreateTransaction` : un objet "Autres" peut avoir été
    // reçu en cadeau (prix d'achat 0).
    final invalidPrice =
        price == null ||
        price < 0 ||
        (price == 0 && _effectiveClass != AssetClass.autres);
    if (id == null ||
        date == null ||
        quantity == null ||
        quantity <= 0 ||
        invalidPrice ||
        fxRateToEur == null ||
        fxRateToEur <= 0) {
      return;
    }
    // Ni l'un ni l'autre n'est éditable depuis ce formulaire : les omettre
    // les réinitialiserait à `null` silencieusement, détachant une
    // transaction de dépôt/dividende/transfert/arbitrage de sa nature ou de
    // sa contrepartie sans aucun avertissement.
    final original = _investment.transactions.firstWhere((t) => t.id == id);
    final updatedTransaction = Transaction(
      id: id,
      date: date,
      isBuy: _newIsBuy,
      quantity: quantity,
      unitPrice: price,
      currency: currency,
      fxRateToEur: fxRateToEur,
      manualUnlockDate: _newUnlockDateOverride,
      note: _noteOrNull,
      type: original.type,
      linkedTransactionId: original.linkedTransactionId,
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
    _noteController.clear();
    setState(() {
      _editingTransactionId = null;
      _newUnlockDateOverride = null;
    });
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
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
                'détenue et le PRU de cette position.'
          : 'Cette transaction fait partie d\'un transfert/arbitrage : sa '
                'contrepartie sera aussi supprimée. Cette action est '
                'irréversible et modifiera la quantité détenue et le PRU '
                'des deux positions concernées.',
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
    if (linkedId != null) await _repo.deleteTransaction(linkedId);
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

  Future<void> _toggleExcludedFromPatrimoine() => _saveInvestment(
    _investment.copyWith(
      excludedFromPatrimoine: !_investment.excludedFromPatrimoine,
    ),
  );

  /// "Réestimer la valeur (€/m²)" — même dialogue qu'un bien immobilier
  /// natif (`investment_detail_screen.dart`'s équivalent), réutilisable ici
  /// tel quel puisqu'il n'opère que sur l'[Investment], indépendamment du
  /// compte qui le contient (une SCPI logée en assurance vie s'estime
  /// exactement comme une SCPI en direct).
  Future<void> _openReestimateDialog() async {
    await showRealEstateReestimateDialog(
      context,
      vaultPath: widget.vaultPath,
      investment: _investment,
      onEstimated: (updated) async {
        await _saveInvestment(updated);
      },
    );
  }

  /// Ouvre une petite popup pour saisir/mettre à jour le cours (prix
  /// unitaire) estimé à la main (voir `Investment.manualPrice`) — seul
  /// moyen de valoriser un objet "Autres" (montre, voiture, art...) ou un
  /// fonds PEE/PEG/PER sans ISIN public (voir [_allowsManualCours]), qui
  /// n'ont ni l'un ni l'autre de cours de marché à chercher. La valeur affichée
  /// ailleurs (`Investment.estimatedValue`) est ce cours multiplié par la
  /// quantité détenue, exactement comme pour un titre coté.
  Future<void> _showManualEstimateDialog() async {
    final controller = TextEditingController(
      text: _investment.manualPrice == null
          ? ''
          : _formatNumber(_investment.manualPrice!),
    );
    final quantity = _investment.quantityHeld;
    final value = await showDialog<double>(
      context: context,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: FrostedCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const shadcn.Text('Cours actuel estimé').large().semiBold(),
                  const SizedBox(height: 8),
                  shadcn.Text(
                    quantity > 1
                        ? 'Prix estimé par unité — à mettre à jour toi-même '
                              'quand tu le juges utile, aucune source de '
                              'cours automatique n\'existe pour ce '
                              'placement. La valeur affichée sera ce cours × '
                              '${formatQuantity(quantity, _effectiveClass)} '
                              'unités détenues.'
                        : 'À mettre à jour toi-même quand tu le juges utile '
                              '— aucune source de cours automatique '
                              'n\'existe pour ce placement.',
                  ).muted().small(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    placeholder: const shadcn.Text('Cours (€)'),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      PrimaryButton(
                        onPressed: () {
                          final parsed = parseDecimal(controller.text);
                          Navigator.of(context).pop(parsed);
                        },
                        child: const shadcn.Text('Enregistrer'),
                      ),
                      const SizedBox(width: 8),
                      OutlineButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const shadcn.Text('Annuler'),
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
    if (value == null || value <= 0) return;
    await _saveInvestment(
      _investment.copyWith(manualPrice: value, manualPriceAt: DateTime.now()),
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
      // Un identifiant auto-généré (voir [isGeneratedIdentifier]) n'a rien
      // d'utile à montrer/re-saisir — le champ reste optionnel pour ces
      // classes (voir [isinOptionalFor]), donc vide plutôt que de préremplir
      // avec un id technique interne : ré-enregistrer sans y toucher
      // régénère simplement un nouveau placeholder ([_commitEditInvestment]).
      _editIsinController.text = isGeneratedIdentifier(_investment.isin)
          ? ''
          : _investment.isin;
      _editLabelController.text = _investment.label;
      _editFundStyle = _investment.fundStyle;
    });
  }

  Future<void> _commitEditInvestment() async {
    final rawIsin = _editIsinController.text.trim();
    final typedIsin =
        identifierOptionsFor(
              _effectiveClass,
              accountEnvelope: widget.account.envelope,
            ) ==
            null
        ? rawIsin.toUpperCase()
        : rawIsin;
    final label = _editLabelController.text.trim();
    // Un identifiant vide reste valide pour "Autres"/un fonds PEE-PEG (voir
    // [isinOptionalFor]) : on en régénère un plutôt que de bloquer
    // l'enregistrement, pour permettre de retirer un ISIN saisi par erreur
    // (auparavant impossible : le champ vide était simplement rejeté).
    final isin =
        typedIsin.isEmpty &&
            isinOptionalFor(
              _effectiveClass,
              accountEnvelope: widget.account.envelope,
            )
        ? placeholderIsinFor(_effectiveClass)
        : typedIsin;
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
        // Modifier l'identifiant/libellé ne doit pas effacer au passage
        // l'exclusion du patrimoine ni une estimation manuelle déjà
        // renseignée — cette reconstruction explicite (plutôt qu'un
        // copyWith) doit reporter tout champ qui ne dépend pas de l'édition
        // en cours.
        excludedFromPatrimoine: _investment.excludedFromPatrimoine,
        manualPrice: _investment.manualPrice,
        manualPriceAt: _investment.manualPriceAt,
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
            if (_allowsManualCours)
              MenuButton(
                leading: const Icon(LucideIcons.tag, size: 14),
                child: const shadcn.Text('Réestimer le cours'),
                onPressed: (_) => _showManualEstimateDialog(),
              ),
            if (_isImmobilier)
              MenuButton(
                leading: const Icon(LucideIcons.mapPin, size: 14),
                child: const shadcn.Text('Réestimer la valeur (€/m²)'),
                onPressed: (_) => _openReestimateDialog(),
              ),
            MenuButton(
              leading: Icon(
                _investment.excludedFromPatrimoine
                    ? LucideIcons.eye
                    : LucideIcons.eyeOff,
                size: 14,
              ),
              child: shadcn.Text(
                _investment.excludedFromPatrimoine
                    ? 'Réintégrer au patrimoine'
                    : 'Exclure du patrimoine',
              ),
              onPressed: (_) => _toggleExcludedFromPatrimoine(),
            ),
            MenuButton(
              enabled: _investment.quantityHeld > 0,
              leading: const Icon(LucideIcons.arrowRightLeft, size: 14),
              child: const shadcn.Text('Transférer vers un autre compte'),
              onPressed: (_) => _openTransferDialog(),
            ),
            MenuButton(
              enabled: _investment.quantityHeld > 0,
              leading: const Icon(LucideIcons.shuffle, size: 14),
              child: const shadcn.Text('Arbitrer vers un autre titre'),
              onPressed: (_) => _openArbitrageDialog(),
            ),
            MenuButton(
              enabled: widget.account.investments.length > 1,
              leading: const Icon(LucideIcons.combine, size: 14),
              child: const shadcn.Text('Fusionner avec une autre position'),
              onPressed: (_) => _openMergeDialog(),
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

  Future<void> _openTransferDialog() async {
    await showTransferDialog(
      context,
      vaultPath: widget.vaultPath,
      sourceAccount: widget.account,
      sourceInvestment: _investment,
      onChanged: widget.onChanged,
    );
    await _refreshInvestmentAfterExternalChange();
  }

  Future<void> _openArbitrageDialog() async {
    await showArbitrageDialog(
      context,
      vaultPath: widget.vaultPath,
      sourceAccount: widget.account,
      sourceInvestment: _investment,
      onChanged: widget.onChanged,
    );
    await _refreshInvestmentAfterExternalChange();
  }

  Future<void> _openMergeDialog() async {
    // Contrairement au transfert/arbitrage, une fusion réussie fait
    // disparaître _investment elle-même (voir `merge_investment_dialog.dart`)
    // : `onChanged` ne se déclenche que sur succès, donc son passage ici
    // signale qu'il n'y a plus rien à afficher — cette popup se ferme
    // plutôt que de tenter un rafraîchissement voué à échouer.
    var merged = false;
    await showMergeInvestmentDialog(
      context,
      vaultPath: widget.vaultPath,
      account: widget.account,
      sourceInvestment: _investment,
      onChanged: () async {
        merged = true;
        await widget.onChanged();
      },
    );
    if (merged) {
      if (!mounted) return;
      Navigator.of(context).pop();
    } else {
      await _refreshInvestmentAfterExternalChange();
    }
  }

  /// Recharge la position depuis le disque après un transfert/arbitrage —
  /// contrairement à [_saveInvestment], celui-ci est persisté par
  /// `transfer_arbitrage_dialog.dart` avec son propre
  /// `InvestmentsRepository` (potentiellement sur un autre compte), qui ne
  /// peut donc pas mettre à jour [_investment] lui-même.
  Future<void> _refreshInvestmentAfterExternalChange() async {
    if (!mounted) return;
    final updatedAccount = await _repo.find(widget.account.id);
    if (updatedAccount == null || !mounted) return;
    for (final investment in updatedAccount.investments) {
      if (investment.id == _investment.id) {
        setState(() => _investment = investment);
        return;
      }
    }
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final investment = _investment;
    // Voir `TransactionRow.centerDate` : la date ne reste centrée que tant
    // qu'aucune transaction affichée ne porte de commentaire.
    final centerDate = !investment.transactions.any((t) => t.hasNote);
    final hasPrice = investment.marketValue != null;
    final displayValue = investment.displayValue;

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
                      if (_effectiveClass == AssetClass.autres) ...[
                        AutresPhotoAvatar(
                          label: investment.label,
                          photoPath: _autresPhotoPath,
                          onTap: _importAutresPhoto,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                      ],
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
                  if (investment.excludedFromPatrimoine) ...[
                    const SizedBox(height: 4),
                    const ExcludedFromPatrimoineBadge(),
                  ],
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
                    if (!_isCurrency &&
                        (!isGeneratedIdentifier(investment.isin) ||
                            (investment.symbol != null &&
                                investment.symbol!.isNotEmpty))) ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          // Un identifiant auto-généré (voir
                          // [isGeneratedIdentifier]) n'a rien d'utile à
                          // montrer — pas de vrai ISIN/ticker à copier.
                          if (!isGeneratedIdentifier(investment.isin))
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
                        )
                      else if (investment.manualPrice != null)
                        InvestmentStatChip(
                          label: 'Cours estimé',
                          value: displayEuros(
                            investment.manualPrice!,
                            widget.hidden,
                          ),
                          trailing: investment.manualPriceAt != null
                              ? ManualPriceBadge(
                                  updatedAt: investment.manualPriceAt!,
                                )
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
                  ] else if (_allowsManualCours)
                    shadcn.Text(
                      investment.manualPriceAt != null
                          ? 'Cours estimé le '
                                '${formatDateDdMmYyyy(investment.manualPriceAt!)} '
                                '(menu « ⋮ » pour le mettre à jour).'
                          : 'Aucun cours renseigné : la valorisation '
                                'ci-dessus correspond au montant net investi '
                                '— menu « ⋮ » pour en ajouter un.',
                    ).muted().xSmall()
                  else
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
                        noteController: _noteController,
                        quantityLabel: _quantityFieldLabel,
                        priceLabel: _priceFieldLabel,
                        showPriceField: !_isEurCurrency && !_isImmobilier,
                        showCurrencySelector: _showCurrencySelector,
                        priceCurrencyController: _priceCurrencyController,
                        currencyExtraOptions:
                            _effectiveClass == AssetClass.crypto
                            ? kKnownStablecoins
                            : const [],
                        onIsBuyChanged: (v) => setState(() => _newIsBuy = v),
                        onDateChanged: (d) => setState(() => _newDate = d),
                        unlockDate: _unlockDate,
                        onUnlockDateChanged: _unlockDateApplicable
                            ? (d) => setState(() => _newUnlockDateOverride = d)
                            : null,
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
                        centerDate: centerDate,
                        // Cette popup est bien plus étroite (560px) qu'une
                        // page pleine largeur — le détail "quantité × prix"
                        // fait déjà doublon avec les chips "Quantité
                        // détenue"/"PRU" affichées juste au-dessus, autant
                        // le masquer ici pour laisser à la date et au
                        // commentaire la place de tenir sur une ligne (voir
                        // [TransactionRow.amountsGroupWidth]).
                        displayTotalOnly: true,
                        amountsGroupWidth: 110,
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
                      noteController: _noteController,
                      quantityLabel: _quantityFieldLabel,
                      priceLabel: _priceFieldLabel,
                      showPriceField: !_isEurCurrency && !_isImmobilier,
                      showCurrencySelector: _showCurrencySelector,
                      priceCurrencyController: _priceCurrencyController,
                      currencyExtraOptions: _effectiveClass == AssetClass.crypto
                          ? kKnownStablecoins
                          : const [],
                      onIsBuyChanged: (v) => setState(() => _newIsBuy = v),
                      onDateChanged: (d) => setState(() => _newDate = d),
                      unlockDate: _unlockDate,
                      onUnlockDateChanged: _unlockDateApplicable
                          ? (d) => setState(() => _newUnlockDateOverride = d)
                          : null,
                      onCreate: _commitCreateTransaction,
                      onCancel: _cancelCreate,
                      documentsSection: _usesTransactionScopedDocuments
                          ? DocumentsSection(
                              vaultPath: widget.vaultPath,
                              documents: [
                                for (final d in investment.documents)
                                  if (d.transactionId == _pendingTransactionId)
                                    d,
                              ],
                              fixedTransactionId: _pendingTransactionId,
                              quantityAssetClass: investment.assetClass,
                              onAdd: _addDocument,
                              onDelete: _deleteDocument,
                            )
                          : null,
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
                        _noteController.clear();
                        _priceCurrencyController.reset();
                        _newUnlockDateOverride = null;
                        _pendingTransactionId = _usesTransactionScopedDocuments
                            ? generateInvestmentId('txn')
                            : null;
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

import 'dart:typed_data';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import 'account_detail_screen.dart' show BackHeader;
import 'confirm_delete_dialog.dart';
import 'document_storage.dart';
import 'documents_section.dart';
import 'investment_identifier_field.dart';
import 'investments_models.dart';
import 'investments_repository.dart';
import 'metal_price_client.dart';
import 'metal_price_repository.dart';
import 'performance_calculator.dart';
import 'price_history_repository.dart';
import 'yahoo_finance_client.dart' show PricePoint;

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

enum _PerfMode { twr, mwr }

/// Détail d'un investissement (ISIN) : quantité détenue, montant net
/// investi ou valorisé au dernier cours connu, et l'historique des
/// transactions avec ajout en ligne. Vue embarquée dans
/// `RealCategoryDetailScreen` (pas de `Navigator.push`) : [onBack]
/// revient au compte, [onChanged] prévient le parent qu'il doit recharger
/// les données après une mutation locale (transaction ajoutée...).
///
/// Le cours affiché ici est une simple lecture locale de la dernière
/// valeur connue (voir [Investment.lastPrice]) : sa résolution/
/// actualisation réseau (Yahoo Finance, ou cours au gramme scrapé pour les
/// métaux précieux — voir `price_refresh_service.dart`) se fait en une
/// seule passe pour tous les investissements à l'ouverture du Dashboard
/// (`dashboard_screen.dart`), pas ici au cas par cas à l'ouverture de
/// chaque investissement — cet écran ne déclenche donc plus aucun appel
/// réseau lui-même.
class InvestmentDetailView extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final Investment investment;
  final bool hidden;
  final VoidCallback onBack;
  final Future<void> Function() onChanged;

  const InvestmentDetailView({
    super.key,
    required this.vaultPath,
    required this.account,
    required this.investment,
    required this.hidden,
    required this.onBack,
    required this.onChanged,
  });

  @override
  State<InvestmentDetailView> createState() => _InvestmentDetailViewState();
}

class _InvestmentDetailViewState extends State<InvestmentDetailView> {
  late InvestmentsRepository _repo;
  List<PricePoint> _priceHistory = [];
  _PerfMode _perfMode = _PerfMode.twr;

  bool _creating = false;
  String? _editingTransactionId;
  bool _newIsBuy = true;
  DateTime? _newDate;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  bool _editingInvestment = false;
  final _editIsinController = TextEditingController();
  final _editLabelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    // Date par défaut sans heure, comme les dates saisies au datepicker —
    // voir `_onOrBeforeDay` dans real_patrimoine_adapter.
    _newDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _loadPriceHistory();
  }

  @override
  void didUpdateWidget(covariant InvestmentDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath ||
        oldWidget.investment.isin != widget.investment.isin) {
      _repo = InvestmentsRepository(widget.vaultPath);
      _loadPriceHistory();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _editIsinController.dispose();
    _editLabelController.dispose();
    super.dispose();
  }

  Future<void> _loadPriceHistory() async {
    // Les métaux précieux physiques n'ont pas d'historique Yahoo Finance :
    // leur série est reconstruite depuis les relevés journaliers stockés par
    // `price_refresh_service.dart` (voir
    // [MetalPriceRepository.pricePointsFor]) — nécessaire à la performance
    // TWR, qui valorise chaque transaction à une date de cours. Un ETC
    // or/argent logé dans un CTO (voir [isMetalEtc]) est, lui, un titre
    // coté : son historique se lit comme celui d'une action.
    if (_effectiveClass == AssetClass.metauxPrecieux &&
        !isMetalEtc(widget.account)) {
      final points = await MetalPriceRepository(widget.vaultPath).pricePointsFor(
        metalKindForInvestment(
          isin: widget.investment.isin,
          label: widget.investment.label,
        ),
        widget.investment.isin,
      );
      if (!mounted) return;
      setState(() => _priceHistory = points);
      return;
    }
    final history = await PriceHistoryRepository(
      widget.vaultPath,
    ).load(widget.investment.isin);
    if (!mounted) return;
    setState(() => _priceHistory = history);
  }

  /// La classe d'actif effective de cet investissement (celle de
  /// l'investissement lui-même si renseignée, sinon celle héritée de son
  /// compte porteur) — détermine notamment si son identifiant est un
  /// véritable code ISIN (voir [_isRealIsin]).
  AssetClass get _effectiveClass =>
      widget.investment.assetClass ?? widget.account.assetClass;

  /// Seules les actions, fonds et parts de private equity sont identifiés
  /// par un vrai code ISIN — les autres classes utilisent [Investment.isin]
  /// comme identifiant libre (ticker crypto, "Or physique", adresse d'un
  /// bien immobilier...), donc ne doivent pas être présentées comme tel.
  bool get _isRealIsin =>
      _effectiveClass == AssetClass.actionsEtFonds ||
      _effectiveClass == AssetClass.privateEquity;

  bool get _isImmobilier => _effectiveClass == AssetClass.immobilier;

  /// Métaux précieux et "Autres" : chaque document doit être rattaché à la
  /// transaction précise qu'il justifie (facture, photo...), pas de section
  /// "Documents" au niveau du compte pour ces deux classes (voir
  /// `account_detail_screen.dart`) — les autres classes, à l'inverse,
  /// n'ont cette section qu'au niveau du compte.
  bool get _usesTransactionScopedDocuments =>
      _effectiveClass == AssetClass.metauxPrecieux ||
      _effectiveClass == AssetClass.autres;

  /// Une épargne tenue en euros (l'immense majorité des cas français —
  /// Livret A, LDDS, LEP, PEL...) n'a pas de taux de change à saisir : un
  /// versement de 1000 € est juste... 1000 €. Le champ "Cours de la paire
  /// de devise" ne devient pertinent que pour une épargne tenue dans une
  /// autre devise (voir [kKnownCurrencies] côté sélection).
  bool get _isEurEpargne =>
      _effectiveClass == AssetClass.epargne &&
      widget.investment.isin.toUpperCase() == 'EUR';

  String get _quantityFieldLabel {
    if (_isImmobilier) return 'Montant total (€)';
    if (_effectiveClass != AssetClass.epargne) return 'Quantité';
    return _isEurEpargne
        ? 'Montant (€)'
        : 'Montant (${widget.investment.isin})';
  }

  String get _priceFieldLabel => _effectiveClass == AssetClass.epargne
      ? 'Cours de la paire de devise'
      : 'Prix unitaire (€)';

  Future<void> _commitCreateTransaction() async {
    final date = _newDate;
    if (date == null) return;
    final quantity = _isImmobilier
        ? 1.0
        : double.tryParse(_quantityController.text.trim());
    final price = _isImmobilier
        ? double.tryParse(_quantityController.text.trim())
        : _isEurEpargne
        ? 1.0
        : double.tryParse(_priceController.text.trim());
    if (quantity == null || quantity <= 0 || price == null || price <= 0) {
      return;
    }
    final updatedInvestment = widget.investment.copyWith(
      transactions: [
        ...widget.investment.transactions,
        Transaction(
          date: date,
          isBuy: _newIsBuy,
          quantity: quantity,
          unitPrice: price,
        ),
      ],
    );
    final updatedAccount = widget.account.copyWith(
      investments: [
        for (final i in widget.account.investments)
          if (i.id == updatedInvestment.id) updatedInvestment else i,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    _quantityController.clear();
    _priceController.clear();
    setState(() => _creating = false);
    widget.onChanged();
  }

  void _startEdit(Transaction transaction) {
    setState(() {
      _creating = false;
      _editingTransactionId = transaction.id;
      _newIsBuy = transaction.isBuy;
      _newDate = transaction.date;
      _quantityController.text = _formatNumber(
        _isImmobilier ? transaction.amount : transaction.quantity,
      );
      _priceController.text = _isImmobilier
          ? ''
          : _formatNumber(transaction.unitPrice);
    });
  }

  void _cancelEdit() {
    _quantityController.clear();
    _priceController.clear();
    setState(() => _editingTransactionId = null);
  }

  Future<void> _commitEditTransaction() async {
    final id = _editingTransactionId;
    final date = _newDate;
    final quantity = _isImmobilier
        ? 1.0
        : double.tryParse(_quantityController.text.trim());
    final price = _isImmobilier
        ? double.tryParse(_quantityController.text.trim())
        : _isEurEpargne
        ? 1.0
        : double.tryParse(_priceController.text.trim());
    if (id == null ||
        date == null ||
        quantity == null ||
        quantity <= 0 ||
        price == null ||
        price <= 0) {
      return;
    }
    final updatedTransaction = Transaction(
      id: id,
      date: date,
      isBuy: _newIsBuy,
      quantity: quantity,
      unitPrice: price,
    );
    final updatedInvestment = widget.investment.copyWith(
      transactions: [
        for (final t in widget.investment.transactions)
          if (t.id == id) updatedTransaction else t,
      ],
    );
    final updatedAccount = widget.account.copyWith(
      investments: [
        for (final i in widget.account.investments)
          if (i.id == updatedInvestment.id) updatedInvestment else i,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    _quantityController.clear();
    _priceController.clear();
    setState(() => _editingTransactionId = null);
    widget.onChanged();
  }

  /// Un investissement n'est supprimable qu'une fois vidé de toutes ses
  /// transactions — même garde-fou que pour la suppression d'un compte
  /// entier (voir `_hasTransactions` dans `account_detail_screen.dart`),
  /// pour ne jamais perdre silencieusement un historique d'achats/ventes.
  bool get _canDelete => widget.investment.transactions.isEmpty;

  Future<void> _deleteInvestment() async {
    if (!_canDelete) return;
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer "${widget.investment.label}" ?',
      message: 'Cet investissement sera définitivement supprimé.',
    );
    if (!confirmed) return;
    final updatedAccount = widget.account.copyWith(
      investments: [
        for (final i in widget.account.investments)
          if (i.id != widget.investment.id) i,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    widget.onBack();
    widget.onChanged();
  }

  void _startEditInvestment() {
    setState(() {
      _editingInvestment = true;
      _editIsinController.text = widget.investment.isin;
      _editLabelController.text = widget.investment.label;
    });
  }

  /// Changer l'identifiant (ISIN, ticker...) invalide le cours déjà résolu
  /// pour l'ancien : on le réinitialise pour forcer une nouvelle résolution
  /// au prochain passage du rafraîchissement global (déclenché par
  /// [onChanged], voir `price_refresh_service.dart`) plutôt que de garder
  /// par erreur un cours qui ne correspond plus à l'investissement modifié.
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
    if ((!_isImmobilier && isin.isEmpty) || label.isEmpty) return;
    final isinChanged = isin != widget.investment.isin;
    final updatedInvestment = Investment(
      id: widget.investment.id,
      isin: _isImmobilier ? widget.investment.isin : isin,
      label: label,
      transactions: widget.investment.transactions,
      symbol: isinChanged ? null : widget.investment.symbol,
      lastPrice: isinChanged ? null : widget.investment.lastPrice,
      lastPriceDate: isinChanged ? null : widget.investment.lastPriceDate,
      priceUnavailable:
          isinChanged ? null : widget.investment.priceUnavailable,
      assetClass: widget.investment.assetClass,
      realEstateType: widget.investment.realEstateType,
      documents: widget.investment.documents,
    );
    await _saveInvestment(updatedInvestment);
    setState(() => _editingInvestment = false);
    await widget.onChanged();
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
              child: const shadcn.Text('Supprimer l\'investissement'),
              onPressed: (_) => _deleteInvestment(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer cette transaction ?',
      message:
          'Cette action est irréversible et modifiera la quantité détenue '
          'et le PRU de cet investissement.',
    );
    if (!confirmed) return;
    // Un document rattaché à cette transaction (voir `DocumentsSection`'s
    // `transactions`) n'a plus de sens sans elle : on le supprime aussi,
    // fichier compris, plutôt que de laisser une pièce justificative
    // orpheline dans le vault.
    final orphanedDocuments = [
      for (final d in widget.investment.documents)
        if (d.transactionId == transaction.id) d,
    ];
    for (final document in orphanedDocuments) {
      await DocumentStorage(widget.vaultPath).delete(document);
    }
    await _saveInvestment(
      widget.investment.copyWith(
        transactions: [
          for (final t in widget.investment.transactions)
            if (t.id != transaction.id) t,
        ],
        documents: [
          for (final d in widget.investment.documents)
            if (d.transactionId != transaction.id) d,
        ],
      ),
    );
    widget.onChanged();
  }

  /// Remplace [widget.investment] par [updated] au sein de son compte et
  /// persiste — factorise la mise à jour partagée par transactions et
  /// documents (l'investissement n'est jamais stocké seul, toujours via le
  /// compte qui le contient).
  Future<void> _saveInvestment(Investment updated) {
    final updatedAccount = widget.account.copyWith(
      investments: [
        for (final i in widget.account.investments)
          if (i.id == updated.id) updated else i,
      ],
    );
    return _repo.saveAccount(updatedAccount);
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
      widget.investment.copyWith(
        documents: [...widget.investment.documents, document],
      ),
    );
    widget.onChanged();
  }

  Future<void> _deleteDocument(VaultDocument document) async {
    await DocumentStorage(widget.vaultPath).delete(document);
    await _saveInvestment(
      widget.investment.copyWith(
        documents: [
          for (final d in widget.investment.documents)
            if (d.id != document.id) d,
        ],
      ),
    );
    widget.onChanged();
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  Future<void> _copyIsin(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.investment.isin));
    if (!context.mounted) return;
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: shadcn.Text(_isRealIsin ? 'ISIN copié' : 'Identifiant copié'),
          subtitle: shadcn.Text(widget.investment.isin),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final investment = widget.investment;
    final theme = Theme.of(context);
    final hasPrice = investment.marketValue != null;
    final displayValue = investment.marketValue ?? investment.investedAmount;

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BackHeader(
                  label: investment.label,
                  onBack: widget.onBack,
                ),
              ),
              Builder(
                builder: (context) => IconButton.ghost(
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                  onPressed: () => _openInvestmentMenu(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_editingInvestment)
            _EditInvestmentForm(
              assetClass: _effectiveClass,
              isImmobilier: _isImmobilier,
              accountEnvelope: widget.account.envelope,
              isinController: _editIsinController,
              labelController: _editLabelController,
              onSave: _commitEditInvestment,
              onCancel: () => setState(() => _editingInvestment = false),
            )
          else ...[
            if (!_isImmobilier) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  shadcn.Text(investment.isin).muted().small(),
                  const SizedBox(width: 4),
                  IconButton.ghost(
                    icon: const Icon(LucideIcons.copy, size: 14),
                    onPressed: () => _copyIsin(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            shadcn.Text(
              displayEuros(displayValue, widget.hidden),
            ).x2Large().bold(),
            if (_isImmobilier && investment.realEstateType != null) ...[
              const SizedBox(height: 4),
              shadcn.Text(investment.realEstateType!.label).muted().small(),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!_isImmobilier) ...[
                _StatChip(
                  label: 'Quantité détenue',
                  value: investment.quantityHeld.toStringAsFixed(2),
                ),
                _StatChip(
                  label: 'PRU',
                  // Une épargne en devise étrangère est tenue à un taux de
                  // change (le PRU est le cours de la paire à l'achat), pas
                  // à un montant : l'afficher avec la précision du taux
                  // plutôt que formaté en euros arrondis.
                  value: _effectiveClass == AssetClass.epargne
                      ? '${investment.pru.toStringAsFixed(4)} €'
                      : displayEuros(investment.pru, widget.hidden),
                ),
              ],
              if (hasPrice)
                _StatChip(
                  label: 'Dernier cours',
                  value: _effectiveClass == AssetClass.epargne
                      ? '${investment.lastPrice!.toStringAsFixed(4)} €'
                      : displayEuros(investment.lastPrice!, widget.hidden),
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
                      onChanged: (_) =>
                          setState(() => _perfMode = _PerfMode.twr),
                      child: const shadcn.Text('TWR'),
                    ),
                    SelectedButton(
                      value: _perfMode == _PerfMode.mwr,
                      selectedStyle: const ButtonStyle.primary(),
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
            const SizedBox(height: 4),
            shadcn.Text(
              _perfMode == _PerfMode.twr
                  ? 'TWR (Time-Weighted Return) : performance de l\'actif, '
                        'indépendamment du moment de vos apports.'
                  : 'MWR (Money-Weighted Return) : rendement réellement '
                        'perçu, compte tenu du montant et de la date de '
                        'chaque apport.',
            ).muted().xSmall(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  investment.priceUnavailable == true
                      ? LucideIcons.triangleAlert
                      : LucideIcons.info,
                  size: 14,
                  color: investment.priceUnavailable == true
                      ? const Color(0xFFF59E0B)
                      : theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: shadcn.Text(
                    investment.priceUnavailable == true
                        ? 'Cours introuvable sur Yahoo Finance pour '
                              '« ${investment.isin} » : identifiant inconnu '
                              'ou actif non coté. Vérifiez l\'identifiant — '
                              'la valorisation ci-dessus correspond au '
                              'montant net investi (prix d\'achat), pas au '
                              'cours actuel du marché.'
                        : 'Cours en temps réel pas encore disponible : la '
                              'valorisation ci-dessus correspond au montant '
                              'net investi (prix d\'achat), pas au cours '
                              'actuel du marché.',
                  ).muted().xSmall(),
                ),
              ],
            ),
          const SizedBox(height: 24),
          const shadcn.Text('Transactions').large().medium(),
          const SizedBox(height: 12),
          for (final txn in investment.transactions.reversed) ...[
            if (txn.id == _editingTransactionId)
              _CreateTransactionForm(
                isBuy: _newIsBuy,
                date: _newDate,
                quantityController: _quantityController,
                priceController: _priceController,
                quantityLabel: _quantityFieldLabel,
                priceLabel: _priceFieldLabel,
                showPriceField: !_isEurEpargne && !_isImmobilier,
                onIsBuyChanged: (v) => setState(() => _newIsBuy = v),
                onDateChanged: (d) => setState(() => _newDate = d),
                onCreate: _commitEditTransaction,
                onCancel: _cancelEdit,
                submitLabel: 'Enregistrer',
                // Les pièces justificatives (facture, photo des pièces...)
                // se consultent et s'ajoutent directement en éditant la
                // transaction qu'elles justifient — métaux précieux et
                // "autres" uniquement, voir la section "Documents" plus bas.
                documentsSection: _usesTransactionScopedDocuments
                    ? DocumentsSection(
                        vaultPath: widget.vaultPath,
                        documents: [
                          for (final d in investment.documents)
                            if (d.transactionId == txn.id) d,
                        ],
                        fixedTransactionId: txn.id,
                        onAdd: _addDocument,
                        onDelete: _deleteDocument,
                      )
                    : null,
              )
            else
              _TransactionRow(
                transaction: txn,
                hidden: widget.hidden,
                onEdit: () => _startEdit(txn),
                onDelete: () => _deleteTransaction(txn),
                displayTotalOnly: _isImmobilier,
                // Pièces justificatives de la transaction (métaux précieux
                // et "autres") — affichées par un bouton trombone sur la
                // rangée, voir `showDocumentViewDialog`.
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
            shadcn.Text('Aucune transaction pour l\'instant.').muted().small(),
          const SizedBox(height: 8),
          if (_creating)
            _CreateTransactionForm(
              isBuy: _newIsBuy,
              date: _newDate,
              quantityController: _quantityController,
              priceController: _priceController,
              quantityLabel: _quantityFieldLabel,
              priceLabel: _priceFieldLabel,
              showPriceField: !_isEurEpargne && !_isImmobilier,
              onIsBuyChanged: (v) => setState(() => _newIsBuy = v),
              onDateChanged: (d) => setState(() => _newDate = d),
              onCreate: _commitCreateTransaction,
              onCancel: () => setState(() => _creating = false),
            )
          else
            _AddTransactionButton(
              onTap: () => setState(() {
                _editingTransactionId = null;
                _newIsBuy = true;
                // Date par défaut sans heure — voir `_onOrBeforeDay` dans
                // real_patrimoine_adapter.
                _newDate = DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                );
                _quantityController.clear();
                _priceController.clear();
                _creating = true;
              }),
            ),
        ],
      ),
    );
  }
}

/// Formulaire d'édition de l'identifiant et du libellé d'un investissement
/// — mêmes champs que `_CreateInvestmentForm` (`account_detail_screen.dart`)
/// à la création, remplis avec les valeurs actuelles.
class _EditInvestmentForm extends StatelessWidget {
  final AssetClass assetClass;
  final bool isImmobilier;
  final AccountEnvelope? accountEnvelope;
  final TextEditingController isinController;
  final TextEditingController labelController;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditInvestmentForm({
    required this.assetClass,
    required this.isImmobilier,
    this.accountEnvelope,
    required this.isinController,
    required this.labelController,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImmobilier)
              TextField(
                controller: labelController,
                placeholder: const shadcn.Text(
                  'Nom du bien (ex: Appartement Lyon 6e)',
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: InvestmentIdentifierField(
                      assetClass: assetClass,
                      accountEnvelope: accountEnvelope,
                      isinController: isinController,
                      labelController: labelController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: labelController,
                      placeholder: const shadcn.Text(
                        'Libellé (ex: TotalEnergies)',
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                PrimaryButton(
                  onPressed: onSave,
                  child: const shadcn.Text('Enregistrer'),
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

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
          shadcn.Text(label).muted().xSmall(),
          shadcn.Text(value).medium(),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final bool hidden;
  final bool displayTotalOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Documents rattachés à cette transaction (pièces justificatives des
  /// métaux précieux et "autres") — affiche un bouton de consultation
  /// quand la liste est non vide.
  final List<VaultDocument> documents;

  /// Chemin du vault pour ouvrir les fichiers depuis [showDocumentViewDialog]
  /// — inutilisé (et `null`) quand [documents] est vide.
  final String? vaultPath;

  const _TransactionRow({
    required this.transaction,
    required this.hidden,
    this.displayTotalOnly = false,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: shadcn.Text(
                transaction.isBuy ? 'Achat' : 'Vente',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ).xSmall(),
            ),
            const SizedBox(width: 12),
            Expanded(child: shadcn.Text(_formatDate(transaction.date)).small()),
            if (!displayTotalOnly) ...[
              shadcn.Text(
                '${transaction.quantity.toStringAsFixed(2)} × '
                '${displayEuros(transaction.unitPrice, hidden)}',
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

class _AddTransactionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTransactionButton({required this.onTap});

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
            'Ajouter une transaction',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _CreateTransactionForm extends StatelessWidget {
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
  /// `Montant (€)`/`Montant (<devise>)` pour une épargne (voir
  /// `InvestmentDetailView`'s `_quantityFieldLabel`).
  final String quantityLabel;

  /// Libellé du champ [priceController] — "Prix unitaire (€)" par défaut,
  /// "Cours de la paire de devise" pour une épargne (voir
  /// `InvestmentDetailView`'s `_priceFieldLabel`).
  final String priceLabel;

  /// `false` masque entièrement le champ [priceController] — une épargne
  /// tenue en euros n'a pas de taux de change à saisir (voir
  /// `InvestmentDetailView`'s `_isEurEpargne`).
  final bool showPriceField;

  /// Section "Documents" scopée à cette transaction (voir
  /// `DocumentsSection`'s `fixedTransactionId`) — `null` pour une
  /// transaction en cours de création (pas encore d'id persisté auquel
  /// rattacher un document) ou hors métaux précieux.
  final Widget? documentsSection;

  const _CreateTransactionForm({
    required this.isBuy,
    required this.date,
    required this.quantityController,
    required this.priceController,
    this.submitLabel = 'Ajouter la transaction',
    this.quantityLabel = 'Quantité',
    this.priceLabel = 'Prix unitaire (€)',
    this.showPriceField = true,
    required this.onIsBuyChanged,
    required this.onDateChanged,
    required this.onCreate,
    required this.onCancel,
    this.documentsSection,
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
                      onChanged: (_) => onIsBuyChanged(true),
                      child: const shadcn.Text('Achat'),
                    ),
                    SelectedButton(
                      value: !isBuy,
                      selectedStyle: const ButtonStyle.primary(),
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
                ],
              ],
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

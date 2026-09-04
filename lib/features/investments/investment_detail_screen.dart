import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/ui/copyable_identifier.dart';
import '../../core/ui/toggle_button_style.dart';
import '../../l10n/app_localizations.dart';
import 'account_detail_screen.dart' show BackHeader;
import 'confirm_delete_dialog.dart';
import 'currency_data.dart' show kKnownStablecoins;
import 'currency_format.dart';
import 'document_storage.dart';
import 'documents_section.dart';
import 'investment_reestimate_dialog.dart';
import 'investments_models.dart';
import 'investments_repository.dart';
import 'metal_price_client.dart';
import 'metal_price_repository.dart';
import 'patrimoine_refresh_controller.dart';
import 'performance_calculator.dart';
import 'price_history_repository.dart';
import 'real_estate/real_estate_documents_section.dart';
import 'real_estate/real_estate_loan_link.dart';
import 'real_estate/real_estate_profitability_section.dart';
import 'real_estate/rent_models.dart';
import 'real_estate/rent_periods_section.dart';
import 'real_estate/work_items_section.dart';
import 'transaction_price_currency.dart';
import 'widgets/investment_edit_form.dart';
import 'widgets/merge_investment_dialog.dart';
import 'widgets/transaction_widgets.dart';
import 'widgets/transfer_arbitrage_dialog.dart';
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

  /// Nom du profil actif — utilisé comme "bailleur" sur une quittance de
  /// loyer générée (voir `RealEstateProfitabilitySection`... en réalité
  /// `RentPeriodsSection`, aucun champ dédié "bailleur" n'existe sur le
  /// bien). Sans effet hors immobilier.
  final String profileName;

  /// Signal global de mutation du patrimoine — transmis à
  /// [RealEstateLoanLinkSection] (immobilier uniquement) pour qu'elle
  /// recharge la liste des crédits disponibles quand l'un d'eux est créé
  /// ailleurs (ex : depuis le bouton "+" de la TopBar) pendant que cette
  /// page reste ouverte, plutôt que de rester figée sur l'état chargé à
  /// l'ouverture jusqu'à ce que l'utilisateur quitte puis revienne.
  final PatrimoineRefreshController patrimoineRefreshController;

  const InvestmentDetailView({
    super.key,
    required this.vaultPath,
    required this.account,
    required this.investment,
    required this.hidden,
    required this.onBack,
    required this.onChanged,
    required this.profileName,
    required this.patrimoineRefreshController,
  });

  @override
  State<InvestmentDetailView> createState() => _InvestmentDetailViewState();
}

class _InvestmentDetailViewState extends State<InvestmentDetailView> {
  late InvestmentsRepository _repo;
  List<PricePoint> _priceHistory = [];
  _PerfMode _perfMode = _PerfMode.twr;

  /// Onglet actif de la section Loyers/Travaux/Documents d'un bien
  /// immobilier — voir [_isImmobilier]. Sans effet pour les autres classes.
  int _realEstateTabIndex = 0;

  bool _creating = false;
  String? _editingTransactionId;
  bool _newIsBuy = true;
  DateTime? _newDate;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();

  /// Devise et taux de change du formulaire de transaction courant (voir
  /// `transaction_price_currency.dart`) : à l'euro par défaut, résolus puis
  /// convertis au moment du commit (`_commitCreateTransaction`/`_commitEditTransaction`).
  late final TransactionPriceCurrencyController _priceCurrencyController;

  bool _editingInvestment = false;
  final _editIsinController = TextEditingController();
  final _editLabelController = TextEditingController();
  FundStyle? _editFundStyle;
  Sector? _editSector;
  List<SectorWeight> _editSectorBreakdown = const [];
  String? _editCountryCode;
  List<CountryWeight> _editCountryBreakdown = const [];

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    _priceCurrencyController = TransactionPriceCurrencyController(
      vaultPath: widget.vaultPath,
    );
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
    if (oldWidget.vaultPath != widget.vaultPath) {
      _priceCurrencyController.dispose();
      _priceCurrencyController = TransactionPriceCurrencyController(
        vaultPath: widget.vaultPath,
      );
    }
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
    // Les métaux précieux physiques n'ont pas d'historique Yahoo Finance :
    // leur série est reconstruite depuis les relevés journaliers stockés par
    // `price_refresh_service.dart` (voir
    // [MetalPriceRepository.pricePointsFor]) — nécessaire à la performance
    // TWR, qui valorise chaque transaction à une date de cours. Un ETC
    // or/argent logé dans un CTO (voir [isMetalEtc]) est, lui, un titre
    // coté : son historique se lit comme celui d'une action.
    if (_effectiveClass == AssetClass.metauxPrecieux &&
        !isMetalEtc(widget.account)) {
      final points = await MetalPriceRepository(widget.vaultPath)
          .pricePointsFor(
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
  /// bien immobilier, code de devise tenue...), donc ne doivent pas être
  /// présentées comme tel.
  bool get _isRealIsin =>
      !_isCurrency &&
      (_effectiveClass == AssetClass.actionsEtFonds ||
          _effectiveClass == AssetClass.privateEquity);

  bool get _isImmobilier => _effectiveClass == AssetClass.immobilier;

  /// Métaux précieux et "Autres" : chaque document doit être rattaché à la
  /// transaction précise qu'il justifie (facture, photo...), pas de section
  /// "Documents" au niveau du compte pour ces deux classes (voir
  /// `account_detail_screen.dart`) — les autres classes, à l'inverse,
  /// n'ont cette section qu'au niveau du compte.
  bool get _usesTransactionScopedDocuments =>
      _effectiveClass == AssetClass.metauxPrecieux ||
      _effectiveClass == AssetClass.autres;

  /// Une position en devise tenue en euros (l'immense majorité des cas
  /// français — Livret A, LDDS, LEP, PEL...) n'a pas de taux de change à
  /// saisir : un versement de 1000 € est juste... 1000 €. Le champ "Cours
  /// de la paire de devise" ne devient pertinent que pour une position en
  /// devise tenue dans une autre devise (voir [kKnownCurrencies] côté
  /// sélection).
  bool get _isEurCurrency =>
      _isCurrency && widget.investment.isin.trim().toUpperCase() == 'EUR';

  /// L'investissement courant est-il tenu en devise (épargne, ou devise
  /// créée dans un compte-titres via le flux de complétion — un compte peut
  /// loger des titres ET des devises côte à côte) ? — mêmes règles que
  /// `isCurrencyInvestment` au niveau du modèle.
  bool get _isCurrency =>
      isCurrencyInvestment(widget.account, widget.investment);

  String get _quantityFieldLabel {
    final l10n = AppLocalizations.of(context);
    if (_isImmobilier) return l10n.investments_field_total_amount_eur;
    if (_isCurrency) {
      return _isEurCurrency
          ? l10n.investments_field_amount_eur
          : l10n.investments_field_amount_currency(widget.investment.isin);
    }
    return l10n.investments_field_quantity;
  }

  String get _priceFieldLabel {
    final l10n = AppLocalizations.of(context);
    return _isCurrency
        ? l10n.investments_field_currency_pair_rate
        : l10n.investments_field_unit_price;
  }

  /// Le sélecteur de devise s'affiche sur le champ prix dès qu'il est
  /// pertinent : hors immobilier (pas de prix unitaire), et hors position
  /// en devise — dont le "prix" est déjà le taux de change en euros, sans
  /// devise à choisir (voir `_isCurrency`).
  bool get _showCurrencySelector =>
      !_isEurCurrency && !_isImmobilier && !_isCurrency;

  /// Devise effective de la transaction en cours de saisie : toujours
  /// l'euro pour une position en devise (le cours saisi est déjà un taux en
  /// euros), sinon la devise choisie sur le formulaire.
  String get _txnCurrency =>
      _isCurrency ? 'EUR' : _priceCurrencyController.currency;

  /// Taux de change à appliquer à la transaction en cours de saisie — 1
  /// pour une transaction en euros, le taux résolu/saisi sinon (peut être
  /// `null` : devise étrangère dont aucun taux n'est encore disponible, le
  /// commit est alors impossible).
  double? get _txnFxRateToEur =>
      _txnCurrency == 'EUR' ? 1.0 : _priceCurrencyController.resolvedRate;

  /// Libellé du champ "Dernier cours" — voir [investmentLastPriceDisplay].
  String get _lastPriceDisplay => investmentLastPriceDisplay(
    widget.account,
    widget.investment,
    hidden: widget.hidden,
  );

  Future<void> _commitCreateTransaction() async {
    final date = _newDate;
    if (date == null) return;
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
    // Devise étrangère sans taux de change (auto et manuel indisponibles) :
    // impossible de convertir en euros, on ne sauvegarde pas.
    if (quantity == null ||
        quantity <= 0 ||
        price == null ||
        price <= 0 ||
        fxRateToEur == null ||
        fxRateToEur <= 0) {
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
          currency: currency,
          fxRateToEur: fxRateToEur,
          note: _noteOrNull,
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
    _noteController.clear();
    setState(() => _creating = false);
    widget.onChanged();
  }

  /// [_noteController]'s text, ou `null` s'il est vide (voir
  /// [Transaction.note] — jamais une chaîne vide persistée).
  String? get _noteOrNull {
    final text = _noteController.text.trim();
    return text.isEmpty ? null : text;
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
      _noteController.text = transaction.note ?? '';
    });
    // Devise et taux enregistrés sur la transaction (historiquement exacts)
    // repris tels quels pour l'édition.
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
    setState(() => _editingTransactionId = null);
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
    // Aucun des trois n'est éditable depuis ce formulaire : les omettre les
    // réinitialiserait à `null` silencieusement, détachant une transaction
    // de dépôt/dividende/transfert/arbitrage de sa nature, de sa
    // contrepartie, ou perdant une date de déblocage saisie à la main.
    final original = widget.investment.transactions.firstWhere(
      (t) => t.id == id,
    );
    final updatedTransaction = Transaction(
      id: id,
      date: date,
      isBuy: _newIsBuy,
      quantity: quantity,
      unitPrice: price,
      currency: currency,
      fxRateToEur: fxRateToEur,
      note: _noteOrNull,
      type: original.type,
      linkedTransactionId: original.linkedTransactionId,
      manualUnlockDate: original.manualUnlockDate,
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
    _noteController.clear();
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDelete(
      context,
      title: l10n.investments_delete_investment_confirm_title(
        widget.investment.label,
      ),
      message: l10n.investments_delete_investment_confirm_message,
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

  /// Voir `merge_investment_dialog.dart` : une fusion réussie fait
  /// disparaître `widget.investment` — cette page navigue en arrière plutôt
  /// que de tenter d'afficher une position qui n'existe plus, même
  /// principe que [_deleteInvestment].
  Future<void> _openMergeDialog() async {
    var merged = false;
    await showMergeInvestmentDialog(
      context,
      vaultPath: widget.vaultPath,
      account: widget.account,
      sourceInvestment: widget.investment,
      onChanged: () async {
        merged = true;
        await widget.onChanged();
      },
    );
    if (merged) widget.onBack();
  }

  void _startEditInvestment() {
    setState(() {
      _editingInvestment = true;
      // Un identifiant auto-généré (voir [isGeneratedIdentifier]) n'a rien
      // d'utile à montrer/re-saisir — le champ reste optionnel pour ces
      // classes (voir [isinOptionalFor]), donc vide plutôt que de préremplir
      // avec un id technique interne : ré-enregistrer sans y toucher
      // régénère simplement un nouveau placeholder ([_commitEditInvestment]).
      _editIsinController.text = isGeneratedIdentifier(widget.investment.isin)
          ? ''
          : widget.investment.isin;
      _editLabelController.text = widget.investment.label;
      _editFundStyle = widget.investment.fundStyle;
      _editSector = widget.investment.sector;
      _editSectorBreakdown = widget.investment.sectorBreakdown;
      _editCountryCode = widget.investment.countryCode;
      _editCountryBreakdown = widget.investment.countryBreakdown;
    });
  }

  /// Changer l'identifiant (ISIN, ticker...) invalide le cours déjà résolu
  /// pour l'ancien : on le réinitialise pour forcer une nouvelle résolution
  /// au prochain passage du rafraîchissement global (déclenché par
  /// [onChanged], voir `price_refresh_service.dart`) plutôt que de garder
  /// par erreur un cours qui ne correspond plus à l'investissement modifié.
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
      // La devise de cotation et son taux, résolus pour l'ancien
      // identifiant, sont tout aussi invalides une fois celui-ci changé.
      quoteCurrency: isinChanged ? null : widget.investment.quoteCurrency,
      lastFxRateToEur: isinChanged ? null : widget.investment.lastFxRateToEur,
      priceUnavailable: isinChanged ? null : widget.investment.priceUnavailable,
      // Reconstruit à la main plutôt que via `copyWith` (qui ne sait pas
      // remettre un champ nullable à `null`, nécessaire ci-dessus pour
      // symbol/lastPrice/etc.) : tous les autres champs doivent donc être
      // reportés explicitement — régression corrigée ici, une édition
      // effaçait auparavant silencieusement imageFileName/surfaceM2/
      // adresse/estimation/cours manuel/exclusion du patrimoine.
      imageFileName: widget.investment.imageFileName,
      assetClass: widget.investment.assetClass,
      realEstateType: widget.investment.realEstateType,
      fundStyle: _editFundStyle,
      sector: _editSector,
      sectorBreakdown: _editSectorBreakdown,
      countryCode: _editCountryCode,
      countryBreakdown: _editCountryBreakdown,
      surfaceM2: widget.investment.surfaceM2,
      addressLabel: widget.investment.addressLabel,
      addressCityCode: widget.investment.addressCityCode,
      addressLat: widget.investment.addressLat,
      addressLon: widget.investment.addressLon,
      estimatedPricePerSqm: widget.investment.estimatedPricePerSqm,
      estimatedValueAt: widget.investment.estimatedValueAt,
      manualPrice: widget.investment.manualPrice,
      manualPriceAt: widget.investment.manualPriceAt,
      documents: widget.investment.documents,
      rentPeriods: widget.investment.rentPeriods,
      workItems: widget.investment.workItems,
      excludedFromPatrimoine: widget.investment.excludedFromPatrimoine,
    );
    await _saveInvestment(updatedInvestment);
    setState(() => _editingInvestment = false);
    await widget.onChanged();
  }

  void _openInvestmentMenu(BuildContext anchorContext) {
    final l10n = AppLocalizations.of(anchorContext);
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
              child: shadcn.Text(l10n.common_edit),
              onPressed: (_) => _startEditInvestment(),
            ),
            if (_isImmobilier)
              MenuButton(
                leading: const Icon(LucideIcons.mapPin, size: 14),
                child: shadcn.Text(l10n.investments_reestimate_dialog_title),
                onPressed: (_) => _openReestimateDialog(),
              ),
            MenuButton(
              enabled: widget.investment.quantityHeld > 0,
              leading: const Icon(LucideIcons.arrowRightLeft, size: 14),
              child: shadcn.Text(l10n.investments_transfer_to_account_menu_item),
              onPressed: (_) => showTransferDialog(
                context,
                vaultPath: widget.vaultPath,
                sourceAccount: widget.account,
                sourceInvestment: widget.investment,
                onChanged: widget.onChanged,
              ),
            ),
            MenuButton(
              enabled: widget.investment.quantityHeld > 0,
              leading: const Icon(LucideIcons.shuffle, size: 14),
              child: shadcn.Text(l10n.investments_arbitrage_to_security_menu_item),
              onPressed: (_) => showArbitrageDialog(
                context,
                vaultPath: widget.vaultPath,
                sourceAccount: widget.account,
                sourceInvestment: widget.investment,
                onChanged: widget.onChanged,
              ),
            ),
            MenuButton(
              enabled: widget.account.investments.length > 1,
              leading: const Icon(LucideIcons.combine, size: 14),
              child: shadcn.Text(l10n.investments_merge_with_position_menu_item),
              onPressed: (_) => _openMergeDialog(),
            ),
            MenuButton(
              enabled: _canDelete,
              leading: const Icon(LucideIcons.trash2, size: 14),
              trailing: _canDelete
                  ? null
                  : shadcn.Text(
                      l10n.investments_delete_investment_requires_empty_tooltip,
                    ).muted().xSmall(),
              child: shadcn.Text(l10n.investments_delete_investment_menu_item),
              onPressed: (_) => _deleteInvestment(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReestimateDialog() async {
    await showRealEstateReestimateDialog(
      context,
      vaultPath: widget.vaultPath,
      investment: widget.investment,
      onEstimated: (updated) async {
        await _saveInvestment(updated);
        await widget.onChanged();
      },
    );
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    // Une moitié de transfert/arbitrage (voir `Transaction.linkedTransactionId`)
    // n'a de sens qu'en paire : la supprimer sans sa contrepartie laisserait
    // une position déséquilibrée (ex : un titre "arrivé" nulle part) sur
    // l'autre compte/position, une erreur silencieuse difficile à repérer.
    final linkedId = transaction.linkedTransactionId;
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDelete(
      context,
      title: l10n.investments_delete_transaction_title,
      message: linkedId == null
          ? l10n.investments_delete_transaction_message(
              widget.investment.label,
            )
          : l10n.investments_delete_linked_transaction_message,
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
    if (linkedId != null) await _repo.deleteTransaction(linkedId);
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
    String? name, [
    String? category,
  ]) async {
    final document = VaultDocument(
      fileName: fileName,
      note: name,
      transactionId: transactionId,
      category: category,
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

  Future<void> _addRentPeriod(RentPeriod period) async {
    await _saveInvestment(
      widget.investment.copyWith(
        rentPeriods: [...widget.investment.rentPeriods, period],
      ),
    );
    widget.onChanged();
  }

  Future<void> _updateRentPeriod(RentPeriod updated) async {
    await _saveInvestment(
      widget.investment.copyWith(
        rentPeriods: [
          for (final p in widget.investment.rentPeriods)
            if (p.id == updated.id) updated else p,
        ],
      ),
    );
    widget.onChanged();
  }

  Future<void> _deleteRentPeriod(RentPeriod period) async {
    await _saveInvestment(
      widget.investment.copyWith(
        rentPeriods: [
          for (final p in widget.investment.rentPeriods)
            if (p.id != period.id) p,
        ],
      ),
    );
    widget.onChanged();
  }

  /// Propose l'enregistrement du PDF déjà généré (voir [RentPeriodsSection
  /// .onDownloadQuittance]) via le sélecteur de fichier natif — même
  /// séquence que `patrimoine_export_dialog.dart` — puis la conserve AUSSI
  /// dans les documents du bien (catégorie "Quittance") pour un historique
  /// consultable sans avoir à la régénérer.
  Future<void> _downloadQuittance(RentPeriod period, Uint8List pdfBytes) async {
    final l10n = AppLocalizations.of(context);
    final monthLabel =
        '${period.periodStart.year}-'
        '${period.periodStart.month.toString().padLeft(2, '0')}';
    try {
      final savePath = await FilePicker.saveFile(
        dialogTitle: l10n.investments_receipt_save_dialog_title,
        fileName: 'quittance-$monthLabel.pdf',
        bytes: pdfBytes,
      );
      if (savePath == null) return;
      final path = savePath.toLowerCase().endsWith('.pdf')
          ? savePath
          : '$savePath.pdf';
      await File(path).writeAsBytes(pdfBytes);
      await _addDocument(
        'quittance-$monthLabel.pdf',
        pdfBytes,
        null,
        l10n.investments_receipt_document_name(monthLabel),
        l10n.real_estate_document_category_receipt,
      );
      if (!mounted) return;
      _showToast(
        title: l10n.investments_receipt_saved_toast_title,
        subtitle: l10n.patrimoine_export_success_subtitle(path),
      );
    } catch (e) {
      if (!mounted) return;
      _showToast(
        title: l10n.investments_receipt_save_failed_toast_title,
        subtitle: l10n.investments_receipt_save_failed_subtitle('$e'),
      );
    }
  }

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

  Future<void> _addWorkItem(WorkItem item) async {
    await _saveInvestment(
      widget.investment.copyWith(
        workItems: [...widget.investment.workItems, item],
      ),
    );
    widget.onChanged();
  }

  Future<void> _deleteWorkItem(WorkItem item) async {
    await _saveInvestment(
      widget.investment.copyWith(
        workItems: [
          for (final w in widget.investment.workItems)
            if (w.id != item.id) w,
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

  @override
  Widget build(BuildContext context) {
    final investment = widget.investment;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
            InvestmentEditForm(
              assetClass: _effectiveClass,
              isImmobilier: _isImmobilier,
              accountEnvelope: widget.account.envelope,
              isinController: _editIsinController,
              labelController: _editLabelController,
              fundStyle: _editFundStyle,
              onFundStyleChanged: (style) =>
                  setState(() => _editFundStyle = style),
              sector: _editSector,
              onSectorChanged: (value) =>
                  setState(() => _editSector = value),
              sectorBreakdown: _editSectorBreakdown,
              onSectorBreakdownChanged: (value) =>
                  setState(() => _editSectorBreakdown = value),
              countryCode: _editCountryCode,
              onCountryCodeChanged: (value) =>
                  setState(() => _editCountryCode = value),
              countryBreakdown: _editCountryBreakdown,
              onCountryBreakdownChanged: (value) =>
                  setState(() => _editCountryBreakdown = value),
              // Cet écran est réservé à l'immobilier (voir sa doc de tête) :
              // le Private Equity ne l'atteint jamais, ces callbacks ne sont
              // donc jamais appelés en pratique.
              onVestingCliffMonthsChanged: (_) {},
              onVestingDurationMonthsChanged: (_) {},
              onExerciseDeadlineChanged: (_) {},
              onSave: _commitEditInvestment,
              onCancel: () => setState(() => _editingInvestment = false),
            )
          else ...[
            if (!_isImmobilier &&
                !_isCurrency &&
                (!isGeneratedIdentifier(investment.isin) ||
                    (investment.symbol != null &&
                        investment.symbol!.isNotEmpty))) ...[
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  // Un identifiant auto-généré (voir [isGeneratedIdentifier])
                  // n'a rien d'utile à montrer — pas de vrai ISIN/ticker à
                  // copier.
                  if (!isGeneratedIdentifier(investment.isin))
                    CopyableIdentifier(
                      value: investment.isin,
                      toastTitle: _isRealIsin
                          ? l10n.investments_isin_copied_toast_title
                          : l10n.investments_identifier_copied_toast_title,
                    ),
                  if (investment.symbol != null &&
                      investment.symbol!.isNotEmpty)
                    CopyableIdentifier(
                      value: investment.symbol!,
                      toastTitle: l10n.investments_ticker_copied_toast_title,
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
            if (!_isImmobilier &&
                !_isCurrency &&
                (investment.fundStyle != null ||
                    investment.sector != null ||
                    investment.countryCode != null)) ...[
              const SizedBox(height: 4),
              shadcn.Text(
                [
                  if (investment.fundStyle != null)
                    investment.fundStyle!.label,
                  if (investment.sector != null) investment.sector!.label,
                  if (investment.countryCode != null)
                    kInvestmentCountries[investment.countryCode] ??
                        investment.countryCode!,
                ].join(' · '),
              ).muted().small(),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!_isImmobilier) ...[
                InvestmentStatChip(
                  label: l10n.investments_quantity_held_label,
                  value: formatQuantity(
                    investment.quantityHeld,
                    _effectiveClass,
                  ),
                ),
                InvestmentStatChip(
                  label: l10n.dashboard_column_pru,
                  // Une position en devise (épargne ou devise d'un compte-
                  // titres) est tenue à un taux de change (le PRU est le
                  // cours de la paire à l'achat), pas à un montant :
                  // l'afficher avec la précision du taux plutôt que formaté
                  // en euros arrondis.
                  value: _isCurrency
                      ? '${investment.pru.toStringAsFixed(4)} €'
                      : displayEuros(investment.pru, widget.hidden),
                ),
              ],
              if (hasPrice)
                InvestmentStatChip(
                  label: l10n.investments_last_price_label,
                  value: _lastPriceDisplay,
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
                        ? l10n.investments_performance_annualized_label(
                            displayPercent(performance.rate * 100),
                          )
                        : l10n.investments_performance_since_start_label(
                            displayPercent(performance.rate * 100),
                          ),
                    style: TextStyle(
                      color: performance.rate >= 0 ? _green : _red,
                      fontWeight: FontWeight.w600,
                    ),
                  ).medium()
                else
                  shadcn.Text(
                    l10n.investments_not_enough_price_history,
                  ).muted().xSmall(),
              ],
            ),
            const SizedBox(height: 4),
            shadcn.Text(
              _perfMode == _PerfMode.twr
                  ? l10n.investments_twr_explanation
                  : l10n.investments_mwr_explanation,
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
                        ? l10n.investments_price_not_found_hint(
                            investment.isin,
                          )
                        : l10n.investments_price_not_yet_available_hint,
                  ).muted().xSmall(),
                ),
              ],
            ),
          if (_isImmobilier) ...[
            const SizedBox(height: 16),
            RealEstateLoanLinkSection(
              vaultPath: widget.vaultPath,
              investmentId: investment.id,
              patrimoineRefreshController: widget.patrimoineRefreshController,
            ),
            const SizedBox(height: 24),
            TabList(
              index: _realEstateTabIndex,
              onChanged: (value) =>
                  setState(() => _realEstateTabIndex = value),
              children: [
                TabItem(child: shadcn.Text(l10n.real_estate_rent_periods_title)),
                TabItem(child: shadcn.Text(l10n.real_estate_work_items_title)),
                TabItem(child: shadcn.Text(l10n.real_estate_documents_title)),
                TabItem(child: shadcn.Text(l10n.investments_tab_profitability)),
              ],
            ),
            const SizedBox(height: 16),
            if (_realEstateTabIndex == 0)
              RentPeriodsSection(
                rentPeriods: investment.rentPeriods,
                onAdd: _addRentPeriod,
                onUpdate: _updateRentPeriod,
                onDelete: _deleteRentPeriod,
                propertyLabel: investment.label,
                propertyAddress: investment.addressLabel,
                landlordName: widget.profileName,
                onDownloadQuittance: _downloadQuittance,
              )
            else if (_realEstateTabIndex == 1)
              WorkItemsSection(
                workItems: investment.workItems,
                onAdd: _addWorkItem,
                onDelete: _deleteWorkItem,
              )
            else if (_realEstateTabIndex == 2)
              RealEstateDocumentsSection(
                vaultPath: widget.vaultPath,
                documents: investment.documents,
                onAdd: (fileName, bytes, category, name) =>
                    _addDocument(fileName, bytes, null, name, category),
                onDelete: _deleteDocument,
              )
            else
              RealEstateProfitabilitySection(
                vaultPath: widget.vaultPath,
                investment: investment,
              ),
          ],
          const SizedBox(height: 24),
          shadcn.Text(l10n.investments_tab_transactions).large().medium(),
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
                currencyExtraOptions: _effectiveClass == AssetClass.crypto
                    ? kKnownStablecoins
                    : const [],
                onIsBuyChanged: (v) => setState(() => _newIsBuy = v),
                onDateChanged: (d) => setState(() => _newDate = d),
                onCreate: _commitEditTransaction,
                onCancel: _cancelEdit,
                submitLabel: l10n.common_save,
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
                        quantityAssetClass: widget.investment.assetClass,
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
                centerDate: centerDate,
              ),
            const SizedBox(height: 8),
          ],
          if (investment.transactions.isEmpty)
            shadcn.Text(l10n.investments_no_transactions_yet).muted().small(),
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
              onCreate: _commitCreateTransaction,
              onCancel: () => setState(() => _creating = false),
            )
          else
            AddTransactionButton(
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
                _noteController.clear();
                // Nouvelle transaction : devise et taux remis à l'euro.
                _priceCurrencyController.reset();
                _creating = true;
              }),
            ),
        ],
      ),
    );
  }
}

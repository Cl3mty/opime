import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/ui/frosted_card.dart';
import '../liabilities/liabilities_models.dart';
import '../liabilities/liabilities_repository.dart';
import '../liabilities/liability_form_fields.dart';
import '../simulations/loan_calculator.dart' show DeferType, LoanType;
import 'investment_identifier_field.dart';
import 'investments_models.dart';
import 'investments_repository.dart';
import 'real_patrimoine_adapter.dart' show emptyCategoryFor;

enum _Step {
  kind,
  assetClass,
  account,
  investment,
  transaction,
  liabilityType,
  liabilityForm,
}

/// Ouvre le flux "Compléter mon patrimoine" (bouton "+" de la TopBar) :
/// classe d'actif → compte (existant ou nouveau) → investissement
/// (existant ou nouveau) → transaction. Chaque étape persiste
/// immédiatement (comme l'ancien "Mes comptes") plutôt qu'à la toute fin,
/// pour qu'un compte/investissement créé reste acquis même si le flux est
/// fermé avant la dernière étape. [onCompleted] est appelé après l'ajout
/// de la transaction, pour que le Dashboard (ouvert ou non derrière cette
/// boîte de dialogue) recharge ses données.
/// Peut aussi créer un passif (prêt immobilier, crédit autre) : la
/// première étape laisse choisir "Actif" ou "Passif", chacun menant à son
/// propre sous-flux (actif : classe → compte → investissement →
/// transaction ; passif : type → formulaire).
///
/// [initialAssetClass], quand fourni (le flux a été ouvert depuis la page
/// de détail d'une catégorie d'actif plutôt que depuis une autre page),
/// présélectionne cette classe et démarre directement à l'étape "quel
/// compte ?" — le choix Actif/Passif puis la classe n'apporteraient rien,
/// le contexte les connaît déjà. [initialLiabilityType] fait de même côté
/// passif : démarre directement sur le formulaire de création.
Future<void> showCompletePatrimoineDialog(
  BuildContext context, {
  required String vaultPath,
  required VoidCallback onCompleted,
  AssetClass? initialAssetClass,
  LiabilityType? initialLiabilityType,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CompletePatrimoineDialog(
      vaultPath: vaultPath,
      onCompleted: onCompleted,
      initialAssetClass: initialAssetClass,
      initialLiabilityType: initialLiabilityType,
    ),
  );
}

class _CompletePatrimoineDialog extends StatefulWidget {
  final String vaultPath;
  final VoidCallback onCompleted;
  final AssetClass? initialAssetClass;
  final LiabilityType? initialLiabilityType;

  const _CompletePatrimoineDialog({
    required this.vaultPath,
    required this.onCompleted,
    this.initialAssetClass,
    this.initialLiabilityType,
  });

  @override
  State<_CompletePatrimoineDialog> createState() =>
      _CompletePatrimoineDialogState();
}

class _CompletePatrimoineDialogState extends State<_CompletePatrimoineDialog> {
  late final InvestmentsRepository _repo = InvestmentsRepository(
    widget.vaultPath,
  );
  late final LiabilitiesRepository _liabilitiesRepo = LiabilitiesRepository(
    widget.vaultPath,
  );
  bool _loading = true;
  List<InvestmentAccount> _accounts = [];

  _Step _step = _Step.kind;
  AssetClass? _assetClass;
  AccountEnvelope? _envelope;
  String? _accountId;
  String? _investmentId;

  bool _creatingAccount = false;
  final _accountNameController = TextEditingController();

  bool _creatingInvestment = false;
  RealEstateType _realEstateType = RealEstateType.residencePrincipale;
  final _isinController = TextEditingController();
  final _labelController = TextEditingController();

  bool _newIsBuy = true;
  DateTime? _txnDate;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  LiabilityType? _liabilityType;
  final _liabNameController = TextEditingController();
  final _liabPrixController = TextEditingController();
  final _liabApportController = TextEditingController();
  final _liabTauxController = TextEditingController();
  final _liabAssuranceMensuelleController = TextEditingController();
  final _liabNbrEcheancesController = TextEditingController();
  final _liabDureeDiffereController = TextEditingController();
  DateTime? _liabDateDebut;
  LoanType _liabLoanType = LoanType.amortissable;
  DeferType _liabTypeDiffere = DeferType.partielle;

  @override
  void initState() {
    super.initState();
    // Dates par défaut sans heure : l'épargne n'est pas un instant mais un
    // jour calendaire — conserver l'heure de `DateTime.now()` ferait passer
    // la transaction du jour au-dessus de minuit UTC de la grille de dates
    // des historiques (voir `_onOrBeforeDay` dans real_patrimoine_adapter).
    _txnDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _liabDateDebut = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final initialAssetClass = widget.initialAssetClass;
    final initialLiabilityType = widget.initialLiabilityType;
    if (initialAssetClass != null) {
      _assetClass = initialAssetClass;
      _envelope = accountEnvelopesFor(initialAssetClass).first;
      _step = _Step.account;
    } else if (initialLiabilityType != null) {
      _liabilityType = initialLiabilityType;
      _step = _Step.liabilityForm;
    }
    _load();
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _isinController.dispose();
    _labelController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _liabNameController.dispose();
    _liabPrixController.dispose();
    _liabApportController.dispose();
    _liabTauxController.dispose();
    _liabAssuranceMensuelleController.dispose();
    _liabNbrEcheancesController.dispose();
    _liabDureeDiffereController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accounts = await _repo.listAll();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _loading = false;
    });
    if (_assetClass == AssetClass.immobilier && _step == _Step.account) {
      await _selectImmobilierAccount();
    }
  }

  InvestmentAccount? get _account {
    final id = _accountId;
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Investment? get _investment {
    final account = _account;
    final id = _investmentId;
    if (account == null || id == null) return null;
    for (final i in account.investments) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Même logique que `InvestmentDetailView`'s `_isEurEpargne` : une
  /// épargne tenue en euros n'a pas de taux de change à saisir pour sa
  /// première transaction non plus.
  bool get _isEurEpargne {
    final investment = _investment;
    final account = _account;
    if (investment == null || account == null) return false;
    final effectiveClass = investment.assetClass ?? account.assetClass;
    return effectiveClass == AssetClass.epargne &&
        investment.isin.toUpperCase() == 'EUR';
  }

  String get _quantityFieldLabel {
    final investment = _investment;
    final account = _account;
    if (investment == null || account == null) return 'Quantité';
    final effectiveClass = investment.assetClass ?? account.assetClass;
    if (effectiveClass == AssetClass.immobilier) return 'Montant total (€)';
    if (effectiveClass != AssetClass.epargne) return 'Quantité';
    return _isEurEpargne ? 'Montant (€)' : 'Montant (${investment.isin})';
  }

  String get _priceFieldLabel {
    final investment = _investment;
    final account = _account;
    if (investment == null || account == null) return 'Prix unitaire (€)';
    final effectiveClass = investment.assetClass ?? account.assetClass;
    return effectiveClass == AssetClass.epargne
        ? 'Cours de la paire de devise'
        : 'Prix unitaire (€)';
  }

  void _selectAssetClass(AssetClass assetClass) {
    if (assetClass == AssetClass.immobilier) {
      _selectImmobilierAccount();
      return;
    }
    setState(() {
      _assetClass = assetClass;
      _envelope = accountEnvelopesFor(assetClass).first;
      _step = _Step.account;
    });
  }

  /// L'immobilier ne se rattache pas à un compte de placement. Le modèle de
  /// stockage conserve un compte technique commun, sans le demander ici.
  Future<void> _selectImmobilierAccount() async {
    final existing = _accounts.where(
      (account) => account.assetClass == AssetClass.immobilier,
    );
    final account = existing.isNotEmpty
        ? existing.first
        : InvestmentAccount(
            assetClass: AssetClass.immobilier,
            envelope: AccountEnvelope.autre,
            name: 'Biens immobiliers',
            investments: const [],
          );
    if (existing.isEmpty) await _repo.saveAccount(account);
    if (!mounted) return;
    setState(() {
      _assetClass = AssetClass.immobilier;
      _envelope = account.envelope;
      _accountId = account.id;
      _accounts = existing.isEmpty ? [..._accounts, account] : _accounts;
      _step = _Step.investment;
    });
  }

  Future<void> _commitCreateAccount() async {
    final name = _accountNameController.text.trim();
    final assetClass = _assetClass;
    if (name.isEmpty || assetClass == null) return;
    final account = InvestmentAccount(
      assetClass: assetClass,
      envelope: _envelope,
      name: name,
      investments: const [],
    );
    await _repo.saveAccount(account);
    _accountNameController.clear();
    setState(() {
      _accounts = [..._accounts, account];
      _accountId = account.id;
      _creatingAccount = false;
      _step = _Step.investment;
    });
  }

  void _selectAccount(String id) {
    setState(() {
      _accountId = id;
      _step = _Step.investment;
    });
  }

  Future<void> _commitCreateInvestment() async {
    final account = _account;
    final assetClass = _assetClass;
    final rawIsin = _isinController.text.trim();
    final isin =
        assetClass != null &&
            identifierOptionsFor(
                  assetClass,
                  accountEnvelope: account?.envelope,
                ) !=
                null
        ? rawIsin
        : rawIsin.toUpperCase();
    final label = _labelController.text.trim();
    if (account == null ||
        label.isEmpty ||
        (assetClass != AssetClass.immobilier && isin.isEmpty)) {
      return;
    }
    // Le compte peut être "étranger" à la classe choisie à l'étape 1 (ex :
    // un ETC or créé dans un CTO "Actions & Fonds" via
    // accountAcceptsCrossClassInvestment) : l'investissement porte alors
    // sa propre classe plutôt que d'hériter de celle du compte.
    final investment = Investment(
      isin: assetClass == AssetClass.immobilier
          ? 'immobilier-${generateInvestmentId('bien')}'
          : isin,
      label: label,
      transactions: const [],
      assetClass: account.assetClass == _assetClass ? null : _assetClass,
      realEstateType: assetClass == AssetClass.immobilier
          ? _realEstateType
          : null,
    );
    final updatedAccount = account.copyWith(
      investments: [...account.investments, investment],
    );
    await _repo.saveAccount(updatedAccount);
    _isinController.clear();
    _labelController.clear();
    setState(() {
      _accounts = [
        for (final a in _accounts)
          if (a.id == account.id) updatedAccount else a,
      ];
      _investmentId = investment.id;
      _creatingInvestment = false;
      _step = _Step.transaction;
    });
  }

  void _selectInvestment(String id) {
    setState(() {
      _investmentId = id;
      _step = _Step.transaction;
    });
  }

  Future<void> _commitCreateTransaction() async {
    final account = _account;
    final investment = _investment;
    final date = _txnDate;
    final isImmobilier = _assetClass == AssetClass.immobilier;
    final quantity = isImmobilier
        ? 1.0
        : double.tryParse(_quantityController.text.trim());
    final price = isImmobilier
        ? double.tryParse(_quantityController.text.trim())
        : _isEurEpargne
        ? 1.0
        : double.tryParse(_priceController.text.trim());
    if (account == null ||
        investment == null ||
        date == null ||
        quantity == null ||
        quantity <= 0 ||
        price == null ||
        price <= 0) {
      return;
    }
    final updatedInvestment = investment.copyWith(
      transactions: [
        ...investment.transactions,
        Transaction(
          date: date,
          isBuy: _newIsBuy,
          quantity: quantity,
          unitPrice: price,
        ),
      ],
    );
    final updatedAccount = account.copyWith(
      investments: [
        for (final i in account.investments)
          if (i.id == updatedInvestment.id) updatedInvestment else i,
      ],
    );
    await _repo.saveAccount(updatedAccount);
    _finish();
  }

  void _selectLiabilityType(LiabilityType type) {
    setState(() {
      _liabilityType = type;
      _step = _Step.liabilityForm;
    });
  }

  Future<void> _commitCreateLiability() async {
    final type = _liabilityType;
    final name = _liabNameController.text.trim();
    final prix = double.tryParse(_liabPrixController.text.trim());
    final apport = double.tryParse(_liabApportController.text.trim()) ?? 0;
    final taux = double.tryParse(_liabTauxController.text.trim());
    final assuranceMensuelle = double.tryParse(
      _liabAssuranceMensuelleController.text.trim(),
    );
    final nbrEcheances = int.tryParse(_liabNbrEcheancesController.text.trim());
    final dureeDiffere =
        int.tryParse(_liabDureeDiffereController.text.trim()) ?? 0;
    final dateDebut = _liabDateDebut;
    if (type == null ||
        name.isEmpty ||
        prix == null ||
        prix <= 0 ||
        apport < 0 ||
        apport >= prix ||
        taux == null ||
        taux < 0 ||
        assuranceMensuelle == null ||
        assuranceMensuelle < 0 ||
        nbrEcheances == null ||
        nbrEcheances <= 0 ||
        dureeDiffere < 0 ||
        dateDebut == null) {
      return;
    }
    final liability = Liability(
      type: type,
      name: name,
      montantEmprunte: prix - apport,
      apport: apport,
      tauxInteret: taux,
      assuranceMensuelle: assuranceMensuelle,
      nbrEcheances: nbrEcheances,
      dateDebut: dateDebut,
      loanType: _liabLoanType,
      differeActif: dureeDiffere > 0,
      dureeDiffereMois: dureeDiffere,
      typeDiffere: _liabTypeDiffere,
    );
    await _liabilitiesRepo.saveLiability(liability);
    _finish();
  }

  void _finish() {
    widget.onCompleted();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Sans ce Center, la boîte n'a que sa largeur bornée (maxWidth) : la
    // hauteur, elle, reste celle — non bornée — de la route plein écran
    // dans laquelle showDialog l'insère, et le contenu s'étire alors sur
    // toute la hauteur de la fenêtre au lieu de se limiter à sa taille
    // naturelle, ce qui donne l'impression d'une page plutôt que d'une
    // boîte de dialogue centrée.
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _loading
                ? const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SingleChildScrollView(child: _buildStep()),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.kind:
        return _KindStep(
          onSelectActif: () => setState(() => _step = _Step.assetClass),
          onSelectPassif: () => setState(() => _step = _Step.liabilityType),
        );
      case _Step.assetClass:
        return _AssetClassStep(
          onSelect: _selectAssetClass,
          onBack: () => setState(() => _step = _Step.kind),
        );
      case _Step.account:
        return _AccountStep(
          assetClass: _assetClass!,
          accounts: _accounts
              .where(
                (a) =>
                    a.assetClass == _assetClass ||
                    accountAcceptsCrossClassInvestment(a, _assetClass!),
              )
              .toList(),
          creating: _creatingAccount,
          nameController: _accountNameController,
          envelope: _envelope!,
          onEnvelopeChanged: (e) => setState(() => _envelope = e),
          onBack: () => setState(() {
            _step = _Step.assetClass;
            _assetClass = null;
            _envelope = null;
          }),
          onSelectAccount: _selectAccount,
          onStartCreate: () => setState(() => _creatingAccount = true),
          onCancelCreate: () => setState(() => _creatingAccount = false),
          onCreate: _commitCreateAccount,
        );
      case _Step.investment:
        return _InvestmentStep(
          account: _account!,
          assetClass: _assetClass!,
          creating: _creatingInvestment,
          isinController: _isinController,
          labelController: _labelController,
          realEstateType: _realEstateType,
          onRealEstateTypeChanged: (type) =>
              setState(() => _realEstateType = type),
          onBack: () => setState(() {
            _step = _assetClass == AssetClass.immobilier
                ? _Step.assetClass
                : _Step.account;
            _accountId = null;
          }),
          onSelectInvestment: _selectInvestment,
          onStartCreate: () => setState(() => _creatingInvestment = true),
          onCancelCreate: () => setState(() => _creatingInvestment = false),
          onCreate: _commitCreateInvestment,
        );
      case _Step.transaction:
        return _TransactionStep(
          investment: _investment!,
          isBuy: _newIsBuy,
          date: _txnDate,
          quantityController: _quantityController,
          priceController: _priceController,
          quantityLabel: _quantityFieldLabel,
          priceLabel: _priceFieldLabel,
          showPriceField:
              !_isEurEpargne && _assetClass != AssetClass.immobilier,
          onBack: () => setState(() {
            _step = _Step.investment;
            _investmentId = null;
          }),
          onIsBuyChanged: (v) => setState(() => _newIsBuy = v),
          onDateChanged: (d) => setState(() => _txnDate = d),
          onCreate: _commitCreateTransaction,
          onSkip: _finish,
        );
      case _Step.liabilityType:
        return _LiabilityTypeStep(
          onSelect: _selectLiabilityType,
          onBack: () => setState(() => _step = _Step.kind),
        );
      case _Step.liabilityForm:
        return _LiabilityFormStep(
          type: _liabilityType!,
          nameController: _liabNameController,
          prixController: _liabPrixController,
          apportController: _liabApportController,
          tauxController: _liabTauxController,
          assuranceMensuelleController: _liabAssuranceMensuelleController,
          nbrEcheancesController: _liabNbrEcheancesController,
          dureeDiffereController: _liabDureeDiffereController,
          dateDebut: _liabDateDebut,
          loanType: _liabLoanType,
          typeDiffere: _liabTypeDiffere,
          onDateChanged: (d) => setState(() => _liabDateDebut = d),
          onLoanTypeChanged: (t) => setState(() => _liabLoanType = t),
          onTypeDiffereChanged: (t) => setState(() => _liabTypeDiffere = t),
          onBack: () => setState(() {
            _step = _Step.liabilityType;
            _liabilityType = null;
          }),
          onCreate: _commitCreateLiability,
        );
    }
  }
}

class _DialogHeader extends StatelessWidget {
  final String title;
  final String step;
  final VoidCallback? onBack;

  const _DialogHeader({required this.title, required this.step, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          IconButton.ghost(
            icon: const Icon(LucideIcons.chevronLeft, size: 18),
            onPressed: onBack,
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              shadcn.Text(step).muted().xSmall(),
              shadcn.Text(title).large().semiBold(),
            ],
          ),
        ),
        IconButton.ghost(
          icon: const Icon(LucideIcons.x, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _KindStep extends StatelessWidget {
  final VoidCallback onSelectActif;
  final VoidCallback onSelectPassif;

  const _KindStep({required this.onSelectActif, required this.onSelectPassif});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _DialogHeader(
          step: 'Étape 1',
          title: 'Que voulez-vous compléter ?',
        ),
        const SizedBox(height: 16),
        _OptionTile(
          leading: const Icon(LucideIcons.trendingUp, size: 18),
          label: 'Un actif',
          sublabel: 'Immobilier, bourse, épargne, crypto...',
          onTap: onSelectActif,
        ),
        const SizedBox(height: 8),
        _OptionTile(
          leading: const Icon(LucideIcons.trendingDown, size: 18),
          label: 'Un passif',
          sublabel: 'Prêt immobilier, crédit à la consommation...',
          onTap: onSelectPassif,
        ),
      ],
    );
  }
}

class _AssetClassStep extends StatelessWidget {
  final ValueChanged<AssetClass> onSelect;
  final VoidCallback onBack;

  const _AssetClassStep({required this.onSelect, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogHeader(
          step: 'Étape 2 sur 5',
          title: 'Quelle classe d\'actif ?',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        for (final assetClass in AssetClass.values) ...[
          _OptionTile(
            leading: Icon(
              emptyCategoryFor(assetClass.categoryId).icon,
              size: 18,
              color: emptyCategoryFor(assetClass.categoryId).color,
            ),
            label: assetClass.label,
            onTap: () => onSelect(assetClass),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AccountStep extends StatelessWidget {
  final AssetClass assetClass;
  final List<InvestmentAccount> accounts;
  final bool creating;
  final TextEditingController nameController;
  final AccountEnvelope envelope;
  final ValueChanged<AccountEnvelope> onEnvelopeChanged;
  final VoidCallback onBack;
  final ValueChanged<String> onSelectAccount;
  final VoidCallback onStartCreate;
  final VoidCallback onCancelCreate;
  final VoidCallback onCreate;

  const _AccountStep({
    required this.assetClass,
    required this.accounts,
    required this.creating,
    required this.nameController,
    required this.envelope,
    required this.onEnvelopeChanged,
    required this.onBack,
    required this.onSelectAccount,
    required this.onStartCreate,
    required this.onCancelCreate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogHeader(
          step: 'Étape 3 sur 5 · ${assetClass.label}',
          title: 'Quel compte ?',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        for (final account in accounts) ...[
          _OptionTile(
            leading: const Icon(LucideIcons.landmark, size: 18),
            label: account.name,
            sublabel: account.assetClass == assetClass
                ? account.envelope?.label
                // Compte "étranger" (ex : CTO Actions & Fonds proposé pour
                // un ETC métaux précieux) : on précise sa vraie classe
                // pour ne pas laisser croire qu'il en a changé.
                : '${account.assetClass.label}'
                      '${account.envelope != null ? ' · ${account.envelope!.label}' : ''}',
            onTap: () => onSelectAccount(account.id),
          ),
          const SizedBox(height: 8),
        ],
        if (creating)
          _InlineCreateForm(
            fields: [
              Select<AccountEnvelope>(
                value: envelope,
                // Assez large pour que chaque libellé ("Contrat de
                // Capitalisation"...) tienne sur une seule ligne dans le
                // popup, aligné par défaut sur la largeur de l'ancre.
                constraints: const BoxConstraints(minWidth: 220),
                onChanged: (v) {
                  if (v != null) onEnvelopeChanged(v);
                },
                itemBuilder: (context, value) => shadcn.Text(value.label),
                popup: (context) => SelectPopup(
                  items: SelectItemList(
                    children: [
                      for (final e in accountEnvelopesFor(assetClass))
                        SelectItemButton(value: e, child: shadcn.Text(e.label)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                placeholder: const shadcn.Text(
                  'Nom du compte (ex: PEA Boursorama)',
                ),
                autofocus: true,
              ),
            ],
            onCreate: onCreate,
            onCancel: onCancelCreate,
            createLabel: 'Créer le compte',
          )
        else
          _AddOptionButton(label: 'Nouveau compte', onTap: onStartCreate),
      ],
    );
  }
}

class _InvestmentStep extends StatelessWidget {
  final InvestmentAccount account;
  final AssetClass assetClass;
  final bool creating;
  final TextEditingController isinController;
  final TextEditingController labelController;
  final RealEstateType realEstateType;
  final ValueChanged<RealEstateType> onRealEstateTypeChanged;
  final VoidCallback onBack;
  final ValueChanged<String> onSelectInvestment;
  final VoidCallback onStartCreate;
  final VoidCallback onCancelCreate;
  final VoidCallback onCreate;

  const _InvestmentStep({
    required this.account,
    required this.assetClass,
    required this.creating,
    required this.isinController,
    required this.labelController,
    required this.realEstateType,
    required this.onRealEstateTypeChanged,
    required this.onBack,
    required this.onSelectInvestment,
    required this.onStartCreate,
    required this.onCancelCreate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogHeader(
          step: 'Étape 4 sur 5 · ${account.name}',
          title: 'Quel investissement ?',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        for (final investment in account.investments) ...[
          _OptionTile(
            leading: const Icon(LucideIcons.chartCandlestick, size: 18),
            label: investment.label,
            sublabel: assetClass == AssetClass.immobilier
                ? null
                : investment.isin,
            onTap: () => onSelectInvestment(investment.id),
          ),
          const SizedBox(height: 8),
        ],
        if (creating)
          _InlineCreateForm(
            fields: [
              if (assetClass == AssetClass.immobilier) ...[
                Select<RealEstateType>(
                  value: realEstateType,
                  onChanged: (type) {
                    if (type != null) onRealEstateTypeChanged(type);
                  },
                  itemBuilder: (context, type) => shadcn.Text(type.label),
                  popup: (context) => SelectPopup(
                    items: SelectItemList(
                      children: [
                        for (final type in RealEstateType.values)
                          SelectItemButton(
                            value: type,
                            child: shadcn.Text(type.label),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (assetClass != AssetClass.immobilier) ...[
                InvestmentIdentifierField(
                  assetClass: assetClass,
                  accountEnvelope: account.envelope,
                  isinController: isinController,
                  labelController: labelController,
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: labelController,
                placeholder: shadcn.Text(
                  assetClass == AssetClass.immobilier
                      ? 'Nom du bien (ex: Appartement Lyon 6e)'
                      : 'Libellé (ex: TotalEnergies)',
                ),
              ),
            ],
            onCreate: onCreate,
            onCancel: onCancelCreate,
            createLabel: 'Créer l\'investissement',
          )
        else
          _AddOptionButton(
            label: 'Nouvel investissement',
            onTap: onStartCreate,
          ),
      ],
    );
  }
}

class _TransactionStep extends StatelessWidget {
  final Investment investment;
  final bool isBuy;
  final DateTime? date;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final String quantityLabel;
  final String priceLabel;
  final bool showPriceField;
  final VoidCallback onBack;
  final ValueChanged<bool> onIsBuyChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final VoidCallback onCreate;
  final VoidCallback onSkip;

  const _TransactionStep({
    required this.investment,
    required this.isBuy,
    required this.date,
    required this.quantityController,
    required this.priceController,
    this.quantityLabel = 'Quantité',
    this.priceLabel = 'Prix unitaire (€)',
    this.showPriceField = true,
    required this.onBack,
    required this.onIsBuyChanged,
    required this.onDateChanged,
    required this.onCreate,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogHeader(
          step: 'Étape 5 sur 5 · ${investment.label}',
          title: 'Ajouter une transaction',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        Row(
          children: [
            PrimaryButton(
              onPressed: onCreate,
              child: const shadcn.Text('Ajouter la transaction'),
            ),
            const SizedBox(width: 8),
            OutlineButton(
              onPressed: onSkip,
              child: const shadcn.Text('Terminer sans transaction'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LiabilityTypeStep extends StatelessWidget {
  final ValueChanged<LiabilityType> onSelect;
  final VoidCallback onBack;

  const _LiabilityTypeStep({required this.onSelect, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogHeader(
          step: 'Étape 2 sur 3',
          title: 'Quel type de passif ?',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        for (final type in LiabilityType.values) ...[
          _OptionTile(
            leading: const Icon(LucideIcons.handCoins, size: 18),
            label: type.label,
            onTap: () => onSelect(type),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Étape finale du sous-flux passif : mêmes champs que le formulaire de
/// création "en place" de `RealPassifDetailScreen` (voir
/// `LiabilityFormFields`), sans le montant restant à rembourser ni le
/// tableau d'amortissement — toujours calculés depuis ces paramètres,
/// jamais saisis directement.
class _LiabilityFormStep extends StatelessWidget {
  final LiabilityType type;
  final TextEditingController nameController;
  final TextEditingController prixController;
  final TextEditingController apportController;
  final TextEditingController tauxController;
  final TextEditingController assuranceMensuelleController;
  final TextEditingController nbrEcheancesController;
  final TextEditingController dureeDiffereController;
  final DateTime? dateDebut;
  final LoanType loanType;
  final DeferType typeDiffere;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<LoanType> onLoanTypeChanged;
  final ValueChanged<DeferType> onTypeDiffereChanged;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  const _LiabilityFormStep({
    required this.type,
    required this.nameController,
    required this.prixController,
    required this.apportController,
    required this.tauxController,
    required this.assuranceMensuelleController,
    required this.nbrEcheancesController,
    required this.dureeDiffereController,
    required this.dateDebut,
    required this.loanType,
    required this.typeDiffere,
    required this.onDateChanged,
    required this.onLoanTypeChanged,
    required this.onTypeDiffereChanged,
    required this.onBack,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogHeader(
          step: 'Étape 3 sur 3 · ${type.label}',
          title: 'Nouveau passif',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        LiabilityFormFields(
          nameController: nameController,
          prixController: prixController,
          apportController: apportController,
          tauxController: tauxController,
          assuranceMensuelleController: assuranceMensuelleController,
          nbrEcheancesController: nbrEcheancesController,
          dureeDiffereController: dureeDiffereController,
          dateDebut: dateDebut,
          loanType: loanType,
          typeDiffere: typeDiffere,
          onDateChanged: onDateChanged,
          onLoanTypeChanged: onLoanTypeChanged,
          onTypeDiffereChanged: onTypeDiffereChanged,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          onPressed: onCreate,
          child: const shadcn.Text('Créer le passif'),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final Widget leading;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;

  const _OptionTile({
    required this.leading,
    required this.label,
    this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.muted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    shadcn.Text(label).medium(),
                    if (sublabel != null)
                      shadcn.Text(sublabel!).muted().xSmall(),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: theme.colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddOptionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddOptionButton({required this.label, required this.onTap});

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

class _InlineCreateForm extends StatelessWidget {
  final List<Widget> fields;
  final VoidCallback onCreate;
  final VoidCallback onCancel;
  final String createLabel;

  const _InlineCreateForm({
    required this.fields,
    required this.onCreate,
    required this.onCancel,
    required this.createLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...fields,
          const SizedBox(height: 10),
          Row(
            children: [
              PrimaryButton(
                onPressed: onCreate,
                child: shadcn.Text(createLabel),
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
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/toggle_button_style.dart';
import '../liabilities/liabilities_models.dart';
import '../liabilities/liabilities_repository.dart';
import '../liabilities/liability_form_fields.dart';
import '../simulations/loan_calculator.dart' show DeferType, LoanType;
import 'bank_logo_avatar.dart';
import 'bank_logo_repository.dart';
import 'confirm_delete_dialog.dart';
import 'currency_data.dart' show kKnownCurrencies;
import 'custom_other_categories_repository.dart';
import 'investment_identifier_field.dart';
import 'investments_models.dart';
import 'investments_repository.dart';
import 'real_patrimoine_adapter.dart' show emptyCategoryFor;
import 'transaction_price_currency.dart';

/// Valeur sentinelle du sélecteur de type "Autres" personnalisé
/// (`_AccountStep`) : aucun type précis choisi, l'enveloppe générique
/// "Autre" reste seule (`InvestmentAccount.customOtherCategory` reste
/// `null`) — distincte de `null` lui-même, qu'un `Select<String>` ne peut
/// pas porter comme valeur sélectionnée.
const _noCustomOtherCategoryValue = '__none__';

enum _Step {
  kind,
  assetClass,
  account,
  // Sous-flux des classes détenues chez un établissement financier
  // (épargne, actions & fonds, private equity) : l'établissement est
  // choisi avant le type de compte (l'enveloppe fiscale), lui-même avant
  // l'investissement et/ou la devise — voir `_selectAssetClass`.
  establishment,
  accountEnvelope,
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

  /// Type "Autres" personnalisé choisi pour le compte en cours de création
  /// à l'étape "Quel compte ?" (voir `_AccountStep`), quand [_envelope] vaut
  /// [AccountEnvelope.autre] — `null` sinon (type fixe, ou pas encore
  /// choisi). Voir `InvestmentAccount.customOtherCategory`.
  String? _customOtherCategory;

  bool _creatingAccount = false;
  final _accountNameController = TextEditingController();

  /// Établissement (banque) saisi à la création d'un compte — optionnel
  /// pour les classes sans établissement (voir [InvestmentAccount.bankName]),
  /// pré-rempli par l'établissement pour les classes à établissement via le
  /// sous-flux dédié.
  final _accountBankController = TextEditingController();

  /// Nom de l'établissement (banque, broker...) saisi à l'étape "Quel
  /// établissement ?" des classes à établissement : le compte (nom +
  /// enveloppe fiscale) n'est créé qu'à l'étape suivante, une fois
  /// l'enveloppe choisie — voir `_selectAccountEnvelope`. Il reste renseigné
  /// tant que le compte n'est pas validé, pour pouvoir revenir en arrière.
  String? _pendingEstablishmentName;

  /// Description facultative du compte (ex : "Épargne vacances", "Mon PEA
  /// long terme"), saisie à l'étape "Quel compte ?" — affichée en seconde
  /// ligne sous le type du compte dans les accordéons (voir
  /// `real_patrimoine_adapter.dart`).
  final _accountDescriptionController = TextEditingController();

  /// Date d'ouverture du compte (voir [InvestmentAccount.openingDate]),
  /// saisie à l'étape "Quel compte ?" des classes à établissement puis
  /// appliquée au compte créé (ou réutilisé s'il n'en a pas) dans
  /// `_selectAccountEnvelope` — `null` si l'utilisateur n'en renseigne pas.
  DateTime? _accountOpeningDate;

  /// Logos des établissements déjà importés (nom d'établissement → chemin
  /// absolu), pour l'avatar cliquable de l'étape "Quel établissement ?".
  Map<String, String> _bankLogos = {};

  /// Types "Autres" personnalisés déjà créés par l'utilisateur (voir
  /// `CustomOtherCategoriesRepository`), proposés en plus des enveloppes
  /// fixes (Art, Voiture...) à l'étape "Quel compte ?" pour
  /// `AssetClass.autres`.
  List<String> _customOtherCategories = [];

  bool _creatingInvestment = false;

  /// À la création d'un investissement dans un compte-titres (Actions &
  /// Fonds), l'utilisateur choisit de créer une position en *devise* (USD,
  /// GBP...) plutôt qu'un titre (ISIN) — voir `_InvestmentStep`.
  bool _creatingDevise = false;
  RealEstateType _realEstateType = RealEstateType.residencePrincipale;
  FundStyle? _fundStyle;
  final _isinController = TextEditingController();
  final _labelController = TextEditingController();

  bool _newIsBuy = true;
  DateTime? _txnDate;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  /// Devise et taux de change de la transaction en cours de saisie (voir
  /// `transaction_price_currency.dart`) — à l'euro par défaut, résolus puis
  /// convertis au moment du commit (`_commitCreateTransaction`).
  late final TransactionPriceCurrencyController _priceCurrencyController;

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
    _txnDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _liabDateDebut = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _priceCurrencyController = TransactionPriceCurrencyController(
      vaultPath: widget.vaultPath,
    );
    final initialAssetClass = widget.initialAssetClass;
    final initialLiabilityType = widget.initialLiabilityType;
    if (initialAssetClass != null) {
      _assetClass = initialAssetClass;
      _envelope = accountEnvelopesFor(initialAssetClass).first;
      // Classes à établissement : le flux démarre par l'établissement, pas
      // par le compte — voir `_selectAssetClass`.
      _step = assetClassRequiresEstablishmentStep(initialAssetClass)
          ? _Step.establishment
          : _Step.account;
    } else if (initialLiabilityType != null) {
      _liabilityType = initialLiabilityType;
      _step = _Step.liabilityForm;
    }
    _load();
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountBankController.dispose();
    _accountDescriptionController.dispose();
    _isinController.dispose();
    _labelController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _priceCurrencyController.dispose();
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
    await _loadBankLogos();
    await _loadCustomOtherCategories();
  }

  Future<void> _loadCustomOtherCategories() async {
    final categories = await CustomOtherCategoriesRepository(
      widget.vaultPath,
    ).load();
    if (!mounted) return;
    setState(() => _customOtherCategories = categories);
  }

  /// Lit les logos déjà importés des établissements (voir
  /// `BankLogoRepository`) pour les afficher sur l'étape "Quel
  /// établissement ?" — ceux des classes à établissement, toutes classes
  /// confondues (une même banque/broker peut abriter des comptes d'épargne
  /// ET des comptes-titres).
  Future<void> _loadBankLogos() async {
    final repo = BankLogoRepository(widget.vaultPath);
    final establishments = {
      for (final a in _accounts)
        if (assetClassRequiresEstablishmentStep(a.assetClass))
          a.bankName ?? a.name,
    };
    final logos = <String, String>{};
    for (final establishment in establishments) {
      final path = await repo.logoPathFor(establishment);
      if (path != null) logos[establishment] = path;
    }
    if (!mounted) return;
    setState(() => _bankLogos = logos);
  }

  /// L'avatar d'une banque est cliquable : l'utilisateur importe (ou
  /// remplace) le logo depuis son disque — au premier passage sur une
  /// banque, ou a posteriori.
  Future<void> _importBankLogo(String bankName) async {
    final result = await FilePicker.pickFiles(withData: true);
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final path = await BankLogoRepository(
      widget.vaultPath,
    ).importLogo(bankName, bytes, sourceName: file.name);
    if (path == null || !mounted) return;
    setState(() => _bankLogos = {..._bankLogos, bankName: path});
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

  /// L'investissement courant est-il tenu en devise (épargne, ou devise
  /// créée dans un compte-titres via l'étape "Investissement et/ou
  /// devises") ? — mêmes règles que `isCurrencyInvestment` à l'affichage.
  bool get _investmentIsCurrency {
    final investment = _investment;
    final account = _account;
    if (investment == null || account == null) return false;
    return isCurrencyInvestment(account, investment);
  }

  /// Même logique que `InvestmentDetailView`'s `_isEurCurrency` : une
  /// épargne — ou une devise — tenue en euros n'a pas de taux de change à
  /// saisir pour sa première transaction non plus.
  bool get _isEurCurrency {
    final investment = _investment;
    if (investment == null || !_investmentIsCurrency) return false;
    return investment.isin.trim().toUpperCase() == 'EUR';
  }

  String get _quantityFieldLabel {
    final investment = _investment;
    final account = _account;
    if (investment == null || account == null) return 'Quantité';
    final effectiveClass = investment.assetClass ?? account.assetClass;
    if (effectiveClass == AssetClass.immobilier) return 'Montant total (€)';
    if (_investmentIsCurrency) {
      return _isEurCurrency ? 'Montant (€)' : 'Montant (${investment.isin})';
    }
    return 'Quantité';
  }

  String get _priceFieldLabel {
    final investment = _investment;
    final account = _account;
    if (investment == null || account == null) return 'Prix unitaire';
    if (_investmentIsCurrency) return 'Cours de la paire de devise';
    return 'Prix unitaire';
  }

  /// Le sélecteur de devise s'affiche sur le champ prix dès qu'il est
  /// pertinent : hors immobilier (pas de prix unitaire), et hors position
  /// en devise — dont le "prix" est déjà le taux de change en euros (voir
  /// `_investmentIsCurrency`).
  bool get _showCurrencySelector =>
      !_isEurCurrency &&
      _assetClass != AssetClass.immobilier &&
      !_investmentIsCurrency;

  void _selectAssetClass(AssetClass assetClass) {
    if (assetClass == AssetClass.immobilier) {
      _selectImmobilierAccount();
      return;
    }
    setState(() {
      _assetClass = assetClass;
      _envelope = accountEnvelopesFor(assetClass).first;
      _pendingEstablishmentName = null;
      // Les classes détenues chez un établissement suivent un sous-flux
      // dédié : quel établissement → quel compte (enveloppe) → quel
      // investissement et/ou quelle devise → quelle transaction — plutôt
      // que le compte puis l'investissement des autres classes.
      _step = assetClassRequiresEstablishmentStep(assetClass)
          ? _Step.establishment
          : _Step.account;
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
      // L'établissement reste vide pour les classes sans banque (cryptos,
      // immobilier...), il est pré-rempli pour l'épargne — voir
      // `_selectAccountEnvelope`.
      bankName: _accountBankController.text.trim().isEmpty
          ? null
          : _accountBankController.text.trim(),
      investments: const [],
      customOtherCategory: assetClass == AssetClass.autres
          ? _customOtherCategory
          : null,
    );
    await _repo.saveAccount(account);
    _accountNameController.clear();
    _accountBankController.clear();
    setState(() {
      _accounts = [..._accounts, account];
      _accountId = account.id;
      _creatingAccount = false;
      _customOtherCategory = null;
      _step = _Step.investment;
    });
  }

  void _selectAccount(String id) {
    setState(() {
      _accountId = id;
      _step = _Step.investment;
    });
  }

  /// "Quel établissement ?" des classes à établissement : un établissement
  /// existant est choisi, on enchaîne sur "Quel compte ?" (l'enveloppe
  /// fiscale) comme pour un nouvel établissement — un même établissement
  /// peut abriter plusieurs comptes (PEA + CTO chez le même broker, Livret A
  /// + LDDS à la même banque...), et le compte existant portant l'enveloppe
  /// retenue est alors réutilisé (voir `_selectAccountEnvelope`). La suite
  /// du flux est identique aux autres classes : investissement et/ou devise,
  /// puis transactions.
  void _selectEstablishment(String establishmentName) {
    setState(() {
      _pendingEstablishmentName = establishmentName;
      _step = _Step.accountEnvelope;
    });
  }

  /// "Quel établissement ?", création : seul le nom de l'établissement est
  /// saisi ici. Le compte (nom + enveloppe fiscale) n'est pas encore créé —
  /// l'enveloppe se choisit à l'étape suivante "Quel compte ?"
  /// (contrairement aux classes sans établissement, où nom et enveloppe sont
  /// saisis d'un bloc à l'étape compte).
  void _commitCreateEstablishment() {
    final name = _accountNameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _pendingEstablishmentName = name;
      _creatingAccount = false;
      _step = _Step.accountEnvelope;
    });
  }

  /// Suppression d'un compte sans transaction, demandée depuis le picker de
  /// l'étape "Quel établissement ?" (voir `_EstablishmentStep`) — un
  /// historique de transactions ne se perd jamais : le compte doit être
  /// entièrement vide, même garde-fou que le détail du compte. Les logos
  /// sont rechargés ensuite : un établissement vidé de ses comptes
  /// disparaît de la liste.
  Future<void> _deleteEmptyAccount(InvestmentAccount account) async {
    if (account.investments.any((i) => i.transactions.isNotEmpty)) return;
    await _repo.deleteAccount(account.id);
    if (!mounted) return;
    setState(() {
      _accounts = [
        for (final a in _accounts)
          if (a.id != account.id) a,
      ];
      // Le compte supprimé était peut-être le compte courant du flux : un
      // retour en arrière depuis l'étape investissement ne doit pas le
      // faire pointer vers un compte fantôme.
      if (_accountId == account.id) _accountId = null;
    });
    await _loadBankLogos();
  }

  /// "Quel compte ?" des classes à établissement : choisir l'enveloppe (PEA,
  /// CTO, Livret A...) pour l'établissement retenu à l'étape précédente. Le
  /// compte existant portant cet établissement et cette enveloppe est
  /// réutilisé s'il existe et que l'enveloppe est unique par établissement
  /// (`accountEnvelopeIsUniquePerEstablishment`), sinon il est créé —
  /// établissement et enveloppe définissent ensemble un compte, et un même
  /// établissement peut abriter plusieurs comptes (plusieurs CTO, plusieurs
  /// contrats d'assurance vie...). Ceux-ci restent sélectionnables
  /// directement sur l'étape (voir `_AccountEnvelopeStep`'s existingAccounts)
  /// pour y ajouter un investissement sans en créer un nouveau.
  Future<void> _selectAccountEnvelope(
    AccountEnvelope envelope, {
    String? customCategory,
  }) async {
    final name = _pendingEstablishmentName;
    final assetClass = _assetClass;
    if (name == null || assetClass == null) return;
    // Description facultative saisie sur l'étape. Elle s'applique au compte
    // créé comme au compte existant réutilisé (on peut ainsi la renseigner
    // dès la création, sans passer par la modification) ; un champ vide
    // laisse le compte existant inchangé.
    final description = _accountDescriptionController.text.trim();
    final openingDate = _accountOpeningDate;
    InvestmentAccount? matching;
    // Même clé d'établissement que la liste de l'étape précédente
    // (`bankName ?? name`, voir `_EstablishmentStep`) : pour un compte sans
    // établissement renseigné (créé avant l'introduction du champ), c'est
    // son nom qui tient lieu d'établissement — pas son libellé d'enveloppe.
    for (final account in _accounts) {
      if (account.assetClass == assetClass &&
          account.envelope == envelope &&
          // Un type "Autres" personnalisé distingue deux comptes portant
          // par ailleurs la même enveloppe générique `autre` (ex :
          // "Vins de collection" vs "Voiture" saisie en texte libre) — sans
          // ce test, choisir un type personnalisé pourrait réutiliser à
          // tort un compte créé sous un autre type personnalisé.
          account.customOtherCategory == customCategory &&
          (account.bankName ?? account.name) == name &&
          accountEnvelopeIsUniquePerEstablishment(assetClass, envelope)) {
        matching = account;
        break;
      }
    }
    InvestmentAccount account;
    if (matching != null) {
      // La description saisie s'applique au compte existant réutilisé
      // (voir commentaire en tête de méthode) ; la date d'ouverture
      // seulement si le compte n'en a pas déjà une — on ne surcharge pas
      // une date existante par mégarde.
      var updated =
          description.isNotEmpty && matching.description != description
          ? matching.copyWith(description: description)
          : matching;
      if (openingDate != null && updated.openingDate == null) {
        updated = updated.copyWith(openingDate: openingDate);
      }
      account = updated;
      if (!identical(account, matching)) await _repo.saveAccount(account);
    } else {
      account = InvestmentAccount(
        assetClass: assetClass,
        envelope: envelope,
        // L'épargne est identifiée par son établissement (le nom du compte
        // suit la banque) ; les autres classes à établissement par leur
        // type — le libellé de l'enveloppe (PEA, CTO...), les comptes du
        // même établissement se distinguant alors par leur description
        // facultative (voir `_buildAccountLeaf` dans
        // `real_patrimoine_adapter.dart`).
        name: assetClass == AssetClass.epargne
            ? name
            : (customCategory ?? envelope.label),
        // L'établissement retenu à l'étape précédente est porté par le compte.
        bankName: name,
        description: description.isEmpty ? null : description,
        openingDate: openingDate,
        investments: const [],
        customOtherCategory: customCategory,
      );
      await _repo.saveAccount(account);
    }
    if (!mounted) return;
    setState(() {
      _accountId = account.id;
      _envelope = envelope;
      _accountBankController.text = name;
      if (matching == null) {
        _accounts = [..._accounts, account];
      } else {
        _accounts = [
          for (final a in _accounts) a.id == account.id ? account : a,
        ];
      }
      // La description ne doit pas resservir pour un autre compte créé au
      // cours de la même session.
      _accountDescriptionController.clear();
      // De même pour la date d'ouverture.
      _accountOpeningDate = null;
      // `_pendingEstablishmentName` est conservé : il sert au libellé de
      // l'étape "Quel compte ?" si l'utilisateur revient en arrière depuis
      // l'étape investissement.
      _step = _Step.investment;
    });
  }

  /// Ouvre une petite popup pour saisir un nouveau type "Autres"
  /// personnalisé (voir `CustomOtherCategoriesRepository`) : une fois
  /// validé, il est mémorisé pour être reproposé ensuite. Retourne le nom
  /// créé, ou `null` si annulé — à l'appelant de décider ce qu'il en fait
  /// (sélection immédiate pour le compte en cours de création).
  Future<String?> _createCustomOtherCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
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
                  const shadcn.Text('Nouveau type').large().semiBold(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    placeholder: const shadcn.Text(
                      'Ex : Vins de collection',
                    ),
                    autofocus: true,
                    onSubmitted: (value) =>
                        Navigator.of(context).pop(value.trim()),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      PrimaryButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(controller.text.trim()),
                        child: const shadcn.Text('Créer'),
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
    if (name == null || name.isEmpty) return null;
    final categories = await CustomOtherCategoriesRepository(
      widget.vaultPath,
    ).addCategory(name);
    if (!mounted) return null;
    setState(() => _customOtherCategories = categories);
    return name;
  }

  Future<void> _commitCreateInvestment() async {
    final account = _account;
    final assetClass = _assetClass;
    final rawIsin = _isinController.text.trim();
    // Une devise (USD, GBP...) est sélectionnée dans une liste de codes déjà
    // en majuscules : pas de transformation — la même passe que pour les
    // classes à options (crypto, épargne, métaux).
    final isin =
        _creatingDevise ||
            (assetClass != null &&
                identifierOptionsFor(
                      assetClass,
                      accountEnvelope: account?.envelope,
                    ) !=
                    null)
        ? rawIsin
        : rawIsin.toUpperCase();
    final label = _labelController.text.trim();
    // Comme l'immobilier, "Autres" n'a pas de vrai identifiant financier à
    // exiger : une référence (numéro de série...) reste facultative, voir
    // `InvestmentIdentifierField`. Un identifiant est généré si laissé vide.
    final identifierRequired =
        assetClass != AssetClass.immobilier && assetClass != AssetClass.autres;
    if (account == null || label.isEmpty || (identifierRequired && isin.isEmpty)) {
      return;
    }
    // Le compte peut être "étranger" à la classe choisie à l'étape 1 (ex :
    // un ETC or créé dans un CTO "Actions & Fonds" via
    // accountAcceptsCrossClassInvestment) : l'investissement porte alors
    // sa propre classe plutôt que d'hériter de celle du compte.
    final investment = Investment(
      isin: assetClass == AssetClass.immobilier
          ? 'immobilier-${generateInvestmentId('bien')}'
          : assetClass == AssetClass.autres && isin.isEmpty
          ? 'autre-${generateInvestmentId('bien')}'
          : isin,
      label: label,
      transactions: const [],
      assetClass: account.assetClass == _assetClass ? null : _assetClass,
      realEstateType: assetClass == AssetClass.immobilier
          ? _realEstateType
          : null,
      fundStyle: assetClass == AssetClass.actionsEtFonds && !_creatingDevise
          ? _fundStyle
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
      _creatingDevise = false;
      _fundStyle = null;
      _step = _Step.transaction;
    });
    // Nouvelle transaction : devise et taux remis à l'euro.
    _priceCurrencyController.reset();
  }

  void _selectInvestment(String id) {
    setState(() {
      _investmentId = id;
      _step = _Step.transaction;
    });
    // Nouvelle transaction : devise et taux remis à l'euro.
    _priceCurrencyController.reset();
  }

  Future<void> _commitCreateTransaction() async {
    final account = _account;
    final investment = _investment;
    final date = _txnDate;
    final isImmobilier = _assetClass == AssetClass.immobilier;
    final quantity = isImmobilier
        ? 1.0
        : parseDecimal(_quantityController.text);
    final price = isImmobilier
        ? parseDecimal(_quantityController.text)
        : _isEurCurrency
        ? 1.0
        : parseDecimal(_priceController.text);
    // La devise d'une position tenue en devise est toujours l'euro : son
    // "cours" saisi est déjà le taux de change de la paire. Sinon, c'est la
    // devise choisie sur le sélecteur du formulaire (voir
    // `_priceCurrencyController`).
    final currency = _investmentIsCurrency
        ? 'EUR'
        : _priceCurrencyController.currency;
    final fxRateToEur = currency == 'EUR'
        ? 1.0
        : _priceCurrencyController.resolvedRate;
    // Devise étrangère sans taux de change (auto et manuel indisponibles) :
    // impossible de convertir en euros, on ne sauvegarde pas.
    if (account == null ||
        investment == null ||
        date == null ||
        quantity == null ||
        quantity <= 0 ||
        price == null ||
        price <= 0 ||
        fxRateToEur == null ||
        fxRateToEur <= 0) {
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
          currency: currency,
          fxRateToEur: fxRateToEur,
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
    final prix = parseDecimal(_liabPrixController.text);
    final apport = parseDecimal(_liabApportController.text) ?? 0;
    final taux = parseDecimal(_liabTauxController.text);
    final assuranceMensuelle = parseDecimal(
      _liabAssuranceMensuelleController.text,
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

  bool get _isEpargneFlow => _assetClass == AssetClass.epargne;

  /// Sous-flux des classes détenues chez un établissement financier
  /// (épargne, actions & fonds, private equity) : l'établissement et
  /// le compte (l'enveloppe) s'y choisissent en deux étapes avant
  /// l'investissement.
  bool get _isEstablishmentFlow =>
      _assetClass != null && assetClassRequiresEstablishmentStep(_assetClass!);

  /// Nombre d'étapes du flux actif courant : 6 pour les classes à
  /// établissement (l'établissement et le compte s'y choisissent en deux
  /// étapes avant l'investissement), 5 sinon.
  int get _totalSteps => _isEstablishmentFlow ? 6 : 5;

  Widget _buildStep() {
    switch (_step) {
      case _Step.kind:
        return _KindStep(
          onSelectActif: () => setState(() => _step = _Step.assetClass),
          onSelectPassif: () => setState(() => _step = _Step.liabilityType),
        );
      case _Step.assetClass:
        return _AssetClassStep(
          stepLabel: 'Étape 2 sur $_totalSteps',
          onSelect: _selectAssetClass,
          onBack: () => setState(() => _step = _Step.kind),
        );
      case _Step.establishment:
        // Un même établissement peut abriter plusieurs comptes (PEA + CTO
        // chez le même broker, Livret A + LDDS à la même banque...) : on
        // regroupe par établissement — toutes classes à établissement
        // confondues — pour ne proposer chacun qu'une seule fois ; le choix
        // du compte (l'enveloppe) se fait à l'étape suivante.
        final establishments = <String, List<InvestmentAccount>>{};
        for (final account in _accounts) {
          if (!assetClassRequiresEstablishmentStep(account.assetClass)) {
            continue;
          }
          final key = account.bankName ?? account.name;
          establishments.putIfAbsent(key, () => []).add(account);
        }
        return _EstablishmentStep(
          stepLabel: 'Étape 3 sur $_totalSteps · ${_assetClass!.label}',
          establishments: establishments,
          creating: _creatingAccount,
          nameController: _accountNameController,
          onBack: () => setState(() {
            _step = _Step.assetClass;
            _assetClass = null;
            _envelope = null;
            _pendingEstablishmentName = null;
          }),
          onSelectEstablishment: _selectEstablishment,
          onStartCreate: () => setState(() => _creatingAccount = true),
          onCancelCreate: () => setState(() => _creatingAccount = false),
          onCreate: _commitCreateEstablishment,
          bankLogos: _bankLogos,
          onImportLogo: _importBankLogo,
          onDeleteAccount: _deleteEmptyAccount,
        );
      case _Step.accountEnvelope:
        final establishment = _pendingEstablishmentName!;
        // Les comptes existants de l'établissement pour cette classe sont
        // proposés avant les tuiles d'enveloppe, pour y ajouter un
        // investissement sans en créer un nouveau (surtout utile quand
        // l'enveloppe est ouvrable plusieurs fois — plusieurs CTO chez le
        // même broker). L'épargne garde son écran historique : seule les
        // tuiles, la réutilisation passant par la logique d'enveloppe
        // unique (`accountEnvelopeIsUniquePerEstablishment`).
        final existingAccounts = _assetClass == AssetClass.epargne
            ? const <InvestmentAccount>[]
            : [
                for (final account in _accounts)
                  if (account.assetClass == _assetClass &&
                      (account.bankName ?? account.name) == establishment)
                    account,
              ];
        return _AccountEnvelopeStep(
          stepLabel: 'Étape 4 sur $_totalSteps · $establishment',
          establishmentName: establishment,
          assetClass: _assetClass!,
          existingAccounts: existingAccounts,
          descriptionController: _accountDescriptionController,
          openingDate: _accountOpeningDate,
          onOpeningDateChanged: (date) =>
              setState(() => _accountOpeningDate = date),
          onBack: () => setState(() {
            _step = _Step.establishment;
            _pendingEstablishmentName = null;
          }),
          onSelect: _selectAccountEnvelope,
          onSelectExisting: _selectAccount,
          customOtherCategories: _customOtherCategories,
          onSelectCustomOtherCategory: (category) => _selectAccountEnvelope(
            AccountEnvelope.autre,
            customCategory: category,
          ),
          onAddCustomOtherCategory: () async {
            final name = await _createCustomOtherCategory();
            if (name == null) return;
            await _selectAccountEnvelope(
              AccountEnvelope.autre,
              customCategory: name,
            );
          },
        );
      case _Step.account:
        return _AccountStep(
          stepLabel: 'Étape 3 sur $_totalSteps · ${_assetClass!.label}',
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
          bankController: _accountBankController,
          envelope: _envelope!,
          onEnvelopeChanged: (e) => setState(() {
            _envelope = e;
            // Un type personnalisé n'a de sens que pour l'enveloppe
            // générique "Autre" — en changer l'oublie.
            if (e != AccountEnvelope.autre) _customOtherCategory = null;
          }),
          onBack: () => setState(() {
            _step = _Step.assetClass;
            _assetClass = null;
            _envelope = null;
            _customOtherCategory = null;
          }),
          onSelectAccount: _selectAccount,
          onStartCreate: () => setState(() => _creatingAccount = true),
          onCancelCreate: () => setState(() {
            _creatingAccount = false;
            _customOtherCategory = null;
          }),
          onCreate: _commitCreateAccount,
          customOtherCategories: _customOtherCategories,
          customOtherCategory: _customOtherCategory,
          onCustomOtherCategoryChanged: (category) =>
              setState(() => _customOtherCategory = category),
          onAddCustomOtherCategory: () async {
            final name = await _createCustomOtherCategory();
            if (name != null) setState(() => _customOtherCategory = name);
          },
        );
      case _Step.investment:
        // Pour l'épargne, cette étape choisit la devise dans laquelle
        // l'investissement est tenu (voir `identifierOptionsFor`), pas un
        // titre — le libellé de l'étape le dit explicitement. Pour un
        // compte-titres (Actions & Fonds), elle permet de créer un
        // investissement (ISIN) OU une devise (EUR, USD...) — voir
        // `_InvestmentStep`'s bascule Investissement / Devise.
        final account = _account!;
        final assetClass = _assetClass!;
        final allowsDevises = assetClass == AssetClass.actionsEtFonds;
        return _InvestmentStep(
          stepLabel:
              'Étape ${_isEstablishmentFlow ? 5 : 4} sur $_totalSteps · '
              '${account.name}',
          title: _isEpargneFlow
              ? 'Quelle devise ?'
              : allowsDevises
              ? 'Quel investissement ou devise ?'
              // "Autres" (montres, voitures de collection, art...) n'a pas
              // de notion d'investissement financier : "pièce" désigne
              // l'objet précis à l'intérieur du bien/de la collection
              // nommée à l'étape précédente.
              : assetClass == AssetClass.autres
              ? 'Quelle pièce ?'
              : 'Quel investissement ?',
          addLabel: _isEpargneFlow
              ? 'Nouvelle devise'
              : allowsDevises
              ? 'Nouvel investissement ou devise'
              : assetClass == AssetClass.autres
              ? 'Nouvelle pièce'
              : 'Nouvel investissement',
          createLabel: _creatingDevise
              ? 'Créer la devise'
              : assetClass == AssetClass.autres
              ? 'Ajouter la pièce'
              : 'Créer l\'investissement',
          allowsDevises: allowsDevises,
          creatingDevise: _creatingDevise,
          onDeviseModeChanged: (v) => setState(() => _creatingDevise = v),
          account: account,
          assetClass: assetClass,
          creating: _creatingInvestment,
          isinController: _isinController,
          labelController: _labelController,
          realEstateType: _realEstateType,
          onRealEstateTypeChanged: (type) =>
              setState(() => _realEstateType = type),
          fundStyle: _fundStyle,
          onFundStyleChanged: (style) => setState(() => _fundStyle = style),
          onBack: () => setState(() {
            _step = _assetClass == AssetClass.immobilier
                ? _Step.assetClass
                : _isEstablishmentFlow
                ? _Step.accountEnvelope
                : _Step.account;
            _accountId = null;
            _creatingDevise = false;
          }),
          onSelectInvestment: _selectInvestment,
          onStartCreate: () => setState(() {
            _creatingInvestment = true;
            _creatingDevise = false;
          }),
          onCancelCreate: () => setState(() => _creatingInvestment = false),
          onCreate: _commitCreateInvestment,
        );
      case _Step.transaction:
        return _TransactionStep(
          stepLabel:
              'Étape $_totalSteps sur $_totalSteps · ${_investment!.label}',
          investment: _investment!,
          isBuy: _newIsBuy,
          date: _txnDate,
          quantityController: _quantityController,
          priceController: _priceController,
          quantityLabel: _quantityFieldLabel,
          priceLabel: _priceFieldLabel,
          showPriceField:
              !_isEurCurrency && _assetClass != AssetClass.immobilier,
          showCurrencySelector: _showCurrencySelector,
          priceCurrencyController: _priceCurrencyController,
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
  final String stepLabel;
  final ValueChanged<AssetClass> onSelect;
  final VoidCallback onBack;

  const _AssetClassStep({
    required this.stepLabel,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogHeader(
          step: stepLabel,
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
  final String stepLabel;
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

  /// Pré-rempli par la banque pour l'épargne (voir
  /// `_selectAccountEnvelope`), le champ "Banque" est sinon proposé à la
  /// création pour toute classe détenue chez un établissement (compte-
  /// titres, assurance-vie...) — voir `assetClassSupportsBankName`. Il
  /// reste masqué pour l'immobilier, la crypto, les métaux physiques et
  /// "Autres" (pas de notion d'établissement financier).
  final TextEditingController bankController;

  /// Types "Autres" personnalisés déjà mémorisés (voir
  /// `CustomOtherCategoriesRepository`), proposés en plus de l'enveloppe
  /// générique "Autre" uniquement quand [assetClass] est
  /// `AssetClass.autres` et [envelope] vaut [AccountEnvelope.autre].
  final List<String> customOtherCategories;
  final String? customOtherCategory;
  final ValueChanged<String?> onCustomOtherCategoryChanged;
  final VoidCallback onAddCustomOtherCategory;

  const _AccountStep({
    required this.stepLabel,
    required this.assetClass,
    required this.accounts,
    required this.creating,
    required this.nameController,
    required this.bankController,
    required this.envelope,
    required this.onEnvelopeChanged,
    required this.onBack,
    required this.onSelectAccount,
    required this.onStartCreate,
    required this.onCancelCreate,
    required this.onCreate,
    this.customOtherCategories = const [],
    this.customOtherCategory,
    required this.onCustomOtherCategoryChanged,
    required this.onAddCustomOtherCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogHeader(
          step: stepLabel,
          // "Autres" (montres, voitures de collection, art...) n'a pas de
          // notion de compte financier : "bien" couvre aussi bien un objet
          // précis qu'une collection (plusieurs pièces regroupées, voir
          // `customOtherCategory`).
          title: assetClass == AssetClass.autres ? 'Quel bien ?' : 'Quel compte ?',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        for (final account in accounts) ...[
          _OptionTile(
            leading: Icon(
              assetClass == AssetClass.autres
                  ? LucideIcons.gem
                  : LucideIcons.landmark,
              size: 18,
            ),
            label: account.name,
            sublabel: account.assetClass == assetClass
                ? account.customOtherCategory ?? account.envelope?.label
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
              // Type "Autres" personnalisé (ex : "Vins de collection"),
              // uniquement pertinent quand l'enveloppe générique "Autre" est
              // choisie — les enveloppes fixes (Art, Voiture, Montre...)
              // portent déjà leur propre catégorie.
              if (assetClass == AssetClass.autres &&
                  envelope == AccountEnvelope.autre) ...[
                const SizedBox(height: 8),
                Select<String>(
                  value: customOtherCategory ?? _noCustomOtherCategoryValue,
                  constraints: const BoxConstraints(minWidth: 220),
                  onChanged: (v) => onCustomOtherCategoryChanged(
                    v == null || v == _noCustomOtherCategoryValue ? null : v,
                  ),
                  itemBuilder: (context, value) => shadcn.Text(
                    value == _noCustomOtherCategoryValue
                        ? 'Aucun type précis'
                        : value,
                  ),
                  popup: (context) => SelectPopup(
                    items: SelectItemList(
                      children: [
                        const SelectItemButton(
                          value: _noCustomOtherCategoryValue,
                          child: shadcn.Text('Aucun type précis'),
                        ),
                        for (final category in customOtherCategories)
                          SelectItemButton(
                            value: category,
                            child: shadcn.Text(category),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _AddOptionButton(
                  label: 'Nouveau type',
                  onTap: onAddCustomOtherCategory,
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                placeholder: shadcn.Text(
                  assetClass == AssetClass.autres
                      ? 'Nom (ex : Montres de collection)'
                      : 'Nom du compte (ex: PEA Boursorama)',
                ),
                autofocus: true,
              ),
              // Le champ "Banque" s'affiche pour toute classe détenue chez
              // un établissement (l'épargne pré-remplit sa banque depuis
              // son sous-flux) et reste masqué là où il n'a pas de sens.
              if (assetClassSupportsBankName(
                assetClass,
                envelope: envelope,
              )) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: bankController,
                  placeholder: const shadcn.Text('Banque (ex: Boursorama)'),
                ),
              ],
            ],
            onCreate: onCreate,
            onCancel: onCancelCreate,
            createLabel: assetClass == AssetClass.autres
                ? 'Créer'
                : 'Créer le compte',
          )
        else
          _AddOptionButton(
            label: assetClass == AssetClass.autres
                ? 'Nouveau bien'
                : 'Nouveau compte',
            onTap: onStartCreate,
          ),
      ],
    );
  }
}

/// Première étape du sous-flux des classes à établissement (épargne,
/// actions & fonds, private equity) : quel établissement financier
/// détient le compte ? On choisit un établissement existant (banque, broker,
/// assureur, plateforme... — regroupé par nom, une ligne par établissement
/// même s'il abrite déjà plusieurs comptes, éventuellement de classes
/// différentes) ou on en saisit un nouveau — seul le nom, le type de compte
/// (l'enveloppe) se choisit à l'étape suivante. L'avatar de chaque
/// établissement (logo importé ou initiales) est cliquable pour
/// importer/remplacer son logo.
class _EstablishmentStep extends StatelessWidget {
  final String stepLabel;

  /// Établissements existants, regroupés par nom d'établissement (nom →
  /// ses comptes, enveloppes éventuellement différentes, toutes classes à
  /// établissement confondues).
  final Map<String, List<InvestmentAccount>> establishments;
  final bool creating;
  final TextEditingController nameController;
  final VoidCallback onBack;

  /// Appelé avec le nom de l'établissement choisi — l'enveloppe (le compte)
  /// se choisit à l'étape suivante.
  final ValueChanged<String> onSelectEstablishment;
  final VoidCallback onStartCreate;
  final VoidCallback onCancelCreate;
  final VoidCallback onCreate;

  /// Logos déjà importés, indexés par nom d'établissement (voir
  /// `BankLogoRepository`).
  final Map<String, String> bankLogos;
  final ValueChanged<String> onImportLogo;

  /// Appelé après confirmation pour supprimer un compte sans transaction
  /// (voir le picker `_showDeleteAccountsDialog`). Le compte reste listé
  /// tant qu'il porte une transaction — même garde-fou que la suppression
  /// depuis le détail du compte (`account_detail_screen.dart`).
  final Future<void> Function(InvestmentAccount account)? onDeleteAccount;

  const _EstablishmentStep({
    required this.stepLabel,
    required this.establishments,
    required this.creating,
    required this.nameController,
    required this.onBack,
    required this.onSelectEstablishment,
    required this.onStartCreate,
    required this.onCancelCreate,
    required this.onCreate,
    required this.bankLogos,
    required this.onImportLogo,
    this.onDeleteAccount,
  });

  /// Un compte est supprimable quand aucune de ses transactions n'existe
  /// (un historique ne se perd jamais silencieusement) — même règle que
  /// partout ailleurs (détail du compte, accordéon des catégories).
  static bool _isDeletable(InvestmentAccount account) =>
      account.investments.every((i) => i.transactions.isEmpty);

  /// La corbeille d'un établissement n'apparaît que s'il abrite au moins un
  /// compte sans transaction — supprimer n'aurait sinon rien à proposer.
  bool _hasDeletableAccounts(List<InvestmentAccount> accounts) =>
      accounts.any(_isDeletable);

  /// Ouvre un picker listant les comptes de l'établissement : chaque compte
  /// sans transaction propose sa suppression (confirmée), les autres sont
  /// signalés comme intouchables. C'est le seul endroit du flux qui expose
  /// la suppression d'un compte vide — un compte vidé de ses transactions
  /// resterait sinon affiché sans pouvoir être retiré.
  void _showDeleteAccountsDialog(
    BuildContext context,
    String establishment,
    List<InvestmentAccount> accounts,
  ) {
    final onDelete = onDeleteAccount;
    if (onDelete == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: FrostedCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shadcn.Text('Supprimer un compte').large().semiBold(),
                  const SizedBox(height: 4),
                  shadcn.Text(
                    'Comptes de $establishment — seuls ceux sans transaction '
                    'sont supprimables.',
                  ).muted().small(),
                  const SizedBox(height: 16),
                  for (final account in accounts) ...[
                    Row(
                      children: [
                        Icon(
                          LucideIcons.wallet,
                          size: 16,
                          color: Theme.of(
                            dialogContext,
                          ).colorScheme.mutedForeground,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Le libellé d'enveloppe (Livret A, PEA,
                              // CTO...) identifie le compte — le nom réel
                              // répéterait l'établissement pour l'épargne.
                              shadcn.Text(
                                account.customOtherCategory ??
                                    account.envelope?.label ??
                                    account.name,
                              ).medium().small(),
                              if (account.description != null)
                                shadcn.Text(
                                  account.description!,
                                ).muted().xSmall(),
                            ],
                          ),
                        ),
                        if (_isDeletable(account))
                          DestructiveButton(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              final confirmed = await confirmDelete(
                                context,
                                title:
                                    'Supprimer « '
                                    '${account.customOtherCategory ?? account.envelope?.label ?? account.name} » ?',
                                message:
                                    'Ce compte et ses investissements '
                                    '(sans transaction) seront '
                                    'définitivement supprimés.',
                              );
                              if (confirmed) await onDelete(account);
                            },
                            child: const shadcn.Text('Supprimer'),
                          )
                        else
                          shadcn.Text(
                            'contient des transactions',
                          ).muted().xSmall(),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlineButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const shadcn.Text('Fermer'),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogHeader(
          step: stepLabel,
          title: 'Quel établissement ?',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        for (final entry in establishments.entries) ...[
          _OptionTile(
            leading: BankLogoAvatar(
              bankName: entry.key,
              logoPath: bankLogos[entry.key],
              size: 28,
              // Cliquer l'avatar importe/remplace le logo de l'établissement.
              onTap: () => onImportLogo(entry.key),
            ),
            label: entry.key,
            // Pas de sous-titre : les comptes de l'établissement (leurs
            // enveloppes) se choisissent à l'étape suivante — les lister ici
            // n'ajoute que de la confusion.
            trailing: _hasDeletableAccounts(entry.value)
                ? IconButton.ghost(
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    onPressed: () => _showDeleteAccountsDialog(
                      context,
                      entry.key,
                      entry.value,
                    ),
                  )
                : null,
            onTap: () => onSelectEstablishment(entry.key),
          ),
          const SizedBox(height: 8),
        ],
        if (creating)
          _InlineCreateForm(
            fields: [
              TextField(
                controller: nameController,
                placeholder: const shadcn.Text(
                  'Nom de l\'établissement (ex: Boursorama)',
                ),
                autofocus: true,
              ),
            ],
            onCreate: onCreate,
            onCancel: onCancelCreate,
            createLabel: 'Continuer',
          )
        else
          _AddOptionButton(label: 'Nouvel établissement', onTap: onStartCreate),
      ],
    );
  }
}

/// Deuxième étape du sous-flux des classes à établissement : quel type de
/// compte (l'enveloppe fiscale — PEA, CTO, Livret A...) pour l'établissement
/// retenu à l'étape précédente ? Une description facultative (ex : "Mon PEA
/// long terme") peut être saisie au-dessus — elle s'applique au compte créé.
/// Les comptes existants de l'établissement pour cette classe sont proposés
/// en premier (un CTO déjà ouvert, réutilisable pour y loger un nouvel
/// investissement), puis une tuile par enveloppe : en choisir une crée (ou
/// réutilise, si l'enveloppe est unique par établissement — voir
/// `accountEnvelopeIsUniquePerEstablishment`) le compte "établissement +
/// enveloppe" puis mène à l'investissement — voir `_selectAccountEnvelope`.
class _AccountEnvelopeStep extends StatelessWidget {
  final String stepLabel;
  final String establishmentName;

  /// Classe d'actif du compte à créer — détermine les enveloppes proposées
  /// (voir `accountEnvelopesFor`).
  final AssetClass assetClass;

  /// Comptes existants de l'établissement pour [assetClass], sélectionnables
  /// tels quels pour y ajouter un investissement sans en créer un nouveau.
  /// Toujours vide pour l'épargne, dont la réutilisation passe par la
  /// logique d'enveloppe unique.
  final List<InvestmentAccount> existingAccounts;
  final VoidCallback onBack;
  final ValueChanged<AccountEnvelope> onSelect;

  /// Appelé avec l'id d'un compte existant choisi.
  final ValueChanged<String> onSelectExisting;

  /// Saisie de la description facultative du compte (voir
  /// `InvestmentAccount.description`).
  final TextEditingController descriptionController;

  /// Date d'ouverture du compte sélectionnée par l'utilisateur (voir
  /// `InvestmentAccount.openingDate`), `null` tant qu'aucune n'est choisie —
  /// l'étape ne sert qu'aux classes à établissement, pour lesquelles la date
  /// a un sens (voir `accountHasOpeningDate`).
  final DateTime? openingDate;
  final ValueChanged<DateTime?> onOpeningDateChanged;

  /// Types "Autres" personnalisés déjà mémorisés (voir
  /// `CustomOtherCategoriesRepository`) — proposés en plus des enveloppes
  /// fixes uniquement quand [assetClass] est `AssetClass.autres`.
  final List<String> customOtherCategories;
  final ValueChanged<String> onSelectCustomOtherCategory;
  final VoidCallback onAddCustomOtherCategory;

  const _AccountEnvelopeStep({
    required this.stepLabel,
    required this.establishmentName,
    required this.assetClass,
    required this.existingAccounts,
    required this.descriptionController,
    required this.openingDate,
    required this.onOpeningDateChanged,
    required this.onBack,
    required this.onSelect,
    required this.onSelectExisting,
    this.customOtherCategories = const [],
    required this.onSelectCustomOtherCategory,
    required this.onAddCustomOtherCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogHeader(step: stepLabel, title: 'Quel compte ?', onBack: onBack),
        const SizedBox(height: 16),
        TextField(
          controller: descriptionController,
          placeholder: const shadcn.Text(
            'Description (facultative, ex: Épargne vacances)',
          ),
        ),
        const SizedBox(height: 8),
        DatePicker(
          value: openingDate,
          onChanged: (date) => onOpeningDateChanged(
            date == null
                ? null
                // Jour calendaire sans heure, comme `_txnDate` et
                // `_liabDateDebut` (voir `initState`).
                : DateTime(date.year, date.month, date.day),
          ),
          placeholder: const shadcn.Text('Date d\'ouverture (facultative)'),
        ),
        if (existingAccounts.isNotEmpty) ...[
          const SizedBox(height: 16),
          shadcn.Text('Comptes existants').medium(),
          const SizedBox(height: 8),
          for (final account in existingAccounts) ...[
            _OptionTile(
              leading: const Icon(LucideIcons.wallet, size: 18),
              label: account.name,
              sublabel:
                  account.description ??
                  account.customOtherCategory ??
                  account.envelope?.label,
              onTap: () => onSelectExisting(account.id),
            ),
            const SizedBox(height: 8),
          ],
          shadcn.Text('Nouveau compte').medium(),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 12),
        for (final envelope in accountEnvelopesFor(assetClass)) ...[
          _OptionTile(
            leading: const Icon(LucideIcons.wallet, size: 18),
            label: envelope.label,
            sublabel: establishmentName,
            onTap: () => onSelect(envelope),
          ),
          const SizedBox(height: 8),
        ],
        if (assetClass == AssetClass.autres) ...[
          for (final category in customOtherCategories) ...[
            _OptionTile(
              leading: const Icon(LucideIcons.wallet, size: 18),
              label: category,
              sublabel: establishmentName,
              onTap: () => onSelectCustomOtherCategory(category),
            ),
            const SizedBox(height: 8),
          ],
          _OptionTile(
            leading: Icon(
              LucideIcons.plus,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: '+ Nouveau type',
            sublabel: null,
            onTap: onAddCustomOtherCategory,
          ),
        ],
      ],
    );
  }
}

class _InvestmentStep extends StatelessWidget {
  final String stepLabel;
  final String title;
  final String addLabel;
  final String createLabel;
  final InvestmentAccount account;
  final AssetClass assetClass;
  final bool creating;

  /// Un compte-titres (Actions & Fonds) peut loger des titres ET des
  /// devises (USD, GBP... en cash) : la création y propose une bascule
  /// "Investissement / Devise" (voir [creatingDevise]).
  final bool allowsDevises;

  /// Mode "Devise" de la bascule — l'identifiant se choisit alors dans la
  /// liste des codes de devise connus plutôt qu'en ISIN libre.
  final bool creatingDevise;
  final ValueChanged<bool>? onDeviseModeChanged;

  final TextEditingController isinController;
  final TextEditingController labelController;
  final RealEstateType realEstateType;
  final ValueChanged<RealEstateType> onRealEstateTypeChanged;
  final FundStyle? fundStyle;
  final ValueChanged<FundStyle?> onFundStyleChanged;
  final VoidCallback onBack;
  final ValueChanged<String> onSelectInvestment;
  final VoidCallback onStartCreate;
  final VoidCallback onCancelCreate;
  final VoidCallback onCreate;

  const _InvestmentStep({
    required this.stepLabel,
    this.title = 'Quel investissement ?',
    this.addLabel = 'Nouvel investissement',
    this.createLabel = 'Créer l\'investissement',
    required this.account,
    required this.assetClass,
    required this.creating,
    this.allowsDevises = false,
    this.creatingDevise = false,
    this.onDeviseModeChanged,
    required this.isinController,
    required this.labelController,
    required this.realEstateType,
    required this.onRealEstateTypeChanged,
    required this.fundStyle,
    required this.onFundStyleChanged,
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
        _DialogHeader(step: stepLabel, title: title, onBack: onBack),
        const SizedBox(height: 16),
        for (final investment in account.investments) ...[
          _OptionTile(
            leading: Icon(
              assetClass == AssetClass.autres
                  ? LucideIcons.gem
                  : LucideIcons.chartCandlestick,
              size: 18,
            ),
            label: investment.label,
            // Immobilier : pas d'identifiant. Épargne et toute autre
            // position en devise : l'identifiant est la devise, déjà portée
            // par le libellé — pas besoin de la répéter en dessous. "Autres"
            // sans référence saisie : un identifiant auto-généré (voir
            // `_commitCreateInvestment`) n'a rien d'utile à montrer.
            sublabel:
                (assetClass == AssetClass.immobilier || investment.isCurrency)
                ? null
                : assetClass == AssetClass.autres &&
                      investment.isin.startsWith('autre-')
                ? null
                : investment.isin,
            onTap: () => onSelectInvestment(investment.id),
          ),
          const SizedBox(height: 8),
        ],
        if (creating)
          _InlineCreateForm(
            fields: [
              if (allowsDevises) ...[
                // Bascule "Investissement / Devise" : un compte-titres peut
                // loger les deux (une action OU des dollars tenus en cash).
                ButtonGroup(
                  children: [
                    SelectedButton(
                      value: !creatingDevise,
                      selectedStyle: const ButtonStyle.primary(),
                      style: toggleUnselectedStyle(context),
                      onChanged: (_) => onDeviseModeChanged?.call(false),
                      child: const shadcn.Text('Investissement'),
                    ),
                    SelectedButton(
                      value: creatingDevise,
                      selectedStyle: const ButtonStyle.primary(),
                      style: toggleUnselectedStyle(context),
                      onChanged: (_) => onDeviseModeChanged?.call(true),
                      child: const shadcn.Text('Devise'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
                TextField(
                  controller: labelController,
                  placeholder: const shadcn.Text(
                    'Nom du bien (ex: Appartement Lyon 6e)',
                  ),
                ),
              ] else if (creatingDevise) ...[
                // Une devise se choisit dans la liste des codes connus
                // (EUR, USD, GBP...) plutôt qu'en ISIN libre — même liste
                // que l'épargne (le libellé se pré-remplit du code choisi).
                InvestmentIdentifierField(
                  assetClass: assetClass,
                  accountEnvelope: account.envelope,
                  isinController: isinController,
                  labelController: labelController,
                  options: kKnownCurrencies,
                ),
              ] else if (assetClass == AssetClass.autres) ...[
                // Pour "Autres", le nom précède la référence : c'est
                // l'information principale d'un objet de collection, la
                // référence n'étant qu'un détail facultatif (numéro de
                // série...) — voir `InvestmentIdentifierField`.
                TextField(
                  controller: labelController,
                  placeholder: const shadcn.Text(
                    'Nom (ex : Rolex Submariner)',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                InvestmentIdentifierField(
                  assetClass: assetClass,
                  accountEnvelope: account.envelope,
                  isinController: isinController,
                  labelController: labelController,
                  autofocus: false,
                ),
              ] else ...[
                InvestmentIdentifierField(
                  assetClass: assetClass,
                  accountEnvelope: account.envelope,
                  isinController: isinController,
                  labelController: labelController,
                ),
                const SizedBox(height: 8),
                // Métaux physiques : le libellé est le produit choisi dans
                // la liste déroulante (pré-rempli automatiquement), inutile
                // de demander un libellé séparé.
                if (requiresLabelFieldFor(
                  assetClass,
                  accountEnvelope: account.envelope,
                ))
                  TextField(
                    controller: labelController,
                    placeholder: const shadcn.Text(
                      'Libellé (ex: TotalEnergies)',
                    ),
                  ),
                if (assetClass == AssetClass.actionsEtFonds) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Select<FundStyle>(
                        value: fundStyle,
                        placeholder: const shadcn.Text(
                          'Style de gestion (facultatif)',
                        ),
                        onChanged: (style) {
                          if (style != null) onFundStyleChanged(style);
                        },
                        itemBuilder: (context, style) =>
                            shadcn.Text(style.label),
                        popup: (context) => SelectPopup(
                          items: SelectItemList(
                            children: [
                              for (final style in FundStyle.values)
                                SelectItemButton(
                                  value: style,
                                  child: shadcn.Text(style.label),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (fundStyle != null) ...[
                        const SizedBox(width: 4),
                        IconButton.ghost(
                          icon: const Icon(LucideIcons.x, size: 14),
                          onPressed: () => onFundStyleChanged(null),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ],
            onCreate: onCreate,
            onCancel: onCancelCreate,
            createLabel: createLabel,
          )
        else
          _AddOptionButton(label: addLabel, onTap: onStartCreate),
      ],
    );
  }
}

class _TransactionStep extends StatelessWidget {
  final String stepLabel;
  final Investment investment;
  final bool isBuy;
  final DateTime? date;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final String quantityLabel;
  final String priceLabel;
  final bool showPriceField;

  /// `true` affiche le sélecteur de devise à côté du champ prix (voir
  /// `_CompletePatrimoineDialogState`'s `_showCurrencySelector`) — faux pour
  /// une position en devise, dont le "prix" est déjà le taux en euros.
  final bool showCurrencySelector;

  /// Contrôleur devise/taux du formulaire (voir
  /// `transaction_price_currency.dart`) — utilisé quand [showCurrencySelector]
  /// pour résoudre le taux et afficher la zone de rappel/conversion.
  final TransactionPriceCurrencyController? priceCurrencyController;

  final VoidCallback onBack;
  final ValueChanged<bool> onIsBuyChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final VoidCallback onCreate;
  final VoidCallback onSkip;

  const _TransactionStep({
    required this.stepLabel,
    required this.investment,
    required this.isBuy,
    required this.date,
    required this.quantityController,
    required this.priceController,
    this.quantityLabel = 'Quantité',
    this.priceLabel = 'Prix unitaire',
    this.showPriceField = true,
    this.showCurrencySelector = false,
    this.priceCurrencyController,
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
          step: stepLabel,
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
              if (showCurrencySelector && priceCurrencyController != null) ...[
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

  /// Widget affiché avant la chevron (action secondaire de la tuile, ex : un
  /// bouton supprimer) — `null` pour les tuiles sans action dédiée.
  final Widget? trailing;
  final VoidCallback onTap;

  const _OptionTile({
    required this.leading,
    required this.label,
    this.sublabel,
    this.trailing,
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
              if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
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

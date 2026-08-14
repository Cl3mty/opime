import 'dart:typed_data';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/date_format.dart';
import '../../core/ui/frosted_card.dart';
import 'confirm_delete_dialog.dart';
import 'document_storage.dart';
import 'documents_section.dart';
import 'ibkr/ibkr_import_dialog.dart';
import 'investment_identifier_field.dart';
import 'investments_models.dart';
import 'investments_repository.dart';
import 'performance_calculator.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Détail d'un compte de placement : montant total, liste des
/// investissements (par ISIN) qui le composent, ajout d'un investissement
/// en ligne. Vue embarquée dans `RealCategoryDetailScreen` (pas de
/// `Navigator.push`, pas de `Scaffold`/`AppBar` propres), atteinte en
/// cliquant sur une ligne de la page de détail d'une catégorie du
/// Dashboard : [onBack] y revient, [onOpenInvestment] ouvre un
/// investissement, [onChanged] prévient le parent qu'il doit recharger les
/// données après une mutation locale.
class AccountDetailView extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final bool hidden;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenInvestment;
  final VoidCallback onChanged;

  /// Noms des établissements (banques, brokers...) déjà créés dans le vault,
  /// pour la liste déroulante du formulaire d'édition : on change de banque
  /// en la sélectionnant, on n'en tape pas une nouvelle à la volée (la
  /// création d'un établissement passe par le flux "Compléter mon
  /// patrimoine"). Voir `_EditAccountForm`.
  final List<String> bankNames;

  /// Ouvre directement le formulaire d'édition du compte (nom, banque,
  /// enveloppe) plutôt que sa vue normale — utilisé par le menu "⋮ Modifier
  /// le compte" de l'accordéon d'une catégorie (voir
  /// `RealCategoryDetailScreen`'s `_openAccountForEdit`), pour éviter à
  /// l'utilisateur de cliquer une deuxième fois une fois le compte ouvert.
  final bool startInEditMode;

  const AccountDetailView({
    super.key,
    required this.vaultPath,
    required this.account,
    required this.hidden,
    required this.bankNames,
    required this.onBack,
    required this.onOpenInvestment,
    required this.onChanged,
    this.startInEditMode = false,
  });

  @override
  State<AccountDetailView> createState() => _AccountDetailViewState();
}

class _AccountDetailViewState extends State<AccountDetailView> {
  late InvestmentsRepository _repo;

  bool _creating = false;
  final _isinController = TextEditingController();
  final _labelController = TextEditingController();

  bool _editingAccount = false;
  final _editNameController = TextEditingController();
  final _editDescriptionController = TextEditingController();

  /// Établissement (banque, broker...) en cours d'édition, `null` si aucun
  /// n'est sélectionné. Contrairement au nom (saisi librement), on change de
  /// banque via une liste déroulante de `bankNames`.
  String? _editBankName;
  AccountEnvelope? _editEnvelope;

  /// Date d'ouverture en cours d'édition (voir
  /// `InvestmentAccount.openingDate`), `null` tant que le formulaire n'a
  /// pas été validé ou si l'utilisateur l'efface.
  DateTime? _editOpeningDate;

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    if (widget.startInEditMode) _startEditAccount();
  }

  @override
  void didUpdateWidget(covariant AccountDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) {
      _repo = InvestmentsRepository(widget.vaultPath);
    }
  }

  @override
  void dispose() {
    _isinController.dispose();
    _labelController.dispose();
    _editNameController.dispose();
    _editDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _commitCreateInvestment() async {
    // Les valeurs choisies dans une liste déroulante (voir
    // `identifierOptionsFor`) gardent leur casse d'origine (ex : "Livret
    // A") plutôt que d'être mises en majuscules comme un ISIN/ticker saisi
    // librement.
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
    if (label.isEmpty ||
        (widget.account.assetClass != AssetClass.immobilier && isin.isEmpty)) {
      return;
    }
    final updated = widget.account.copyWith(
      investments: [
        ...widget.account.investments,
        Investment(
          isin: widget.account.assetClass == AssetClass.immobilier
              ? 'immobilier-${generateInvestmentId('bien')}'
              : isin,
          label: label,
          transactions: const [],
          realEstateType: widget.account.assetClass == AssetClass.immobilier
              ? RealEstateType.residencePrincipale
              : null,
        ),
      ],
    );
    await _repo.saveAccount(updated);
    _isinController.clear();
    _labelController.clear();
    setState(() => _creating = false);
    widget.onChanged();
  }

  void _startEditAccount() {
    setState(() {
      _editingAccount = true;
      _editNameController.text = widget.account.name;
      _editBankName = widget.account.bankName;
      _editDescriptionController.text = widget.account.description ?? '';
      _editOpeningDate = widget.account.openingDate;
      _editEnvelope =
          widget.account.envelope ??
          accountEnvelopesFor(widget.account.assetClass).first;
    });
  }

  Future<void> _commitEditAccount() async {
    // Seuls les comptes dont la classe d'actif gère un établissement
    // (épargne, PEA, CTO...) portent une banque — les autres (immobilier,
    // crypto, métaux) gardent `bankName` à `null`.
    final canHaveBank = supportsBankName(widget.account);
    final name = _commitEditAccountName();
    if (name.isEmpty) return;
    // Une banque ou une description effacées (champ vidé) valent `null` —
    // comme à la lecture du disque (`InvestmentAccount.fromJson`).
    final description = _editDescriptionController.text.trim();
    final updated = widget.account.copyWith(
      name: name,
      envelope: _editEnvelope,
      bankName: canHaveBank ? _editBankName : null,
      description: description.isEmpty ? null : description,
      // La date d'ouverture est effaçable via le formulaire : on la
      // remplace telle quelle, `null` inclus.
      openingDate: _editOpeningDate,
    );
    await _repo.saveAccount(updated);
    setState(() => _editingAccount = false);
    widget.onChanged();
  }

  /// Le nom d'un compte découle de son identité dans le formulaire d'édition,
  /// il n'est pas saisi librement :
  ///
  /// * épargne — le nom suit la banque sélectionnée (banque et nom sont
  ///   identiques pour un compte d'épargne, comme à la création) ;
  /// * enveloppe avec établissement (assurance-vie, PEA, comptes-titres...) —
  ///   le nom est le type de compte (l'enveloppe), mis à jour si on en
  ///   change, conservé sinon pour ne pas renommer un compte existant ;
  /// * enveloppe sans établissement (crypto, métaux précieux, immobilier) —
  ///   le nom reste saisi librement.
  String _commitEditAccountName() {
    final isEpargne = widget.account.assetClass == AssetClass.epargne;
    if (isEpargne) return _editBankName ?? widget.account.name;
    final requiresEstablishment =
        assetClassRequiresEstablishmentStep(widget.account.assetClass);
    if (requiresEstablishment) {
      // Nom = type de compte : on ne le renomme que si le type a changé.
      final envelopeChanged = _editEnvelope != widget.account.envelope;
      return envelopeChanged
          ? (_editEnvelope?.label ?? widget.account.name)
          : widget.account.name;
    }
    return _editNameController.text.trim();
  }

  /// Un compte avec des transactions ne peut pas être supprimé directement
  /// (perte de données trop facile) : il faut d'abord vider chacun de ses
  /// investissements en supprimant leurs transactions une à une.
  bool get _hasTransactions =>
      widget.account.investments.any((i) => i.transactions.isNotEmpty);

  Future<void> _deleteAccount() async {
    if (_hasTransactions) return;
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer "${widget.account.name}" ?',
      message:
          'Ce compte et ses investissements (sans transaction) seront '
          'définitivement supprimés.',
    );
    if (!confirmed) return;
    await _repo.deleteAccount(widget.account.id);
    widget.onBack();
    widget.onChanged();
  }

  Future<void> _addDocument(
    String fileName,
    Uint8List bytes,
    String? transactionId,
    String? name,
  ) async {
    // Un compte n'a pas de notion de transaction (celles-ci vivent au
    // niveau des investissements qu'il contient) : ce paramètre n'est
    // jamais renseigné ici, voir `DocumentsSection`'s `transactions`.
    final document = VaultDocument(fileName: fileName, note: name);
    await DocumentStorage(widget.vaultPath).save(document, bytes);
    final updated = widget.account.copyWith(
      documents: [...widget.account.documents, document],
    );
    await _repo.saveAccount(updated);
    widget.onChanged();
  }

  Future<void> _deleteDocument(VaultDocument document) async {
    await DocumentStorage(widget.vaultPath).delete(document);
    final updated = widget.account.copyWith(
      documents: [
        for (final d in widget.account.documents)
          if (d.id != document.id) d,
      ],
    );
    await _repo.saveAccount(updated);
    widget.onChanged();
  }

  /// "Importer un relevé (IBKR)" du menu "⋮" — voir `ibkr_import_dialog.dart`.
  /// Réservé aux comptes Actions & Fonds (CTO, PEA...), seuls concernés par
  /// les titres/dividendes d'un relevé de courtier.
  Future<void> _importIbkrStatement() async {
    await showIbkrImportDialog(
      context,
      vaultPath: widget.vaultPath,
      account: widget.account,
      onImported: widget.onChanged,
    );
  }

  void _openAccountMenu(BuildContext anchorContext) {
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.pencil, size: 14),
              child: const shadcn.Text('Modifier le compte'),
              onPressed: (_) => _startEditAccount(),
            ),
            MenuButton(
              enabled: !_hasTransactions,
              leading: const Icon(LucideIcons.trash2, size: 14),
              trailing: _hasTransactions
                  ? const shadcn.Text('Vide-le d\'abord').muted().xSmall()
                  : null,
              child: const shadcn.Text('Supprimer le compte'),
              onPressed: (_) => _deleteAccount(),
            ),
            if (widget.account.assetClass == AssetClass.actionsEtFonds)
              MenuButton(
                leading: const Icon(LucideIcons.upload, size: 14),
                child: const shadcn.Text('Importer un relevé (IBKR)'),
                onPressed: (_) => _importIbkrStatement(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final pricedInvestments = account.investments
        .where((i) => i.marketValue != null)
        .toList();
    final mwr = pricedInvestments.isEmpty
        ? null
        : calculateMwr(
            transactions: [
              for (final i in pricedInvestments) ...i.transactions,
            ],
            currentValue: pricedInvestments.fold(
              0.0,
              (sum, i) => sum + i.marketValue!,
            ),
            asOf: DateTime.now(),
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BackHeader(label: account.name, onBack: widget.onBack),
              ),
              Builder(
                builder: (context) => IconButton.ghost(
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                  onPressed: () => _openAccountMenu(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_editingAccount)
            _EditAccountForm(
              assetClass: account.assetClass,
              // Le nom d'un compte n'est pas saisi librement : il découle du
              // type de compte (enveloppe) ou de la banque pour l'épargne —
              // voir `_commitEditAccountName`. Seules les enveloppes sans
              // établissement (immobilier, crypto, métaux) gardent un champ
              // de saisie.
              nameController: _editNameController,
              showNameField:
                  !assetClassRequiresEstablishmentStep(account.assetClass),
              // On change de banque via une liste déroulante des
              // établissements déjà créés dans le vault — la création d'un
              // établissement passe par le flux "Compléter mon patrimoine".
              bankNames: widget.bankNames,
              bankName: _editBankName,
              onBankNameChanged: (v) => setState(() => _editBankName = v),
              // Un compte sans établissement possible (immobilier, crypto,
              // métaux physiques) n'a pas de champ banque à éditer — voir
              // `supportsBankName`.
              showBankField: supportsBankName(account),
              descriptionController: _editDescriptionController,
              // La date d'ouverture ne concerne que les comptes
              // d'investissement (épargne, compte-titres...) — voir
              // `accountHasOpeningDate`.
              openingDate: _editOpeningDate,
              showOpeningDateField: accountHasOpeningDate(account.assetClass),
              onOpeningDateChanged: (date) => setState(
                () => _editOpeningDate = date == null
                    ? null
                    // Jour calendaire sans heure, comme à la création.
                    : DateTime(date.year, date.month, date.day),
              ),
              envelope: _editEnvelope!,
              onEnvelopeChanged: (e) => setState(() => _editEnvelope = e),
              onSave: _commitEditAccount,
              onCancel: () => setState(() => _editingAccount = false),
            )
          else ...[
            shadcn.Text(
              account.envelope != null
                  ? '${account.assetClass.label} · ${account.envelope!.label}'
                  : account.assetClass.label,
            ).muted().small(),
            if (account.openingDate != null) ...[
              const SizedBox(height: 2),
              shadcn.Text(
                'Ouvert le ${formatDateDdMmYyyy(account.openingDate!)}',
              ).muted().xSmall(),
            ],
            const SizedBox(height: 4),
            shadcn.Text(
              displayEuros(account.totalMarketValue, widget.hidden),
            ).x2Large().bold(),
            const SizedBox(height: 2),
            shadcn.Text(
              pricedInvestments.length == account.investments.length &&
                      account.investments.isNotEmpty
                  ? 'Valorisation au dernier cours connu'
                  : 'Montant net investi (cours pas encore disponible pour '
                        'tous les investissements)',
            ).muted().xSmall(),
          ],
          if (mwr != null && !_editingAccount) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mwr.rate >= 0
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                  size: 14,
                  color: mwr.rate >= 0 ? _green : _red,
                ),
                const SizedBox(width: 4),
                shadcn.Text(
                  mwr.annualized
                      ? '${displayPercent(mwr.rate * 100)} par an (MWR, '
                            'rendement pondéré par vos apports)'
                      : '${displayPercent(mwr.rate * 100)} depuis le début '
                            '(MWR, moins d\'un an de recul)',
                  style: TextStyle(
                    color: mwr.rate >= 0 ? _green : _red,
                    fontWeight: FontWeight.w600,
                  ),
                ).xSmall(),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const shadcn.Text('Investissements').large().medium(),
          const SizedBox(height: 12),
          for (final investment in account.investments) ...[
            _InvestmentCard(
              investment: investment,
              accountAssetClass: account.assetClass,
              hidden: widget.hidden,
              onTap: () => widget.onOpenInvestment(investment.id),
            ),
            const SizedBox(height: 12),
          ],
          if (_creating)
            _CreateInvestmentForm(
              assetClass: account.assetClass,
              accountEnvelope: account.envelope,
              isinController: _isinController,
              labelController: _labelController,
              onCreate: _commitCreateInvestment,
              onCancel: () => setState(() => _creating = false),
            )
          else
            _AddInvestmentButton(onTap: () => setState(() => _creating = true)),
          // Pour les métaux précieux et "autres", chaque document doit être
          // rattaché à une transaction précise d'un investissement (voir
          // `InvestmentDetailView`) — pas de documents au niveau du compte
          // pour ces deux classes. Pour toutes les autres, c'est l'inverse :
          // le compte est le seul niveau où on en attache.
          if (account.assetClass != AssetClass.metauxPrecieux &&
              account.assetClass != AssetClass.autres) ...[
            const SizedBox(height: 24),
            DocumentsSection(
              vaultPath: widget.vaultPath,
              documents: account.documents,
              quantityAssetClass: account.assetClass,
              onAdd: _addDocument,
              onDelete: _deleteDocument,
            ),
          ],
        ],
      ),
    );
  }
}

class BackHeader extends StatelessWidget {
  final String label;
  final VoidCallback onBack;

  const BackHeader({super.key, required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onBack,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.chevronLeft, size: 20),
            const SizedBox(width: 4),
            shadcn.Text(label).x2Large().semiBold(),
          ],
        ),
      ),
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  final Investment investment;
  final AssetClass accountAssetClass;
  final bool hidden;
  final VoidCallback onTap;

  const _InvestmentCard({
    required this.investment,
    required this.accountAssetClass,
    required this.hidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = investment.marketValue ?? investment.investedAmount;
    final crossClass =
        investment.assetClass != null &&
        investment.assetClass != accountAssetClass;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      shadcn.Text(investment.label).medium(),
                      // Immobilier : pas d'identifiant à afficher. Position
                      // en devise (épargne, ou devise logée dans un compte-
                      // titres) : l'identifiant est le code de la devise,
                      // déjà porté par le libellé — pas besoin de le répéter.
                      if (accountAssetClass != AssetClass.immobilier &&
                          !investment.isCurrency)
                        shadcn.Text(investment.isin).muted().small(),
                      if (crossClass)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: shadcn.Text(
                            investment.assetClass!.label,
                            style: TextStyle(color: theme.colorScheme.primary),
                          ).xSmall(),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    shadcn.Text(displayEuros(value, hidden)).semiBold(),
                    if (accountAssetClass != AssetClass.immobilier)
                      shadcn.Text(
                        // Une position en devise (épargne, ou devise logée
                        // dans un compte-titres) se compte dans sa propre
                        // monnaie, pas en "unités".
                        investment.isCurrency
                            ? '${formatQuantity(investment.quantityHeld, accountAssetClass)} '
                                  '${investment.isin}'
                            : '${formatQuantity(investment.quantityHeld, accountAssetClass)} '
                                  'unités',
                      ).muted().xSmall(),
                  ],
                ),
                const SizedBox(width: 12),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: theme.colorScheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddInvestmentButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddInvestmentButton({required this.onTap});

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
            'Ajouter un investissement',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _CreateInvestmentForm extends StatelessWidget {
  final AssetClass assetClass;
  final AccountEnvelope? accountEnvelope;
  final TextEditingController isinController;
  final TextEditingController labelController;
  final VoidCallback onCreate;
  final VoidCallback onCancel;

  const _CreateInvestmentForm({
    required this.assetClass,
    this.accountEnvelope,
    required this.isinController,
    required this.labelController,
    required this.onCreate,
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
            if (assetClass == AssetClass.immobilier)
              TextField(
                controller: labelController,
                placeholder: const shadcn.Text(
                  'Nom du bien (ex: Appartement Lyon 6e)',
                ),
              )
            else if (!requiresLabelFieldFor(
              assetClass,
              accountEnvelope: accountEnvelope,
            ))
              // Métaux physiques : le libellé est le produit choisi dans la
              // liste déroulante (pré-rempli automatiquement), inutile de
              // demander un libellé séparé.
              InvestmentIdentifierField(
                assetClass: assetClass,
                accountEnvelope: accountEnvelope,
                isinController: isinController,
                labelController: labelController,
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
                  onPressed: onCreate,
                  child: const shadcn.Text('Ajouter'),
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

class _EditAccountForm extends StatelessWidget {
  final AssetClass assetClass;
  final TextEditingController nameController;

  /// Le champ "Nom du compte" n'apparaît que pour les enveloppes sans
  /// établissement (immobilier, crypto, métaux) : ailleurs le nom découle du
  /// type de compte (enveloppe) ou de la banque pour l'épargne — voir
  /// `_commitEditAccountName`.
  final bool showNameField;

  /// Établissements (banques, brokers...) déjà créés dans le vault — on
  /// change de banque en la sélectionnant dans cette liste, on n'en saisit
  /// pas de nouvelle à la volée (la création d'un établissement passe par le
  /// flux "Compléter mon patrimoine"). Le champ n'apparaît que si
  /// [showBankField].
  final List<String> bankNames;
  final String? bankName;
  final ValueChanged<String> onBankNameChanged;
  final bool showBankField;

  /// Pré-rempli avec la description actuelle, effaçable (champ vide →
  /// `null`).
  final TextEditingController descriptionController;

  /// Date d'ouverture en cours d'édition (voir
  /// `InvestmentAccount.openingDate`), effaçable — le champ n'apparaît que
  /// si [showOpeningDateField] (comptes d'investissement, voir
  /// `accountHasOpeningDate`).
  final DateTime? openingDate;
  final bool showOpeningDateField;
  final ValueChanged<DateTime?> onOpeningDateChanged;

  final AccountEnvelope envelope;
  final ValueChanged<AccountEnvelope> onEnvelopeChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditAccountForm({
    required this.assetClass,
    required this.nameController,
    required this.showNameField,
    required this.bankNames,
    required this.bankName,
    required this.onBankNameChanged,
    required this.showBankField,
    required this.descriptionController,
    required this.openingDate,
    required this.showOpeningDateField,
    required this.onOpeningDateChanged,
    required this.envelope,
    required this.onEnvelopeChanged,
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Select<AccountEnvelope>(
                  value: envelope,
                  constraints: const BoxConstraints(minWidth: 220),
                  onChanged: (v) {
                    if (v != null) onEnvelopeChanged(v);
                  },
                  itemBuilder: (context, value) => shadcn.Text(value.label),
                  popup: (context) => SelectPopup(
                    items: SelectItemList(
                      children: [
                        for (final e in accountEnvelopesFor(assetClass))
                          SelectItemButton(
                            value: e,
                            child: shadcn.Text(e.label),
                          ),
                      ],
                    ),
                  ),
                ),
                if (showNameField) ...[
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: nameController,
                      placeholder: const shadcn.Text('Nom du compte'),
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (showBankField) ...[
                  // Sélection d'un établissement existant : contrairement au
                  // nom, la banque ne se saisit pas à la volée (la création
                  // d'un établissement passe par le flux "Compléter mon
                  // patrimoine").
                  Select<String>(
                    value: bankName,
                    constraints: const BoxConstraints(minWidth: 200),
                    placeholder: const shadcn.Text('Établissement (banque)'),
                    onChanged: (v) {
                      if (v != null) onBankNameChanged(v);
                    },
                    itemBuilder: (context, value) => shadcn.Text(value),
                    popup: (context) => SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final bank in {...bankNames, ?bankName}.toList()
                            ..sort())
                            SelectItemButton(
                              value: bank,
                              child: shadcn.Text(bank),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              placeholder: const shadcn.Text(
                'Description (facultative, ex: Épargne vacances)',
              ),
              // Autofocus sur la description quand il n'y a pas de champ de
              // saisie libre (nom) au-dessus.
              autofocus: !showNameField && !showBankField,
            ),
            const SizedBox(height: 12),
            if (showOpeningDateField) ...[
              Row(
                children: [
                  DatePicker(
                    value: openingDate,
                    onChanged: onOpeningDateChanged,
                    placeholder: const shadcn.Text('Date d\'ouverture'),
                  ),
                  // La date reste effaçable une fois renseignée (le picker
                  // seul n'expose pas de "désélectionner" évident).
                  if (openingDate != null) ...[
                    const SizedBox(width: 8),
                    GhostButton(
                      onPressed: () => onOpeningDateChanged(null),
                      child: const shadcn.Text('Effacer la date'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
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

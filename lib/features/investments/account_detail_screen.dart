import 'dart:typed_data';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import 'confirm_delete_dialog.dart';
import 'document_storage.dart';
import 'documents_section.dart';
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

  /// Ouvre directement le formulaire d'édition du compte (nom, enveloppe)
  /// plutôt que sa vue normale — utilisé par le menu "⋮ Modifier le
  /// compte" de l'accordéon d'une catégorie (voir
  /// `RealCategoryDetailScreen`'s `_openAccountForEdit`), pour éviter à
  /// l'utilisateur de cliquer une deuxième fois une fois le compte ouvert.
  final bool startInEditMode;

  const AccountDetailView({
    super.key,
    required this.vaultPath,
    required this.account,
    required this.hidden,
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
  AccountEnvelope? _editEnvelope;

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
      _editEnvelope =
          widget.account.envelope ??
          accountEnvelopesFor(widget.account.assetClass).first;
    });
  }

  Future<void> _commitEditAccount() async {
    final name = _editNameController.text.trim();
    if (name.isEmpty) return;
    final updated = widget.account.copyWith(
      name: name,
      envelope: _editEnvelope,
    );
    await _repo.saveAccount(updated);
    setState(() => _editingAccount = false);
    widget.onChanged();
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
              nameController: _editNameController,
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
                      if (accountAssetClass != AssetClass.immobilier)
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
                        '${investment.quantityHeld.toStringAsFixed(2)} unités',
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
  final AccountEnvelope envelope;
  final ValueChanged<AccountEnvelope> onEnvelopeChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditAccountForm({
    required this.assetClass,
    required this.nameController,
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
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: nameController,
                    placeholder: const shadcn.Text('Nom du compte'),
                    autofocus: true,
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

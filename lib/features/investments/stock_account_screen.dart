import 'dart:typed_data';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'account_detail_screen.dart' show AccountEditForm, BackHeader;
import 'confirm_delete_dialog.dart';
import 'document_storage.dart';
import 'documents_section.dart';
import 'ibkr/ibkr_import_dialog.dart';
import 'investments_models.dart';
import 'investments_repository.dart';
import 'widgets/account_summary_header.dart';
import 'widgets/account_transactions_tab.dart';
import 'widgets/position_detail_dialog.dart';
import 'widgets/positions_table.dart';

/// Écran compte dédié à toutes les classes d'actif sauf l'immobilier
/// (Actions & Fonds, épargne, métaux précieux, crypto, private equity,
/// "autres") — remplace la paire page compte + page actif
/// (`AccountDetailView` + `InvestmentDetailView`) par une unique page à 2
/// onglets (Positions/Transactions), le détail d'une position s'ouvrant en
/// popup plutôt que sur une page séparée — voir
/// `widgets/position_detail_dialog.dart`. L'immobilier garde
/// `AccountDetailView`/`InvestmentDetailView` : un bien immobilier est
/// toujours seul dans son compte (pas de notion de "plusieurs positions" à
/// tableauter), et sa réestimation €/m² (`investment_reestimate_dialog.dart`)
/// n'a pas d'équivalent ici.
///
/// Même embarquement que `AccountDetailView` (pas de `Navigator.push`, pas
/// de `Scaffold`/`AppBar` propres) : [onBack] revient au tableau,
/// [onChanged] prévient le parent qu'il doit recharger après une mutation
/// locale.
class StockAccountScreen extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final bool hidden;
  final VoidCallback onBack;
  final VoidCallback onChanged;

  /// Noms des établissements déjà créés dans le vault — voir
  /// `AccountEditForm`.
  final List<String> bankNames;

  /// Ouvre directement le formulaire d'édition du compte — voir
  /// `AccountDetailView`'s `startInEditMode`.
  final bool startInEditMode;

  /// Ouvre directement la popup de détail de cette position à l'arrivée
  /// sur l'écran — utilisé quand on clique une position directement depuis
  /// le tableau de catégorie (`RealCategoryDetailScreen`'s `_openInvestment`),
  /// pour garder le même raccourci "un clic → le détail" qu'avant la
  /// fusion compte/actif, sans pour autant garder de page dédiée.
  final String? initialInvestmentId;

  /// Restreint ce qui est AFFICHÉ (positions, transactions, totaux) aux
  /// investissements du compte dont la classe effective vaut cette classe —
  /// utilisé pour qu'un compte multi-support n'affiche jamais que ce qui
  /// correspond à la catégorie parcourue, dans les deux sens : un contrat
  /// d'assurance vie (classe propre "Actions & Fonds") qui porte aussi des
  /// parts de SCPI (classe effective Immobilier — voir
  /// `accountAcceptsCrossClassInvestment`) n'affiche QUE ces parts ouvert
  /// depuis Immobilier, et QUE ses fonds/actions (jamais les parts de SCPI)
  /// ouvert depuis sa propre catégorie Actions & Fonds. `null` : aucun
  /// filtre — tout le compte, peu importe la classe effective de chaque
  /// investissement (utilisé par ex. par les tests qui n'ont pas besoin de
  /// ce scoping). N'affecte jamais [account] lui-même ni aucune opération
  /// d'écriture (modifier/supprimer le compte, ajouter un document...), qui
  /// continuent de porter sur le compte réel dans son intégralité.
  final AssetClass? restrictToAssetClass;

  const StockAccountScreen({
    super.key,
    required this.vaultPath,
    required this.account,
    required this.hidden,
    required this.bankNames,
    required this.onBack,
    required this.onChanged,
    this.startInEditMode = false,
    this.initialInvestmentId,
    this.restrictToAssetClass,
  });

  @override
  State<StockAccountScreen> createState() => _StockAccountScreenState();
}

class _StockAccountScreenState extends State<StockAccountScreen> {
  late InvestmentsRepository _repo;
  int _tabIndex = 0;

  /// Bascule ponctuelle de [StockAccountScreen.restrictToAssetClass] :
  /// l'utilisateur peut choisir de voir malgré tout tout le contenu du
  /// compte (voir le bouton discret sous l'en-tête) plutôt que de rester
  /// restreint à la catégorie parcourue en permanence. État local à cet
  /// écran, jamais persisté : repart masqué à chaque nouvelle ouverture.
  bool _showAllClasses = false;

  bool _editingAccount = false;
  final _editNameController = TextEditingController();
  final _editDescriptionController = TextEditingController();
  String? _editBankName;
  AccountEnvelope? _editEnvelope;
  DateTime? _editOpeningDate;

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    if (widget.startInEditMode) _startEditAccount();
    final initialInvestmentId = widget.initialInvestmentId;
    if (initialInvestmentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final investment in widget.account.investments) {
          if (investment.id == initialInvestmentId) {
            _openPosition(investment);
            break;
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant StockAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) {
      _repo = InvestmentsRepository(widget.vaultPath);
    }
  }

  @override
  void dispose() {
    _editNameController.dispose();
    _editDescriptionController.dispose();
    super.dispose();
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
    final canHaveBank = supportsBankName(widget.account);
    final name = _commitEditAccountName();
    if (name.isEmpty) return;
    final description = _editDescriptionController.text.trim();
    final updated = widget.account.copyWith(
      name: name,
      envelope: _editEnvelope,
      bankName: canHaveBank ? _editBankName : null,
      description: description.isEmpty ? null : description,
      openingDate: _editOpeningDate,
    );
    await _repo.saveAccount(updated);
    setState(() => _editingAccount = false);
    widget.onChanged();
  }

  /// Le nom d'un compte découle de son identité dans le formulaire
  /// d'édition, il n'est pas saisi librement — même règles que
  /// `AccountDetailView`'s `_commitEditAccountName` :
  ///
  /// * épargne — le nom suit la banque sélectionnée ;
  /// * enveloppe avec établissement (Actions & Fonds, assurance-vie,
  ///   "autres" chez un établissement...) — le nom est le type de compte
  ///   (l'enveloppe), mis à jour si on en change, conservé sinon ;
  /// * enveloppe sans établissement (crypto, métaux précieux physiques) —
  ///   le nom reste saisi librement.
  String _commitEditAccountName() {
    final isEpargne = widget.account.assetClass == AssetClass.epargne;
    if (isEpargne) return _editBankName ?? widget.account.name;
    final requiresEstablishment = assetClassRequiresEstablishmentStep(
      widget.account.assetClass,
    );
    if (requiresEstablishment) {
      final envelopeChanged = _editEnvelope != widget.account.envelope;
      return envelopeChanged
          ? (_editEnvelope?.label ?? widget.account.name)
          : widget.account.name;
    }
    return _editNameController.text.trim();
  }

  // "Autres" (montres, voitures de collection, art...) a aussi ses
  // documents par transaction (voir `_usesTransactionScopedDocuments` dans
  // `position_detail_dialog.dart`/`account_transactions_tab.dart`), mais un
  // onglet Documents général reste utile pour des pièces qui ne rattachent
  // à aucune transaction précise (facture globale, certificat
  // d'authenticité, attestation d'assurance...) — les deux coexistent, comme
  // pour Actions & Fonds. Seuls les métaux précieux restent exclusivement
  // scopés à la transaction.
  bool get _showDocumentsTab =>
      widget.account.assetClass != AssetClass.metauxPrecieux;

  /// Classe à laquelle restreindre l'affichage — [StockAccountScreen
  /// .restrictToAssetClass], sauf si l'utilisateur a ponctuellement demandé
  /// à tout voir (voir [_showAllClasses] et le bouton discret sous
  /// l'en-tête), auquel cas plus aucun filtre ne s'applique.
  AssetClass? get _effectiveRestrictToAssetClass =>
      _showAllClasses ? null : widget.restrictToAssetClass;

  /// Sous-ensemble affiché des positions du compte (voir
  /// [_effectiveRestrictToAssetClass]) — `null` sans restriction, pour ne
  /// rien changer au comportement par défaut des composants d'affichage. Ne
  /// sert jamais aux opérations d'écriture, qui restent toutes basées sur
  /// `widget.account.investments` en intégralité.
  List<Investment>? get _visibleInvestments {
    final restrict = _effectiveRestrictToAssetClass;
    if (restrict == null) return null;
    return [
      for (final i in widget.account.investments)
        if ((i.assetClass ?? widget.account.assetClass) == restrict) i,
    ];
  }

  /// Positions masquées par [StockAccountScreen.restrictToAssetClass] (donc
  /// jamais affectées par [_showAllClasses], contrairement à
  /// [_visibleInvestments] — il s'agit ici de savoir si le bouton "Afficher
  /// tout le compte" a une raison d'exister, pas de ce qui est affiché
  /// maintenant). Vide si le compte n'est pas restreint : rien à révéler,
  /// pas de bouton.
  List<Investment> get _hiddenInvestments {
    final restrict = widget.restrictToAssetClass;
    if (restrict == null) return const [];
    return [
      for (final i in widget.account.investments)
        if ((i.assetClass ?? widget.account.assetClass) != restrict) i,
    ];
  }

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

  Future<void> _importIbkrStatement() async {
    await showIbkrImportDialog(
      context,
      vaultPath: widget.vaultPath,
      account: widget.account,
      onImported: widget.onChanged,
    );
  }

  /// "Exclure du patrimoine"/"Réintégrer au patrimoine" du menu "⋮" — comme
  /// `position_detail_dialog.dart`'s équivalent par investissement, mais
  /// pour le compte entier d'un coup (voir `InvestmentAccount.
  /// excludedFromPatrimoine`).
  Future<void> _toggleExcludedFromPatrimoine() async {
    await _repo.saveAccount(
      widget.account.copyWith(
        excludedFromPatrimoine: !widget.account.excludedFromPatrimoine,
      ),
    );
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
            MenuButton(
              leading: Icon(
                widget.account.excludedFromPatrimoine
                    ? LucideIcons.eye
                    : LucideIcons.eyeOff,
                size: 14,
              ),
              child: shadcn.Text(
                widget.account.excludedFromPatrimoine
                    ? 'Réintégrer au patrimoine'
                    : 'Exclure du patrimoine',
              ),
              onPressed: (_) => _toggleExcludedFromPatrimoine(),
            ),
            // Relevé de courtier (titres/dividendes) : le format IBKR est
            // celui d'un CTO — un PEA/PEA-PME a une fiscalité et des
            // mouvements différents, non couverts par ce parseur.
            if (widget.account.envelope == AccountEnvelope.cto)
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

  void _openPosition(Investment investment) {
    showPositionDetailDialog(
      context,
      vaultPath: widget.vaultPath,
      account: widget.account,
      investment: investment,
      hidden: widget.hidden,
      onChanged: () async => widget.onChanged(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;

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
            AccountEditForm(
              assetClass: account.assetClass,
              nameController: _editNameController,
              showNameField: !assetClassRequiresEstablishmentStep(
                account.assetClass,
              ),
              bankNames: widget.bankNames,
              bankName: _editBankName,
              onBankNameChanged: (v) => setState(() => _editBankName = v),
              showBankField: supportsBankName(account),
              descriptionController: _editDescriptionController,
              openingDate: _editOpeningDate,
              showOpeningDateField: accountHasOpeningDate(account.assetClass),
              onOpeningDateChanged: (date) => setState(
                () => _editOpeningDate = date == null
                    ? null
                    : DateTime(date.year, date.month, date.day),
              ),
              envelope: _editEnvelope!,
              onEnvelopeChanged: (e) => setState(() => _editEnvelope = e),
              onSave: _commitEditAccount,
              onCancel: () => setState(() => _editingAccount = false),
            )
          else ...[
            AccountSummaryHeader(
              account: account,
              hidden: widget.hidden,
              visibleInvestments: _visibleInvestments,
            ),
            if (_hiddenInvestments.isNotEmpty) ...[
              const SizedBox(height: 6),
              _ShowAllClassesToggle(
                hiddenCount: _hiddenInvestments.length,
                expanded: _showAllClasses,
                onPressed: () =>
                    setState(() => _showAllClasses = !_showAllClasses),
              ),
            ],
          ],
          const SizedBox(height: 24),
          TabList(
            index: _tabIndex,
            onChanged: (value) => setState(() => _tabIndex = value),
            children: [
              const TabItem(child: shadcn.Text('Positions')),
              const TabItem(child: shadcn.Text('Transactions')),
              // Pour les métaux précieux, chaque document doit être
              // rattaché à une transaction précise d'une position (voir
              // `PositionDetailDialog`/`AccountTransactionsTab`) — pas
              // d'onglet Documents général pour cette classe. Les autres
              // (dont "Autres", qui a aussi des documents par transaction)
              // ont les deux : cet onglet pour les documents généraux
              // (facture globale, certificat...) en plus.
              if (_showDocumentsTab)
                const TabItem(child: shadcn.Text('Documents')),
            ],
          ),
          const SizedBox(height: 16),
          if (_tabIndex == 0)
            PositionsTable(
              account: account,
              hidden: widget.hidden,
              onTap: _openPosition,
              vaultPath: widget.vaultPath,
              onChanged: () async => widget.onChanged(),
              visibleInvestments: _visibleInvestments,
            )
          else if (_tabIndex == 1)
            AccountTransactionsTab(
              vaultPath: widget.vaultPath,
              account: account,
              hidden: widget.hidden,
              onChanged: () async => widget.onChanged(),
              restrictToAssetClass: _effectiveRestrictToAssetClass,
            )
          else if (_tabIndex == 2 && _showDocumentsTab)
            DocumentsSection(
              vaultPath: widget.vaultPath,
              documents: account.documents,
              quantityAssetClass: account.assetClass,
              onAdd: _addDocument,
              onDelete: _deleteDocument,
            ),
        ],
      ),
    );
  }
}

/// Bouton discret affiché sous l'en-tête quand [StockAccountScreen
/// .restrictToAssetClass] masque des positions (voir
/// `_StockAccountScreenState._hiddenInvestments`) — permet de révéler
/// ponctuellement tout le contenu du compte plutôt que de rester restreint
/// à la catégorie parcourue en permanence, sans jamais changer les données
/// elles-mêmes (voir la doc de [StockAccountScreen.restrictToAssetClass]).
class _ShowAllClassesToggle extends StatelessWidget {
  final int hiddenCount;
  final bool expanded;
  final VoidCallback onPressed;

  const _ShowAllClassesToggle({
    required this.hiddenCount,
    required this.expanded,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GhostButton(
      size: ButtonSize.small,
      density: ButtonDensity.compact,
      onPressed: onPressed,
      leading: Icon(
        expanded ? LucideIcons.eyeOff : LucideIcons.eye,
        size: 12,
      ),
      child: shadcn.Text(
        expanded
            ? 'Masquer le reste du compte'
            : 'Afficher tout le compte (+$hiddenCount)',
      ).muted().xSmall(),
    );
  }
}

import 'dart:async' show unawaited;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart' show displayEuros;
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../../l10n/app_localizations.dart';
import '../dashboard/patrimoine_models.dart';
import '../dashboard/widgets/allocation_card.dart';
import '../dashboard/widgets/category_breakdown_card.dart';
import '../investments/account_detail_screen.dart' show AccountDetailView, BackHeader;
import '../investments/investment_detail_screen.dart';
import '../investments/investments_models.dart';
import '../investments/investments_repository.dart';
import '../investments/patrimoine_refresh_controller.dart';
import '../investments/real_patrimoine_adapter.dart'
    show
        assetClassHistoriesFor,
        buildAllRealCategories,
        buildRealCategories,
        buildRealCategoriesByAccount,
        earliestOfDates,
        earliestTransactionDateAcrossAccounts,
        loadAllPriceHistories;
import '../investments/real_patrimoine_card.dart';
import '../investments/stock_account_screen.dart';
import '../investments/yahoo_finance_client.dart' show PricePoint;
import '../liabilities/liabilities_models.dart';
import '../liabilities/liabilities_repository.dart';
import '../liabilities/liability_detail_view.dart';
import '../liabilities/real_passifs_adapter.dart'
    show
        buildAllRealPassifCategories,
        buildRealPassifCategories,
        earliestLiabilityStart,
        totalPassifHistoryFor;
import 'entities_models.dart';
import 'entities_repository.dart';
import 'entity_ownership_summary.dart';

/// Détail d'une [BusinessEntity] — deux onglets :
/// - "Aperçu" : graphique "Patrimoine" + Allocation, puis les VRAIS comptes/
///   passifs de l'entité (voir `InvestmentAccount.entityId`/
///   `Liability.entityId`) regroupés par catégorie via [CategoryBreakdownCard]
///   (mêmes cartes Placements/Dettes que le patrimoine personnel), plus une
///   éventuelle section "Entreprises détenues" si cette entité est elle-même
///   propriétaire d'autres entités (voir [_openSubEntity]).
/// - "Bilan" : un vrai bilan comptable (voir [_BalanceSheetView]) — TOUTES
///   les catégories d'actif/passif réelles, remplies ou à 0 € selon la
///   situation, jamais un bilan saisi librement (voir la doc de tête
///   d'`entities_models.dart`).
///
/// Cliquer un compte/investissement/passif ouvre en local (même principe
/// que `real_category_detail_screen.dart`/`real_passif_detail_screen.dart`,
/// pas de `Navigator.push`) sa page de détail dédiée —
/// `StockAccountScreen`/`AccountDetailView` pour un compte (selon sa classe
/// d'actif), `LiabilityDetailView` pour un passif. Pour ajouter un compte/
/// passif à cette entité, l'utilisateur repasse par le flux "Compléter mon
/// patrimoine" (choix de l'entité à l'étape 1) — cet écran est un écran de
/// consultation/gestion, pas un point de création.
class EntityDetailScreen extends StatefulWidget {
  final String vaultPath;
  final BusinessEntity entity;
  final AmountVisibilityController amountVisibility;
  final PatrimoineRefreshController patrimoineRefreshController;

  /// Nom du profil actif — voir `InvestmentDetailView.profileName`.
  final String profileName;

  /// Referme cette page (voir [BackHeader]) — fourni par l'appelant
  /// (`dashboard_screen.dart`'s `_openEntityDetail`, `entities_screen.dart`'s
  /// `_openEntity`, ou cette même classe pour une entité détenue ouverte en
  /// local, voir [_EntityDetailScreenState._openSubEntity]) : cet écran ne
  /// sait pas lui-même vers quoi revenir.
  final VoidCallback onBack;

  const EntityDetailScreen({
    super.key,
    required this.vaultPath,
    required this.entity,
    required this.amountVisibility,
    required this.patrimoineRefreshController,
    required this.profileName,
    required this.onBack,
  });

  @override
  State<EntityDetailScreen> createState() => _EntityDetailScreenState();
}

class _EntityDetailScreenState extends State<EntityDetailScreen> {
  late InvestmentsRepository _accountsRepo;
  late LiabilitiesRepository _liabilitiesRepo;
  late EntityRepository _entitiesRepo;
  bool _loading = true;
  bool _loadError = false;
  List<InvestmentAccount> _accounts = [];
  List<Liability> _liabilities = [];
  Map<String, List<PricePoint>> _priceHistories = {};

  /// Toutes les entités du coffre-fort — pour résoudre le nom du (ou des)
  /// propriétaire(s) de [EntityDetailScreen.entity] dans l'en-tête (voir
  /// `entityOwnershipSummary`), qui peut être détenue en partie via
  /// d'autres entités.
  Map<String, BusinessEntity> _entitiesById = {};

  /// Date la plus ancienne parmi les comptes/passifs de cette entité — pour
  /// borner la période "Tout" du graphique "Patrimoine" (voir
  /// [_actifsHistoryFor]), même principe que `dashboard_screen.dart`'s
  /// `_earliest` côté personnel.
  DateTime? _earliest;

  /// Période du graphique "Patrimoine" de l'onglet Aperçu — propre à cet
  /// écran, indépendante de celle du Dashboard.
  int _periodIndex = 5;

  /// Onglet actif : Aperçu (comptes/passifs, graphique, allocation) ou
  /// Bilan (tableau comptable Actif/Passif, voir [_BalanceSheetView]).
  int _tabIndex = 0;

  String? _selectedAccountId;
  String? _selectedInvestmentId;
  String? _selectedLiabilityId;

  /// Entité détenue par [EntityDetailScreen.entity] ouverte en local (voir
  /// la section "Entreprises détenues") — recursion sur cette même classe
  /// plutôt qu'un écran dédié, même principe "local swap" que le reste de
  /// l'app. `null` tant qu'on est sur la vue normale de cette entité.
  BusinessEntity? _openSubEntity;

  @override
  void initState() {
    super.initState();
    _accountsRepo = InvestmentsRepository(widget.vaultPath);
    _liabilitiesRepo = LiabilitiesRepository(widget.vaultPath);
    _entitiesRepo = EntityRepository(widget.vaultPath);
    // Un compte/passif de cette entité peut être créé ailleurs (le flux
    // "Compléter mon patrimoine" reste accessible depuis n'importe quelle
    // page) pendant que cet écran reste ouvert.
    widget.patrimoineRefreshController.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    widget.patrimoineRefreshController.removeListener(_reload);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    await _reload();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _reload() async {
    try {
      final allAccounts = await _accountsRepo.listAll();
      final allLiabilities = await _liabilitiesRepo.listAll();
      final allEntities = await _entitiesRepo.listAll();
      final accounts = allAccounts
          .where((a) => a.entityId == widget.entity.id)
          .toList();
      final priceHistories = await loadAllPriceHistories(
        widget.vaultPath,
        accounts,
      );
      final liabilities = allLiabilities
          .where((l) => l.entityId == widget.entity.id)
          .toList();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _liabilities = liabilities;
        _priceHistories = priceHistories;
        _entitiesById = {for (final e in allEntities) e.id: e};
        _earliest = earliestOfDates(
          earliestTransactionDateAcrossAccounts(accounts),
          earliestLiabilityStart(liabilities),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  Future<void> _refresh() => _reload();

  InvestmentAccount? get _selectedAccount {
    final id = _selectedAccountId;
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Investment? get _selectedInvestment {
    final account = _selectedAccount;
    final id = _selectedInvestmentId;
    if (account == null || id == null) return null;
    for (final investment in account.investments) {
      if (investment.id == id) return investment;
    }
    return null;
  }

  Liability? get _selectedLiability {
    final id = _selectedLiabilityId;
    if (id == null) return null;
    for (final liability in _liabilities) {
      if (liability.id == id) return liability;
    }
    return null;
  }

  /// Ouvre l'investissement [investmentId] (voir la carte "Placements" de
  /// l'onglet Aperçu, mode "Par investissement") en retrouvant son compte
  /// porteur — [_selectedInvestment] a besoin des deux ids, alors que
  /// [CategoryBreakdownCard.onAccountTap] n'en fournit qu'un. Ne fait rien
  /// si introuvable (ex. l'id `merged_$isin` d'un même titre détenu dans
  /// plusieurs comptes de cette entité, voir
  /// `real_patrimoine_adapter.dart`'s `_buildMergedInvestmentLeaf` — cas
  /// suffisamment rare pour ne pas justifier un second point d'ouverture).
  void _openInvestmentById(String investmentId) {
    for (final account in _accounts) {
      for (final investment in account.investments) {
        if (investment.id == investmentId) {
          setState(() {
            _selectedAccountId = account.id;
            _selectedInvestmentId = investmentId;
          });
          return;
        }
      }
    }
  }

  List<String> get _bankNames {
    final names = <String>{};
    for (final account in _accounts) {
      final bankName = account.bankName;
      if (bankName != null && bankName.isNotEmpty) names.add(bankName);
    }
    return names.toList()..sort();
  }

  /// Historique "Patrimoine net/brut" de cette entité — même fonction
  /// partagée que le Dashboard (`dashboard_screen.dart`'s
  /// `_actifsHistoryFor`) et sa section Entités
  /// (`EntitiesOverviewSection`'s `_EntitySection`), juste appliquée aux
  /// comptes propres à cette entité.
  Map<String, List<NetWorthPoint>> _actifsHistoryFor(DashboardPeriod period) =>
      assetClassHistoriesFor(_accounts, _priceHistories, period, _earliest);

  List<NetWorthPoint> _totalPassifHistoryFor(DashboardPeriod period) =>
      totalPassifHistoryFor(_liabilities, period, _earliest);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError) {
      return LoadErrorView(
        message: l10n.entities_detail_load_error,
        onRetry: _load,
      );
    }

    final hidden = widget.amountVisibility.hidden;
    final account = _selectedAccount;
    final investment = _selectedInvestment;
    final liability = _selectedLiability;

    if (account != null && account.assetClass != AssetClass.immobilier) {
      return StockAccountScreen(
        vaultPath: widget.vaultPath,
        account: account,
        hidden: hidden,
        bankNames: _bankNames,
        priceHistories: _priceHistories,
        initialInvestmentId: investment?.id,
        onBack: () => setState(() {
          _selectedAccountId = null;
          _selectedInvestmentId = null;
        }),
        onChanged: () => unawaited(_refresh()),
      );
    }
    if (account != null && investment != null) {
      return InvestmentDetailView(
        vaultPath: widget.vaultPath,
        account: account,
        investment: investment,
        hidden: hidden,
        onBack: () => setState(() => _selectedInvestmentId = null),
        onChanged: _refresh,
        profileName: widget.profileName,
        patrimoineRefreshController: widget.patrimoineRefreshController,
      );
    }
    if (account != null) {
      return AccountDetailView(
        vaultPath: widget.vaultPath,
        account: account,
        hidden: hidden,
        bankNames: _bankNames,
        onBack: () => setState(() => _selectedAccountId = null),
        onOpenInvestment: (id) => setState(() => _selectedInvestmentId = id),
        onChanged: _refresh,
      );
    }
    if (liability != null) {
      return LiabilityDetailView(
        vaultPath: widget.vaultPath,
        liability: liability,
        hidden: hidden,
        onBack: () => setState(() => _selectedLiabilityId = null),
        onChanged: _refresh,
      );
    }
    final subEntity = _openSubEntity;
    if (subEntity != null) {
      return EntityDetailScreen(
        key: ValueKey(subEntity.id),
        vaultPath: widget.vaultPath,
        entity: subEntity,
        amountVisibility: widget.amountVisibility,
        patrimoineRefreshController: widget.patrimoineRefreshController,
        profileName: widget.profileName,
        onBack: () => setState(() => _openSubEntity = null),
      );
    }

    // Entités détenues DIRECTEMENT par celle-ci (voir `OwnershipStake
    // .ownerId`) — une entité à détention mixte détenue en partie par cette
    // entité ET en partie ailleurs apparaît quand même ici, cette section ne
    // reflète qu'un lien de détention, pas la hiérarchie d'affichage à
    // propriétaire unique de `orderedEntityHierarchy`.
    final ownedEntities = [
      for (final e in _entitiesById.values)
        if (e.stakes.any((s) => s.ownerId == widget.entity.id)) e,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackHeader(label: widget.entity.name, onBack: widget.onBack),
          const SizedBox(height: 4),
          shadcn.Text(
            '${widget.entity.type.label} · '
            '${entityOwnershipSummary(l10n, widget.entity, _entitiesById)}',
          ).muted().small(),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TabList(
              index: _tabIndex,
              onChanged: (value) => setState(() => _tabIndex = value),
              children: [
                TabItem(child: shadcn.Text(l10n.entities_tab_overview)),
                TabItem(child: shadcn.Text(l10n.entities_tab_balance_sheet)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_tabIndex == 1)
            _BalanceSheetView(
              accounts: _accounts,
              liabilities: _liabilities,
              priceHistories: _priceHistories,
              vaultPath: widget.vaultPath,
              hidden: hidden,
            )
          else ...[
            if (ownedEntities.isNotEmpty) ...[
              shadcn.Text(
                l10n.entities_owned_companies_section_title,
              ).large().medium(),
              const SizedBox(height: 8),
              for (final owned in ownedEntities) ...[
                _OwnedEntityRow(
                  entity: owned,
                  stakePercent: owned.stakes
                      .firstWhere((s) => s.ownerId == widget.entity.id)
                      .percent,
                  onTap: () => setState(() => _openSubEntity = owned),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 800;
                final avoirsByAccount = buildRealCategoriesByAccount(
                  _accounts,
                  _priceHistories,
                  widget.vaultPath,
                );
                final avoirsByInvestment = buildRealCategories(
                  _accounts,
                  _priceHistories,
                  widget.vaultPath,
                );
                final dettes = buildRealPassifCategories(_liabilities);
                final patrimoineCard = RealPatrimoineCard(
                  actifs: avoirsByInvestment,
                  actifsHistoryFor: _actifsHistoryFor,
                  totalPassifHistoryFor: _totalPassifHistoryFor,
                  hidden: hidden,
                  periodIndex: _periodIndex,
                  onPeriodChanged: (i) => setState(() => _periodIndex = i),
                );
                final allocationCard = AllocationCard(
                  actifs: avoirsByInvestment,
                  passifs: dettes,
                  hidden: hidden,
                );
                final period = DashboardPeriod.values[_periodIndex];
                if (narrow) {
                  return Column(
                    children: [
                      SizedBox(height: 460, child: patrimoineCard),
                      const SizedBox(height: 16),
                      SizedBox(height: 320, child: allocationCard),
                      const SizedBox(height: 16),
                      CategoryBreakdownCard(
                        title: l10n.dashboard_assets_label,
                        categories: avoirsByAccount,
                        categoriesByInvestment: avoirsByInvestment,
                        hidden: hidden,
                        showPru: false,
                        period: period,
                        onAccountTap: _openInvestmentById,
                      ),
                      const SizedBox(height: 16),
                      CategoryBreakdownCard(
                        title: l10n.dashboard_liabilities_label,
                        categories: dettes,
                        hidden: hidden,
                        showPru: false,
                        period: period,
                        onAccountTap: (id) =>
                            setState(() => _selectedLiabilityId = id),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 460,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 2, child: patrimoineCard),
                          const SizedBox(width: 16),
                          Expanded(child: allocationCard),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CategoryBreakdownCard(
                      title: l10n.dashboard_assets_label,
                      categories: avoirsByAccount,
                      categoriesByInvestment: avoirsByInvestment,
                      hidden: hidden,
                      showPru: false,
                      period: period,
                      onAccountTap: _openInvestmentById,
                    ),
                    const SizedBox(height: 16),
                    CategoryBreakdownCard(
                      title: l10n.dashboard_liabilities_label,
                      categories: dettes,
                      hidden: hidden,
                      showPru: false,
                      period: period,
                      onAccountTap: (id) =>
                          setState(() => _selectedLiabilityId = id),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Ligne d'une entité détenue par celle affichée (voir "Entreprises
/// détenues" dans [_EntityDetailScreenState.build]) — cliquer ouvre son
/// propre détail en local (voir `_openSubEntity`), même comportement que
/// [_EntityAccountRow]/[_EntityLiabilityRow] ci-dessous.
class _OwnedEntityRow extends StatelessWidget {
  final BusinessEntity entity;
  final double stakePercent;
  final VoidCallback onTap;

  const _OwnedEntityRow({
    required this.entity,
    required this.stakePercent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FrostedCard(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(LucideIcons.building2, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shadcn.Text(entity.name).medium(),
                    const SizedBox(height: 2),
                    shadcn.Text(entity.type.label).muted().small(),
                  ],
                ),
              ),
              shadcn.Text(
                l10n.entities_owned_stake_label(_formatStakePercent(stakePercent)),
              ).muted().small(),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronRight, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatStakePercent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

/// Une ligne de bilan (voir [_BalanceSheetSection]) — un libellé et un
/// montant, JAMAIS masquée même à 0 € : un vrai bilan liste toutes ses
/// rubriques standard, remplies ou non selon la situation de l'entité
/// (une SCI n'a par exemple jamais de stocks), plutôt que de faire
/// disparaître celles sans montant.
class _BalanceSheetLine {
  final String label;
  final double amount;

  const _BalanceSheetLine(this.label, this.amount);
}

/// Une rubrique de bilan (ex. "Actif immobilisé", "Dettes") — un sous-total
/// que [_BalanceSheetTable] affiche uniquement quand la rubrique a plus
/// d'une ligne (une rubrique à ligne unique, ex. "Capitaux propres", n'a
/// rien à sous-totaliser : la répéter juste en dessous serait redondant).
class _BalanceSheetSection {
  final String title;
  final List<_BalanceSheetLine> lines;

  const _BalanceSheetSection(this.title, this.lines);

  double get total => lines.fold(0, (sum, line) => sum + line.amount);
}

/// Onglet "Bilan" : un VRAI bilan comptable d'entreprise, Actif et Passif
/// dans deux tableaux structurés par rubriques (voir [_BalanceSheetSection])
/// — pas une simple liste des comptes/passifs existants (voir l'onglet
/// Aperçu juste au-dessus pour ça). Simplifié aux rubriques du Plan
/// Comptable Général qu'une PME/société patrimoniale rencontre le plus
/// souvent (immobilisations, actif circulant, capitaux propres, provisions,
/// dettes) plutôt que la nomenclature complète : ce que l'app peut
/// effectivement renseigner à partir de comptes/passifs réels (voir le
/// mappage dans [build]), le reste (stocks, créances, dettes fournisseurs...)
/// reste à 0 € faute de source de données, mais la rubrique existe quand
/// même — un vrai bilan liste toujours ces lignes standard.
///
/// Un vrai bilan s'équilibre toujours (Total Actif == Total Passif) : les
/// Capitaux propres sont calculés (Actif total − Dettes réelles totales,
/// soit exactement [entityNetValue]), jamais saisis — sans cette ligne, une
/// entité à 100 000 € d'actif sans le moindre emprunt aurait 100 000 €
/// d'Actif pour 0 € de Passif, ce qui n'a pas de sens comptable (voir la
/// doc de tête de `entities_models.dart` — c'est justement pour réserver
/// "Actif"/"Passif" à ce sens strict que le patrimoine personnel a été
/// renommé en "Placements"/"Dettes").
class _BalanceSheetView extends StatelessWidget {
  final List<InvestmentAccount> accounts;
  final List<Liability> liabilities;
  final Map<String, List<PricePoint>> priceHistories;
  final String vaultPath;
  final bool hidden;

  const _BalanceSheetView({
    required this.accounts,
    required this.liabilities,
    required this.priceHistories,
    required this.vaultPath,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Montant réel par classe d'actif/type de passif (voir
    // `buildAllRealCategories`/`buildAllRealPassifCategories`, toujours les
    // 7 classes/2 types réels, à 0 € sans compte/passif) — indexés par
    // `AssetClass`/`LiabilityType` pour les répartir dans les bonnes
    // rubriques du bilan ci-dessous, plutôt que par le nom de compte/passif
    // individuel (voir l'onglet Aperçu pour ce niveau de détail).
    final actifById = {
      for (final c in buildAllRealCategories(accounts, priceHistories, vaultPath))
        c.id: c.montant,
    };
    double forClass(AssetClass ac) => actifById[ac.categoryId] ?? 0;
    final passifById = {
      for (final c in buildAllRealPassifCategories(liabilities)) c.id: c.montant,
    };
    double forType(LiabilityType t) => passifById[t.categoryId] ?? 0;

    // Immobilisations incorporelles, stocks, créances, dettes fournisseurs
    // et dettes fiscales/sociales n'ont aucune source de données dans
    // l'app (pas de compte/passif de ce type) : toujours 0 €, mais la
    // rubrique reste affichée — voir la doc de tête.
    final fixedAssets = _BalanceSheetSection(
      l10n.entities_balance_sheet_fixed_assets_title,
      [
        _BalanceSheetLine(l10n.entities_balance_sheet_intangible_assets, 0),
        _BalanceSheetLine(
          l10n.entities_balance_sheet_tangible_assets,
          forClass(AssetClass.immobilier),
        ),
        _BalanceSheetLine(
          l10n.entities_balance_sheet_financial_assets,
          forClass(AssetClass.privateEquity),
        ),
      ],
    );
    final currentAssets = _BalanceSheetSection(
      l10n.entities_balance_sheet_current_assets_title,
      [
        _BalanceSheetLine(l10n.entities_balance_sheet_inventory, 0),
        _BalanceSheetLine(l10n.entities_balance_sheet_receivables, 0),
        _BalanceSheetLine(
          l10n.entities_balance_sheet_marketable_securities,
          forClass(AssetClass.actionsEtFonds) +
              forClass(AssetClass.crypto) +
              forClass(AssetClass.metauxPrecieux) +
              forClass(AssetClass.autres),
        ),
        _BalanceSheetLine(
          l10n.entities_balance_sheet_cash,
          forClass(AssetClass.epargne),
        ),
      ],
    );
    final totalActif = fixedAssets.total + currentAssets.total;

    final totalDettesReelles = forType(LiabilityType.pretImmobilier) +
        forType(LiabilityType.creditAutre);
    final equity = _BalanceSheetSection(
      l10n.entities_balance_sheet_equity_title,
      [
        _BalanceSheetLine(
          l10n.entities_balance_sheet_equity_title,
          totalActif - totalDettesReelles,
        ),
      ],
    );
    final provisions = _BalanceSheetSection(
      l10n.entities_balance_sheet_provisions_title,
      [_BalanceSheetLine(l10n.entities_balance_sheet_provisions_line, 0)],
    );
    final debts = _BalanceSheetSection(
      l10n.entities_balance_sheet_debts_title,
      [
        _BalanceSheetLine(
          l10n.entities_balance_sheet_financial_debts,
          totalDettesReelles,
        ),
        _BalanceSheetLine(l10n.entities_balance_sheet_trade_payables, 0),
        _BalanceSheetLine(l10n.entities_balance_sheet_tax_and_social_debts, 0),
      ],
    );
    // Total Passif == Total Actif par construction (voir la doc de tête) :
    // affiché depuis `totalActif` directement plutôt que recalculé
    // (equity.total + provisions.total + debts.total, arithmétiquement
    // identique) pour qu'aucun écart d'arrondi ne les distingue jamais à
    // l'écran.

    final actifTable = _BalanceSheetTable(
      title: l10n.entities_balance_sheet_assets_title,
      totalLabel: l10n.entities_balance_sheet_total_assets,
      total: totalActif,
      hidden: hidden,
      sections: [fixedAssets, currentAssets],
    );
    final passifTable = _BalanceSheetTable(
      title: l10n.entities_balance_sheet_liabilities_title,
      totalLabel: l10n.entities_balance_sheet_total_liabilities,
      total: totalActif,
      hidden: hidden,
      sections: [equity, provisions, debts],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              actifTable,
              const SizedBox(height: 16),
              passifTable,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: actifTable),
            const SizedBox(width: 16),
            Expanded(child: passifTable),
          ],
        );
      },
    );
  }
}

class _BalanceSheetTable extends StatelessWidget {
  final String title;
  final String totalLabel;
  final double total;
  final bool hidden;
  final List<_BalanceSheetSection> sections;

  const _BalanceSheetTable({
    required this.title,
    required this.totalLabel,
    required this.total,
    required this.hidden,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shadcn.Text(title).large().semiBold(),
            for (final section in sections) ...[
              const SizedBox(height: 14),
              // Rubrique à ligne unique (ex. "Capitaux propres") : affichée
              // directement comme une ligne de premier rang, sans en-tête
              // ni sous-total séparés — les deux répéteraient exactement le
              // même libellé/montant (voir la doc de
              // [_BalanceSheetSection]). Rubrique à plusieurs lignes (ex.
              // "Actif immobilisé") : en-tête + détail + sous-total.
              if (section.lines.length == 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: shadcn.Text(section.lines.single.label).medium(),
                      ),
                      shadcn.Text(
                        displayEuros(section.lines.single.amount, hidden),
                      ).medium(),
                    ],
                  ),
                )
              else ...[
                shadcn.Text(
                  section.title.toUpperCase(),
                ).muted().xSmall().semiBold(),
                const SizedBox(height: 4),
                for (final line in section.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: shadcn.Text(
                            line.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ).small(),
                        ),
                        const SizedBox(width: 8),
                        shadcn.Text(displayEuros(line.amount, hidden)).small(),
                      ],
                    ),
                  ),
                Container(height: 1, color: theme.colorScheme.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: shadcn.Text(
                          l10n.entities_balance_sheet_subtotal_label(
                            section.title,
                          ),
                        ).small().medium(),
                      ),
                      shadcn.Text(
                        displayEuros(section.total, hidden),
                      ).small().medium(),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Container(height: 2, color: theme.colorScheme.border),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: shadcn.Text(totalLabel).semiBold()),
                shadcn.Text(displayEuros(total, hidden)).semiBold(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


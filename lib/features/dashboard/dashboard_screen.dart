import 'dart:async' show unawaited;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../investments/investments_models.dart'
    show AssetClass, InvestmentAccount;
import '../investments/investments_repository.dart';
import '../investments/patrimoine_refresh_controller.dart';
import '../investments/price_refresh_service.dart';
import '../investments/price_sync_status_controller.dart';
import '../investments/real_patrimoine_adapter.dart';
import '../investments/real_patrimoine_card.dart';
import '../liabilities/liabilities_repository.dart';
import '../liabilities/real_passifs_adapter.dart';
import '../entities/entities_models.dart' show BusinessEntity;
import '../entities/entities_patrimoine_adapter.dart';
import '../entities/entities_repository.dart';
import '../../core/storage/vault_folder_service.dart' show VaultKind;
import 'onboarding_highlight_controller.dart';
import 'patrimoine_models.dart';
import 'widgets/allocation_card.dart';
import 'widgets/category_breakdown_card.dart';
import 'widgets/dashboard_onboarding_view.dart';
import 'widgets/top_assets_row.dart';
import '../investments/yahoo_finance_client.dart' show PricePoint;
import '../liabilities/liabilities_models.dart' show Liability;

/// Tableau de bord : patrimoine (graphique + évolution), allocation, et
/// meilleurs actifs, à partir des comptes de placement réels
/// (`features/investments/`), toujours pour l'intégralité des classes
/// d'actifs (même vides). La création se fait exclusivement via le flux
/// "Compléter mon patrimoine" de la TopBar — voir
/// [PatrimoineRefreshController] pour le signal de rechargement associé.
///
/// C'est aussi ici, à l'ouverture, que les cours de tous les investissements
/// sont résolus/synchronisés en une seule passe (voir
/// `price_refresh_service.dart`) — pas au cas par cas à l'ouverture de
/// chaque investissement comme auparavant — pour que la valorisation et la
/// performance affichées soient déjà à jour dès l'arrivée sur le Dashboard.
class DashboardScreen extends StatelessWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;
  final PatrimoineRefreshController refreshSignal;
  final PriceSyncStatusController priceSyncStatus;
  final OnboardingHighlightController onboardingHighlight;
  final VaultKind vaultKind;

  const DashboardScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
    required this.refreshSignal,
    required this.priceSyncStatus,
    required this.onboardingHighlight,
    this.vaultKind = VaultKind.personal,
  });

  @override
  Widget build(BuildContext context) {
    return _RealDashboard(
      vaultPath: vaultPath,
      amountVisibility: amountVisibility,
      refreshSignal: refreshSignal,
      priceSyncStatus: priceSyncStatus,
      onboardingHighlight: onboardingHighlight,
      vaultKind: vaultKind,
    );
  }
}

class _RealDashboard extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;
  final PatrimoineRefreshController refreshSignal;
  final PriceSyncStatusController priceSyncStatus;
  final OnboardingHighlightController onboardingHighlight;
  final VaultKind vaultKind;

  const _RealDashboard({
    required this.vaultPath,
    required this.amountVisibility,
    required this.refreshSignal,
    required this.priceSyncStatus,
    required this.onboardingHighlight,
    required this.vaultKind,
  });

  @override
  State<_RealDashboard> createState() => _RealDashboardState();
}

class _RealDashboardState extends State<_RealDashboard> {
  late InvestmentsRepository _repo;
  late LiabilitiesRepository _liabilitiesRepo;
  bool _loading = true;
  List<PatrimoineCategory> _categories = [];
  List<PatrimoineCategory> _categoriesByAccount = [];
  List<PatrimoineCategory> _passifCategories = [];

  /// Période partagée entre le graphique "Patrimoine" (`RealPatrimoineCard`)
  /// et les cartes "Actifs"/"Passifs" (`CategoryBreakdownCard`) juste en
  /// dessous — un seul sélecteur, sur le graphique, pilote les deux (voir
  /// `RealPatrimoineCard.periodIndex`/`onPeriodChanged`), plutôt qu'un
  /// sélecteur propre à chaque carte.
  int _periodIndex = 5;
  List<DashboardAsset> _topAssets = [];
  bool _isEverythingEmpty = false;

  // Données brutes retenues (pas seulement les `PatrimoineCategory` qui en
  // découlent) pour que les closures ci-dessous puissent recalculer
  // l'historique "Patrimoine net" à la demande, borné à la période
  // sélectionnée dans `RealPatrimoineCard` — sans relire le disque à
  // chaque changement d'onglet (voir [_actifsHistoryFor]/
  // [_totalPassifHistoryFor], purement en mémoire).
  List<InvestmentAccount> _accounts = [];
  Map<String, List<PricePoint>> _priceHistories = {};
  List<Liability> _liabilities = [];
  DateTime? _earliest;

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    _liabilitiesRepo = LiabilitiesRepository(widget.vaultPath);
    // Un ajout/modification/suppression fait ailleurs dans l'app (une autre
    // page du même profil, ou le flux "Compléter mon patrimoine" de la
    // TopBar) ne change que des données déjà en cache localement — un
    // rechargement disque silencieux suffit, pas besoin de repasser par
    // l'écran de chargement plein cadre ni de relancer toute la
    // synchronisation réseau des cours comme le fait [_load] au premier
    // affichage.
    widget.refreshSignal.addListener(_loadFromDisk);
    _load();
  }

  @override
  void didUpdateWidget(covariant _RealDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) {
      _repo = InvestmentsRepository(widget.vaultPath);
      _liabilitiesRepo = LiabilitiesRepository(widget.vaultPath);
      _load();
    }
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_loadFromDisk);
    // Repart de zéro pour le prochain profil affiché (ce signal ne doit
    // jamais rester actif par erreur pour un autre profil) — voir
    // [OnboardingHighlightController]. Différé via microtask : appeler
    // notifyListeners() en plein dispose() (l'arbre de widgets est
    // verrouillé pendant le démontage) fait planter tout listener qui
    // tente un setState() synchrone en retour (ex : AddMenuButton via
    // AnimatedBuilder, voir top_bar_actions.dart) avec "setState() or
    // markNeedsBuild() called when widget tree was locked".
    final onboardingHighlight = widget.onboardingHighlight;
    Future.microtask(() => onboardingHighlight.setEmpty(false));
    super.dispose();
  }

  /// Charge depuis le disque (aucun appel réseau) et affiche l'écran, puis
  /// lance en tâche de fond la synchronisation des cours (voir
  /// [_refreshFromNetwork]) — ne bloque jamais l'affichage initial sur les
  /// données déjà en cache, potentiellement lentes à rafraîchir (autant
  /// d'investissements à résoudre/interroger).
  Future<void> _load() async {
    setState(() => _loading = true);
    await _loadFromDisk();
    if (!mounted) return;
    setState(() => _loading = false);
    unawaited(_refreshFromNetwork());
  }

  Future<void> _loadFromDisk() async {
    final allAccounts = await _repo.listAll();
    final priceHistories = await loadAllPriceHistories(
      widget.vaultPath,
      allAccounts,
    );
    final allLiabilities = await _liabilitiesRepo.listAll();
    // Uniquement pour un coffre-fort professionnel (voir `VaultKind`) — un
    // coffre-fort personnel n'a pas accès au module Entités, inutile de
    // lire un fichier qui n'existe jamais pour lui.
    final entities = widget.vaultKind == VaultKind.professional
        ? await EntityRepository(widget.vaultPath).listAll()
        : const <BusinessEntity>[];
    if (!mounted) return;
    // Un compte/passif rattaché à une entité (`entityId` non nul) est
    // consolidé sous "Entités professionnelles" (voir `entities_patrimoine
    // _adapter.dart`), pas sous les catégories personnelles habituelles —
    // sinon il compterait deux fois dans le patrimoine net affiché.
    final accounts = allAccounts.where((a) => a.entityId == null).toList();
    final liabilities = allLiabilities
        .where((l) => l.entityId == null)
        .toList();
    // Aucun compte avec au moins un investissement, aucun passif, et aucune
    // entité professionnelle : rien à montrer dans les cartes habituelles,
    // voir [DashboardOnboardingView] et [OnboardingHighlightController] —
    // sans le `entities.isEmpty` ici, un coffre-fort professionnel qui n'a
    // encore saisi QUE des entités (aucun compte/passif personnel) verrait
    // à tort l'écran d'accueil vide plutôt que sa catégorie Entités.
    final isEverythingEmpty =
        accounts.every((a) => a.investments.isEmpty) &&
        liabilities.isEmpty &&
        entities.isEmpty;
    widget.onboardingHighlight.setEmpty(isEverythingEmpty);
    setState(() {
      _isEverythingEmpty = isEverythingEmpty;
      _accounts = accounts;
      _priceHistories = priceHistories;
      _liabilities = liabilities;
      _earliest = _earliestOf(
        earliestTransactionDateAcrossAccounts(accounts),
        earliestLiabilityStart(liabilities),
      );
      // Une seule ligne par entité (pas de distinction "par compte/par
      // investissement" comme pour les classes réelles) : la même catégorie
      // sert aux deux vues. Comptes/passifs rattachés à une entité
      // (`entityId` non nul), pas ceux déjà filtrés ci-dessus.
      final entityAccounts = allAccounts
          .where((a) => a.entityId != null)
          .toList();
      final entityLiabilities = allLiabilities
          .where((l) => l.entityId != null)
          .toList();
      final entitiesCategory = entities.isEmpty
          ? null
          : buildEntitiesCategory(entities, entityAccounts, entityLiabilities);
      _categories = [
        ...buildAllRealCategories(accounts, priceHistories, widget.vaultPath),
        ?entitiesCategory,
      ];
      _categoriesByAccount = [
        ...buildAllRealCategoriesByAccount(
          accounts,
          priceHistories,
          widget.vaultPath,
        ),
        ?entitiesCategory,
      ];
      _topAssets = buildRealTopAssets(accounts, priceHistories);
      _passifCategories = buildAllRealPassifCategories(liabilities);
    });
  }

  static DateTime? _earliestOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  /// Historique "Patrimoine net"/"Patrimoine brut" par classe d'actif pour
  /// une période donnée — voir `RealPatrimoineCard.actifsHistoryFor`.
  /// Recalculé à la demande à partir des données déjà en mémoire (aucune
  /// E/S), à chaque changement d'onglet de période. C'est le seul endroit du
  /// Dashboard qui exclut les investissements/comptes marqués "exclus du
  /// patrimoine" (`excludeFlagged: true`, voir
  /// [investmentsForEffectiveClass]) — les pages de catégorie continuent de
  /// tout comptabiliser.
  ///
  /// Ajoute [leveragedValueForEffectiveClass] à chaque point :
  /// [categoryHistoryOnGrid] seul ne lit jamais `InvestmentAccount
  /// .leveragedPositions` (aucun historique de cours pour ces positions,
  /// voir sa doc) — sans cet ajout, le dernier point de cette courbe (le
  /// total "Patrimoine brut" affiché) ne correspondait pas à celui de la
  /// carte Allocation ([PatrimoineCategory.montantPatrimoine], qui les
  /// compte déjà) dès qu'une position à effet de levier était ouverte.
  Map<String, List<NetWorthPoint>> _actifsHistoryFor(DashboardPeriod period) {
    final today = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final earliest = _earliest ?? today;
    final start = period.startFor(today: today, earliest: earliest);
    final grid = evenDateGrid(start, today);
    return {
      for (final assetClass in AssetClass.values)
        assetClass.categoryId: [
          for (final point in categoryHistoryOnGrid(
            investmentsForEffectiveClass(
              _accounts,
              assetClass,
              excludeFlagged: true,
            ),
            _priceHistories,
            grid,
          ))
            NetWorthPoint(
              point.date,
              point.value +
                  leveragedValueForEffectiveClass(
                    _accounts,
                    assetClass,
                    point.date,
                    excludeFlagged: true,
                  ),
            ),
        ],
    };
  }

  /// Comme [_actifsHistoryFor], côté passifs — même grille (même [_earliest],
  /// même période) pour que la soustraction actifs − passifs de
  /// `buildPatrimoineChartData` reste alignée terme à terme.
  List<NetWorthPoint> _totalPassifHistoryFor(DashboardPeriod period) {
    final today = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final earliest = _earliest ?? today;
    final start = period.startFor(today: today, earliest: earliest);
    final grid = evenDateGrid(start, today);
    return totalBalanceOnGrid(_liabilities, grid);
  }

  /// Résout/synchronise le cours de tous les investissements du vault (voir
  /// `price_refresh_service.dart`), puis recharge depuis le disque pour
  /// refléter les cours fraîchement écrits — sans redéclencher elle-même
  /// une nouvelle synchronisation réseau (contrairement à [_load]).
  Future<void> _refreshFromNetwork() async {
    final accounts = await _repo.listAll();
    await refreshAllPrices(
      vaultPath: widget.vaultPath,
      accounts: accounts,
      repo: _repo,
      priceSyncStatus: widget.priceSyncStatus,
    );
    if (!mounted) return;
    await _loadFromDisk();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isEverythingEmpty) {
      return const DashboardOnboardingView();
    }
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: widget.amountVisibility,
      builder: (context, _) {
        final hidden = widget.amountVisibility.hidden;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 800;
                  final patrimoineCard = RealPatrimoineCard(
                    actifs: _categories,
                    actifsHistoryFor: _actifsHistoryFor,
                    totalPassifHistoryFor: _totalPassifHistoryFor,
                    hidden: hidden,
                    periodIndex: _periodIndex,
                    onPeriodChanged: (i) => setState(() => _periodIndex = i),
                  );
                  final allocationCard = AllocationCard(
                    actifs: _categories,
                    passifs: _passifCategories,
                    hidden: hidden,
                  );
                  if (narrow) {
                    return Column(
                      children: [
                        SizedBox(height: 460, child: patrimoineCard),
                        const SizedBox(height: 16),
                        SizedBox(height: 320, child: allocationCard),
                      ],
                    );
                  }
                  return SizedBox(
                    height: 460,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: patrimoineCard),
                        const SizedBox(width: 16),
                        Expanded(child: allocationCard),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              if (_topAssets.isNotEmpty) ...[
                TopAssetsRow(
                  assets: _topAssets,
                  hidden: hidden,
                  period: DashboardPeriod.values[_periodIndex],
                ),
                const SizedBox(height: 24),
              ],
              CategoryBreakdownCard(
                title: l10n.dashboard_assets_label,
                categories: _categoriesByAccount,
                categoriesByInvestment: _categories,
                hidden: hidden,
                // Le PRU reste visible sur les pages de détail de chaque
                // classe d'actif, pas ici : la vue agrégée du Dashboard
                // montre uniquement valeur, évolution et +/- value.
                showPru: false,
                period: DashboardPeriod.values[_periodIndex],
              ),
              const SizedBox(height: 16),
              CategoryBreakdownCard(
                title: l10n.dashboard_liabilities_label,
                categories: _passifCategories,
                hidden: hidden,
                showPru: false,
                period: DashboardPeriod.values[_periodIndex],
              ),
            ],
          ),
        );
      },
    );
  }
}

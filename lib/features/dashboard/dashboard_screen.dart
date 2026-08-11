import 'dart:async' show unawaited;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../investments/investments_models.dart' show AssetClass;
import '../investments/investments_repository.dart';
import '../investments/patrimoine_refresh_controller.dart';
import '../investments/price_refresh_service.dart';
import '../investments/price_sync_status_controller.dart';
import '../investments/real_patrimoine_adapter.dart';
import '../investments/real_patrimoine_card.dart';
import '../liabilities/liabilities_repository.dart';
import '../liabilities/real_passifs_adapter.dart';
import 'dashboard_dummy_data.dart';
import 'onboarding_highlight_controller.dart';
import 'widgets/allocation_card.dart';
import 'widgets/category_breakdown_card.dart';
import 'widgets/dashboard_onboarding_view.dart';
import 'widgets/patrimoine_card.dart';
import 'widgets/top_assets_row.dart';

/// Tableau de bord : patrimoine (graphique + évolution), allocation, et
/// meilleurs actifs — même structure visuelle pour tout le monde. Le
/// profil "Lou" ([isDemoProfile]) voit des données d'exemple
/// ([dashboardSampleData]) ; tout autre profil voit ses propres comptes de
/// placement réels (`features/investments/`), toujours pour l'intégralité
/// des classes d'actifs (même vides). La création se fait exclusivement
/// via le flux "Compléter mon patrimoine" de la TopBar — voir
/// [PatrimoineRefreshController] pour le signal de rechargement associé.
///
/// C'est aussi ici, à l'ouverture, que les cours de tous les investissements
/// sont résolus/synchronisés en une seule passe (voir
/// `price_refresh_service.dart`) — pas au cas par cas à l'ouverture de
/// chaque investissement comme auparavant — pour que la valorisation et la
/// performance affichées soient déjà à jour dès l'arrivée sur le Dashboard.
class DashboardScreen extends StatelessWidget {
  final String vaultPath;
  final bool isDemoProfile;
  final AmountVisibilityController amountVisibility;
  final PatrimoineRefreshController refreshSignal;
  final PriceSyncStatusController priceSyncStatus;
  final OnboardingHighlightController onboardingHighlight;

  const DashboardScreen({
    super.key,
    required this.vaultPath,
    required this.isDemoProfile,
    required this.amountVisibility,
    required this.refreshSignal,
    required this.priceSyncStatus,
    required this.onboardingHighlight,
  });

  @override
  Widget build(BuildContext context) {
    if (isDemoProfile) {
      return _DemoDashboard(amountVisibility: amountVisibility);
    }
    return _RealDashboard(
      vaultPath: vaultPath,
      amountVisibility: amountVisibility,
      refreshSignal: refreshSignal,
      priceSyncStatus: priceSyncStatus,
      onboardingHighlight: onboardingHighlight,
    );
  }
}

class _DemoDashboard extends StatelessWidget {
  final AmountVisibilityController amountVisibility;

  const _DemoDashboard({required this.amountVisibility});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: amountVisibility,
      builder: (context, _) {
        final hidden = amountVisibility.hidden;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 800;
              final patrimoineCard = PatrimoineCard(
                data: dashboardSampleData,
                hidden: hidden,
              );
              final allocationCard = AllocationCard(
                actifs: dashboardActifsCategories,
                passifs: dashboardPassifsCategories,
                hidden: hidden,
              );

              final topRow = narrow
                  ? Column(
                      children: [
                        SizedBox(height: 460, child: patrimoineCard),
                        const SizedBox(height: 16),
                        SizedBox(height: 320, child: allocationCard),
                      ],
                    )
                  : SizedBox(
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  topRow,
                  const SizedBox(height: 24),
                  TopAssetsRow(assets: dashboardSampleData.topAssets),
                  const SizedBox(height: 24),
                  CategoryBreakdownCard(
                    title: 'Actifs',
                    categories: dashboardActifsCategories,
                    hidden: hidden,
                    // Le PRU reste visible sur les pages de détail de
                    // chaque classe d'actif, pas ici : la vue agrégée du
                    // Dashboard montre uniquement montant et évolution.
                    showPru: false,
                  ),
                  const SizedBox(height: 16),
                  CategoryBreakdownCard(
                    title: 'Passifs',
                    categories: dashboardPassifsCategories,
                    hidden: hidden,
                    showPru: false,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _RealDashboard extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;
  final PatrimoineRefreshController refreshSignal;
  final PriceSyncStatusController priceSyncStatus;
  final OnboardingHighlightController onboardingHighlight;

  const _RealDashboard({
    required this.vaultPath,
    required this.amountVisibility,
    required this.refreshSignal,
    required this.priceSyncStatus,
    required this.onboardingHighlight,
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
  List<DashboardAsset> _topAssets = [];
  Map<String, List<NetWorthPoint>> _actifsHistoryById = {};
  List<NetWorthPoint> _totalPassifHistory = [];
  bool _isEverythingEmpty = false;

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
    // Repart de zéro pour le prochain profil affiché (ex : Lou, sur lequel
    // ce signal ne doit jamais rester actif par erreur) — voir
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
    final accounts = await _repo.listAll();
    final priceHistories = await loadAllPriceHistories(
      widget.vaultPath,
      accounts,
    );
    final liabilities = await _liabilitiesRepo.listAll();
    if (!mounted) return;
    // Aucun compte avec au moins un investissement, et aucun passif : rien
    // à montrer dans les cartes habituelles, voir [DashboardOnboardingView]
    // et [OnboardingHighlightController].
    final isEverythingEmpty =
        accounts.every((a) => a.investments.isEmpty) && liabilities.isEmpty;
    widget.onboardingHighlight.setEmpty(isEverythingEmpty);
    setState(() {
      _isEverythingEmpty = isEverythingEmpty;
      _categories = buildAllRealCategories(
        accounts,
        priceHistories,
        widget.vaultPath,
      );
      _categoriesByAccount = buildAllRealCategoriesByAccount(
        accounts,
        priceHistories,
        widget.vaultPath,
      );
      _topAssets = buildRealTopAssets(accounts, priceHistories);
      final grid = sharedDateGrid(accounts);
      _actifsHistoryById = {
        for (final assetClass in AssetClass.values)
          assetClass.categoryId: categoryHistoryOnGrid(
            investmentsForEffectiveClass(accounts, assetClass),
            priceHistories,
            grid,
          ),
      };
      _totalPassifHistory = totalBalanceOnGrid(liabilities, grid);
      _passifCategories = buildAllRealPassifCategories(liabilities);
    });
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
                    actifsHistoryById: _actifsHistoryById,
                    totalPassifHistory: _totalPassifHistory,
                    hidden: hidden,
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
                TopAssetsRow(assets: _topAssets),
                const SizedBox(height: 24),
              ],
              CategoryBreakdownCard(
                title: 'Actifs',
                categories: _categoriesByAccount,
                hidden: hidden,
                // Le PRU reste visible sur les pages de détail de chaque
                // classe d'actif, pas ici : la vue agrégée du Dashboard
                // montre uniquement montant et évolution.
                showPru: false,
              ),
              const SizedBox(height: 16),
              CategoryBreakdownCard(
                title: 'Passifs',
                categories: _passifCategories,
                hidden: hidden,
                showPru: false,
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../dashboard/category_detail_screen.dart';
import '../dashboard/patrimoine_models.dart';
import '../investments/patrimoine_refresh_controller.dart';
import 'liabilities_models.dart';
import 'liabilities_repository.dart';
import 'liability_detail_view.dart';
import 'real_passifs_adapter.dart'
    show
        buildRealPassifCategories,
        emptyPassifCategoryFor,
        perLiabilityHistoryOnGrid;

/// Charge les passifs réels puis affiche [CategoryDetailScreen] pour le
/// type [categoryId] ('passifs_prets_immobiliers'/'passifs_emprunts'). La
/// création d'un passif se fait exclusivement via le flux "Compléter mon
/// patrimoine" de la TopBar (voir `investments/complete_patrimoine_dialog.dart`),
/// pas depuis cette page. Cliquer sur une ligne ouvre en local (pas de
/// `Navigator.push`) le détail du passif : édition, suppression,
/// documents.
///
/// Le graphique par onglets de période de [CategoryDetailScreen] reste
/// volontairement non borné par période ici (voir
/// [_historyByLiabilityId]/[perLiabilityHistoryOnGrid]) : il projette
/// toujours jusqu'au remboursement final de chaque prêt, cohérent avec la
/// vue détaillée d'un passif ([LiabilityDetailView]) qui fait de même.
class RealPassifDetailScreen extends StatefulWidget {
  final String vaultPath;
  final String categoryId;
  final AmountVisibilityController amountVisibility;
  final PatrimoineRefreshController patrimoineRefreshController;

  const RealPassifDetailScreen({
    super.key,
    required this.vaultPath,
    required this.categoryId,
    required this.amountVisibility,
    required this.patrimoineRefreshController,
  });

  @override
  State<RealPassifDetailScreen> createState() => _RealPassifDetailScreenState();
}

class _RealPassifDetailScreenState extends State<RealPassifDetailScreen> {
  late LiabilitiesRepository _repo;
  bool _loading = true;
  List<Liability> _liabilities = [];
  PatrimoineCategory? _category;
  Map<String, List<NetWorthPoint>> _historyByLiabilityId = {};
  String? _selectedLiabilityId;

  @override
  void initState() {
    super.initState();
    _repo = LiabilitiesRepository(widget.vaultPath);
    // Un passif peut être créé ailleurs pendant que cette page est ouverte
    // (le flux "Compléter mon patrimoine" de la TopBar reste accessible
    // depuis n'importe quelle page) : s'abonner au signal global permet de
    // le refléter sans que l'utilisateur ait à quitter puis revenir.
    widget.patrimoineRefreshController.addListener(_reload);
    _load();
  }

  @override
  void didUpdateWidget(covariant RealPassifDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath ||
        oldWidget.categoryId != widget.categoryId) {
      _repo = LiabilitiesRepository(widget.vaultPath);
      _selectedLiabilityId = null;
      _load();
    }
  }

  @override
  void dispose() {
    widget.patrimoineRefreshController.removeListener(_reload);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _reload();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// Recharge sans passer par l'écran de chargement plein cadre — que ce
  /// soit après une mutation locale (voir [_refresh]) ou un changement
  /// ailleurs dans l'app (voir le listener posé dans [initState]) : dans
  /// les deux cas, remplacer tout l'écran par un spinner ferait perdre le
  /// passif actuellement sélectionné ou tout formulaire ouvert.
  Future<void> _reload() async {
    final liabilities = await _repo.listAll();
    if (!mounted) return;
    final categories = buildRealPassifCategories(liabilities);
    PatrimoineCategory? found;
    for (final category in categories) {
      if (category.id == widget.categoryId) {
        found = category;
        break;
      }
    }
    final categoryLiabilities = [
      for (final l in liabilities)
        if (l.type.categoryId == widget.categoryId) l,
    ];
    setState(() {
      _liabilities = liabilities;
      _category = found ?? emptyPassifCategoryFor(widget.categoryId);
      _historyByLiabilityId = perLiabilityHistoryOnGrid(categoryLiabilities);
    });
  }

  Future<void> _refresh() async {
    await _reload();
    widget.patrimoineRefreshController.notifyChanged();
  }

  void _openLiability(PatrimoineAccount tapped) {
    setState(() => _selectedLiabilityId = tapped.id);
  }

  Liability? get _selectedLiability {
    final id = _selectedLiabilityId;
    if (id == null) return null;
    for (final liability in _liabilities) {
      if (liability.id == id) return liability;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    if (_loading || category == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final liability = _selectedLiability;
    if (liability != null) {
      return LiabilityDetailView(
        vaultPath: widget.vaultPath,
        liability: liability,
        hidden: widget.amountVisibility.hidden,
        onBack: () => setState(() => _selectedLiabilityId = null),
        onChanged: _refresh,
      );
    }

    return CategoryDetailScreen(
      category: category,
      amountVisibility: widget.amountVisibility,
      onAccountTap: _openLiability,
      // Toujours la même projection complète, quelle que soit la période
      // sélectionnée dans l'onglet — voir la doc de classe ci-dessus.
      historyByLineIdForPeriod: (_) => _historyByLiabilityId,
      showAvatar: false,
      accountsCardTitle: 'Passifs',
    );
  }
}

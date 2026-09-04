import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../l10n/app_localizations.dart';
import '../dashboard/category_detail_screen.dart';
import '../dashboard/patrimoine_models.dart';
import '../investments/patrimoine_refresh_controller.dart';
import 'liabilities_models.dart';
import 'liabilities_repository.dart';
import 'liability_detail_view.dart';
import 'real_passifs_adapter.dart'
    show
        buildRealPassifCategories,
        earliestLiabilityStart,
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
/// Le graphique par onglets de période de [CategoryDetailScreen] projette
/// toujours jusqu'au remboursement final de chaque prêt (capital restant dû
/// à 0 €), quel que soit l'onglet choisi — un passif se raconte par "combien
/// il reste à rembourser et jusqu'à quand", pas par une fenêtre glissante
/// qui s'arrêterait aujourd'hui comme pour un actif. L'onglet de période
/// change en revanche bien la borne de DÉBUT affichée (voir
/// [_historyForPeriod]/`real_passifs_adapter.dart`'s `perLiabilityHistoryOnGrid`) :
/// "Tout" montre depuis le déblocage du prêt, "1A" ne montre que la
/// dernière année avant l'échéance projetée, etc.
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
  List<Liability> _categoryLiabilities = [];
  PatrimoineCategory? _category;
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
    // Même filtre que `dashboard_screen.dart` : un passif rattaché à une
    // entité professionnelle (`entityId` non nul) n'appartient pas aux
    // catégories de passifs personnels affichées ici.
    final liabilities = (await _repo.listAll())
        .where((l) => l.entityId == null)
        .toList();
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
      _categoryLiabilities = categoryLiabilities;
    });
  }

  /// Historique par prêt pour [period] — la borne de fin reste toujours
  /// l'échéance projetée de chaque prêt (voir la doc de classe), seule la
  /// borne de début varie avec [period] (voir
  /// `real_passifs_adapter.dart`'s `perLiabilityHistoryOnGrid`).
  Map<String, List<NetWorthPoint>> _historyForPeriod(DashboardPeriod period) {
    final today = DateTime.now();
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final earliest = earliestLiabilityStart(_categoryLiabilities) ?? todayUtc;
    final periodStart = period.startFor(today: todayUtc, earliest: earliest);
    return perLiabilityHistoryOnGrid(
      _categoryLiabilities,
      periodStart: periodStart,
    );
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
      historyByLineIdForPeriod: _historyForPeriod,
      showAvatar: false,
      // Réutilise la clé de navigation existante ("Passifs") plutôt que
      // d'en créer une dédiée : même libellé, même sens.
      accountsCardTitle: AppLocalizations.of(context).nav_liabilities,
      // La courbe projette toujours jusqu'à 0 € (voir la doc de classe) :
      // un "% d'évolution" y serait toujours -100 %, quel que soit
      // l'onglet — pas une vraie mesure de performance sur la période.
      // Le montant en euros (combien il reste à rembourser sur la fenêtre
      // affichée) reste, lui, informatif.
      showChangePercent: false,
    );
  }
}

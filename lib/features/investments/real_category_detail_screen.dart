import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../dashboard/category_detail_screen.dart';
import '../dashboard/dashboard_dummy_data.dart';
import 'account_detail_screen.dart';
import 'confirm_delete_dialog.dart';
import 'investment_detail_screen.dart';
import 'investments_models.dart';
import 'investments_repository.dart';
import 'patrimoine_refresh_controller.dart';
import 'real_patrimoine_adapter.dart';

/// Charge les comptes réels puis affiche [CategoryDetailScreen] pour la
/// classe d'actif [categoryId] ('actifs_immobilier', 'actifs_crypto'...) —
/// équivalent réel des entrées `actifs_*` du Dashboard de démo, ouvertes
/// depuis `CategoryBreakdownCard`/`AllocationCard` via `NavigationScope`.
/// Sans compte pour cette classe, affiche l'état vide de
/// [CategoryDetailScreen] plutôt que rien.
///
/// Cliquer sur une ligne du tableau ouvre en local (pas de `Navigator.push`,
/// même principe que l'ancien "Mes comptes") la vue de détail du compte
/// puis de l'investissement réel correspondant — actualisation de cours,
/// historique complet des transactions, bascule TWR/MWR : ce sont les
/// seuls écrans qui exposent encore ces actions, la création (compte/
/// investissement/transaction) passant désormais uniquement par le flux
/// "Compléter mon patrimoine" de la TopBar.
class RealCategoryDetailScreen extends StatefulWidget {
  final String vaultPath;
  final String categoryId;
  final AmountVisibilityController amountVisibility;
  final PatrimoineRefreshController patrimoineRefreshController;

  const RealCategoryDetailScreen({
    super.key,
    required this.vaultPath,
    required this.categoryId,
    required this.amountVisibility,
    required this.patrimoineRefreshController,
  });

  @override
  State<RealCategoryDetailScreen> createState() =>
      _RealCategoryDetailScreenState();
}

class _RealCategoryDetailScreenState extends State<RealCategoryDetailScreen> {
  late InvestmentsRepository _repo;
  bool _loading = true;
  List<InvestmentAccount> _accounts = [];
  PatrimoineCategory? _category;
  List<PatrimoineAccount>? _categoryByAccount;

  String? _selectedAccountId;
  String? _selectedInvestmentId;
  bool _openAccountInEditMode = false;

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    // Un actif peut être créé ailleurs pendant que cette page est ouverte
    // (le flux "Compléter mon patrimoine" de la TopBar reste accessible
    // depuis n'importe quelle page) : s'abonner au signal global permet de
    // refléter ce nouvel actif sans que l'utilisateur ait à quitter puis
    // revenir sur cette page.
    widget.patrimoineRefreshController.addListener(_reload);
    _load();
  }

  @override
  void didUpdateWidget(covariant RealCategoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath ||
        oldWidget.categoryId != widget.categoryId) {
      _selectedAccountId = null;
      _selectedInvestmentId = null;
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
  /// les deux cas, remplacer tout l'écran par un spinner ferait perdre la
  /// sélection compte/investissement en cours et tout formulaire ouvert.
  Future<void> _reload() async {
    final accounts = await _repo.listAll();
    final priceHistories = await loadAllPriceHistories(
      widget.vaultPath,
      accounts,
    );
    final categories = buildRealCategories(
      accounts,
      priceHistories,
      widget.vaultPath,
    );
    final categoriesByAccount = buildRealCategoriesByAccount(
      accounts,
      priceHistories,
      widget.vaultPath,
    );
    if (!mounted) return;
    PatrimoineCategory? found;
    for (final category in categories) {
      if (category.id == widget.categoryId) {
        found = category;
        break;
      }
    }
    PatrimoineCategory? foundByAccount;
    for (final category in categoriesByAccount) {
      if (category.id == widget.categoryId) {
        foundByAccount = category;
        break;
      }
    }
    setState(() {
      _accounts = accounts;
      _category = found ?? emptyCategoryFor(widget.categoryId);
      _categoryByAccount = foundByAccount?.accounts;
    });
  }

  /// Prévient le Dashboard (et toute autre page ouverte) qu'il doit lui
  /// aussi se recharger — comme entre `InvestmentsDashboardScreen` et
  /// `onAccountsChanged` avant lui, mais via le signal global puisque le
  /// Dashboard n'est plus le parent direct de cet écran.
  Future<void> _refresh() async {
    await _reload();
    widget.patrimoineRefreshController.notifyChanged();
  }

  void _openInvestment(PatrimoineAccount tapped) {
    for (final account in _accounts) {
      for (final investment in account.investments) {
        if (investment.id == tapped.id) {
          setState(() {
            _selectedAccountId = account.id;
            _selectedInvestmentId = investment.id;
          });
          return;
        }
      }
    }
  }

  /// "Modifier le compte" du menu "⋮" de l'accordéon (voir
  /// [CategoryDetailScreen.onAccountEdit]) : ouvre directement
  /// [AccountDetailView] avec son formulaire d'édition déjà affiché, sans
  /// que l'utilisateur ait à cliquer une deuxième fois une fois le compte
  /// ouvert.
  void _openAccountForEdit(PatrimoineAccount tapped) {
    setState(() {
      _selectedAccountId = tapped.id;
      _openAccountInEditMode = true;
    });
  }

  /// "Supprimer le compte" du menu "⋮" de l'accordéon (voir
  /// [CategoryDetailScreen.onAccountDelete]) — même garde-fou et même
  /// confirmation que `AccountDetailView`'s propre suppression
  /// (`account_detail_screen.dart`), pour ne jamais perdre silencieusement
  /// un historique de transactions.
  Future<void> _deleteAccountFromAccordion(PatrimoineAccount tapped) async {
    InvestmentAccount? account;
    for (final a in _accounts) {
      if (a.id == tapped.id) {
        account = a;
        break;
      }
    }
    if (account == null ||
        account.investments.any((i) => i.transactions.isNotEmpty)) {
      return;
    }
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer "${account.name}" ?',
      message:
          'Ce compte et ses investissements (sans transaction) seront '
          'définitivement supprimés.',
    );
    if (!confirmed) return;
    await _repo.deleteAccount(account.id);
    await _refresh();
  }

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

  /// Établissements (banques, brokers...) déjà présents dans le vault, pour
  /// la liste déroulante du formulaire d'édition d'un compte
  /// (`_EditAccountForm` d'`account_detail_screen.dart`) — on ne peut
  /// changer de banque qu'en en sélectionnant une existante.
  List<String> get _bankNames {
    final names = <String>{};
    for (final account in _accounts) {
      final bankName = account.bankName;
      if (bankName != null && bankName.isNotEmpty) names.add(bankName);
    }
    return names.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    if (_loading || category == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final hidden = widget.amountVisibility.hidden;
    final account = _selectedAccount;
    final investment = _selectedInvestment;

    if (account != null && investment != null) {
      return InvestmentDetailView(
        vaultPath: widget.vaultPath,
        account: account,
        investment: investment,
        hidden: hidden,
        onBack: () => setState(() => _selectedInvestmentId = null),
        onChanged: _refresh,
      );
    }
    if (account != null) {
      return AccountDetailView(
        vaultPath: widget.vaultPath,
        account: account,
        hidden: hidden,
        bankNames: _bankNames,
        startInEditMode: _openAccountInEditMode,
        onBack: () => setState(() {
          _selectedAccountId = null;
          _openAccountInEditMode = false;
        }),
        onOpenInvestment: (id) => setState(() => _selectedInvestmentId = id),
        onChanged: _refresh,
      );
    }
    return CategoryDetailScreen(
      category: category,
      amountVisibility: widget.amountVisibility,
      onAccountTap: _openInvestment,
      distributionByAccount: _categoryByAccount,
      onAccountEdit: _openAccountForEdit,
      onAccountDelete: _deleteAccountFromAccordion,
      // Permet d'importer les logos des banques (avatar cliquable).
      vaultPath: widget.vaultPath,
      // Les avatars restent affichés pour toutes les classes d'actif : pour
      // les métaux précieux, la photo du produit détenu remplace les
      // initiales (voir `real_patrimoine_adapter.dart`).
    );
  }
}

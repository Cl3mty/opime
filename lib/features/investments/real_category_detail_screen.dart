import 'dart:async' show unawaited;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../dashboard/category_detail_screen.dart';
import '../dashboard/patrimoine_models.dart';
import 'account_detail_screen.dart';
import 'confirm_delete_dialog.dart';
import 'current_account_focus_controller.dart';
import 'investment_detail_screen.dart';
import 'investments_models.dart';
import 'investments_repository.dart';
import 'patrimoine_refresh_controller.dart';
import 'real_patrimoine_adapter.dart';
import 'stock_account_screen.dart';
import 'yahoo_finance_client.dart' show PricePoint;

/// Charge les comptes réels puis affiche [CategoryDetailScreen] pour la
/// classe d'actif [categoryId] ('actifs_immobilier', 'actifs_crypto'...) —
/// ouvert depuis `CategoryBreakdownCard`/`AllocationCard` via
/// `NavigationScope`. Sans compte pour cette classe, affiche l'état vide de
/// [CategoryDetailScreen] plutôt que rien.
///
/// Cliquer sur une ligne du tableau ouvre en local (pas de `Navigator.push`,
/// même principe que l'ancien "Mes comptes") la vue de détail du compte —
/// `StockAccountScreen` pour toutes les classes sauf l'immobilier
/// (positions + transactions, popup de détail par position), l'ancienne
/// paire `AccountDetailView`/`InvestmentDetailView` pour l'immobilier.
/// Actualisation de cours, historique complet des transactions, bascule
/// TWR/MWR : ce sont les seuls écrans qui exposent encore ces actions, la
/// création (compte/investissement/transaction) passant désormais
/// uniquement par le flux "Compléter mon patrimoine" de la TopBar.
class RealCategoryDetailScreen extends StatefulWidget {
  final String vaultPath;
  final String categoryId;
  final AmountVisibilityController amountVisibility;
  final PatrimoineRefreshController patrimoineRefreshController;

  /// Tenu à jour à chaque rendu avec le compte/investissement actuellement
  /// affiché (voir [CurrentAccountFocusController]) — lu par
  /// [AddMenuButton] pour présélectionner ce contexte à l'ouverture du flux
  /// "Compléter mon patrimoine" plutôt que de le faire rechoisir.
  final CurrentAccountFocusController currentAccountFocus;

  const RealCategoryDetailScreen({
    super.key,
    required this.vaultPath,
    required this.categoryId,
    required this.amountVisibility,
    required this.patrimoineRefreshController,
    required this.currentAccountFocus,
  });

  @override
  State<RealCategoryDetailScreen> createState() =>
      _RealCategoryDetailScreenState();
}

class _RealCategoryDetailScreenState extends State<RealCategoryDetailScreen> {
  late InvestmentsRepository _repo;
  bool _loading = true;
  List<InvestmentAccount> _accounts = [];
  Map<String, List<PricePoint>> _priceHistories = {};
  PatrimoineCategory? _category;
  List<PatrimoineAccount>? _categoryByAccount;
  List<PatrimoineAccount>? _categoryByInvestment;

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
    // Cette page quitte l'écran (changement de page, ou de vault/catégorie
    // via [didUpdateWidget], qui recrée l'élément avec une nouvelle clé) :
    // son focus ne doit pas rester "collé" pour une autre page qui n'a rien
    // à voir avec le compte affiché ici.
    widget.currentAccountFocus.value = null;
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
    // Fusion par identifiant entre comptes (voir
    // `real_patrimoine_adapter.dart`'s `buildRealCategoriesByInvestment`,
    // qui fusionne par ISIN pour "Actions & Fonds" et par ticker pour
    // "Crypto" — `Investment.isin` sert de ticker en l'absence d'ISIN pour
    // une crypto, voir `identifierOptionsFor`) : seules ces deux classes ont
    // l'usage aujourd'hui (détenir le même titre/la même crypto dans
    // plusieurs comptes/wallets est un cas réel là où les autres classes
    // n'en ont pas besoin) — calculée pour toutes les classes reste sans
    // effet (une seule catégorie recherchée juste après) mais reste bon
    // marché, aucune E/S supplémentaire par rapport aux deux listes déjà
    // construites ci-dessus.
    final categoriesByInvestment =
        widget.categoryId == AssetClass.actionsEtFonds.categoryId ||
            widget.categoryId == AssetClass.crypto.categoryId
        ? buildRealCategoriesByInvestment(
            accounts,
            priceHistories,
            widget.vaultPath,
          )
        : const <PatrimoineCategory>[];
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
    PatrimoineCategory? foundByInvestment;
    for (final category in categoriesByInvestment) {
      if (category.id == widget.categoryId) {
        foundByInvestment = category;
        break;
      }
    }
    setState(() {
      _accounts = accounts;
      _priceHistories = priceHistories;
      _category = found ?? emptyCategoryFor(widget.categoryId);
      _categoryByAccount = foundByAccount?.accounts;
      _categoryByInvestment = foundByInvestment?.accounts;
    });
  }

  /// Historique de la catégorie pour une période donnée — voir
  /// [CategoryDetailScreen.historyForPeriod]. Calculé à la demande à partir
  /// des comptes/cours déjà en mémoire (aucune E/S), pas mis en cache : la
  /// période change rarement assez pour que ça coûte quelque chose.
  List<NetWorthPoint> _historyForPeriod(DashboardPeriod period) {
    final assetClass = assetClassForCategoryId(widget.categoryId);
    if (assetClass == null) return const [];
    final investments = investmentsForEffectiveClass(_accounts, assetClass);
    final today = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final earliest = earliestTransactionDate(investments) ?? today;
    final start = period.startFor(today: today, earliest: earliest);
    return netWorthHistoryFor(
      investments,
      _priceHistories,
      start: start,
      end: today,
    );
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

  /// Chevron de la ligne de compte (voir [CategoryDetailScreen.onAccountOpen])
  /// — ouvre [StockAccountScreen] en vue normale (pas en édition), pour
  /// toutes les classes d'actif sauf l'immobilier — voir [build].
  void _openAccountToView(PatrimoineAccount tapped) {
    setState(() => _selectedAccountId = tapped.id);
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

  /// Cette page affiche-t-elle une classe d'actif avec sa page compte
  /// dédiée (`StockAccountScreen`) ? — toutes sauf l'immobilier, voir
  /// [build] et le commentaire de tête de `stock_account_screen.dart`.
  bool get _usesStockAccountScreen {
    final assetClass = assetClassForCategoryId(widget.categoryId);
    return assetClass != null && assetClass != AssetClass.immobilier;
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

    // Reflète à chaque rendu le compte/investissement affiché — source de
    // vérité unique (les mêmes variables locales pilotent le contenu rendu
    // juste en dessous), pour ne jamais désynchroniser le focus de ce qui
    // est réellement à l'écran. Une simple assignation sur un
    // `ValueNotifier` que rien n'écoute activement (voir sa doc) : aucun
    // effet de bord, donc sans risque à faire ici plutôt que dans chacun
    // des nombreux callbacks qui changent `_selectedAccountId`/
    // `_selectedInvestmentId`. Un investissement précis n'a de page dédiée
    // que pour l'immobilier (`InvestmentDetailView`) — ailleurs,
    // `_selectedInvestmentId` ne fait qu'ouvrir une popup ponctuelle sur la
    // page compte, pas une vue focalisée durable sur cet investissement.
    widget.currentAccountFocus.value = account == null
        ? null
        : (
            assetClass: account.assetClass,
            accountId: account.id,
            investmentId: account.assetClass == AssetClass.immobilier
                ? investment?.id
                : null,
          );

    if (account != null && account.assetClass != AssetClass.immobilier) {
      return StockAccountScreen(
        vaultPath: widget.vaultPath,
        account: account,
        hidden: hidden,
        bankNames: _bankNames,
        startInEditMode: _openAccountInEditMode,
        // Un clic sur une position directement depuis le tableau de
        // catégorie (voir `_openInvestment`) ouvrait autrefois sa page
        // dédiée directement — ouvre maintenant sa popup de détail dès
        // l'arrivée sur la page compte, pour garder le même raccourci.
        initialInvestmentId: investment?.id,
        onBack: () => setState(() {
          _selectedAccountId = null;
          _selectedInvestmentId = null;
          _openAccountInEditMode = false;
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
      allocationByAccount: _categoryByAccount,
      allocationByInvestment: _categoryByInvestment,
      historyForPeriod: _historyForPeriod,
      onAccountEdit: _openAccountForEdit,
      onAccountDelete: _deleteAccountFromAccordion,
      // Toutes les classes sauf l'immobilier ont une page compte dédiée
      // assez riche (`StockAccountScreen`, avec son propre menu "Modifier"/
      // "Supprimer") pour justifier un chevron direct plutôt que le menu
      // "⋮" — l'immobilier garde le comportement "⋮" existant.
      onAccountOpen: _usesStockAccountScreen ? _openAccountToView : null,
      // Permet d'importer les logos des banques (avatar cliquable).
      vaultPath: widget.vaultPath,
      // Les avatars restent affichés pour toutes les classes d'actif : pour
      // les métaux précieux, la photo du produit détenu remplace les
      // initiales (voir `real_patrimoine_adapter.dart`).
    );
  }
}

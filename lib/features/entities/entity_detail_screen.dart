import 'dart:async' show unawaited;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart' show displayEuros;
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../../l10n/app_localizations.dart';
import '../investments/account_detail_screen.dart';
import '../investments/investment_detail_screen.dart';
import '../investments/investments_models.dart';
import '../investments/investments_repository.dart';
import '../investments/patrimoine_refresh_controller.dart';
import '../investments/real_patrimoine_adapter.dart' show loadAllPriceHistories;
import '../investments/stock_account_screen.dart';
import '../investments/yahoo_finance_client.dart' show PricePoint;
import '../liabilities/liabilities_models.dart';
import '../liabilities/liabilities_repository.dart';
import '../liabilities/liability_detail_view.dart';
import 'entities_models.dart';
import 'entities_patrimoine_adapter.dart' show entityNetValue;

/// Détail d'une [BusinessEntity] : la liste de ses comptes (voir
/// `InvestmentAccount.entityId`) et passifs (voir `Liability.entityId`) —
/// les vrais comptes/passifs de cette entité, pas un bilan libre (voir la
/// doc de tête de `entities_models.dart`). Cliquer une ligne ouvre en local
/// (même principe que `real_category_detail_screen.dart`/
/// `real_passif_detail_screen.dart`, pas de `Navigator.push`) sa page de
/// détail dédiée — `StockAccountScreen`/`AccountDetailView` pour un compte
/// (selon sa classe d'actif), `LiabilityDetailView` pour un passif. Pour
/// ajouter un compte/passif à cette entité, l'utilisateur repasse par le
/// flux "Compléter mon patrimoine" (choix de l'entité à l'étape 1) — cet
/// écran est un écran de consultation/gestion, pas un point de création.
class EntityDetailScreen extends StatefulWidget {
  final String vaultPath;
  final BusinessEntity entity;
  final AmountVisibilityController amountVisibility;
  final PatrimoineRefreshController patrimoineRefreshController;

  /// Nom du profil actif — voir `InvestmentDetailView.profileName`.
  final String profileName;

  const EntityDetailScreen({
    super.key,
    required this.vaultPath,
    required this.entity,
    required this.amountVisibility,
    required this.patrimoineRefreshController,
    required this.profileName,
  });

  @override
  State<EntityDetailScreen> createState() => _EntityDetailScreenState();
}

class _EntityDetailScreenState extends State<EntityDetailScreen> {
  late InvestmentsRepository _accountsRepo;
  late LiabilitiesRepository _liabilitiesRepo;
  bool _loading = true;
  bool _loadError = false;
  List<InvestmentAccount> _accounts = [];
  List<Liability> _liabilities = [];
  Map<String, List<PricePoint>> _priceHistories = {};

  String? _selectedAccountId;
  String? _selectedInvestmentId;
  String? _selectedLiabilityId;

  @override
  void initState() {
    super.initState();
    _accountsRepo = InvestmentsRepository(widget.vaultPath);
    _liabilitiesRepo = LiabilitiesRepository(widget.vaultPath);
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
      final accounts = allAccounts
          .where((a) => a.entityId == widget.entity.id)
          .toList();
      final priceHistories = await loadAllPriceHistories(
        widget.vaultPath,
        accounts,
      );
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _liabilities = allLiabilities
            .where((l) => l.entityId == widget.entity.id)
            .toList();
        _priceHistories = priceHistories;
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

    final netValue = entityNetValue(widget.entity.id, _accounts, _liabilities);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shadcn.Text(widget.entity.name).x2Large().bold(),
          const SizedBox(height: 4),
          shadcn.Text(
            widget.entity.parentEntityId != null
                ? l10n.entities_ownership_by_parent(
                    widget.entity.type.label,
                    _formatPercent(widget.entity.ownershipPercent),
                  )
                : l10n.entities_ownership_by_user(
                    widget.entity.type.label,
                    _formatPercent(widget.entity.ownershipPercent),
                  ),
          ).muted().small(),
          const SizedBox(height: 16),
          FrostedCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shadcn.Text(l10n.entities_net_value_label).muted().small(),
                  const SizedBox(height: 4),
                  shadcn.Text(displayEuros(netValue, hidden)).x2Large().bold(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          shadcn.Text(l10n.entities_accounts_section_title).large().medium(),
          const SizedBox(height: 8),
          if (_accounts.isEmpty)
            shadcn.Text(
              l10n.entities_no_accounts_yet,
            ).muted().small()
          else
            for (final a in _accounts) ...[
              _EntityAccountRow(
                account: a,
                hidden: hidden,
                onTap: () => setState(() => _selectedAccountId = a.id),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 24),
          shadcn.Text(
            l10n.entities_liabilities_section_title,
          ).large().medium(),
          const SizedBox(height: 8),
          if (_liabilities.isEmpty)
            shadcn.Text(l10n.entities_no_liabilities_yet).muted().small()
          else
            for (final l in _liabilities) ...[
              _EntityLiabilityRow(
                liability: l,
                hidden: hidden,
                onTap: () => setState(() => _selectedLiabilityId = l.id),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  String _formatPercent(double value) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toString();
}

class _EntityAccountRow extends StatelessWidget {
  final InvestmentAccount account;
  final bool hidden;
  final VoidCallback onTap;

  const _EntityAccountRow({
    required this.account,
    required this.hidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = account.totalMarketValue + account.totalLeveragedValue;
    return FrostedCard(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shadcn.Text(account.name).medium(),
                    const SizedBox(height: 2),
                    shadcn.Text(account.assetClass.label).muted().small(),
                  ],
                ),
              ),
              shadcn.Text(displayEuros(value, hidden)).medium(),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronRight, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntityLiabilityRow extends StatelessWidget {
  final Liability liability;
  final bool hidden;
  final VoidCallback onTap;

  const _EntityLiabilityRow({
    required this.liability,
    required this.hidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shadcn.Text(liability.name).medium(),
                    const SizedBox(height: 2),
                    shadcn.Text(liability.type.label).muted().small(),
                  ],
                ),
              ),
              shadcn.Text(
                displayEuros(liability.remainingBalance, hidden),
              ).medium(),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronRight, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

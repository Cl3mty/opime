import 'dart:async' show unawaited;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/profiles/profile_controller.dart';
import '../dashboard/onboarding_highlight_controller.dart';
import '../investments/complete_patrimoine_dialog.dart';
import '../investments/current_account_focus_controller.dart';
import '../investments/investments_models.dart' show assetClassForCategoryId;
import '../investments/investments_repository.dart';
import '../investments/patrimoine_refresh_controller.dart';
import '../investments/price_refresh_service.dart';
import '../investments/price_sync_status_controller.dart';
import '../liabilities/liabilities_models.dart' show liabilityTypeForCategoryId;
import '../../l10n/app_localizations.dart';

/// Bouton icône avec tooltip, utilisé par les actions rapides de la barre
/// du haut (recherche/eye/plus), qu'elle soit rendue par [TopBar] (desktop)
/// ou directement dans l'AppBar mobile de [AppShell].
class TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const TopBarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // ignore: implicit_call_tearoffs
      tooltip: TooltipContainer(child: shadcn.Text(tooltip)),
      child: IconButton.ghost(icon: Icon(icon), onPressed: onPressed),
    );
  }
}

/// Bascule montrer/masquer les montants de l'app.
class AmountVisibilityToggleButton extends StatelessWidget {
  final AmountVisibilityController amountVisibility;

  const AmountVisibilityToggleButton({
    super.key,
    required this.amountVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: amountVisibility,
      builder: (context, _) {
        final hidden = amountVisibility.hidden;
        final l10n = AppLocalizations.of(context);
        return TopBarIconButton(
          icon: hidden ? LucideIcons.eyeOff : LucideIcons.eye,
          tooltip: hidden
              ? l10n.navigation_amounts_show
              : l10n.navigation_amounts_hide,
          onPressed: amountVisibility.toggle,
        );
      },
    );
  }
}

/// Bouton "+" de la TopBar : ouvre le flux "Compléter mon patrimoine", qui
/// crée soit un actif (classe → compte → investissement → transaction),
/// soit un passif (type → formulaire de prêt) — voir
/// `complete_patrimoine_dialog.dart`.
///
/// Se met en valeur (échelle et lueur à 105%) tant que
/// [onboardingHighlight] signale qu'aucune donnée n'existe encore pour le
/// profil actif — même signal que le conseil de démarrage affiché sur le
/// Dashboard, voir `dashboard/onboarding_highlight_controller.dart`.
///
/// [compact] réduit le bouton à une icône (utilisé dans l'AppBar mobile,
/// trop étroite pour un libellé) ; sinon un bouton avec libellé, comme
/// dans la TopBar desktop/tablette.
class AddMenuButton extends StatelessWidget {
  final ProfileController profileController;
  final PatrimoineRefreshController patrimoineRefreshController;
  final CurrentAccountFocusController currentAccountFocus;
  final OnboardingHighlightController onboardingHighlight;
  final PriceSyncStatusController priceSyncStatus;
  final bool compact;

  /// Clé de la page actuellement affichée (ex : `'actifs_crypto'`) — quand
  /// elle correspond à une classe d'actif réelle, le flux démarre
  /// directement à l'étape "quel compte ?" pour cette classe plutôt que de
  /// la faire choisir à nouveau.
  final String? currentPageKey;

  const AddMenuButton({
    super.key,
    required this.profileController,
    required this.patrimoineRefreshController,
    required this.currentAccountFocus,
    required this.onboardingHighlight,
    required this.priceSyncStatus,
    this.compact = false,
    this.currentPageKey,
  });

  void _open(BuildContext context) {
    final pageKey = currentPageKey;
    // Un compte (voire un investissement précis) est déjà affiché en plein
    // cadre (voir [CurrentAccountFocusController]) : le flux y ajoute
    // directement, sans faire rechoisir la classe/le compte déjà sous les
    // yeux de l'utilisateur. Sinon, repli sur l'ancien comportement
    // (présélection de la classe depuis la page de catégorie courante).
    final focus = currentAccountFocus.value;
    showCompletePatrimoineDialog(
      context,
      vaultPath: profileController.activeDataPath,
      onCompleted: () {
        // Rechargement immédiat depuis le cache (données déjà à jour sur
        // disque), pour que le Dashboard et les pages de catégorie ouvertes
        // reflètent le nouvel actif sans attendre le réseau.
        patrimoineRefreshController.notifyChanged();
        // Puis résolution des cours en arrière-plan : la plus/moins-value
        // et la performance du nouvel investissement se calculent dès que
        // son cours est connu, sans attendre la prochaine ouverture du
        // Dashboard — voir [PatrimoineRefreshController].
        unawaited(_refreshPricesAfterCompletion());
      },
      initialAssetClass: focus != null
          ? focus.assetClass
          : pageKey == null
          ? null
          : assetClassForCategoryId(pageKey),
      initialAccountId: focus?.accountId,
      initialInvestmentId: focus?.investmentId,
      initialLiabilityType: focus != null || pageKey == null
          ? null
          : liabilityTypeForCategoryId(pageKey),
    );
  }

  /// Résout les cours de tous les investissements (voir
  /// `price_refresh_service.dart`), puis notifie à nouveau le signal de
  /// rechargement : les éléments visuels impactés par la performance et la
  /// plus/moins-value se mettent à jour une fois les cours connus. Le flux
  /// de complétion lui-même est déjà refermé (mutation persistée), ce
  /// rechargement est donc purement réactif.
  Future<void> _refreshPricesAfterCompletion() async {
    final vaultPath = profileController.activeDataPath;
    final repo = InvestmentsRepository(vaultPath);
    final accounts = await repo.listAll();
    await refreshAllPrices(
      vaultPath: vaultPath,
      accounts: accounts,
      repo: repo,
      priceSyncStatus: priceSyncStatus,
    );
    patrimoineRefreshController.notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: onboardingHighlight,
      builder: (context, child) {
        final highlighted = onboardingHighlight.isEmpty;
        final label = AppLocalizations.of(context).navigation_complete_patrimoine;
        final button = compact
            ? IconButton.primary(
                icon: const Icon(LucideIcons.plus),
                onPressed: () => _open(context),
              )
            : PrimaryButton(
                leading: const Icon(LucideIcons.plus, size: 16),
                onPressed: () => _open(context),
                child: shadcn.Text(label),
              );
        return Tooltip(
          // ignore: implicit_call_tearoffs
          tooltip: TooltipContainer(child: shadcn.Text(label)),
          child: highlighted
              ? Transform.scale(
                  scale: 1.05,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.55),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: button,
                  ),
                )
              : button,
        );
      },
    );
  }
}

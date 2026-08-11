import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/profiles/profile_controller.dart';
import '../dashboard/onboarding_highlight_controller.dart';
import '../investments/complete_patrimoine_dialog.dart';
import '../investments/investments_models.dart' show assetClassForCategoryId;
import '../investments/patrimoine_refresh_controller.dart';
import '../liabilities/liabilities_models.dart' show liabilityTypeForCategoryId;

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
        return TopBarIconButton(
          icon: hidden ? LucideIcons.eyeOff : LucideIcons.eye,
          tooltip: hidden ? 'Afficher les montants' : 'Masquer les montants',
          onPressed: amountVisibility.toggle,
        );
      },
    );
  }
}

/// Bouton "+" de la TopBar : ouvre le flux "Compléter mon patrimoine", qui
/// crée soit un actif (classe → compte → investissement → transaction),
/// soit un passif (type → formulaire de prêt) — voir
/// `complete_patrimoine_dialog.dart`. Désactivé sur le profil "Lou" (démo) :
/// les données qu'il créerait ne seraient de toute façon jamais affichées,
/// le Dashboard de Lou restant figé sur les données d'exemple.
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
  final OnboardingHighlightController onboardingHighlight;
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
    required this.onboardingHighlight,
    this.compact = false,
    this.currentPageKey,
  });

  bool get _isDemoProfile => profileController.active?.name == 'Lou';

  void _open(BuildContext context) {
    final pageKey = currentPageKey;
    showCompletePatrimoineDialog(
      context,
      vaultPath: profileController.activeDataPath,
      onCompleted: patrimoineRefreshController.notifyChanged,
      initialAssetClass: pageKey == null
          ? null
          : assetClassForCategoryId(pageKey),
      initialLiabilityType: pageKey == null
          ? null
          : liabilityTypeForCategoryId(pageKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _isDemoProfile
        ? 'Non disponible sur le profil de démonstration'
        : 'Compléter mon patrimoine';
    return AnimatedBuilder(
      animation: onboardingHighlight,
      builder: (context, child) {
        final highlighted = !_isDemoProfile && onboardingHighlight.isEmpty;
        final button = compact
            ? IconButton.primary(
                icon: const Icon(LucideIcons.plus),
                onPressed: _isDemoProfile ? null : () => _open(context),
              )
            : PrimaryButton(
                leading: const Icon(LucideIcons.plus, size: 16),
                onPressed: _isDemoProfile ? null : () => _open(context),
                child: const shadcn.Text('Compléter mon patrimoine'),
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

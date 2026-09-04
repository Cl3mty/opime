import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../l10n/app_localizations.dart';
import 'price_sync_status_controller.dart';

/// Bandeau global affiché quand [controller] signale une coupure réseau
/// (voir [PriceSyncStatusController]) — un seul bandeau pour toute l'app,
/// pas un par investissement, même principe que `UpdateBanner`
/// (`core/updates/update_banner.dart`). Se referme automatiquement dès
/// qu'une synchronisation de cours réussit à nouveau, sans action requise
/// de l'utilisateur.
class PriceSyncBanner extends StatefulWidget {
  final PriceSyncStatusController controller;
  final Widget child;

  const PriceSyncBanner({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<PriceSyncBanner> createState() => _PriceSyncBannerState();
}

class _PriceSyncBannerState extends State<PriceSyncBanner> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant PriceSyncBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.offline) return widget.child;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Même correctif que `FrostedCard` : un aplat de couleur à alpha fixe
    // se voit beaucoup moins sur un fond clair que sur un fond sombre — le
    // bandeau devenait quasi invisible en thème clair avec une seule valeur
    // d'opacité pour les deux. En sombre, la teinte doit être plus marquée
    // pour rester lisible sur un fond déjà très sombre.
    final isDark = theme.brightness == Brightness.dark;
    final tintAlpha = isDark ? 0.18 : 0.16;
    // Texte à fort contraste : en thème clair le rouge `destructive`
    // (foncé) ressort sur la teinte très pâle ; en thème sombre c'est le
    // premier plan clair qui se détache du fond rouge sombre.
    final textColor = isDark
        ? theme.colorScheme.foreground
        : theme.colorScheme.destructive;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.destructive.withValues(alpha: tintAlpha),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                LucideIcons.wifiOff,
                size: 16,
                color: theme.colorScheme.destructive,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: shadcn.Text(
                  l10n.investments_price_sync_offline_message,
                  style: TextStyle(color: textColor),
                ).small(),
              ),
            ],
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

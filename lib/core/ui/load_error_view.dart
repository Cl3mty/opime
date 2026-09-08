import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:opime/l10n/app_localizations.dart';

/// État d'erreur générique pour un écran dont le chargement initial a
/// échoué ou dépassé son délai (ex : dossier Vault lent ou inaccessible
/// sur un emplacement synchronisé type iCloud Drive) : remplace un
/// spinner qui tournerait indéfiniment par un message explicite et un
/// bouton pour réessayer.
class LoadErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const LoadErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.circleAlert,
              size: 32,
              color: Theme.of(context).colorScheme.mutedForeground,
            ),
            const SizedBox(height: 16),
            shadcn.Text(message, textAlign: TextAlign.center).muted(),
            const SizedBox(height: 16),
            OutlineButton(
              onPressed: onRetry,
              leading: const Icon(LucideIcons.refreshCw),
              child: shadcn.Text(l10n.common_retry),
            ),
          ],
        ),
      ),
    );
  }
}

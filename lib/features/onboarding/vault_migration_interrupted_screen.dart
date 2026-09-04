import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../l10n/app_localizations.dart';

/// Écran bloquant affiché quand `VaultMigrationMarker` détecte qu'une
/// opération "activer/désactiver le chiffrement" a été interrompue avant
/// sa fin (app fermée en plein milieu) — voir `main.dart`'s `_buildHome` et
/// `vault_encryption_migration_service.dart`. Le vault peut contenir un
/// mélange de fichiers déjà migrés et d'autres non : on affiche cet
/// avertissement explicite plutôt que de charger silencieusement un vault
/// potentiellement incohérent (ce qui, avant ce garde-fou, ne se
/// manifestait que bien plus tard par l'échec de déchiffrement d'un
/// fichier précis, sans lien évident avec sa cause réelle).
class VaultMigrationInterruptedScreen extends StatelessWidget {
  final String vaultPath;
  final VoidCallback onContinueAnyway;

  const VaultMigrationInterruptedScreen({
    super.key,
    required this.vaultPath,
    required this.onContinueAnyway,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.triangleAlert,
                  size: 56,
                  color: Theme.of(context).colorScheme.destructive,
                ),
                const SizedBox(height: 24),
                shadcn.Text(
                  l10n.onboarding_migration_interrupted_title,
                  textAlign: TextAlign.center,
                ).large().large().medium(),
                const SizedBox(height: 12),
                shadcn.Text(
                  l10n.onboarding_migration_interrupted_description,
                  textAlign: TextAlign.center,
                ).muted(),
                const SizedBox(height: 12),
                shadcn.Text(
                  vaultPath,
                  textAlign: TextAlign.center,
                ).muted().xSmall(),
                const SizedBox(height: 24),
                shadcn.Text(
                  l10n.onboarding_migration_interrupted_recommendation,
                  textAlign: TextAlign.center,
                ).muted().small(),
                const SizedBox(height: 24),
                OutlineButton(
                  onPressed: onContinueAnyway,
                  child: shadcn.Text(
                    l10n.onboarding_migration_interrupted_continue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

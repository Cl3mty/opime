import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../l10n/app_localizations.dart';

/// Web uniquement : affiché quand le coffre-fort actif est un dossier réel
/// choisi via l'API File System Access (voir `VaultFolderService`) et que le
/// navigateur a besoin d'une confirmation explicite de l'utilisateur pour
/// ré-autoriser l'accès à ce dossier — typique après un rechargement de
/// page ou une nouvelle session de navigateur (à la différence de l'OPFS,
/// qui n'a jamais besoin de cette confirmation). La ré-autorisation
/// elle-même ([onReauthorize]) DOIT être déclenchée directement par le clic
/// sur le bouton ci-dessous : le navigateur rejette silencieusement
/// `requestPermission()` si elle n'est pas appelée depuis un geste
/// utilisateur direct (voir `vault_fs_web.dart`).
class LocalFolderReauthScreen extends StatefulWidget {
  final String vaultName;
  final Future<bool> Function() onReauthorize;

  const LocalFolderReauthScreen({
    super.key,
    required this.vaultName,
    required this.onReauthorize,
  });

  @override
  State<LocalFolderReauthScreen> createState() =>
      _LocalFolderReauthScreenState();
}

class _LocalFolderReauthScreenState extends State<LocalFolderReauthScreen> {
  bool _loading = false;
  bool _failed = false;

  Future<void> _reauthorize() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final ok = await widget.onReauthorize();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.folderLock,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.onboarding_local_folder_reauth_title,
                  textAlign: TextAlign.center,
                ).large().large().medium(),
                const SizedBox(height: 12),
                Text(
                  l10n.onboarding_local_folder_reauth_description(
                    widget.vaultName,
                  ),
                  textAlign: TextAlign.center,
                ).muted(),
                const SizedBox(height: 24),
                PrimaryButton(
                  onPressed: _loading ? null : _reauthorize,
                  leading: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(LucideIcons.folderLock),
                  child: Text(l10n.onboarding_local_folder_reauth_button),
                ),
                if (_failed) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.onboarding_local_folder_reauth_failed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.destructive,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

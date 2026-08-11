import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/storage/vault_folder_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VaultFolderService vaultFolderService;
  final ValueChanged<String> onVaultReady;

  const OnboardingScreen({
    super.key,
    required this.vaultFolderService,
    required this.onVaultReady,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = await widget.vaultFolderService.pickAndCreateVaultFolder();
      if (path == null) {
        setState(() => _loading = false);
        return;
      }
      widget.onVaultReady(path);
    } catch (e) {
      setState(() {
        _error = 'Impossible de créer le dossier de données : $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  LucideIcons.folderOpen,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Bienvenue sur Opime',
                  textAlign: TextAlign.center,
                ).large().large().medium(),
                const SizedBox(height: 12),
                const Text(
                  'Choisis où seront stockées tes données. Tu peux commencer en local et déplacer ce dossier vers un service cloud (iCloud, Google Drive, Dropbox...) plus tard.',
                  textAlign: TextAlign.center,
                ).muted(),
                const SizedBox(height: 32),
                PrimaryButton(
                  onPressed: _loading ? null : _pick,
                  leading: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(LucideIcons.folder),
                  child: Text(
                    _loading ? 'Création...' : 'Choisir un emplacement',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
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

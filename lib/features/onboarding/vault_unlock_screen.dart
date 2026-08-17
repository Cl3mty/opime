import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/storage/vault_crypto.dart';
import '../../core/storage/vault_encryption_metadata.dart';
import '../../core/storage/vault_folder_service.dart';

/// Écran affiché au lancement quand le vault actif est chiffré (voir
/// `main.dart`'s `_buildHome`, entre "vault trouvé" et le chargement des
/// profils — rien d'autre ne peut lire quoi que ce soit avant la
/// déverrouiller). Même structure visuelle que `OnboardingScreen`.
class VaultUnlockScreen extends StatefulWidget {
  final VaultEncryptionMetadata metadata;
  final ValueChanged<VaultCipher> onUnlocked;
  final VoidCallback onForgotPassword;

  /// Permettent de changer de dossier vault directement depuis cet écran —
  /// utile si le mot de passe saisi n'est pas celui du vault actuellement
  /// sélectionné (ex : mauvais dossier iCloud/Dropbox), sans devoir d'abord
  /// se déverrouiller pour atteindre les Réglages.
  final VaultFolderService vaultFolderService;
  final Future<void> Function(String path) onVaultActivated;

  const VaultUnlockScreen({
    super.key,
    required this.metadata,
    required this.onUnlocked,
    required this.onForgotPassword,
    required this.vaultFolderService,
    required this.onVaultActivated,
  });

  @override
  State<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends State<VaultUnlockScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _pickingFolder = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Laisse le temps au spinner de s'afficher avant la dérivation PBKDF2
    // (synchrone, ~1-2 s), qui bloquerait sinon le tout premier frame.
    await Future.delayed(Duration.zero);
    try {
      final dek = widget.metadata.unlockWithPassword(_controller.text);
      widget.onUnlocked(VaultCipher(dek));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Mot de passe incorrect.';
        _loading = false;
      });
    }
  }

  Future<void> _changeFolder() async {
    setState(() {
      _pickingFolder = true;
      _error = null;
    });
    try {
      final vault = await widget.vaultFolderService.pickAndRememberVault(
        dialogTitle: 'Choisis ou crée un vault Opime',
      );
      if (vault != null) await widget.onVaultActivated(vault.vaultPath);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Impossible de changer de dossier : $e');
      }
    } finally {
      if (mounted) setState(() => _pickingFolder = false);
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
                  LucideIcons.lock,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                const shadcn.Text(
                  'Vault verrouillé',
                  textAlign: TextAlign.center,
                ).large().large().medium(),
                const SizedBox(height: 12),
                const shadcn.Text(
                  'Ce vault est chiffré. Saisis ton mot de passe pour accéder à tes données.',
                  textAlign: TextAlign.center,
                ).muted(),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  obscureText: true,
                  autofocus: true,
                  placeholder: const shadcn.Text('Mot de passe'),
                  onSubmitted: (_) => _loading ? null : _unlock(),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  onPressed: (_loading || _pickingFolder) ? null : _unlock,
                  leading: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(LucideIcons.lockOpen),
                  child: shadcn.Text(
                    _loading ? 'Déverrouillage...' : 'Déverrouiller',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: (_loading || _pickingFolder)
                      ? null
                      : widget.onForgotPassword,
                  child: const shadcn.Text('Mot de passe oublié ?'),
                ),
                TextButton(
                  onPressed: (_loading || _pickingFolder)
                      ? null
                      : _changeFolder,
                  leading: _pickingFolder
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(LucideIcons.folderOpen, size: 14),
                  child: shadcn.Text(
                    _pickingFolder
                        ? 'Sélection en cours...'
                        : 'Changer de dossier de vault',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  shadcn.Text(
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

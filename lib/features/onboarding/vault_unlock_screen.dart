import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/storage/vault_crypto.dart';
import '../../core/storage/vault_encryption_metadata.dart';

/// Écran affiché au lancement quand le vault actif est chiffré (voir
/// `main.dart`'s `_buildHome`, entre "vault trouvé" et le chargement des
/// profils — rien d'autre ne peut lire quoi que ce soit avant la
/// déverrouiller). Même structure visuelle que `OnboardingScreen`.
class VaultUnlockScreen extends StatefulWidget {
  final VaultEncryptionMetadata metadata;
  final ValueChanged<VaultCipher> onUnlocked;
  final VoidCallback onForgotPassword;

  const VaultUnlockScreen({
    super.key,
    required this.metadata,
    required this.onUnlocked,
    required this.onForgotPassword,
  });

  @override
  State<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends State<VaultUnlockScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
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
                  onPressed: _loading ? null : _unlock,
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
                  onPressed: _loading ? null : widget.onForgotPassword,
                  child: const shadcn.Text('Mot de passe oublié ?'),
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

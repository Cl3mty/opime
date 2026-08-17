import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/storage/vault_crypto.dart';
import '../../core/storage/vault_encryption_metadata.dart';
import '../../core/storage/vault_encryption_migration_service.dart';
import '../../core/storage/vault_encryption_repository.dart';
import '../../core/storage/vault_session.dart';
import '../../core/ui/frosted_card.dart';

const _migrationService = VaultEncryptionMigrationService();

/// Ouvre le flux "Activer le chiffrement" : mot de passe → clé de
/// récupération (affichée une seule fois, confirmation obligatoire) →
/// migration "chiffrer en place" de tous les fichiers privés existants
/// (voir `vault_private_paths.dart`). Retourne `true` si le chiffrement a
/// bien été activé (l'appelant doit alors recharger le profil actif pour
/// que les repositories déjà construits utilisent la nouvelle session —
/// voir `VaultSession.current`, posé ici juste avant de retourner).
Future<bool> showEnableEncryptionDialog(
  BuildContext context, {
  required String vaultPath,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _EnableEncryptionDialog(vaultPath: vaultPath),
  );
  return result ?? false;
}

/// Ouvre le flux "Désactiver le chiffrement" : le mot de passe actuel est
/// redemandé (confirmation d'intention plutôt qu'un simple bouton, une
/// migration en clair étant irréversible sans repartir de la clé de
/// récupération), puis migration "déchiffrer en place". Retourne `true` si
/// désactivé avec succès.
Future<bool> showDisableEncryptionDialog(
  BuildContext context, {
  required String vaultPath,
  required VaultEncryptionMetadata metadata,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _DisableEncryptionDialog(vaultPath: vaultPath, metadata: metadata),
  );
  return result ?? false;
}

/// Ouvre le flux "Générer une nouvelle clé de récupération" : le mot de
/// passe actuel est redemandé pour retrouver la DEK (jamais conservée en
/// clair, voir `VaultCipher`), puis une nouvelle clé de récupération est
/// générée et affichée une seule fois — l'ancienne cesse de fonctionner.
Future<bool> showRegenerateRecoveryKeyDialog(
  BuildContext context, {
  required String vaultPath,
  required VaultEncryptionMetadata metadata,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _RegenerateRecoveryKeyDialog(vaultPath: vaultPath, metadata: metadata),
  );
  return result ?? false;
}

/// Cadre visuel partagé par les trois dialogues — même structure que
/// `investment_reestimate_dialog.dart`.
class _DialogFrame extends StatelessWidget {
  final Widget child;
  const _DialogFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  final String label;
  final int done;
  final int total;
  const _ProgressView({
    required this.label,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(label).semiBold(),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: total == 0 ? null : done / total),
        const SizedBox(height: 8),
        shadcn.Text(
          total == 0 ? 'Préparation...' : '$done / $total fichier(s)',
        ).muted().small(),
      ],
    );
  }
}

/// Bulle affichant la clé de récupération à copier, avec une case à cocher
/// obligatoire ("je l'ai notée") avant de pouvoir continuer — c'est le seul
/// moment où cette clé est visible, elle n'est jamais conservée en clair
/// nulle part par la suite (voir `VaultEncryptionMetadata`).
class _RecoveryKeyView extends StatefulWidget {
  final String recoveryKey;
  final VoidCallback onConfirmed;
  const _RecoveryKeyView({
    required this.recoveryKey,
    required this.onConfirmed,
  });

  @override
  State<_RecoveryKeyView> createState() => _RecoveryKeyViewState();
}

class _RecoveryKeyViewState extends State<_RecoveryKeyView> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const shadcn.Text('Ta clé de récupération').large().semiBold(),
        const SizedBox(height: 8),
        const shadcn.Text(
          'Note-la en lieu sûr (gestionnaire de mots de passe, papier...). '
          'Elle permet de redéfinir ton mot de passe si tu l\'oublies — '
          'sans elle, tes données sont définitivement perdues. Elle ne sera '
          'plus jamais affichée.',
        ).muted().small(),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.muted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: SelectableText(
            widget.recoveryKey,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Checkbox(
          state: _confirmed ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (state) =>
              setState(() => _confirmed = state == CheckboxState.checked),
          trailing: const shadcn.Text('J\'ai noté cette clé en lieu sûr'),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          onPressed: _confirmed ? widget.onConfirmed : null,
          child: const shadcn.Text('Continuer'),
        ),
      ],
    );
  }
}

enum _EnableStep { password, recoveryKey, migrating }

class _EnableEncryptionDialog extends StatefulWidget {
  final String vaultPath;
  const _EnableEncryptionDialog({required this.vaultPath});

  @override
  State<_EnableEncryptionDialog> createState() =>
      _EnableEncryptionDialogState();
}

class _EnableEncryptionDialogState extends State<_EnableEncryptionDialog> {
  _EnableStep _step = _EnableStep.password;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _loading = false;

  VaultEncryptionMetadata? _metadata;
  String? _recoveryKey;
  Uint8List? _dek;
  int _done = 0;
  int _total = 0;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Choisis un mot de passe.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'Les deux mots de passe ne correspondent pas.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(Duration.zero);
    final recoveryKey = generateRecoveryKey();
    final metadata = VaultEncryptionMetadata.create(
      password: password,
      recoveryKey: recoveryKey,
    );
    if (!mounted) return;
    setState(() {
      _metadata = metadata;
      _recoveryKey = recoveryKey;
      _dek = metadata.unlockWithPassword(password);
      _loading = false;
      _step = _EnableStep.recoveryKey;
    });
  }

  Future<void> _runMigration() async {
    setState(() => _step = _EnableStep.migrating);
    final cipher = VaultCipher(_dek!);
    await _migrationService.encryptInPlace(
      vaultPath: widget.vaultPath,
      cipher: cipher,
      onProgress: (done, total) {
        if (mounted) {
          setState(() {
            _done = done;
            _total = total;
          });
        }
      },
    );
    await VaultEncryptionRepository(widget.vaultPath).save(_metadata!);
    VaultSession.current = cipher;
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return _DialogFrame(
      child: switch (_step) {
        _EnableStep.password => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const shadcn.Text('Activer le chiffrement').large().semiBold(),
            const SizedBox(height: 8),
            const shadcn.Text(
              'Choisis un mot de passe pour chiffrer les données privées de '
              'ce vault (comptes, budget, passifs, projets, notes de '
              'stratégie, simulations). Il te sera redemandé à chaque '
              'lancement de l\'app.',
            ).muted().small(),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              placeholder: const shadcn.Text('Mot de passe'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              placeholder: const shadcn.Text('Confirmer le mot de passe'),
              onSubmitted: (_) => _loading ? null : _submitPassword(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              shadcn.Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.destructive,
                ),
              ).small(),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlineButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const shadcn.Text('Annuler'),
                ),
                const SizedBox(width: 8),
                PrimaryButton(
                  onPressed: _loading ? null : _submitPassword,
                  leading: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(),
                        )
                      : null,
                  child: const shadcn.Text('Continuer'),
                ),
              ],
            ),
          ],
        ),
        _EnableStep.recoveryKey => _RecoveryKeyView(
          recoveryKey: _recoveryKey!,
          onConfirmed: _runMigration,
        ),
        _EnableStep.migrating => _ProgressView(
          label: 'Chiffrement des données en cours...',
          done: _done,
          total: _total,
        ),
      },
    );
  }
}

enum _DisableStep { password, migrating }

class _DisableEncryptionDialog extends StatefulWidget {
  final String vaultPath;
  final VaultEncryptionMetadata metadata;
  const _DisableEncryptionDialog({
    required this.vaultPath,
    required this.metadata,
  });

  @override
  State<_DisableEncryptionDialog> createState() =>
      _DisableEncryptionDialogState();
}

class _DisableEncryptionDialogState extends State<_DisableEncryptionDialog> {
  _DisableStep _step = _DisableStep.password;
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;
  int _done = 0;
  int _total = 0;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(Duration.zero);
    Uint8List dek;
    try {
      dek = widget.metadata.unlockWithPassword(_passwordController.text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Mot de passe incorrect.';
        _loading = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _step = _DisableStep.migrating);
    final cipher = VaultCipher(dek);
    await _migrationService.decryptInPlace(
      vaultPath: widget.vaultPath,
      cipher: cipher,
      onProgress: (done, total) {
        if (mounted) {
          setState(() {
            _done = done;
            _total = total;
          });
        }
      },
    );
    await VaultEncryptionRepository(widget.vaultPath).delete();
    VaultSession.current = null;
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return _DialogFrame(
      child: switch (_step) {
        _DisableStep.password => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const shadcn.Text('Désactiver le chiffrement').large().semiBold(),
            const SizedBox(height: 8),
            const shadcn.Text(
              'Les données privées de ce vault redeviendront des fichiers '
              'en clair. Confirme ton mot de passe pour continuer.',
            ).muted().small(),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              placeholder: const shadcn.Text('Mot de passe'),
              onSubmitted: (_) => _loading ? null : _submitPassword(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              shadcn.Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.destructive,
                ),
              ).small(),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlineButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const shadcn.Text('Annuler'),
                ),
                const SizedBox(width: 8),
                DestructiveButton(
                  onPressed: _loading ? null : _submitPassword,
                  leading: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(),
                        )
                      : null,
                  child: const shadcn.Text('Désactiver'),
                ),
              ],
            ),
          ],
        ),
        _DisableStep.migrating => _ProgressView(
          label: 'Déchiffrement des données en cours...',
          done: _done,
          total: _total,
        ),
      },
    );
  }
}

enum _RegenerateStep { password, recoveryKey }

class _RegenerateRecoveryKeyDialog extends StatefulWidget {
  final String vaultPath;
  final VaultEncryptionMetadata metadata;
  const _RegenerateRecoveryKeyDialog({
    required this.vaultPath,
    required this.metadata,
  });

  @override
  State<_RegenerateRecoveryKeyDialog> createState() =>
      _RegenerateRecoveryKeyDialogState();
}

class _RegenerateRecoveryKeyDialogState
    extends State<_RegenerateRecoveryKeyDialog> {
  _RegenerateStep _step = _RegenerateStep.password;
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;
  String? _newRecoveryKey;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(Duration.zero);
    Uint8List dek;
    try {
      dek = widget.metadata.unlockWithPassword(_passwordController.text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Mot de passe incorrect.';
        _loading = false;
      });
      return;
    }
    final (updated, newRecoveryKey) = widget.metadata.rewrapWithNewRecoveryKey(
      dek,
    );
    await VaultEncryptionRepository(widget.vaultPath).save(updated);
    if (!mounted) return;
    setState(() {
      _newRecoveryKey = newRecoveryKey;
      _loading = false;
      _step = _RegenerateStep.recoveryKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _DialogFrame(
      child: switch (_step) {
        _RegenerateStep.password => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const shadcn.Text(
              'Générer une nouvelle clé de récupération',
            ).large().semiBold(),
            const SizedBox(height: 8),
            const shadcn.Text(
              'Confirme ton mot de passe. L\'ancienne clé de récupération '
              'cessera de fonctionner.',
            ).muted().small(),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              placeholder: const shadcn.Text('Mot de passe'),
              onSubmitted: (_) => _loading ? null : _submitPassword(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              shadcn.Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.destructive,
                ),
              ).small(),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlineButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const shadcn.Text('Annuler'),
                ),
                const SizedBox(width: 8),
                PrimaryButton(
                  onPressed: _loading ? null : _submitPassword,
                  leading: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(),
                        )
                      : null,
                  child: const shadcn.Text('Continuer'),
                ),
              ],
            ),
          ],
        ),
        _RegenerateStep.recoveryKey => _RecoveryKeyView(
          recoveryKey: _newRecoveryKey!,
          onConfirmed: () => Navigator.of(context).pop(true),
        ),
      },
    );
  }
}

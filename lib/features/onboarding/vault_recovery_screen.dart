import 'dart:typed_data' show Uint8List;

import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/storage/vault_crypto.dart';
import '../../core/storage/vault_encryption_metadata.dart';
import '../../l10n/app_localizations.dart';

/// Mécanisme de récupération en cas de mot de passe oublié — accessible
/// depuis [VaultUnlockScreen]. Deux temps : la clé de récupération
/// désenveloppe la DEK (indépendamment du mot de passe, voir
/// `vault_encryption_metadata.dart`), puis un nouveau mot de passe est
/// exigé immédiatement (la DEK est ré-enveloppée sous ce nouveau mot de
/// passe, sans toucher à aucun fichier du vault — voir
/// [VaultEncryptionMetadata.rewrapPassword]).
class VaultRecoveryScreen extends StatefulWidget {
  final VaultEncryptionMetadata metadata;

  /// Appelé une fois la récupération terminée : [updatedMetadata] (avec la
  /// nouvelle enveloppe mot de passe) doit être persisté par l'appelant
  /// (voir `VaultEncryptionRepository.save`), puis [cipher] utilisé pour
  /// déverrouiller la session comme un déverrouillage classique.
  final Future<void> Function(
    VaultEncryptionMetadata updatedMetadata,
    VaultCipher cipher,
  )
  onRecovered;
  final VoidCallback onCancel;

  const VaultRecoveryScreen({
    super.key,
    required this.metadata,
    required this.onRecovered,
    required this.onCancel,
  });

  @override
  State<VaultRecoveryScreen> createState() => _VaultRecoveryScreenState();
}

class _VaultRecoveryScreenState extends State<VaultRecoveryScreen> {
  final _recoveryKeyController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// `null` : saisie de la clé de récupération. Non-null : clé validée, DEK
  /// désenveloppée, saisie du nouveau mot de passe.
  Uint8List? _recoveredDek;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _recoveryKeyController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyRecoveryKey() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(Duration.zero);
    try {
      final dek = widget.metadata.unlockWithRecoveryKey(
        _recoveryKeyController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _recoveredDek = dek;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context).onboarding_recovery_key_incorrect;
        _loading = false;
      });
    }
  }

  Future<void> _setNewPassword() async {
    final l10n = AppLocalizations.of(context);
    final newPassword = _newPasswordController.text;
    if (newPassword.isEmpty) {
      setState(() => _error = l10n.onboarding_choose_password);
      return;
    }
    if (newPassword != _confirmPasswordController.text) {
      setState(() => _error = l10n.onboarding_passwords_mismatch);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(Duration.zero);
    final dek = _recoveredDek!;
    final updated = widget.metadata.rewrapPassword(
      dek: dek,
      newPassword: newPassword,
    );
    await widget.onRecovered(updated, VaultCipher(dek));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recovered = _recoveredDek != null;
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
                  LucideIcons.keyRound,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                shadcn.Text(
                  recovered
                      ? l10n.onboarding_recovery_new_password_title
                      : l10n.onboarding_recovery_title,
                  textAlign: TextAlign.center,
                ).large().large().medium(),
                const SizedBox(height: 12),
                shadcn.Text(
                  recovered
                      ? l10n.onboarding_recovery_new_password_description
                      : l10n.onboarding_recovery_description,
                  textAlign: TextAlign.center,
                ).muted(),
                const SizedBox(height: 24),
                if (!recovered) ...[
                  TextField(
                    controller: _recoveryKeyController,
                    autofocus: true,
                    placeholder: shadcn.Text(
                      l10n.onboarding_recovery_key_hint,
                    ),
                    onSubmitted: (_) => _loading ? null : _verifyRecoveryKey(),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    onPressed: _loading ? null : _verifyRecoveryKey,
                    leading: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(LucideIcons.check),
                    child: shadcn.Text(
                      _loading
                          ? l10n.onboarding_recovery_verifying
                          : l10n.onboarding_recovery_validate_key,
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    autofocus: true,
                    placeholder: shadcn.Text(l10n.onboarding_new_password),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    placeholder: shadcn.Text(
                      l10n.onboarding_confirm_new_password,
                    ),
                    onSubmitted: (_) => _loading ? null : _setNewPassword(),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    onPressed: _loading ? null : _setNewPassword,
                    leading: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(LucideIcons.lockOpen),
                    child: shadcn.Text(
                      _loading
                          ? l10n.onboarding_recovery_saving
                          : l10n.onboarding_recovery_set_and_unlock,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : widget.onCancel,
                  child: shadcn.Text(l10n.common_cancel),
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

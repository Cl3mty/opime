import 'dart:convert';
import 'dart:typed_data';

import 'vault_crypto.dart';

/// Texte connu chiffré sous la DEK à l'activation — permet de vérifier
/// qu'un mot de passe/une clé de récupération est correct (le déchiffrement
/// de [VaultEncryptionMetadata.verification] réussit et retombe sur cette
/// valeur) avant de tenter de lire un vrai fichier du vault.
const _verificationPlaintext = 'opime-vault-check';

/// Métadonnées de chiffrement du vault — persistées en clair (jamais
/// chiffrées elles-mêmes, elles doivent rester lisibles pour tenter un
/// déverrouillage) dans `<vault>/.opime/vault_encryption.json`. Porte la
/// DEK (clé de chiffrement des données) enveloppée deux fois — une fois
/// sous une clé dérivée du mot de passe, une fois sous une clé dérivée de
/// la clé de récupération — voir `vault_crypto.dart`'s `wrapDek`/`unwrapDek`
/// pour la conception "clé enveloppée".
class VaultEncryptionMetadata {
  final bool enabled;
  final Uint8List passwordSalt;
  final int passwordIterations;
  final Uint8List recoverySalt;
  final int recoveryIterations;
  final SealedBox verification;
  final SealedBox wrappedDekByPassword;
  final SealedBox wrappedDekByRecoveryKey;

  const VaultEncryptionMetadata({
    required this.enabled,
    required this.passwordSalt,
    required this.passwordIterations,
    required this.recoverySalt,
    required this.recoveryIterations,
    required this.verification,
    required this.wrappedDekByPassword,
    required this.wrappedDekByRecoveryKey,
  });

  /// Active le chiffrement : génère une nouvelle DEK aléatoire, l'enveloppe
  /// sous [password] ET sous [recoveryKey] (chacun avec son propre sel), et
  /// prépare la valeur de vérification. [dek] n'est exposé que pour les
  /// tests (déterminisme) — en usage normal, une DEK aléatoire est générée.
  factory VaultEncryptionMetadata.create({
    required String password,
    required String recoveryKey,
    Uint8List? dek,
  }) {
    final actualDek = dek ?? generateDek();
    final passwordSalt = generateSalt();
    final recoverySalt = generateSalt();
    return VaultEncryptionMetadata(
      enabled: true,
      passwordSalt: passwordSalt,
      passwordIterations: kVaultKdfIterations,
      recoverySalt: recoverySalt,
      recoveryIterations: kVaultKdfIterations,
      verification: seal(
        Uint8List.fromList(utf8.encode(_verificationPlaintext)),
        actualDek,
      ),
      wrappedDekByPassword: wrapDek(
        dek: actualDek,
        secret: password,
        salt: passwordSalt,
      ),
      wrappedDekByRecoveryKey: wrapDek(
        dek: actualDek,
        secret: recoveryKey,
        salt: recoverySalt,
      ),
    );
  }

  /// Désenveloppe la DEK à partir de [password] et vérifie qu'elle est
  /// correcte — lève une exception si le mot de passe est erroné (échec de
  /// désenveloppement ou, plus rarement, échec de la vérification malgré un
  /// désenveloppement réussi).
  Uint8List unlockWithPassword(String password) {
    final dek = unwrapDek(
      wrapped: wrappedDekByPassword,
      secret: password,
      salt: passwordSalt,
      iterations: passwordIterations,
    );
    _verifyDek(dek);
    return dek;
  }

  /// Comme [unlockWithPassword], via la clé de récupération plutôt que le
  /// mot de passe — c'est le mécanisme de récupération en cas de mot de
  /// passe oublié, indépendant de ce dernier.
  Uint8List unlockWithRecoveryKey(String recoveryKey) {
    final dek = unwrapDek(
      wrapped: wrappedDekByRecoveryKey,
      secret: recoveryKey,
      salt: recoverySalt,
      iterations: recoveryIterations,
    );
    _verifyDek(dek);
    return dek;
  }

  /// Ré-enveloppe la DEK (déjà déverrouillée) sous un nouveau mot de passe —
  /// ne re-chiffre aucun fichier du vault, seule la DEK change
  /// d'enveloppe (voir la doc de tête sur la conception "clé enveloppée").
  VaultEncryptionMetadata rewrapPassword({
    required Uint8List dek,
    required String newPassword,
  }) {
    final newSalt = generateSalt();
    return _copyWith(
      passwordSalt: newSalt,
      passwordIterations: kVaultKdfIterations,
      wrappedDekByPassword: wrapDek(
        dek: dek,
        secret: newPassword,
        salt: newSalt,
      ),
    );
  }

  /// Ré-enveloppe la DEK (déjà déverrouillée) sous une nouvelle clé de
  /// récupération fraîchement générée — invalide l'ancienne. Voir
  /// [rewrapPassword] : même principe, sans re-chiffrer aucun fichier.
  (VaultEncryptionMetadata, String) rewrapWithNewRecoveryKey(Uint8List dek) {
    final newRecoveryKey = generateRecoveryKey();
    final newSalt = generateSalt();
    final updated = _copyWith(
      recoverySalt: newSalt,
      recoveryIterations: kVaultKdfIterations,
      wrappedDekByRecoveryKey: wrapDek(
        dek: dek,
        secret: newRecoveryKey,
        salt: newSalt,
      ),
    );
    return (updated, newRecoveryKey);
  }

  void _verifyDek(Uint8List dek) {
    final decrypted = utf8.decode(unseal(verification, dek));
    if (decrypted != _verificationPlaintext) {
      throw StateError(
        'Vérification échouée : la DEK désenveloppée ne correspond pas à ce vault.',
      );
    }
  }

  VaultEncryptionMetadata _copyWith({
    bool? enabled,
    Uint8List? passwordSalt,
    int? passwordIterations,
    Uint8List? recoverySalt,
    int? recoveryIterations,
    SealedBox? verification,
    SealedBox? wrappedDekByPassword,
    SealedBox? wrappedDekByRecoveryKey,
  }) => VaultEncryptionMetadata(
    enabled: enabled ?? this.enabled,
    passwordSalt: passwordSalt ?? this.passwordSalt,
    passwordIterations: passwordIterations ?? this.passwordIterations,
    recoverySalt: recoverySalt ?? this.recoverySalt,
    recoveryIterations: recoveryIterations ?? this.recoveryIterations,
    verification: verification ?? this.verification,
    wrappedDekByPassword: wrappedDekByPassword ?? this.wrappedDekByPassword,
    wrappedDekByRecoveryKey:
        wrappedDekByRecoveryKey ?? this.wrappedDekByRecoveryKey,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'enabled': enabled,
    'passwordKdf': {
      'algorithm': 'pbkdf2-hmac-sha256',
      'salt': base64Encode(passwordSalt),
      'iterations': passwordIterations,
    },
    'recoveryKdf': {
      'algorithm': 'pbkdf2-hmac-sha256',
      'salt': base64Encode(recoverySalt),
      'iterations': recoveryIterations,
    },
    'verification': _sealedToJson(verification),
    'wrappedDekByPassword': _sealedToJson(wrappedDekByPassword),
    'wrappedDekByRecoveryKey': _sealedToJson(wrappedDekByRecoveryKey),
  };

  factory VaultEncryptionMetadata.fromJson(Map<String, dynamic> json) {
    final passwordKdf = json['passwordKdf'] as Map<String, dynamic>;
    final recoveryKdf = json['recoveryKdf'] as Map<String, dynamic>;
    return VaultEncryptionMetadata(
      enabled: json['enabled'] as bool? ?? false,
      passwordSalt: base64Decode(passwordKdf['salt'] as String),
      passwordIterations: passwordKdf['iterations'] as int,
      recoverySalt: base64Decode(recoveryKdf['salt'] as String),
      recoveryIterations: recoveryKdf['iterations'] as int,
      verification: _sealedFromJson(
        json['verification'] as Map<String, dynamic>,
      ),
      wrappedDekByPassword: _sealedFromJson(
        json['wrappedDekByPassword'] as Map<String, dynamic>,
      ),
      wrappedDekByRecoveryKey: _sealedFromJson(
        json['wrappedDekByRecoveryKey'] as Map<String, dynamic>,
      ),
    );
  }
}

Map<String, dynamic> _sealedToJson(SealedBox box) => {
  'nonce': base64Encode(box.nonce),
  'ciphertext': base64Encode(box.ciphertext),
};

SealedBox _sealedFromJson(Map<String, dynamic> json) => SealedBox(
  nonce: base64Decode(json['nonce'] as String),
  ciphertext: base64Decode(json['ciphertext'] as String),
);

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_crypto.dart';
import 'package:opime/core/storage/vault_encryption_metadata.dart';

void main() {
  group('VaultEncryptionMetadata.create', () {
    test(
      'le mot de passe et la clé de récupération déverrouillent tous deux la même DEK',
      () {
        final dek = generateDek();
        final metadata = VaultEncryptionMetadata.create(
          password: 'mon mot de passe',
          recoveryKey: 'ABCD-EFGH-1234',
          dek: dek,
        );

        expect(metadata.unlockWithPassword('mon mot de passe'), dek);
        expect(metadata.unlockWithRecoveryKey('ABCD-EFGH-1234'), dek);
      },
    );

    test('enabled vaut true par défaut à la création', () {
      final metadata = VaultEncryptionMetadata.create(
        password: 'x',
        recoveryKey: 'y',
      );
      expect(metadata.enabled, isTrue);
    });
  });

  group('unlockWithPassword / unlockWithRecoveryKey', () {
    late VaultEncryptionMetadata metadata;

    setUp(() {
      metadata = VaultEncryptionMetadata.create(
        password: 'correct-password',
        recoveryKey: 'RECOVERY-KEY-1',
      );
    });

    test('un mot de passe erroné lève une exception', () {
      expect(
        () => metadata.unlockWithPassword('wrong-password'),
        throwsA(anything),
      );
    });

    test('une clé de récupération erronée lève une exception', () {
      expect(
        () => metadata.unlockWithRecoveryKey('WRONG-KEY'),
        throwsA(anything),
      );
    });
  });

  group('rewrapPassword', () {
    test('la DEK reste identique, le nouveau mot de passe la déverrouille', () {
      final metadata = VaultEncryptionMetadata.create(
        password: 'old-password',
        recoveryKey: 'RECOVERY-KEY-1',
      );
      final dek = metadata.unlockWithPassword('old-password');

      final rewrapped = metadata.rewrapPassword(
        dek: dek,
        newPassword: 'new-password',
      );

      expect(rewrapped.unlockWithPassword('new-password'), dek);
      expect(
        () => rewrapped.unlockWithPassword('old-password'),
        throwsA(anything),
      );
      // La clé de récupération, elle, continue de fonctionner sans
      // changement : seule l'enveloppe mot de passe a été remplacée.
      expect(rewrapped.unlockWithRecoveryKey('RECOVERY-KEY-1'), dek);
    });
  });

  group('rewrapWithNewRecoveryKey', () {
    test(
      'génère une nouvelle clé de récupération qui déverrouille la même DEK',
      () {
        final metadata = VaultEncryptionMetadata.create(
          password: 'password',
          recoveryKey: 'OLD-RECOVERY-KEY',
        );
        final dek = metadata.unlockWithPassword('password');

        final (rewrapped, newRecoveryKey) = metadata.rewrapWithNewRecoveryKey(
          dek,
        );

        expect(rewrapped.unlockWithRecoveryKey(newRecoveryKey), dek);
        expect(
          () => rewrapped.unlockWithRecoveryKey('OLD-RECOVERY-KEY'),
          throwsA(anything),
        );
        expect(rewrapped.unlockWithPassword('password'), dek);
      },
    );
  });

  group('toJson / fromJson', () {
    test('aller-retour restitue un déverrouillage identique', () {
      final original = VaultEncryptionMetadata.create(
        password: 'password',
        recoveryKey: 'RECOVERY-KEY',
      );

      final roundTripped = VaultEncryptionMetadata.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      final dekFromOriginal = original.unlockWithPassword('password');
      final dekFromRoundTrip = roundTripped.unlockWithPassword('password');
      expect(dekFromRoundTrip, dekFromOriginal);
      expect(roundTripped.enabled, isTrue);
    });
  });
}

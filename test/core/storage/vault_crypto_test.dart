import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_crypto.dart';

void main() {
  group('deriveKey (PBKDF2)', () {
    test('déterministe : même mot de passe + même sel -> même clé', () {
      final salt = generateSalt();
      final a = deriveKey(
        secret: 'correct horse',
        salt: salt,
        iterations: 1000,
      );
      final b = deriveKey(
        secret: 'correct horse',
        salt: salt,
        iterations: 1000,
      );
      expect(a, b);
    });

    test('un sel différent produit une clé différente', () {
      final a = deriveKey(
        secret: 'correct horse',
        salt: generateSalt(),
        iterations: 1000,
      );
      final b = deriveKey(
        secret: 'correct horse',
        salt: generateSalt(),
        iterations: 1000,
      );
      expect(a, isNot(b));
    });

    test('la clé dérivée fait 32 octets (AES-256)', () {
      final key = deriveKey(
        secret: 'x',
        salt: generateSalt(),
        iterations: 1000,
      );
      expect(key.length, 32);
    });
  });

  group('seal / unseal (AES-256-GCM)', () {
    test('aller-retour restitue le texte clair d\'origine', () {
      final key = randomBytes(32);
      final plaintext = Uint8List.fromList('hello vault'.codeUnits);

      final sealed = seal(plaintext, key);
      final decrypted = unseal(sealed, key);

      expect(decrypted, plaintext);
    });

    test('deux chiffrements du même texte utilisent des nonces différents', () {
      final key = randomBytes(32);
      final plaintext = Uint8List.fromList('hello vault'.codeUnits);

      final a = seal(plaintext, key);
      final b = seal(plaintext, key);

      expect(a.nonce, isNot(b.nonce));
      expect(a.ciphertext, isNot(b.ciphertext));
    });

    test('une clé incorrecte fait échouer le déchiffrement', () {
      final key = randomBytes(32);
      final wrongKey = randomBytes(32);
      final sealed = seal(Uint8List.fromList('secret'.codeUnits), key);

      expect(() => unseal(sealed, wrongKey), throwsA(anything));
    });

    test(
      'un ciphertext altéré fait échouer le déchiffrement (détection de falsification)',
      () {
        final key = randomBytes(32);
        final sealed = seal(Uint8List.fromList('secret'.codeUnits), key);
        final tampered = Uint8List.fromList(sealed.ciphertext);
        tampered[0] ^= 0xFF;

        expect(
          () =>
              unseal(SealedBox(nonce: sealed.nonce, ciphertext: tampered), key),
          throwsA(anything),
        );
      },
    );
  });

  group('encodeSealed / decodeSealed', () {
    test('aller-retour restitue nonce et ciphertext identiques', () {
      final key = randomBytes(32);
      final sealed = seal(Uint8List.fromList('data'.codeUnits), key);

      final encoded = encodeSealed(sealed);
      final decoded = decodeSealed(encoded);

      expect(decoded.nonce, sealed.nonce);
      expect(decoded.ciphertext, sealed.ciphertext);
    });

    test(
      'des octets trop courts pour contenir un nonce lèvent FormatException',
      () {
        expect(() => decodeSealed(Uint8List(5)), throwsFormatException);
      },
    );
  });

  group('wrapDek / unwrapDek', () {
    test(
      'le mot de passe et la clé de récupération retrouvent la même DEK, indépendamment',
      () {
        final dek = generateDek();
        const password = 'mon mot de passe';
        const recoveryKey = 'XXXX-YYYY-ZZZZ';
        final passwordSalt = generateSalt();
        final recoverySalt = generateSalt();

        final wrappedByPassword = wrapDek(
          dek: dek,
          secret: password,
          salt: passwordSalt,
          iterations: 1000,
        );
        final wrappedByRecovery = wrapDek(
          dek: dek,
          secret: recoveryKey,
          salt: recoverySalt,
          iterations: 1000,
        );

        final unwrappedByPassword = unwrapDek(
          wrapped: wrappedByPassword,
          secret: password,
          salt: passwordSalt,
          iterations: 1000,
        );
        final unwrappedByRecovery = unwrapDek(
          wrapped: wrappedByRecovery,
          secret: recoveryKey,
          salt: recoverySalt,
          iterations: 1000,
        );

        expect(unwrappedByPassword, dek);
        expect(unwrappedByRecovery, dek);
      },
    );

    test('un mot de passe erroné ne désenveloppe pas la DEK', () {
      final dek = generateDek();
      final salt = generateSalt();
      final wrapped = wrapDek(
        dek: dek,
        secret: 'bon mot de passe',
        salt: salt,
        iterations: 1000,
      );

      expect(
        () => unwrapDek(
          wrapped: wrapped,
          secret: 'mauvais mot de passe',
          salt: salt,
          iterations: 1000,
        ),
        throwsA(anything),
      );
    });
  });

  group('generateRecoveryKey', () {
    test('longueur et alphabet cohérents, sans caractères ambigus', () {
      final key = generateRecoveryKey();
      expect(key, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z-]+$')));
      // Pas de 0 ambigu avec O ni de 1 avec I/L — l'alphabet Crockford les
      // exclut déjà, on vérifie juste qu'aucun ne s'est glissé dedans.
      expect(key.contains('O'), isFalse);
      expect(key.contains('I'), isFalse);
      expect(key.contains('L'), isFalse);
      expect(key.contains('U'), isFalse);
    });

    test('deux générations successives produisent des clés différentes', () {
      expect(generateRecoveryKey(), isNot(generateRecoveryKey()));
    });
  });

  group('VaultCipher', () {
    test('aller-retour chiffrement/déchiffrement de fichier', () {
      final cipher = VaultCipher(generateDek());
      final plaintext = Uint8List.fromList('{"amount": 1234.56}'.codeUnits);

      final encrypted = cipher.encryptBytes(plaintext);
      final decrypted = cipher.decryptBytes(encrypted);

      expect(decrypted, plaintext);
      expect(encrypted, isNot(plaintext));
    });
  });
}

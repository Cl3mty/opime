import 'dart:convert' show utf8;
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';

/// Itérations PBKDF2-HMAC-SHA256 pour dériver une clé à partir d'un mot de
/// passe/d'une clé de récupération — recommandation OWASP 2023 pour cet
/// algorithme. Cette dérivation s'exécute une fois par déverrouillage (pas
/// par fichier), le coût est donc acceptable même à ce nombre d'itérations.
const kVaultKdfIterations = 310000;

const _saltLength = 16;
const _dekLength = 32; // AES-256
const _nonceLength = 12; // taille de nonce standard pour AES-GCM
const _recoveryKeyBytes = 20;

/// Octets aléatoires cryptographiquement sûrs — sel, DEK, nonce, clé de
/// récupération partagent tous la même source.
Uint8List randomBytes(int length) => enc.SecureRandom(length).bytes;

/// Nouveau sel pour une dérivation PBKDF2 (mot de passe ou clé de
/// récupération) — voir [deriveKey]. Un sel n'est pas secret : il est
/// destiné à être stocké en clair aux côtés du reste des métadonnées de
/// chiffrement (voir `vault_encryption_metadata.dart`).
Uint8List generateSalt() => randomBytes(_saltLength);

/// Nouvelle clé de chiffrement des données (DEK) — 256 bits aléatoires,
/// jamais dérivée directement d'un mot de passe (voir la conception "clé
/// enveloppée" du plan de chiffrement du vault : [wrapDek]/[unwrapDek]).
Uint8List generateDek() => randomBytes(_dekLength);

/// Dérive une clé AES-256 à partir d'un mot de passe (ou d'une clé de
/// récupération) et d'un sel, via PBKDF2-HMAC-SHA256. Le même sel et le
/// même nombre d'itérations doivent être fournis pour retrouver la même
/// clé d'un appel à l'autre.
Uint8List deriveKey({
  required String secret,
  required Uint8List salt,
  int iterations = kVaultKdfIterations,
}) {
  final derivator = PBKDF2KeyDerivator(Mac('SHA-256/HMAC'))
    ..init(Pbkdf2Parameters(salt, iterations, _dekLength));
  return derivator.process(Uint8List.fromList(utf8.encode(secret)));
}

/// Résultat d'un chiffrement AES-256-GCM — [nonce] (12 octets, généré à
/// chaque appel, jamais réutilisé) et [ciphertext] (qui inclut déjà le tag
/// d'authentification de 16 octets ajouté par GCM). Voir
/// [encodeSealed]/[decodeSealed] pour leur représentation concaténée sur
/// disque.
class SealedBox {
  final Uint8List nonce;
  final Uint8List ciphertext;
  const SealedBox({required this.nonce, required this.ciphertext});
}

enc.Encrypter _gcmEncrypter(Uint8List key) =>
    enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));

/// Chiffre [plaintext] sous [key] (32 octets, AES-256).
SealedBox seal(Uint8List plaintext, Uint8List key) {
  final nonce = randomBytes(_nonceLength);
  final encrypted = _gcmEncrypter(
    key,
  ).encryptBytes(plaintext, iv: enc.IV(nonce));
  return SealedBox(nonce: nonce, ciphertext: encrypted.bytes);
}

/// Déchiffre un [SealedBox] sous [key] — lève une exception si [key] est
/// incorrecte ou si les octets ont été altérés (échec de vérification du
/// tag d'authentification GCM) : jamais de contenu déchiffré silencieusement
/// faux, l'appelant doit traiter toute exception comme "mot de passe erroné
/// ou fichier corrompu".
Uint8List unseal(SealedBox box, Uint8List key) {
  final bytes = _gcmEncrypter(
    key,
  ).decryptBytes(enc.Encrypted(box.ciphertext), iv: enc.IV(box.nonce));
  return Uint8List.fromList(bytes);
}

/// Concatène nonce+ciphertext pour l'écriture sur disque d'un fichier
/// chiffré (voir `vault_file_storage.dart`).
Uint8List encodeSealed(SealedBox box) =>
    Uint8List.fromList([...box.nonce, ...box.ciphertext]);

/// Reconstruit un [SealedBox] à partir des octets bruts d'un fichier
/// chiffré — lève une [FormatException] si le fichier est trop court pour
/// contenir ne serait-ce que le nonce (fichier tronqué/corrompu).
SealedBox decodeSealed(Uint8List bytes) {
  if (bytes.length < _nonceLength) {
    throw const FormatException('Fichier chiffré tronqué : nonce manquant.');
  }
  return SealedBox(
    nonce: bytes.sublist(0, _nonceLength),
    ciphertext: bytes.sublist(_nonceLength),
  );
}

/// Enveloppe (chiffre) [dek] sous une clé dérivée de [secret]/[salt] — voir
/// la conception "clé enveloppée" du plan : la DEK n'est jamais dérivée
/// directement d'un secret, ce qui permet au mot de passe ET à la clé de
/// récupération de la retrouver indépendamment (chacun avec son propre
/// sel), et rend un futur changement de mot de passe bon marché (ré-
/// envelopper la DEK sans re-chiffrer aucun fichier).
SealedBox wrapDek({
  required Uint8List dek,
  required String secret,
  required Uint8List salt,
  int iterations = kVaultKdfIterations,
}) {
  final kek = deriveKey(secret: secret, salt: salt, iterations: iterations);
  return seal(dek, kek);
}

/// Désenveloppe une DEK précédemment enveloppée par [wrapDek] — lève une
/// exception si [secret] (mot de passe ou clé de récupération) est
/// incorrect.
Uint8List unwrapDek({
  required SealedBox wrapped,
  required String secret,
  required Uint8List salt,
  int iterations = kVaultKdfIterations,
}) {
  final kek = deriveKey(secret: secret, salt: salt, iterations: iterations);
  return unseal(wrapped, kek);
}

const _crockfordAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Génère une clé de récupération lisible par un humain — 20 octets
/// aléatoires (160 bits) encodés en Base32 (alphabet Crockford, sans
/// caractères ambigus comme `0`/`O` ou `1`/`I`), présentée par groupes de 4
/// caractères séparés par des tirets pour faciliter la copie manuelle.
String generateRecoveryKey() {
  final encoded = _crockfordBase32(randomBytes(_recoveryKeyBytes));
  final groups = <String>[];
  for (var i = 0; i < encoded.length; i += 4) {
    groups.add(encoded.substring(i, min(i + 4, encoded.length)));
  }
  return groups.join('-');
}

String _crockfordBase32(Uint8List bytes) {
  final buffer = StringBuffer();
  var bitBuffer = 0;
  var bitCount = 0;
  for (final byte in bytes) {
    bitBuffer = (bitBuffer << 8) | byte;
    bitCount += 8;
    while (bitCount >= 5) {
      bitCount -= 5;
      buffer.write(_crockfordAlphabet[(bitBuffer >> bitCount) & 0x1F]);
    }
  }
  if (bitCount > 0) {
    buffer.write(_crockfordAlphabet[(bitBuffer << (5 - bitCount)) & 0x1F]);
  }
  return buffer.toString();
}

/// Clé de chiffrement des données déverrouillée, prête à chiffrer/déchiffrer
/// les fichiers du vault — vit uniquement en mémoire pour la durée du
/// process (voir `main.dart`), jamais persistée sur disque ni dans
/// `shared_preferences`. Utilisée par `vault_file_storage.dart`.
class VaultCipher {
  final Uint8List _dek;
  const VaultCipher(this._dek);

  Uint8List encryptBytes(Uint8List plaintext) =>
      encodeSealed(seal(plaintext, _dek));

  Uint8List decryptBytes(Uint8List sealedBytes) =>
      unseal(decodeSealed(sealedBytes), _dek);
}

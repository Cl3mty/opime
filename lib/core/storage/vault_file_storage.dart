import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'vault_crypto.dart' show VaultCipher;

/// Point d'entrée unique pour lire/écrire un fichier « privé » du vault
/// (données de patrimoine de l'utilisateur) — transparent : passthrough sur
/// un vault en clair ([cipher] `null`), chiffrement/déchiffrement AES-GCM
/// automatique sur un vault verrouillé par mot de passe ([cipher] non nul).
///
/// Seuls les repositories portant des données privées (comptes, budget,
/// passifs, projets, notes de stratégie, simulations, profils, documents)
/// passent par cette classe — les caches de données publiques/re-
/// téléchargeables (cours de marché, DVF, loyers, frontières géo, logos,
/// images produits) continuent de lire/écrire directement via `dart:io`,
/// hors du périmètre du chiffrement (voir la classification du plan de
/// chiffrement du vault).
///
/// [vaultPath] est la racine à partir de laquelle les chemins relatifs
/// passés à chaque méthode sont résolus — pour la plupart des repositories,
/// c'est le dossier du profil actif ; pour [ProfileRepository]
/// (`core/profiles/profile_repository.dart`), c'est la racine du vault
/// elle-même (`profiles.json` y vit directement).
class VaultFileStorage {
  VaultFileStorage({required this.vaultPath, VaultCipher? cipher})
    : _cipher = cipher;

  final String vaultPath;
  final VaultCipher? _cipher;

  File _resolve(String relativePath) => File(p.join(vaultPath, relativePath));

  Future<bool> exists(String relativePath) => _resolve(relativePath).exists();

  Future<void> delete(String relativePath) async {
    final file = _resolve(relativePath);
    if (await file.exists()) await file.delete();
  }

  /// Lit un fichier texte (JSON, Markdown...) — toujours via les octets
  /// bruts puis décodage UTF-8, jamais `File.readAsString` directement (qui
  /// suppose de l'UTF-8 sur disque, faux une fois chiffré).
  Future<String> readString(String relativePath) async {
    final bytes = await readBytes(relativePath);
    return utf8.decode(bytes);
  }

  Future<void> writeString(String relativePath, String content) =>
      writeBytes(relativePath, utf8.encode(content));

  Future<Uint8List> readBytes(String relativePath) async {
    final bytes = await _resolve(relativePath).readAsBytes();
    if (_cipher == null) return bytes;
    return _cipher.decryptBytes(bytes);
  }

  Future<void> writeBytes(String relativePath, List<int> bytes) async {
    final file = _resolve(relativePath);
    final dir = file.parent;
    if (!await dir.exists()) await dir.create(recursive: true);
    final plain = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await file.writeAsBytes(
      _cipher == null ? plain : _cipher.encryptBytes(plain),
    );
  }
}

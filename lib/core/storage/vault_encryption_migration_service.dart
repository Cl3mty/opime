import 'dart:io';

import 'package:path/path.dart' as p;

import '../profiles/profile_repository.dart';
import 'vault_crypto.dart' show VaultCipher;
import 'vault_file_storage.dart';
import 'vault_private_paths.dart';

/// Chiffre ou déchiffre en place tous les fichiers privés d'un vault (voir
/// `vault_private_paths.dart` pour la liste exacte) — utilisé par les
/// Réglages pour activer/désactiver le chiffrement sur un vault existant.
/// Chaque fichier est lu sous l'ancien état puis réécrit sous le nouveau,
/// un par un ; [onProgress] rapporte `(fichiers traités, total)` pour une
/// barre de progression, le nombre de fichiers pouvant être important sur
/// un vault ancien avec beaucoup d'historique.
///
/// Énumère les profils via [ProfileRepository] en lisant `profiles.json`
/// sous l'état *courant* (avant la migration) — voir [readCipherFor] :
/// `null` avant un chiffrement (le vault est encore en clair à ce stade),
/// la clé existante avant un déchiffrement (le vault est encore chiffré).
class VaultEncryptionMigrationService {
  const VaultEncryptionMigrationService();

  Future<void> encryptInPlace({
    required String vaultPath,
    required VaultCipher cipher,
    void Function(int done, int total)? onProgress,
  }) => _migrate(
    vaultPath: vaultPath,
    from: null,
    to: cipher,
    onProgress: onProgress,
  );

  Future<void> decryptInPlace({
    required String vaultPath,
    required VaultCipher cipher,
    void Function(int done, int total)? onProgress,
  }) => _migrate(
    vaultPath: vaultPath,
    from: cipher,
    to: null,
    onProgress: onProgress,
  );

  Future<void> _migrate({
    required String vaultPath,
    required VaultCipher? from,
    required VaultCipher? to,
    void Function(int done, int total)? onProgress,
  }) async {
    final roots = await _rootsToMigrate(vaultPath, readCipher: from);
    final total = roots.fold<int>(0, (sum, root) => sum + root.$2.length);
    var done = 0;
    onProgress?.call(0, total);

    for (final (rootPath, relativePaths) in roots) {
      final source = VaultFileStorage(vaultPath: rootPath, cipher: from);
      final target = VaultFileStorage(vaultPath: rootPath, cipher: to);
      for (final relativePath in relativePaths) {
        final bytes = await source.readBytes(relativePath);
        await target.writeBytes(relativePath, bytes);
        done++;
        onProgress?.call(done, total);
      }
    }
  }

  /// Une entrée par racine à parcourir : `(vaultPath, ['profiles.json'])`
  /// pour la racine du vault, puis `(dossierDuProfil, [...])` pour chaque
  /// profil — voir [privateRelativePathsForProfile].
  Future<List<(String, List<String>)>> _rootsToMigrate(
    String vaultPath, {
    required VaultCipher? readCipher,
  }) async {
    final roots = <(String, List<String>)>[];

    if (await File(p.join(vaultPath, kProfilesJsonRelativePath)).exists()) {
      roots.add((vaultPath, [kProfilesJsonRelativePath]));
    }

    final profileRepo = ProfileRepository(vaultPath, cipher: readCipher);
    final profiles = await profileRepo.listAll();
    for (final profile in profiles) {
      final profilePath = profileRepo.pathFor(profile.id);
      final relativePaths = await privateRelativePathsForProfile(profilePath);
      if (relativePaths.isNotEmpty) roots.add((profilePath, relativePaths));
    }

    return roots;
  }
}

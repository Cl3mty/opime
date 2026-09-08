import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'vault_fs_io.dart' if (dart.library.js_interop) 'vault_fs_web.dart'
    as platform;

/// Statistiques d'une entrée du vault (l'équivalent du `FileStat` de
/// `dart:io`, sans y faire référence pour rester compilable sur web).
class VaultFileStat {
  final int size;
  final DateTime modified;

  const VaultFileStat({required this.size, required this.modified});
}

/// Découpe un chemin vault (ex. `/Opime/Famille/Opime`) en segments de noms
/// OPFS — en excluant le segment racine `/` que `package:path` conserve
/// (voir `p.split('/a/b')` → `['/', 'a', 'b']`), car `getDirectoryHandle('/')`
/// est rejeté par les navigateurs (« Name is not allowed »). Partagé entre
/// backends pour être unit-testeable sur desktop.
List<String> vaultPathSegments(String path) =>
    p.split(path).where((s) => s.isNotEmpty && s != '/').toList();

/// Saisit et prépare le stockage de la plateforme courante. Sur desktop
/// c'est un no-op (le vault est un vrai dossier, tous les chemins sont
/// réels) ; sur web cela s'ouvre le système de fichiers local du
/// navigateur (OPFS) qui fera office de disque virtuel. À appeler une fois,
/// avant `runApp` (voir `main.dart`).
Future<void> initVaultFs() => platform.initVaultFs();

/// Le sélecteur de dossier réel de l'API File System Access
/// (`showDirectoryPicker`) est-il disponible dans ce navigateur ? Toujours
/// `false` sur desktop (qui a son propre sélecteur natif, voir
/// `VaultFolderService`) — Safari et Firefox ne l'implémentaient pas encore
/// au moment d'écrire ceci ; la seule alternative web reste alors l'OPFS.
bool get supportsLocalFolderPicker => platform.supportsLocalFolderPicker;

/// Web uniquement : rebascule la racine du stockage vault sur l'OPFS par
/// défaut — à appeler avant de résoudre un coffre-fort qui n'utilise pas de
/// dossier local, pour annuler une éventuelle bascule précédente vers un
/// dossier réel dans la même session de navigateur (voir
/// `VaultFolderService._resolveAccessibleVault`). No-op sur desktop.
void useOpfsRoot() => platform.useOpfsRoot();

/// Web uniquement : ouvre le sélecteur de dossier natif du navigateur et
/// bascule immédiatement la racine du stockage vault dessus — voir
/// [VaultDirectory]/[VaultFile], qui résolvent leurs chemins par rapport à
/// cette racine. Persiste aussi le handle choisi sous [vaultId] pour le
/// retrouver aux prochaines sessions (voir [restoreLocalFolderRoot]).
/// Renvoie le nom du dossier choisi (à utiliser comme nom de coffre-fort par
/// défaut), ou `null` si l'utilisateur a annulé le sélecteur.
Future<String?> pickLocalFolderRoot(String vaultId) =>
    platform.pickLocalFolderRoot(vaultId);

/// Web uniquement : retrouve, pour une session de navigateur ultérieure, le
/// dossier précédemment choisi (voir [pickLocalFolderRoot]) pour le
/// coffre-fort [vaultId] et bascule la racine du stockage vault dessus si la
/// permission est encore accordée silencieusement. Renvoie `null` si aucun
/// dossier n'a jamais été choisi pour ce coffre-fort, `false` si la
/// permission doit être redemandée via un geste utilisateur (voir
/// [reauthorizeLocalFolderRoot]), `true` si la racine a bien été rebasculée.
Future<bool?> restoreLocalFolderRoot(String vaultId) =>
    platform.restoreLocalFolderRoot(vaultId);

/// Web uniquement : redemande explicitement la permission sur le dossier
/// précédemment choisi pour [vaultId] — DOIT être appelée depuis un geste
/// utilisateur direct (ex. `onPressed` d'un bouton), le navigateur rejette
/// silencieusement cet appel sinon. Bascule la racine dessus et renvoie
/// `true` en cas de succès.
Future<bool> reauthorizeLocalFolderRoot(String vaultId) =>
    platform.reauthorizeLocalFolderRoot(vaultId);

/// Web uniquement : oublie le dossier persisté pour [vaultId] (coffre-fort
/// supprimé/oublié, voir `VaultFolderService.forgetVault`).
Future<void> forgetLocalFolderRoot(String vaultId) =>
    platform.forgetLocalFolderRoot(vaultId);

/// Base commune aux fichiers et dossiers du vault. Remplaçant de
/// `dart:io`'s `FileSystemEntity`, décliné en [VaultFile]/[VaultDirectory]
/// — le backend (`dart:io` sur desktop, OPFS sur web) est choisi au moment
/// de la compilation par l'import conditionnel ci-dessus.
abstract class VaultEntity {
  final String path;

  const VaultEntity(this.path);

  VaultDirectory get parent => VaultDirectory(p.dirname(path));

  /// Existe-t-il ?
  Future<bool> exists() => platform.fsExists(path);

  Future<void> delete({bool recursive = false}) =>
      platform.fsDelete(path, recursive: recursive);

  /// Copie ce fichier (ou reproduit récursivement ce dossier) vers
  /// [newPath].
  Future<void> copy(String newPath) => platform.fsCopy(path, newPath);

  /// Renomme (ou déplace) et renvoie l'entité sous son nouveau chemin —
  /// même convention que `dart:io` (`File.rename`/`Directory.rename`
  /// renvoient l'entité renommée).
  Future<VaultEntity> rename(String newPath) async {
    await platform.fsRename(path, newPath);
    return this is VaultDirectory
        ? VaultDirectory(newPath)
        : VaultFile(newPath);
  }

  Future<VaultFileStat> stat() => platform.fsStat(path);
}

/// Un fichier du vault. Toutes les opérations sont asynchrones pour être
/// identiques sur desktop (`dart:io`) et web (OPFS, async par nature).
class VaultFile extends VaultEntity {
  VaultFile(super.path);

  Future<void> create() => platform.fsCreateFile(path);

  Future<Uint8List> readAsBytes() => platform.fsReadBytes(path);

  Future<String> readAsString() async =>
      utf8.decode(await platform.fsReadBytes(path));

  Future<void> writeAsBytes(Uint8List bytes) =>
      platform.fsWriteBytes(path, bytes);

  Future<void> writeAsString(String contents) =>
      platform.fsWriteBytes(path, utf8.encode(contents));
}

/// Un dossier du vault.
class VaultDirectory extends VaultEntity {
  VaultDirectory(super.path);

  Future<void> create({bool recursive = false}) =>
      platform.fsCreateDir(path, recursive: recursive);

  /// Liste les entrées (fichiers et dossiers) contenues dans ce dossier.
  ///
  /// Différence assumée avec `dart:io` : renvoie une `Future<List<...>>`
  /// matérialisée plutôt qu'un `Stream<FileSystemEntity>`, puisque OPFS
  /// n'a pas de stream natif — les quelques appels `.list()`/`.listSync()`
  /// du code existant deviennent `await ` (dir).list()`.
  Future<List<VaultEntity>> list({bool recursive = false}) async {
    final entries = await platform.fsListDir(path, recursive: recursive);
    return [
      for (final entry in entries)
        entry.isDirectory
            ? VaultDirectory(entry.path)
            : VaultFile(entry.path),
    ];
  }
}

/// Un point d'entrée du désigné : soit un fichier, soit un dossier —
/// correspond à un élément du résultat de [VaultDirectory.list].
final class VaultDirEntry {
  final bool isDirectory;
  final String path;

  const VaultDirEntry(this.isDirectory, this.path);
}
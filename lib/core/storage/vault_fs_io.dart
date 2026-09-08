/// Backend desktop du stockage vault : délègue tout à `dart:io` — sur
/// macOS/Windows/Linux le vault est un vrai dossier du disque, donc les
/// opérations sont des opérations fichier réelles. La signature de ce
/// module est strictement identique à celle de `vault_fs_web.dart`, seul
/// l'un des deux est compilé selon la plateforme (import conditionnel dans
/// `vault_fs.dart`).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'vault_fs.dart';

Future<void> initVaultFs() async {
  // Rien à préparer : `dart:io` est synchrone d'attitude et le vault natif
  // existe déjà sur disque. Fonction présente pour la parité d'API avec le
  // backend web (voir `vault_fs_web.dart`).
}

/// Le sélecteur de dossier local (API File System Access) n'a de sens que
/// sur le web — le desktop a déjà son propre sélecteur de dossier natif
/// (`file_picker`, voir `VaultFolderService`). Fonctions présentes
/// uniquement pour la parité d'API avec `vault_fs_web.dart` ; jamais
/// appelées en pratique sur cette plateforme (tous les appelants gardent
/// leurs appels derrière `if (kIsWeb)`).
bool get supportsLocalFolderPicker => false;

void useOpfsRoot() {}

Future<String?> pickLocalFolderRoot(String vaultId) =>
    throw UnsupportedError(
      'pickLocalFolderRoot est réservé au web (voir file_picker sur desktop).',
    );

Future<bool?> restoreLocalFolderRoot(String vaultId) async => null;

Future<bool> reauthorizeLocalFolderRoot(String vaultId) async => false;

Future<void> forgetLocalFolderRoot(String vaultId) async {}

Future<bool> fsExists(String path) async {
  // `FileSystemEntity.type(followLinks: true)` peut renvoyer `notFound` pour
  // une entrée pourtant présente (fichier fraîchement écrit) — constatée
  // sur macOS dans `flutter test` (write non flushé puis `exists()`
  // immédiat) : on préfère les sondes `File.exists`/`Directory.exists`, qui
  // ne passent pas par ce chemin, comportement identique à l'ancien
  // `VaultFileStorage` (qui ne rencontrait jamais ce faux négatif).
  if (await File(path).exists()) return true;
  return Directory(path).exists();
}

Future<void> fsCreateFile(String path) async {
  final file = File(path);
  if (await file.exists()) return;
  await file.parent.create(recursive: true);
  await file.writeAsBytes(const []);
}

Future<void> fsCreateDir(String path, {required bool recursive}) async {
  await Directory(path).create(recursive: recursive);
}

Future<void> fsDelete(String path, {required bool recursive}) async {
  final entity = FileSystemEntity.typeSync(path) == FileSystemEntityType.directory
      ? Directory(path)
      : File(path);
  if (recursive && entity is Directory) {
    await entity.delete(recursive: true);
  } else {
    await entity.delete();
  }
}

Future<Uint8List> fsReadBytes(String path) async =>
    Uint8List.fromList(await File(path).readAsBytes());

Future<void> fsWriteBytes(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}

Future<List<VaultDirEntry>> fsListDir(
  String path, {
  required bool recursive,
}) async {
  final dir = Directory(path);
  if (!await dir.exists()) return const [];
  final entries = <VaultDirEntry>[];
  await for (final entity in dir.list(recursive: recursive, followLinks: false)) {
    entries.add(VaultDirEntry(entity is Directory, entity.path));
  }
  return entries;
}

Future<void> fsCopy(String from, String to) async {
  final entity = FileSystemEntity.typeSync(from);
  if (entity == FileSystemEntityType.directory) {
    await _copyDirectory(VaultDirectory(from), VaultDirectory(to));
  } else {
    final file = File(from);
    if (!await file.exists()) return;
    await file.copy(to);
  }
}

Future<void> fsRename(String from, String to) async {
  final entity = FileSystemEntity.typeSync(from);
  if (entity == FileSystemEntityType.directory) {
    final dir = Directory(from);
    if (!await dir.exists()) return;
    await dir.rename(to);
  } else {
    final file = File(from);
    if (!await file.exists()) return;
    await file.rename(to);
  }
}

Future<VaultFileStat> fsStat(String path) async {
  final stat = await File(path).stat();
  return VaultFileStat(
    size: stat.size,
    modified: stat.modified,
  );
}

Future<void> _copyDirectory(VaultDirectory from, VaultDirectory to) async {
  if (!await from.exists()) return;
  await to.create(recursive: true);
  for (final entity in await from.list()) {
    final target = p.join(to.path, p.basename(entity.path));
    if (entity is VaultDirectory) {
      await _copyDirectory(entity, VaultDirectory(target));
    } else if (entity is VaultFile) {
      await entity.copy(target);
    }
  }
}
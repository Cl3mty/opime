/// Backend web du stockage vault : persiste les données soit dans le
/// ***système de fichiers local du navigateur*** (OPFS — Origin Private File
/// System), soit dans un ***vrai dossier du disque*** choisi par
/// l'utilisateur via l'API File System Access (`showDirectoryPicker` — voir
/// [pickLocalFolderRoot]), qui peut lui-même être synchronisé par Google
/// Drive Desktop, iCloud Drive, Dropbox... exactement comme sur desktop. Les
/// deux backends exposent la même interface `FileSystemDirectoryHandle`, ce
/// qui permet à toutes les fonctions `fs*` ci-dessous de rester identiques
/// quelle que soit la racine active — seule [_root] change. Signature
/// strictement identique à `vault_fs_io.dart` ; seul l'un des deux modules
/// est compilé selon la plateforme (voir `vault_fs.dart`).
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:web/web.dart' as web;

import 'vault_fs.dart';

/// Racine OPFS de l'application (soutenue par Chrome/Edge, Firefox ≥ 111 et
/// Safari ≥ 15.2) — toujours accessible sans permission ni sélecteur,
/// contrairement à [pickLocalFolderRoot]. Conservée séparément de [_root]
/// pour pouvoir y revenir (voir [useOpfsRoot]) quand le coffre-fort actif
/// change pour un qui n'utilise pas de dossier local.
late web.FileSystemDirectoryHandle _opfsRoot;

/// Racine effectivement utilisée par toutes les fonctions `fs*` ci-dessous —
/// l'OPFS par défaut, ou le dossier réel du dernier
/// [pickLocalFolderRoot]/[restoreLocalFolderRoot] réussi.
late web.FileSystemDirectoryHandle _root;

Future<void> initVaultFs() async {
  _opfsRoot = await web.window.navigator.storage.getDirectory().toDart;
  _root = _opfsRoot;
}

/// Rebascule la racine du stockage vault sur l'OPFS — appelé par
/// `VaultFolderService` avant de résoudre un coffre-fort qui n'utilise pas
/// de dossier local, pour annuler une éventuelle bascule précédente vers un
/// dossier réel (changement de coffre-fort actif dans la même session de
/// navigateur).
void useOpfsRoot() {
  _root = _opfsRoot;
}

/// `showDirectoryPicker()`/`FileSystemHandle.queryPermission`/
/// `requestPermission` ne font pas partie des IDL standard dont
/// `package:web` génère ses bindings (extensions Chromium non encore
/// spécifiées formellement) : branchées ici directement via
/// `dart:js_interop_unsafe`, même motif que [_removeHandle]/[_entryNames]
/// plus bas dans ce fichier.
bool get supportsLocalFolderPicker =>
    (web.window as JSObject).hasProperty('showDirectoryPicker'.toJS).toDart;

Future<web.FileSystemDirectoryHandle> _showDirectoryPicker() async {
  final fn = (web.window as JSObject).getProperty<JSFunction>(
    'showDirectoryPicker'.toJS,
  );
  // `mode: 'readwrite'` demandé dès le sélecteur : sans lui, la permission
  // accordée par défaut n'est que `read`, et la première écriture dans le
  // dossier (création des fichiers du coffre-fort, juste après) déclenche
  // alors une SECONDE invite du navigateur pour l'écriture — demander les
  // deux d'un coup n'en montre qu'une seule.
  final options = JSObject()..setProperty('mode'.toJS, 'readwrite'.toJS);
  final promise = fn.callAsFunction(web.window, options) as JSPromise<JSAny?>;
  final result = await promise.toDart;
  return result as web.FileSystemDirectoryHandle;
}

/// Appelle `handle.queryPermission({mode:'readwrite'})` ou
/// `handle.requestPermission({mode:'readwrite'})` selon [method] — renvoie
/// `'granted'`, `'denied'` ou `'prompt'`. `requestPermission` n'a d'effet
/// que si elle est appelée depuis un geste utilisateur direct (clic) ; le
/// navigateur la rejette silencieusement sinon (voir
/// `VaultFolderService.reauthorizeActiveVault`, seul appelant légitime).
Future<String> _handlePermission(
  web.FileSystemDirectoryHandle handle,
  String method,
) async {
  final fn = (handle as JSObject).getProperty<JSFunction>(method.toJS);
  final options = JSObject()..setProperty('mode'.toJS, 'readwrite'.toJS);
  final promise = fn.callAsFunction(handle, options) as JSPromise<JSAny?>;
  final result = await promise.toDart;
  return (result as JSString).toDart;
}

/// Ouvre le sélecteur de dossier natif du navigateur et bascule
/// immédiatement [_root] dessus, puis persiste le handle sous [vaultId]
/// (voir [saveLocalFolderHandle]) pour le retrouver aux prochaines sessions
/// (voir [restoreLocalFolderRoot]). Renvoie le nom du dossier choisi (à
/// utiliser comme nom de coffre-fort par défaut), ou `null` si l'utilisateur
/// a annulé le sélecteur (`AbortError`) — la racine active n'est alors pas
/// modifiée.
Future<String?> pickLocalFolderRoot(String vaultId) async {
  final web.FileSystemDirectoryHandle handle;
  try {
    handle = await _showDirectoryPicker();
  } catch (_) {
    return null;
  }
  _root = handle;
  try {
    await saveLocalFolderHandle(vaultId, handle);
  } catch (_) {
    // La racine reste utilisable pour cette session ; seule la
    // persistance entre sessions échoue (IndexedDB indisponible/bloquée,
    // ex. navigation privée) — pas une raison de faire échouer la
    // création du coffre-fort.
  }
  return handle.name;
}

/// Retrouve, pour une session de navigateur ultérieure, le dossier
/// précédemment choisi pour le coffre-fort [vaultId] et bascule [_root]
/// dessus si la permission est encore accordée silencieusement (sans geste
/// utilisateur — voir `FileSystemHandle.queryPermission`, qui ne mute rien).
/// Renvoie :
/// - `null` si aucun dossier n'a jamais été choisi pour ce coffre-fort (ne
///   devrait pas arriver pour un `SavedVault` marqué
///   `VaultStorage.webLocalFolder`, sauf base IndexedDB vidée par
///   l'utilisateur/le navigateur) ;
/// - `false` si un dossier existe mais la permission doit être redemandée
///   via un geste utilisateur (voir [reauthorizeLocalFolderRoot]) — [_root]
///   n'est alors PAS modifié ;
/// - `true` si [_root] a bien été rebasculée, prête à l'emploi.
Future<bool?> restoreLocalFolderRoot(String vaultId) async {
  final handle = await loadLocalFolderHandle(vaultId);
  if (handle == null) return null;
  final permission = await _handlePermission(handle, 'queryPermission');
  if (permission != 'granted') return false;
  _root = handle;
  return true;
}

/// Redemande explicitement la permission sur le dossier précédemment choisi
/// pour [vaultId] — DOIT être appelée depuis un geste utilisateur direct
/// (ex. `onPressed` d'un bouton), voir [_handlePermission]. Bascule [_root]
/// dessus et renvoie `true` en cas de succès.
Future<bool> reauthorizeLocalFolderRoot(String vaultId) async {
  final handle = await loadLocalFolderHandle(vaultId);
  if (handle == null) return false;
  final permission = await _handlePermission(handle, 'requestPermission');
  if (permission != 'granted') return false;
  _root = handle;
  return true;
}

/// Oublie le dossier persisté pour [vaultId] (coffre-fort supprimé/oublié,
/// voir `VaultFolderService.forgetVault`).
Future<void> forgetLocalFolderRoot(String vaultId) =>
    deleteLocalFolderHandle(vaultId);

/// -------------------------------------------------------------------
/// Persistance des dossiers réels choisis via l'API File System Access
/// -------------------------------------------------------------------
///
/// Un `FileSystemDirectoryHandle` obtenu via `showDirectoryPicker()` (à la
/// différence de la racine OPFS, toujours ré-obtenue à l'identique par
/// `navigator.storage.getDirectory()`) doit être explicitement conservé
/// d'une session de navigateur à l'autre pour ne pas forcer l'utilisateur à
/// resélectionner son dossier à chaque rechargement de page — le seul
/// mécanisme du navigateur pour ça est IndexedDB (un handle n'est pas
/// sérialisable en JSON/`localStorage`, mais est "structured-cloneable",
/// donc stockable tel quel dans IndexedDB). Un seul objet-store, une entrée
/// par coffre-fort (clé = [SavedVault.id]).

const _handlesDbName = 'opime_vault_handles';
const _handlesStoreName = 'handles';

Future<web.IDBDatabase> _openHandlesDb() {
  final completer = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open(_handlesDbName, 1);
  request.onupgradeneeded = ((web.Event _) {
    (request.result as web.IDBDatabase).createObjectStore(_handlesStoreName);
  }).toJS;
  request.onsuccess = ((web.Event _) {
    completer.complete(request.result as web.IDBDatabase);
  }).toJS;
  request.onerror = ((web.Event _) {
    completer.completeError(
      request.error ?? StateError("IndexedDB : échec d'ouverture"),
    );
  }).toJS;
  return completer.future;
}

/// Renvoie `request.result` une fois la requête terminée — toujours
/// `JSAny?` (jamais générique : un cast vers un type concret déclenche un
/// avertissement de l'analyseur sur les casts JS interop génériques), à
/// charge de l'appelant de le convertir vers le type concret attendu.
Future<JSAny?> _awaitRequest(web.IDBRequest request) {
  final completer = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) {
    completer.complete(request.result);
  }).toJS;
  request.onerror = ((web.Event _) {
    completer.completeError(
      request.error ?? StateError('IndexedDB : échec de la requête'),
    );
  }).toJS;
  return completer.future;
}

Future<void> saveLocalFolderHandle(
  String vaultId,
  web.FileSystemDirectoryHandle handle,
) async {
  final db = await _openHandlesDb();
  final store = db
      .transaction(_handlesStoreName.toJS, 'readwrite')
      .objectStore(_handlesStoreName);
  await _awaitRequest(store.put(handle, vaultId.toJS));
  db.close();
}

Future<web.FileSystemDirectoryHandle?> loadLocalFolderHandle(
  String vaultId,
) async {
  try {
    final db = await _openHandlesDb();
    final store = db
        .transaction(_handlesStoreName.toJS, 'readonly')
        .objectStore(_handlesStoreName);
    final result = await _awaitRequest(store.get(vaultId.toJS));
    db.close();
    return result == null ? null : result as web.FileSystemDirectoryHandle;
  } catch (_) {
    return null;
  }
}

Future<void> deleteLocalFolderHandle(String vaultId) async {
  try {
    final db = await _openHandlesDb();
    final store = db
        .transaction(_handlesStoreName.toJS, 'readwrite')
        .objectStore(_handlesStoreName);
    await _awaitRequest(store.delete(vaultId.toJS));
    db.close();
  } catch (_) {
    // Best-effort : un coffre-fort oublié dont le handle IndexedDB ne peut
    // pas être nettoyé ne laisse qu'une entrée orpheline sans conséquence
    // (jamais relue, puisque son `SavedVault` n'existe plus).
  }
}

/// Découpe `path` (de type `/a/b/c`) en segments de noms, sans le segment
/// racine `/` (voir `vaultPathSegments`).
List<String> _segments(String path) => vaultPathSegments(path);

/// Renvoie le handle du parent de [path], en créant les niveaux manquants.
Future<web.FileSystemDirectoryHandle> _parentFor(String path) async {
  final segments = _segments(path);
  if (segments.isEmpty) return _root;
  segments.removeLast();
  var current = _root;
  for (final segment in segments) {
    current = await current.getDirectoryHandle(segment, web.FileSystemGetDirectoryOptions(create: true)).toDart;
  }
  return current;
}

extension on Object {
  /// `NotFoundError` signale une entrée absente (équivalent du `false` des
  /// opérations `exists()` de `dart:io`).
  bool get isNotFound =>
      isA<web.DOMException>() && (this as web.DOMException).name == 'NotFoundError';

  /// `TypeMismatchError` signale une entrée présente mais de l'autre sorte
  /// que celle demandée (un dossier au lieu d'un fichier, ou l'inverse) —
  /// jamais levée par `dart:io`, mais systématique sur OPFS (`getFileHandle`
  /// sur un dossier, `getDirectoryHandle` sur un fichier).
  bool get isTypeMismatch =>
      isA<web.DOMException>() &&
      (this as web.DOMException).name == 'TypeMismatchError';
}

Future<bool> fsExists(String path) async {
  final segments = _segments(path);
  if (segments.isEmpty) return true;
  var current = _root;
  for (var i = 0; i < segments.length; i++) {
    final isLast = i == segments.length - 1;
    try {
      if (isLast) {
        // Le dernier segment peut être un fichier OU un dossier : on
        // essaie d'abord en tant que dossier (sans create), puis en tant
        // que fichier. Un « type mismatch » sur un sens veut dire que
        // l'entrée existe dans l'autre.
        try {
          await current.getDirectoryHandle(segments[i]).toDart;
          return true;
        } catch (e) {
          if (e.isTypeMismatch) {
            try {
              await current.getFileHandle(segments[i]).toDart;
              return true;
            } catch (e2) {
              if (e2.isNotFound) return false;
              rethrow;
            }
          }
          if (e.isNotFound) return false;
          rethrow;
        }
      }
      current = await current.getDirectoryHandle(segments[i]).toDart;
    } catch (e) {
      if (e.isNotFound) return false;
      rethrow;
    }
  }
  return true;
}

Future<void> fsCreateFile(String path) async {
  final parent = await _parentFor(path);
  await parent
      .getFileHandle(p.basename(path), web.FileSystemGetFileOptions(create: true))
      .toDart;
}

Future<void> fsCreateDir(String path, {required bool recursive}) async {
  // OPFS crée toujours les parents manquants (l'équivalent de
  // `recursive: true` de `dart:io`) ; le paramètre est conservé pour la
  // parité d'API uniquement.
  var current = _root;
  for (final segment in _segments(path)) {
    current = await current.getDirectoryHandle(segment, web.FileSystemGetDirectoryOptions(create: true)).toDart;
  }
}

Future<void> fsDelete(String path, {required bool recursive}) async {
  final segments = _segments(path);
  if (segments.isEmpty) return;
  final parent = await _parentFor(path);
  final name = segments.last;
  // On tente d'abord un fichier, puis un dossier. Un « type mismatch »
  // signifie que l'entrée existe mais en tant que dossier : on poursuit
  // donc vers la variante dossier au lieu de rethrow.
  try {
    final file = await parent.getFileHandle(name).toDart;
    await _removeHandle(file, recursive: false);
    return;
  } catch (e) {
    if (e.isNotFound || e.isTypeMismatch) {
      // Absent (rien à supprimer) ou dossier : on tente la suppression en
      // tant que dossier — elle échouera proprement si rien n'existe.
    } else {
      rethrow;
    }
  }
  final dir = await parent.getDirectoryHandle(name).toDart;
  await _removeHandle(dir, recursive: recursive);
}

/// Appelle `handle.remove({recursive})` — non exposé par `package:web`
/// (1.1.1), donc branché via `dart:js_interop`.
Future<void> _removeHandle(JSObject handle, {required bool recursive}) async {
  final fn = handle.getProperty<JSFunction>('remove'.toJS);
  final options = web.FileSystemRemoveOptions(recursive: recursive);
  final promise = recursive
      ? fn.callAsFunction(handle, options) as JSPromise<JSAny?>
      : fn.callAsFunction(handle) as JSPromise<JSAny?>;
  await promise.toDart;
}

Future<Uint8List> fsReadBytes(String path) async {
  final segments = _segments(path);
  if (segments.isEmpty) {
    throw StateError('Chemin invalide : $path');
  }
  final parent = await _parentFor(path);
  final handle = await parent.getFileHandle(segments.last).toDart;
  final blob = await handle.getFile().toDart;
  final buffer = await blob.arrayBuffer().toDart; // JSArrayBuffer
  return Uint8List.view(buffer.toDart); // ByteBuffer
}

Future<void> fsWriteBytes(String path, Uint8List bytes) async {
  final parent = await _parentFor(path);
  final handle = await parent
      .getFileHandle(
        p.basename(path),
        web.FileSystemGetFileOptions(create: true),
      )
      .toDart;
  final writable = await handle.createWritable().toDart;
  await writable.write(bytes.toJS).toDart;
  await writable.close().toDart;
}

Future<List<VaultDirEntry>> fsListDir(
  String path, {
  required bool recursive,
}) async {
  final dir = await _dirFor(path);
  final entries = <VaultDirEntry>[];
  await _listInto(dir, path, entries, recursive: recursive);
  return entries;
}

Future<web.FileSystemDirectoryHandle> _dirFor(String path) async {
  var current = _root;
  for (final segment in _segments(path)) {
    current = await current.getDirectoryHandle(segment, web.FileSystemGetDirectoryOptions(create: true)).toDart;
  }
  return current;
}

Future<void> _listInto(
  web.FileSystemDirectoryHandle dir,
  String dirPath,
  List<VaultDirEntry> out, {
  required bool recursive,
}) async {
  for (final name in await _entryNames(dir)) {
    final childPath = p.join(dirPath, name);
    final isDirectory = await _isDirectory(dir, name);
    out.add(VaultDirEntry(isDirectory, childPath));
    if (recursive && isDirectory) {
      final child = await dir.getDirectoryHandle(name).toDart;
      await _listInto(child, childPath, out, recursive: true);
    }
  }
}

/// Itère les noms des entrées d'un dossier OPFS. `values()` n'étant pas
/// exposé par `package:web` (1.1.1), on le branche directement via
/// `dart:js_interop` (protocole itérateur asynchrone standard).
Future<List<String>> _entryNames(web.FileSystemDirectoryHandle dir) async {
  final values = (dir as JSObject).getProperty<JSAny?>('values'.toJS);
  final iterator = (values as JSFunction?)?.callAsFunction(dir);
  if (iterator == null) return const [];
  final it = iterator as JSObject;
  final next = it.getProperty<JSFunction>('next'.toJS);
  final names = <String>[];
  while (true) {
    final result = await (next.callAsFunction(it) as JSPromise<JSAny?>).toDart;
    if (result == null) break;
    final item = result as JSObject;
    final done = item.getProperty<JSBoolean>('done'.toJS).toDart;
    if (done) break;
    final value = item.getProperty<JSAny?>('value'.toJS) as JSObject;
    final name = value.getProperty<JSString>('name'.toJS).toDart;
    names.add(name);
  }
  return names;
}

Future<bool> _isDirectory(
  web.FileSystemDirectoryHandle parent,
  String name,
) async {
  try {
    await parent.getDirectoryHandle(name).toDart;
    return true;
  } catch (e) {
    // Absent, ou présent en tant que fichier : ce n'est pas un dossier.
    if (e.isNotFound || e.isTypeMismatch) return false;
    rethrow;
  }
}

Future<void> fsCopy(String from, String to) async {
  if (await _isDirectoryPath(from)) {
    await _copyDirectoryTree(from, to);
    return;
  }
  final bytes = await fsReadBytes(from);
  await fsWriteBytes(to, bytes);
}

Future<void> _copyDirectoryTree(String from, String to) async {
  await fsCreateDir(to, recursive: true);
  for (final entry in await fsListDir(from, recursive: false)) {
    final target = p.join(to, p.basename(entry.path));
    if (entry.isDirectory) {
      await _copyDirectoryTree(entry.path, target);
    } else {
      await fsCopy(entry.path, target);
    }
  }
}

/// [path] désigne-t-il un dossier (virtuel) ?
Future<bool> _isDirectoryPath(String path) async {
  final segments = _segments(path);
  if (segments.isEmpty) return true;
  final parent = await _parentFor(path);
  try {
    await parent.getDirectoryHandle(segments.last).toDart;
    return true;
  } catch (e) {
    // Absent, ou présent en tant que fichier (« type mismatch ») : ce
    // n'est pas un dossier.
    if (e.isNotFound || e.isTypeMismatch) {
      try {
        await parent.getFileHandle(segments.last).toDart;
        return false;
      } catch (e2) {
        if (e2.isNotFound) return false;
        rethrow;
      }
    }
    rethrow;
  }
}

Future<void> fsRename(String from, String to) async {
  if (await _isDirectoryPath(from)) {
    await _copyDirectoryTree(from, to);
    await fsDelete(from, recursive: true);
    return;
  }
  final bytes = await fsReadBytes(from);
  await fsWriteBytes(to, bytes);
  await fsDelete(from, recursive: false);
}

Future<VaultFileStat> fsStat(String path) async {
  final segments = _segments(path);
  if (segments.isEmpty) {
    throw StateError('Chemin invalide : $path');
  }
  final parent = await _parentFor(path);
  final handle = await parent.getFileHandle(segments.last).toDart;
  final blob = await handle.getFile().toDart;
  return VaultFileStat(
    size: blob.size,
    modified: DateTime.fromMillisecondsSinceEpoch(blob.lastModified),
  );
}
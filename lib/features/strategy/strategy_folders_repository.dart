import 'dart:convert';
import 'dart:math';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';

/// Identifiant de dossier : un timestamp seul (voir `StrategyNote.id`, la
/// même convention) collisionnerait si deux dossiers sont créés dans la
/// même milliseconde (ex : `deleteFolder` en supprimerait un second par
/// erreur) — un court suffixe aléatoire lève cette ambiguïté.
String _generateFolderId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  final suffix = List.generate(
    6,
    (_) => chars[rand.nextInt(chars.length)],
  ).join();
  return '${DateTime.now().millisecondsSinceEpoch}_$suffix';
}

/// Dossier rangeant des notes de `strategy/` (voir [StrategyFoldersRepository])
/// — un simple regroupement visuel avec un nom et une couleur, les notes
/// elles-mêmes restant de simples fichiers `.md` inchangés (voir
/// `StrategyRepository`) : supprimer un dossier ne supprime jamais les
/// notes qu'il contenait, il les range seulement de nouveau hors dossier.
class StrategyFolder {
  final String id;
  final String name;

  /// [Color.toARGB32()]/`Color.value` — stocké en entier brut plutôt que de
  /// dépendre de `dart:ui`/Flutter dans cette couche de stockage, comme le
  /// reste du repository.
  final int color;

  StrategyFolder({String? id, required this.name, required this.color})
    : id = id ?? _generateFolderId();

  factory StrategyFolder.fromJson(Map<String, dynamic> json) => StrategyFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as int,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
}

/// Dossiers de l'onglet Stratégie et affectation des notes à un dossier —
/// tout dans un seul fichier JSON (`strategy/folders.json`) : la liste des
/// dossiers eux-mêmes, et une table `noteId -> folderId` séparée (une note
/// n'a pas de fichier JSON propre où loger cette affectation, voir
/// `StrategyDocumentsRepository`, qui a la même contrainte pour les
/// documents rattachés à une note et suit le même principe).
class StrategyFoldersRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  StrategyFoldersRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _relativePath = 'strategy/folders.json';

  Future<({List<StrategyFolder> folders, Map<String, String> noteFolders})>
  _readAll() async {
    if (!await _storage.exists(_relativePath)) {
      return (folders: <StrategyFolder>[], noteFolders: <String, String>{});
    }
    final content = await _storage.readString(_relativePath);
    if (content.trim().isEmpty) {
      return (folders: <StrategyFolder>[], noteFolders: <String, String>{});
    }
    try {
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final folders = (decoded['folders'] as List? ?? [])
          .map((e) => StrategyFolder.fromJson(e as Map<String, dynamic>))
          .toList();
      final noteFolders =
          (decoded['noteFolders'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(key, value as String),
          );
      return (folders: folders, noteFolders: noteFolders);
    } catch (_) {
      return (folders: <StrategyFolder>[], noteFolders: <String, String>{});
    }
  }

  Future<void> _writeAll(
    List<StrategyFolder> folders,
    Map<String, String> noteFolders,
  ) async {
    final encoded = {
      'folders': folders.map((f) => f.toJson()).toList(),
      'noteFolders': noteFolders,
    };
    await _storage.writeString(
      _relativePath,
      const JsonEncoder.withIndent('  ').convert(encoded),
    );
  }

  Future<List<StrategyFolder>> listFolders() async =>
      (await _readAll()).folders;

  /// Dossier de chaque note ayant une affectation (les notes absentes de
  /// cette table ne sont dans aucun dossier).
  Future<Map<String, String>> noteFolders() async =>
      (await _readAll()).noteFolders;

  Future<StrategyFolder> createFolder(String name, int color) async {
    final trimmed = name.trim();
    final folder = StrategyFolder(
      name: trimmed.isEmpty ? 'Nouveau dossier' : trimmed,
      color: color,
    );
    final all = await _readAll();
    await _writeAll([...all.folders, folder], all.noteFolders);
    return folder;
  }

  Future<void> renameFolder(String folderId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final all = await _readAll();
    await _writeAll([
      for (final f in all.folders)
        if (f.id == folderId)
          StrategyFolder(id: f.id, name: trimmed, color: f.color)
        else
          f,
    ], all.noteFolders);
  }

  Future<void> setFolderColor(String folderId, int color) async {
    final all = await _readAll();
    await _writeAll([
      for (final f in all.folders)
        if (f.id == folderId)
          StrategyFolder(id: f.id, name: f.name, color: color)
        else
          f,
    ], all.noteFolders);
  }

  /// Supprime le dossier — les notes qu'il contenait ne sont jamais
  /// supprimées, seulement rangées de nouveau hors dossier (voir la doc de
  /// classe de [StrategyFolder]).
  Future<void> deleteFolder(String folderId) async {
    final all = await _readAll();
    await _writeAll(
      [
        for (final f in all.folders)
          if (f.id != folderId) f,
      ],
      {
        for (final entry in all.noteFolders.entries)
          if (entry.value != folderId) entry.key: entry.value,
      },
    );
  }

  /// Range [noteId] dans [folderId], ou hors de tout dossier si `null` —
  /// aussi utilisé pour oublier une note supprimée (voir
  /// `StrategyScreen._deleteNote`), pour ne pas laisser une entrée qui
  /// pointe vers une note qui n'existe plus.
  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    final all = await _readAll();
    final noteFolders = {...all.noteFolders};
    if (folderId == null) {
      noteFolders.remove(noteId);
    } else {
      noteFolders[noteId] = folderId;
    }
    await _writeAll(all.folders, noteFolders);
  }
}

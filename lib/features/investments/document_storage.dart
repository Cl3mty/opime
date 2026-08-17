import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';
import 'investments_models.dart';

/// Stocke le contenu réel des documents rattachés aux comptes/
/// investissements — un fichier par document sous
/// `<vault>/investissements/documents/`, nommé par l'id du document (pas
/// son nom d'origine, pour éviter toute collision) suivi de son extension.
/// Les métadonnées (nom d'origine, date, note) voyagent, elles, dans le
/// JSON du compte via [VaultDocument] — même séparation que les cours
/// (`price_history_repository.dart`) entre métadonnées légères et données
/// volumineuses.
class DocumentStorage {
  final String vaultPath;
  late final VaultFileStorage _storage;

  DocumentStorage(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _dirRelativePath = 'investissements/documents';

  /// Chemin absolu du fichier d'un document — utilisé par
  /// `metal_mirror_repository.dart` pour copier ses pièces justificatives
  /// vers le miroir lisible (voir sa documentation de tête : ce miroir est
  /// volontairement laissé en clair, la copie s'y fait donc sur les octets
  /// bruts, chiffrés ou non selon l'état de ce fichier source).
  File fileFor(VaultDocument document) {
    final ext = p.extension(document.fileName);
    return File(p.join(vaultPath, _dirRelativePath, '${document.id}$ext'));
  }

  String _relativePathFor(VaultDocument document) => p.join(
    _dirRelativePath,
    '${document.id}${p.extension(document.fileName)}',
  );

  Future<void> save(VaultDocument document, Uint8List bytes) =>
      _storage.writeBytes(_relativePathFor(document), bytes);

  Future<void> delete(VaultDocument document) =>
      _storage.delete(_relativePathFor(document));
}

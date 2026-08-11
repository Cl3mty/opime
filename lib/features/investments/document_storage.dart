import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
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
  DocumentStorage(this.vaultPath);

  Directory get _dir =>
      Directory(p.join(vaultPath, 'investissements', 'documents'));

  File fileFor(VaultDocument document) {
    final ext = p.extension(document.fileName);
    return File(p.join(_dir.path, '${document.id}$ext'));
  }

  Future<void> save(VaultDocument document, Uint8List bytes) async {
    if (!await _dir.exists()) await _dir.create(recursive: true);
    await fileFor(document).writeAsBytes(bytes);
  }

  Future<void> delete(VaultDocument document) async {
    final file = fileFor(document);
    if (await file.exists()) await file.delete();
  }
}

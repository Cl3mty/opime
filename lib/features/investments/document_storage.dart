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

  /// Chemin absolu du fichier d'un document — utile pour vérifier son
  /// existence uniquement. **Ne jamais ouvrir ou copier ce fichier tel
  /// quel** (que ce soit vers le miroir métaux précieux, voir
  /// `metal_mirror_repository.dart`, ou via `launchUrl`/l'application par
  /// défaut du système, voir `documents_section.dart`'s
  /// `materializeForExternalOpen`) : ses octets sont chiffrés dès que le
  /// vault l'est, une application externe ne sait pas les déchiffrer.
  /// Utiliser [readBytes] ou [materializeForExternalOpen] selon le besoin.
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

  /// Contenu déchiffré d'un document — à utiliser (plutôt que [fileFor])
  /// partout où le contenu doit rester exploitable une fois recopié
  /// ailleurs, quel que soit l'état de chiffrement du vault. Voir
  /// `metal_mirror_repository.dart`, dont le miroir doit toujours rester en
  /// clair.
  Future<Uint8List> readBytes(VaultDocument document) =>
      _storage.readBytes(_relativePathFor(document));

  /// Écrit le contenu déchiffré de [document] dans un nouveau fichier
  /// temporaire (hors du vault, dans le dossier temp du système), à ouvrir
  /// avec l'application par défaut du système (voir
  /// `documents_section.dart`'s `_open`/`showDocumentViewDialog`) —
  /// `launchUrl(Uri.file(...))` directement sur [fileFor] ouvrirait sinon
  /// les octets chiffrés tels quels dès que le vault l'est (l'application
  /// externe ne sait pas les déchiffrer). Un nouveau fichier à chaque
  /// appel, jamais réutilisé : ce sont de petites pièces justificatives, le
  /// coût est négligeable, et ça évite une copie déchiffrée périmée si le
  /// document a changé depuis un appel précédent. Le fichier temporaire
  /// n'est pas supprimé après coup (on ne sait pas quand l'application
  /// externe a fini de le lire) — laissé au nettoyage périodique du dossier
  /// temp du système, même compromis que la plupart des apps qui ouvrent
  /// une pièce jointe chiffrée avec un visualiseur externe.
  Future<File> materializeForExternalOpen(VaultDocument document) async {
    final bytes = await readBytes(document);
    final dir = await Directory.systemTemp.createTemp('opime_document_');
    final file = File(p.join(dir.path, document.fileName));
    await file.writeAsBytes(bytes);
    return file;
  }
}

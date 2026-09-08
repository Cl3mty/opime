import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';
import '../../core/storage/vault_fs.dart';
import '../../core/storage/temp_file.dart' as temp;
import 'investments_models.dart';

/// Stocke le contenu réel de documents rattachés à un élément du vault — un
/// fichier par document sous `<vault>/<dirRelativePath>/`, nommé par l'id du
/// document (pas son nom d'origine, pour éviter toute collision) suivi de
/// son extension. Les métadonnées (nom d'origine, date, note) voyagent,
/// elles, à part via [VaultDocument] — même séparation que les cours
/// (`price_history_repository.dart`) entre métadonnées légères et données
/// volumineuses.
///
/// [dirRelativePath] par défaut aux documents de comptes/investissements
/// (usage historique de cette classe) ; un autre appelant (ex : les notes
/// de `strategy/`, voir `StrategyDocumentsRepository`) passe son propre
/// sous-dossier pour garder ses fichiers séparés.
class DocumentStorage {
  final String vaultPath;
  final String dirRelativePath;
  late final VaultFileStorage _storage;

  DocumentStorage(
    this.vaultPath, {
    VaultCipher? cipher,
    this.dirRelativePath = _defaultDirRelativePath,
  }) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _defaultDirRelativePath = 'investissements/documents';

  /// Chemin absolu du fichier d'un document — utile pour vérifier son
  /// existence uniquement. **Ne jamais ouvrir ou copier ce fichier tel
  /// quel** (que ce soit vers le miroir métaux précieux, voir
  /// `metal_mirror_repository.dart`, ou via `launchUrl`/l'application par
  /// défaut du système, voir `documents_section.dart`'s
  /// `materializeForExternalOpen`) : ses octets sont chiffrés dès que le
  /// vault l'est, une application externe ne sait pas les déchiffrer.
  /// Utiliser [readBytes] ou [materializeForExternalOpen] selon le besoin.
  VaultFile fileFor(VaultDocument document) {
    final ext = p.extension(document.fileName);
    return VaultFile(p.join(vaultPath, dirRelativePath, '${document.id}$ext'));
  }

  String _relativePathFor(VaultDocument document) => p.join(
    dirRelativePath,
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

  /// Matérialise le contenu déchiffré de [document] hors du vault dans un
  /// nouveau fichier temporaire, à ouvrir avec `openExternalFile` (voir
  /// `external_open.dart`) — le fichier du vault étant chiffré dès que le
  /// vault l'est, une application externe ne sait pas le déchiffrer (et sur
  /// web il n'existe ni disque temp ni application externe). Renvoie le
  /// chemin du fichier temporaire : chemin réel du système sur desktop,
  /// chemin virtuel OPFS sur web. Un nouveau fichier à chaque appel, jamais
  /// réutilisé : de petites pièces justificatives, un coût négligeable, et
  /// pas de copie déchiffrée périmée si le document a changé depuis un
  /// appel précédent. Le fichier temporaire n'est pas supprimé après coup
  /// (on ne sait pas quand l'application externe a fini de le lire) —
  /// laissé au nettoyage périodique du dossier temp du système (desktop),
  /// même compromis que la plupart des apps qui ouvrent une pièce jointe
  /// chiffrée avec un visualiseur externe.
  Future<String> materializeForExternalOpen(VaultDocument document) async {
    final bytes = await readBytes(document);
    return temp.createTempCopy(
      fileName: document.fileName,
      bytes: bytes,
      vaultPath: vaultPath,
    );
  }
}

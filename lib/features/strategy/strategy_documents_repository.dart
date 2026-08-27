import 'dart:convert';
import 'dart:typed_data';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';
import '../investments/document_storage.dart';
import '../investments/investments_models.dart' show VaultDocument;

/// Sous-dossier où sont stockés les octets des documents rattachés à une
/// note (voir [DocumentStorage.dirRelativePath]) — à part des documents de
/// comptes/investissements, même s'ils partagent le même mécanisme de
/// stockage.
const strategyDocumentsFolder = 'strategy/documents';

/// Documents rattachés à une note de `strategy/` (ex : un dossier "Impôts"
/// contenant les relevés annuels IBKR et les déclarations) — même
/// mécanisme que les documents de comptes/investissements
/// ([DocumentStorage]/[VaultDocument]), mais les notes étant de simples
/// fichiers `.md` sans JSON propre (voir `StrategyRepository`), les
/// métadonnées ne peuvent pas voyager dans le fichier de la note comme
/// elles le font dans `Investment.documents` — elles sont donc indexées à
/// part ici, par id de note, dans un unique fichier JSON.
class StrategyDocumentsRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;
  late final DocumentStorage _documentStorage;

  StrategyDocumentsRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
    _documentStorage = DocumentStorage(
      vaultPath,
      cipher: cipher,
      dirRelativePath: strategyDocumentsFolder,
    );
  }

  static const _indexRelativePath = 'strategy/documents.json';

  Future<Map<String, List<VaultDocument>>> _readAll() async {
    if (!await _storage.exists(_indexRelativePath)) return {};
    final content = await _storage.readString(_indexRelativePath);
    if (content.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: (entry.value as List)
              .map((e) => VaultDocument.fromJson(e as Map<String, dynamic>))
              .toList(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, List<VaultDocument>> all) async {
    final encoded = {
      for (final entry in all.entries)
        if (entry.value.isNotEmpty)
          entry.key: entry.value.map((d) => d.toJson()).toList(),
    };
    await _storage.writeString(
      _indexRelativePath,
      const JsonEncoder.withIndent('  ').convert(encoded),
    );
  }

  Future<List<VaultDocument>> documentsFor(String noteId) async {
    final all = await _readAll();
    return all[noteId] ?? const [];
  }

  /// Enregistre les octets de [bytes] puis rattache [fileName] (renommé
  /// [name] si renseigné) à la note [noteId] — reflète tel quel le
  /// paramètre `onAdd` attendu par `DocumentsSection`.
  Future<List<VaultDocument>> addDocument(
    String noteId,
    String fileName,
    Uint8List bytes, {
    String? name,
  }) async {
    final document = VaultDocument(fileName: fileName, note: name);
    await _documentStorage.save(document, bytes);
    final all = await _readAll();
    all[noteId] = [...(all[noteId] ?? const []), document];
    await _writeAll(all);
    return all[noteId]!;
  }

  Future<List<VaultDocument>> removeDocument(
    String noteId,
    VaultDocument document,
  ) async {
    await _documentStorage.delete(document);
    final all = await _readAll();
    all[noteId] = [
      for (final d in all[noteId] ?? const []) if (d.id != document.id) d,
    ];
    await _writeAll(all);
    return all[noteId] ?? const [];
  }

  /// Supprime tous les documents rattachés à [noteId] (octets et
  /// métadonnées) — à appeler quand la note elle-même est supprimée, pour
  /// ne pas laisser de fichiers orphelins dans le vault (voir
  /// `StrategyRepository.deleteNote`, appelé séparément par l'appelant).
  Future<void> deleteAllFor(String noteId) async {
    final all = await _readAll();
    final documents = all[noteId];
    if (documents == null) return;
    for (final document in documents) {
      await _documentStorage.delete(document);
    }
    all.remove(noteId);
    await _writeAll(all);
  }
}

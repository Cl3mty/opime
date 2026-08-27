import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

/// Métadonnées de la photo d'un objet "Autres" mise en cache localement —
/// seul le nom de fichier est stocké dans l'index ; les octets de l'image
/// vivent dans `investissements/autres/photos/` (même séparation
/// légère/volumineuse que les documents, voir `document_storage.dart`).
class AutresPhotoEntry {
  final String file;

  const AutresPhotoEntry({required this.file});

  factory AutresPhotoEntry.fromJson(Map<String, dynamic> json) =>
      AutresPhotoEntry(file: json['file'] as String? ?? '');

  Map<String, dynamic> toJson() => {'file': file};
}

/// Cache local des photos d'objets "Autres" (montre, voiture de collection,
/// art...) importées par l'utilisateur — pas de source automatique
/// contrairement aux métaux précieux physiques (voir
/// `metal_image_repository.dart`, qui scrape un catalogue marchand) : l'avatar
/// d'un investissement "Autres" est cliquable et ouvre un sélecteur de
/// fichier, exactement comme `BankLogoAvatar` pour le logo d'une banque
/// (voir `bank_logo_repository.dart`). Un fichier par objet sous
/// `<vault>/investissements/autres/photos/`, indexé par
/// [Investment.id] (pas par libellé, librement modifiable et pas
/// nécessairement unique — contrairement à un nom de banque) dans
/// `photos.json`. Même pattern que les deux repositories ci-dessus : index
/// JSON réécrit en entier à chaque sauvegarde, lecture tolérante (fichier
/// manquant/corrompu → aucune photo).
class AutresPhotoRepository {
  final String vaultPath;

  AutresPhotoRepository(this.vaultPath);

  Directory get _dir =>
      Directory(p.join(vaultPath, 'investissements', 'autres', 'photos'));

  File get _indexFile => File(
    p.join(vaultPath, 'investissements', 'autres', 'photos.json'),
  );

  static const _allowedExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif'};

  /// L'index complet (id d'investissement → [AutresPhotoEntry]), vide si le
  /// fichier est absent ou illisible — jamais d'erreur levée.
  Future<Map<String, AutresPhotoEntry>> readIndex() async {
    if (!await _indexFile.exists()) return {};
    try {
      final content = await _indexFile.readAsString();
      if (content.trim().isEmpty) return {};
      final json = jsonDecode(content) as Map<String, dynamic>;
      return {
        for (final entry in json.entries)
          entry.key: AutresPhotoEntry.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeIndex(Map<String, AutresPhotoEntry> index) async {
    if (!await _dir.exists()) await _dir.create(recursive: true);
    final json = {for (final e in index.entries) e.key: e.value.toJson()};
    await _indexFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  /// Chemin absolu de la photo en cache pour l'investissement [investmentId],
  /// ou `null` s'il n'y en a pas encore (jamais importée, ou fichier
  /// supprimé/corrompu).
  Future<String?> photoPathFor(String investmentId) async {
    final index = await readIndex();
    final entry = index[investmentId];
    if (entry == null || entry.file.isEmpty) return null;
    final file = File(p.join(_dir.path, entry.file));
    if (!await file.exists()) return null;
    return file.path;
  }

  /// Importe (ou remplace) la photo de l'investissement [investmentId]
  /// depuis les octets d'une image choisie par l'utilisateur ([bytes],
  /// l'extension étant déduite de [sourceName]). Retourne le chemin absolu
  /// de la photo importée, ou `null` si l'extension n'est pas une image
  /// connue (le fichier est alors ignoré).
  Future<String?> importPhoto(
    String investmentId,
    Uint8List bytes, {
    required String sourceName,
  }) async {
    final ext = p.extension(sourceName).toLowerCase();
    if (!_allowedExtensions.contains(ext)) return null;
    if (!await _dir.exists()) await _dir.create(recursive: true);
    final fileName = '$investmentId$ext';
    final file = File(p.join(_dir.path, fileName));
    await file.writeAsBytes(bytes);
    final index = await readIndex();
    index[investmentId] = AutresPhotoEntry(file: fileName);
    await _writeIndex(index);
    return file.path;
  }

  /// Supprime la photo (fichier + entrée d'index) d'un investissement.
  Future<void> deletePhoto(String investmentId) async {
    final index = await readIndex();
    final entry = index.remove(investmentId);
    if (entry != null) {
      final file = File(p.join(_dir.path, entry.file));
      if (await file.exists()) await file.delete();
    }
    await _writeIndex(index);
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

/// Métadonnées du logo d'une banque mis en cache localement — seul le nom
/// de fichier est stocké dans l'index ; les octets de l'image vivent dans
/// `investissements/logos_banques/` (même séparation légère/volumineuse que
/// les documents, voir `document_storage.dart`).
class BankLogoEntry {
  final String file;

  const BankLogoEntry({required this.file});

  factory BankLogoEntry.fromJson(Map<String, dynamic> json) => BankLogoEntry(
    file: json['file'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'file': file};
}

/// Cache local des logos de banques, importés par l'utilisateur (l'avatar
/// d'une banque est cliquable et ouvre un sélecteur de fichier pour importer
/// l'image du logo — voir `BankLogoAvatar`) — un fichier par banque sous
/// `<vault>/investissements/logos_banques/`, indexé par nom de banque dans
/// `logos_banques.json`. Aucun appel réseau, aucune clé d'API : l'image
/// vient du disque de l'utilisateur, cohérent avec la philosophie
/// local-first du projet.
///
/// Même pattern que `metal_image_repository.dart` : index JSON réécrit en
/// entier à chaque sauvegarde, lecture tolérante (fichier manquant/corrompu
/// → aucun logo), nom de fichier stable dérivé de la banque pour que
/// l'import d'un nouveau logo écrase l'ancien.
class BankLogoRepository {
  final String vaultPath;

  BankLogoRepository(this.vaultPath);

  Directory get _dir => Directory(
    p.join(vaultPath, 'investissements', 'logos_banques'),
  );

  File get _indexFile => File(
    p.join(vaultPath, 'investissements', 'logos_banques.json'),
  );

  /// Nom de fichier stable d'une banque : minuscules sans accents, tout
  /// caractère non alphanumérique remplacé par `_`. L'import d'un nouveau
  /// logo de la même banque écrase donc l'ancien fichier.
  static String fileSlugFor(String bankName) {
    const accents = 'àáâäãåçéèêëíìîïñóòôöõúùûüýÿ';
    const plains = 'aaaaaaceeeeiiiinooooouuuuyy';
    var normalized = bankName.trim().toLowerCase();
    for (var i = 0; i < accents.length; i++) {
      normalized = normalized.replaceAll(accents[i], plains[i]);
    }
    return normalized.replaceAll(RegExp('[^a-z0-9]'), '_');
  }

  /// L'index complet (nom de banque → [BankLogoEntry]), vide si le fichier
  /// est absent ou illisible — jamais d'erreur levée.
  Future<Map<String, BankLogoEntry>> readIndex() async {
    if (!await _indexFile.exists()) return {};
    try {
      final content = await _indexFile.readAsString();
      if (content.trim().isEmpty) return {};
      final json = jsonDecode(content) as Map<String, dynamic>;
      return {
        for (final entry in json.entries)
          entry.key: BankLogoEntry.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeIndex(Map<String, BankLogoEntry> index) async {
    if (!await _dir.exists()) await _dir.create(recursive: true);
    final json = {for (final e in index.entries) e.key: e.value.toJson()};
    await _indexFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  /// Chemin absolu du logo en cache pour [bankName], ou `null` s'il n'y en
  /// a pas encore (jamais importé, ou fichier supprimé/corrompu).
  Future<String?> logoPathFor(String bankName) async {
    final index = await readIndex();
    final entry = index[bankName];
    if (entry == null || entry.file.isEmpty) return null;
    final file = File(p.join(_dir.path, entry.file));
    if (!await file.exists()) return null;
    return file.path;
  }

  /// Importe (ou remplace) le logo de [bankName] depuis les octets d'une
  /// image choisie par l'utilisateur ([bytes], l'extension étant déduite de
  /// [sourceName]). Retourne le chemin absolu du logo importé, ou `null` si
  /// l'extension n'est pas une image connue (le fichier est alors ignoré).
  Future<String?> importLogo(
    String bankName,
    Uint8List bytes, {
    required String sourceName,
  }) async {
    final ext = p.extension(sourceName).toLowerCase();
    const allowedExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.svg', '.gif'};
    if (!allowedExtensions.contains(ext)) return null;
    if (!await _dir.exists()) await _dir.create(recursive: true);
    final fileName = '${fileSlugFor(bankName)}$ext';
    final file = File(p.join(_dir.path, fileName));
    await file.writeAsBytes(bytes);
    final index = await readIndex();
    index[bankName] = BankLogoEntry(file: fileName);
    await _writeIndex(index);
    return file.path;
  }

  /// Supprime le logo (fichier + entrée d'index) d'une banque.
  Future<void> deleteLogo(String bankName) async {
    final index = await readIndex();
    final entry = index.remove(bankName);
    if (entry != null) {
      final file = File(p.join(_dir.path, entry.file));
      if (await file.exists()) await file.delete();
    }
    await _writeIndex(index);
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'metal_price_client.dart';

/// Une entrée de l'index local des images produits : le nom de fichier
/// téléchargé localement et l'URL d'origine du site marchand (pour relancer
/// un téléchargement si le fichier disparaît).
class MetalImageEntry {
  final String file;
  final String url;

  const MetalImageEntry({required this.file, required this.url});

  factory MetalImageEntry.fromJson(Map<String, dynamic> json) =>
      MetalImageEntry(
        file: json['file'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'file': file, 'url': url};
}

/// Cache local des images des pièces/lingots d'or et d'argent, scrapées du
/// catalogue achat-or-et-argent.fr ([MetalPriceClient.fetchProductImages]) —
/// la photo du produit détenu s'affiche à la place de l'avatar à initiales
/// dans les accordéons de la page "Métaux précieux".
///
/// Organisation sous le dossier du profil, à côté du cache de cours des
/// métaux (`metal_price_repository.dart`, même dossier `investissements/
/// metaux/`) :
///  * les images elles-mêmes dans `images/<id produit><ext>` (l'id du site
///    marchand est stable pour un même produit — nommer par l'id évite de
///    renommer quand un libellé évolue) ;
///  * un index `images.json` reliant le libellé du produit (le texte par
///    lequel il est identifié côté investissement, ex : "20 Francs Napoléon")
///    à son fichier local et son URL d'origine — la corrélation
///    investissement ↔ image, elle, est stockée sur chaque investissement
///    via `Investment.imageFileName` (voir `price_refresh_service.dart`).
///
/// Même convention que les autres repositories du projet : un fichier JSON
/// réécrit en entier à chaque sauvegarde, `JsonEncoder.withIndent('  ')`.
class MetalImageRepository {
  final String vaultPath;

  MetalImageRepository(this.vaultPath);

  Directory get _imagesDir =>
      Directory(p.join(vaultPath, 'investissements', 'metaux', 'images'));

  File get _indexFile => File(
    p.join(vaultPath, 'investissements', 'metaux', 'images.json'),
  );

  File fileFor(String fileName) => File(p.join(_imagesDir.path, fileName));

  /// Index lu depuis le disque : libellé de produit → entrée locale. Vide
  /// si le fichier n'existe pas encore ou est illisible (on repart alors de
  /// zéro au prochain rafraîchissement).
  Future<Map<String, MetalImageEntry>> readIndex() async {
    if (!await _indexFile.exists()) return {};
    try {
      final decoded = jsonDecode(await _indexFile.readAsString());
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: MetalImageEntry.fromJson(
              entry.value as Map<String, dynamic>,
            ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> writeIndex(Map<String, MetalImageEntry> index) async {
    if (!await _imagesDir.exists()) await _imagesDir.create(recursive: true);
    await _indexFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        for (final entry in index.entries) entry.key: entry.value.toJson(),
      }),
    );
  }

  /// Télécharge l'image [product] dans le cache local et retourne le nom de
  /// fichier sous lequel elle est stockée, ou `null` si le téléchargement a
  /// échoué (réseau, réponse inattendue...) — l'app retombe alors sur
  /// l'avatar à initiales, jamais d'erreur propagée.
  Future<String?> download(MetalProductImage product) async {
    final extension = p.extension(Uri.parse(product.imageUrl).path);
    final fileName = '${product.id}${extension.isEmpty ? '.webp' : extension}';
    final target = fileFor(fileName);
    try {
      final response = await http.get(
        Uri.parse(product.imageUrl),
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
              'AppleWebKit/605.1.15',
        },
      );
      if (response.statusCode != 200) return null;
      if (!await _imagesDir.exists()) await _imagesDir.create(recursive: true);
      await target.writeAsBytes(response.bodyBytes);
      return await target.exists() ? fileName : null;
    } catch (_) {
      return null;
    }
  }
}

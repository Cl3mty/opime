import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'geo_dvf_client.dart';

/// Cache local des ventes geo-dvf déjà récupérées — un fichier JSON par
/// commune et par année sous `<vault>/simulations/dvf_cache/`, pour éviter
/// de retélécharger le même fichier à chaque estimation. Même convention
/// que `MetalPriceRepository` : un fichier réécrit en entier à chaque
/// sauvegarde, `JsonEncoder.withIndent('  ')` pour rester lisible à la main.
class DvfCacheRepository {
  final String vaultPath;

  DvfCacheRepository(this.vaultPath);

  File _fileFor(String citycode, int year) => File(
    p.join(vaultPath, 'simulations', 'dvf_cache', '${citycode}_$year.json'),
  );

  Future<void> _ensureDir() async {
    final dir = Directory(p.join(vaultPath, 'simulations', 'dvf_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  /// Ventes en cache pour [citycode]/[year], ou `null` si cette commune/année
  /// n'a encore jamais été récupérée — distinct d'une liste vide (déjà
  /// récupérée, mais aucune vente cette année-là, voir
  /// `GeoDvfClient.fetchCommuneYear`).
  Future<List<DvfSale>?> load(String citycode, int year) async {
    final file = _fileFor(citycode, year);
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content) as List;
      return [
        for (final e in decoded) DvfSale.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String citycode, int year, List<DvfSale> sales) async {
    await _ensureDir();
    final jsonList = [for (final sale in sales) sale.toJson()];
    await _fileFor(
      citycode,
      year,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
  }
}

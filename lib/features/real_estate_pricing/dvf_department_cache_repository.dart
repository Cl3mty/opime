import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'geo_dvf_client.dart';

/// Cache local des ventes geo-dvf récupérées **par département** — un
/// fichier JSON par département et par année sous
/// `<vault>/simulations/dvf_department_cache/`, distinct de
/// [DvfCacheRepository] (qui cache par commune, pour l'estimation à une
/// adresse précise). Utilisé par la carte de chaleur nationale
/// (`real_estate_heatmap_map.dart`) : sans ce cache, chaque montage du
/// widget retélécharge la centaine de fichiers gzip nationaux (l'écran
/// Estimation est démonté/remonté à chaque bascule vers l'onglet Prêt, voir
/// `simulations_real_estate_screen.dart`). Sert aussi de source pour les
/// agrégations communales/grille fine (`real_estate_heatmap_data.dart`),
/// qui n'ont ainsi besoin d'aucun appel réseau supplémentaire une fois le
/// palier départemental chargé une première fois.
class DvfDepartmentCacheRepository {
  final String vaultPath;

  DvfDepartmentCacheRepository(this.vaultPath);

  File _fileFor(String deptCode, int year) => File(
    p.join(vaultPath, 'simulations', 'dvf_department_cache', '${deptCode}_$year.json'),
  );

  Future<void> _ensureDir() async {
    final dir = Directory(p.join(vaultPath, 'simulations', 'dvf_department_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  /// Ventes en cache pour [deptCode]/[year], ou `null` si ce département/
  /// cette année n'a encore jamais été récupéré — distinct d'une liste vide
  /// (déjà récupérée, mais aucune vente cette année-là).
  Future<List<DvfSale>?> load(String deptCode, int year) async {
    final file = _fileFor(deptCode, year);
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

  Future<void> save(String deptCode, int year, List<DvfSale> sales) async {
    await _ensureDir();
    final jsonList = [for (final sale in sales) sale.toJson()];
    await _fileFor(
      deptCode,
      year,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
  }
}

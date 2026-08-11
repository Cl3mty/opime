import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'metal_price_client.dart';
import 'yahoo_finance_client.dart';

/// Un relevé de cours d'un métal (or ou argent) stocké pour un jour donné —
/// [MetalPriceSnapshot] plus sa date de relevé.
class MetalDailyPrice {
  final DateTime date;
  final MetalPriceSnapshot snapshot;

  const MetalDailyPrice({required this.date, required this.snapshot});
}

/// Cache local des cours quotidiens de l'or et de l'argent — un fichier
/// JSON par métal sous le dossier du profil (`investissements/metaux/`),
/// un instantané (cours au gramme + prix de rachat de chaque pièce/lingot)
/// par jour. Alimenté par `price_refresh_service.dart` au premier accès de
/// chaque journée (voir [MetalPriceRepository.save]), relu ensuite pour :
///  * valoriser les investissements métaux précieux hors ligne (repli sur le
///    dernier relevé même périmé si le scraping échoue) ;
///  * reconstruire l'historique de patrimoine et la performance TWR des
///    métaux ([pricePointsFor]).
///
/// Même convention que les autres repositories du projet : un fichier JSON
/// réécrit en entier à chaque sauvegarde, avec `JsonEncoder.withIndent('  ')`
/// pour rester lisible à la main.
class MetalPriceRepository {
  final String vaultPath;

  MetalPriceRepository(this.vaultPath);

  File _fileFor(MetalKind metal) => File(
    p.join(vaultPath, 'investissements', 'metaux', '${metal.fileName}.json'),
  );

  Future<void> _ensureDir() async {
    final dir = Directory(p.join(vaultPath, 'investissements', 'metaux'));
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  /// Tous les relevés stockés pour [metal], du plus ancien au plus récent.
  Future<List<MetalDailyPrice>> loadAll(MetalKind metal) async {
    final file = _fileFor(metal);
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List;
    final prices = [
      for (final e in list)
        MetalDailyPrice(
          date: DateTime.parse((e as Map<String, dynamic>)['date'] as String),
          snapshot: MetalPriceSnapshot(
            pricePerGram: (e['pricePerGram'] as num).toDouble(),
            productPrices: {
              for (final entry in (e['products'] as Map<String, dynamic>).entries)
                entry.key: (entry.value as num).toDouble(),
            },
          ),
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return prices;
  }

  /// Dernier relevé stocké pour [metal], ou `null` si aucun n'existe encore.
  Future<MetalDailyPrice?> latest(MetalKind metal) async {
    final all = await loadAll(metal);
    return all.isEmpty ? null : all.last;
  }

  /// Stocke [snapshot] pour [date] (défaut : aujourd'hui), en remplaçant le
  /// relevé du même jour calendaire s'il y en a un.
  Future<MetalDailyPrice> save(
    MetalKind metal,
    MetalPriceSnapshot snapshot, {
    DateTime? date,
  }) async {
    final now = date ?? DateTime.now();
    final day = DateTime.utc(now.year, now.month, now.day);
    final all = [
      for (final stored in await loadAll(metal))
        if (stored.date.year != day.year ||
            stored.date.month != day.month ||
            stored.date.day != day.day)
          stored,
      MetalDailyPrice(date: day, snapshot: snapshot),
    ]..sort((a, b) => a.date.compareTo(b.date));

    await _ensureDir();
    final jsonList = [
      for (final stored in all)
        {
          'date': stored.date.toIso8601String(),
          'pricePerGram': stored.snapshot.pricePerGram,
          'products': stored.snapshot.productPrices,
        },
    ];
    await _fileFor(
      metal,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
    return MetalDailyPrice(date: day, snapshot: snapshot);
  }

  /// Historique de cours d'un produit (pièce/lingot) reconstruit depuis les
  /// relevés stockés : le prix de rachat du produit lui-même chaque jour, ou
  /// le cours au gramme si le produit n'y figure pas ce jour-là (même repli
  /// que la valorisation — voir `price_refresh_service.dart`). Sert
  /// d'équivalent à l'historique Yahoo Finance des actifs cotés pour :
  ///  * l'historique de patrimoine du Dashboard
  ///    (`real_patrimoine_adapter.dart`, [loadAllPriceHistories]) ;
  ///  * la performance TWR d'un investissement (`investment_detail_screen.dart`).
  Future<List<PricePoint>> pricePointsFor(MetalKind metal, String productName) async {
    final all = await loadAll(metal);
    return [
      for (final stored in all)
        PricePoint(
          stored.date,
          stored.snapshot.productPrices[productName] ??
              stored.snapshot.pricePerGram,
        ),
    ];
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../core/money_format.dart' show round2;
import 'yahoo_finance_client.dart';

/// Résultat de [PriceHistoryRepository.syncIfNeeded] : [points] est
/// toujours le meilleur historique disponible, [upToDate] indique si une
/// tentative de récupération était nécessaire et a réussi (`false` si
/// elle a échoué — hors ligne, API indisponible...).
typedef SyncResult = ({List<PricePoint> points, bool upToDate});

/// Cache local de l'historique de cours par ISIN — même convention que
/// [InvestmentsRepository] (`investments_repository.dart`) : un fichier
/// JSON par actif sous le dossier du profil, réécrit en entier à chaque
/// sauvegarde.
class PriceHistoryRepository {
  final String vaultPath;
  final YahooFinanceClient _client;

  PriceHistoryRepository(this.vaultPath, {YahooFinanceClient? client})
    : _client = client ?? YahooFinanceClient();

  File _fileFor(String isin) =>
      File(p.join(vaultPath, 'investissements', 'cours', '$isin.json'));

  Future<void> _ensureDir() async {
    final dir = Directory(p.join(vaultPath, 'investissements', 'cours'));
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  Future<List<PricePoint>> load(String isin) async {
    final file = _fileFor(isin);
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list
        .map(
          (e) => PricePoint(
            DateTime.parse((e as Map<String, dynamic>)['date'] as String),
            (e['close'] as num).toDouble(),
          ),
        )
        .toList();
  }

  /// [round] à `false` pour les cryptomonnaies, dont le cours a un sens en
  /// dessous du centime — voir [round2].
  Future<void> save(
    String isin,
    List<PricePoint> points, {
    bool round = true,
  }) async {
    await _ensureDir();
    final jsonList = [
      for (final point in points)
        {
          'date': point.date.toIso8601String(),
          'close': round ? round2(point.close) : point.close,
        },
    ];
    await _fileFor(
      isin,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
  }

  /// Complète le cache jusqu'à aujourd'hui si besoin, en ne demandant à
  /// l'API que l'écart manquant (potentiellement plusieurs jours après une
  /// absence). Jamais d'exception propagée : en cas d'échec réseau,
  /// [SyncResult.points] retombe simplement sur le cache existant, et
  /// [SyncResult.upToDate] passe à `false` pour que l'appelant puisse
  /// distinguer "déjà à jour" de "tentative de mise à jour échouée" — même
  /// résultat de `points` dans les deux cas sinon.
  Future<SyncResult> syncIfNeeded(
    String isin,
    String symbol, {
    bool round = true,
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final cached = await load(isin);
    final today = _dateOnly(DateTime.now());
    final lastCachedDate = cached.isEmpty
        ? null
        : cached.map((p) => p.date).reduce((a, b) => a.isAfter(b) ? a : b);

    if (lastCachedDate != null && !lastCachedDate.isBefore(today)) {
      return (points: cached, upToDate: true);
    }

    final fetched = await _client.fetchDailyHistory(
      symbol,
      since: lastCachedDate,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
    if (fetched.isEmpty) return (points: cached, upToDate: false);

    final merged = <DateTime, PricePoint>{
      for (final point in cached) point.date: point,
      for (final point in fetched) point.date: point,
    };
    final result = merged.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    await save(isin, result, round: round);
    return (points: result, upToDate: true);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}

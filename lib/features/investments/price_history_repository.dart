import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../core/money_format.dart' show round2;
import 'yahoo_finance_client.dart';

/// Résultat de [PriceHistoryRepository.syncIfNeeded] : [points] est
/// toujours le meilleur historique disponible, [upToDate] indique si une
/// tentative de récupération était nécessaire et a réussi (`false` si
/// elle a échoué — hors ligne, API indisponible...), et [currency] est la
/// devise de cotation de l'actif (`meta.currency` de l'API Yahoo) —
/// `null` quand le cache était déjà à jour et n'a pas été rafraîchi.
typedef SyncResult = ({
  List<PricePoint> points,
  bool upToDate,
  String? currency,
});

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

  /// [round] à `false` pour les cryptomonnaies et les épargnes en devise
  /// étrangère, dont la quantité/le cours/le taux ont un sens en dessous du
  /// centime — voir [requiresFullPricePrecision] et [round2].
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
  /// l'API que l'écart manquant — mais aussi, si [neededSince] est fourni et
  /// antérieur au tout premier point déjà en cache, l'écart plus ancien : un
  /// investissement dont on vient d'ajouter une transaction plus ancienne
  /// que tout l'historique connu (saisie manuelle rétroactive, import IBKR)
  /// doit pouvoir étendre son historique vers le passé, pas seulement vers
  /// aujourd'hui — sans quoi l'estimation de performance sur une période qui
  /// couvre cette transaction resterait faussée par un historique tronqué.
  /// `null` (par défaut) ne redemande que jusqu'à aujourd'hui, comme avant.
  ///
  /// Les trous qui subsistent malgré la requête (quelques jours sans
  /// donnée alors qu'ils sont dans la plage demandée — source ponctuellement
  /// indisponible ou payante, par exemple — à distinguer d'un week-end ou
  /// jour férié, jamais comblé ici : voir [_interpolateGaps]) sont comblés
  /// par interpolation linéaire plutôt que laissés vides.
  ///
  /// Jamais d'exception propagée : en cas d'échec réseau,
  /// [SyncResult.points] retombe simplement sur le cache existant, et
  /// [SyncResult.upToDate] passe à `false` pour que l'appelant puisse
  /// distinguer "déjà à jour" de "tentative de mise à jour échouée" — même
  /// résultat de `points` dans les deux cas sinon.
  Future<SyncResult> syncIfNeeded(
    String isin,
    String symbol, {
    DateTime? neededSince,
    bool round = true,
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final cached = await load(isin);
    final today = _dateOnly(DateTime.now());
    final neededSinceDay = neededSince == null
        ? today
        : _dateOnly(neededSince);

    DateTime? cachedEarliest;
    DateTime? cachedLatest;
    for (final point in cached) {
      if (cachedEarliest == null || point.date.isBefore(cachedEarliest)) {
        cachedEarliest = point.date;
      }
      if (cachedLatest == null || point.date.isAfter(cachedLatest)) {
        cachedLatest = point.date;
      }
    }

    final needsOlder =
        cachedEarliest == null || cachedEarliest.isAfter(neededSinceDay);
    final needsNewer = cachedLatest == null || cachedLatest.isBefore(today);
    if (!needsOlder && !needsNewer) {
      return (points: cached, upToDate: true, currency: null);
    }

    // Un trou plus ancien que le cache se comble en une seule requête large
    // depuis [neededSinceDay] (qui couvre alors aussi l'écart récent) —
    // sinon, comme avant, on ne redemande que l'écart récent depuis le
    // dernier point connu.
    final since = needsOlder ? neededSinceDay : cachedLatest;
    final fetched = await _client.fetchDailyHistory(
      symbol,
      since: since,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
    if (fetched.points.isEmpty) {
      return (points: cached, upToDate: false, currency: null);
    }

    final merged = <DateTime, PricePoint>{
      for (final point in cached) point.date: point,
      for (final point in fetched.points) point.date: point,
    };
    final sorted = merged.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final result = _interpolateGaps(sorted);
    await save(isin, result, round: round);
    return (points: result, upToDate: true, currency: fetched.currency);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}

/// Comble par interpolation linéaire les trous strictement compris entre
/// [minGapDays] et [maxGapDays] jours calendaires entre deux points
/// consécutifs déjà triés par date. En dessous de [minGapDays] (un week-end
/// ou un jour férié isolé — 1 à 4 jours), un trou est normal et attendu pour
/// une cotation quotidienne : il n'est jamais comblé, la dernière valeur
/// connue faisant déjà foi jusqu'au point suivant (voir
/// `real_patrimoine_adapter.dart`'s `_priceAt`). Au-delà de [maxGapDays], le
/// trou est probablement une indisponibilité prolongée et réelle (titre
/// suspendu, source cassée sur une longue période...) : mieux vaut le
/// laisser tel quel que d'inventer une tendance sur plusieurs semaines sans
/// aucune donnée pour l'étayer.
List<PricePoint> _interpolateGaps(
  List<PricePoint> sorted, {
  int minGapDays = 4,
  int maxGapDays = 10,
}) {
  if (sorted.length < 2) return sorted;
  final result = <PricePoint>[sorted.first];
  for (var i = 1; i < sorted.length; i++) {
    final previous = sorted[i - 1];
    final next = sorted[i];
    final gapDays = next.date.difference(previous.date).inDays;
    if (gapDays > minGapDays && gapDays <= maxGapDays) {
      for (var offset = 1; offset < gapDays; offset++) {
        final t = offset / gapDays;
        result.add(
          PricePoint(
            previous.date.add(Duration(days: offset)),
            previous.close + (next.close - previous.close) * t,
          ),
        );
      }
    }
    result.add(next);
  }
  return result;
}

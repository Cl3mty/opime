import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

/// Type de bien pour les indicateurs de loyer — distinct de
/// [PropertyTypeFilter] (`price_estimator.dart`), qui porte une valeur
/// `any` sans équivalent côté loyers (le jeu de données "Carte des loyers"
/// ne publie qu'un fichier "maison" et un fichier "appartement", jamais
/// "tous types confondus").
enum RentPropertyType { maison, appartement }

/// Estimation de loyer au m² pour une commune — issue de la "Carte des
/// loyers" (ANIL/DHUP, `data.gouv.fr`), un modèle prédictif publié
/// annuellement à partir d'annonces de location (SeLoger, leboncoin).
class RentEstimate {
  final String communeCode;
  final String departmentCode;
  final double loyerPredM2;
  final double lowerBound;
  final double upperBound;

  /// `"commune"` : estimation directe pour la commune. `"maille"` : repli
  /// sur une maille géographique plus large, faute d'assez d'annonces
  /// locales — voir [sampleSize].
  final String predictionType;
  final int sampleSize;

  const RentEstimate({
    required this.communeCode,
    required this.departmentCode,
    required this.loyerPredM2,
    required this.lowerBound,
    required this.upperBound,
    required this.predictionType,
    required this.sampleSize,
  });

  factory RentEstimate.fromJson(Map<String, dynamic> json) => RentEstimate(
    communeCode: json['communeCode'] as String,
    departmentCode: json['departmentCode'] as String,
    loyerPredM2: (json['loyerPredM2'] as num).toDouble(),
    lowerBound: (json['lowerBound'] as num).toDouble(),
    upperBound: (json['upperBound'] as num).toDouble(),
    predictionType: json['predictionType'] as String,
    sampleSize: json['sampleSize'] as int,
  );

  Map<String, dynamic> toJson() => {
    'communeCode': communeCode,
    'departmentCode': departmentCode,
    'loyerPredM2': loyerPredM2,
    'lowerBound': lowerBound,
    'upperBound': upperBound,
    'predictionType': predictionType,
    'sampleSize': sampleSize,
  };
}

/// Client pour la "Carte des loyers" (ANIL/DHUP, `data.gouv.fr`) — gratuit,
/// sans clé, licence ouverte. Contrairement à geo-dvf (un fichier par
/// commune), c'est **un seul fichier national** par type de bien : pas de
/// notion de rayon/agrégation ici, juste une lecture directe par code
/// commune une fois le fichier téléchargé — voir `rent_price_repository.dart`
/// pour la mise en cache (un seul fichier, pas par commune).
///
/// URLs de redirection stables `data.gouv.fr` (pas les URLs
/// `static.data.gouv.fr` horodatées, qui changent à chaque édition
/// annuelle) — vérifiées en direct sur l'édition 2025.
class RentPriceClient {
  static const _urls = {
    RentPropertyType.appartement:
        'https://www.data.gouv.fr/api/1/datasets/r/55b34088-0964-415f-9df7-d87dd98a09be',
    RentPropertyType.maison:
        'https://www.data.gouv.fr/api/1/datasets/r/129f764d-b613-44e4-952c-5ff50a8c9b73',
  };

  /// Table des loyers par commune pour [type] — `null` sur échec réseau,
  /// jamais d'exception. `http.get` suit automatiquement la redirection
  /// vers le fichier `static.data.gouv.fr` de l'édition en cours.
  Future<Map<String, RentEstimate>?> fetchNational(
    RentPropertyType type, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    try {
      final response = await http.get(Uri.parse(_urls[type]!));
      onNetworkSuccess?.call();
      if (response.statusCode != 200) return null;
      return parseCsv(response.body);
    } on SocketException catch (_) {
      onNetworkError?.call();
      return null;
    } on http.ClientException catch (_) {
      onNetworkError?.call();
      return null;
    } on TimeoutException catch (_) {
      onNetworkError?.call();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parse le CSV national (`;` comme séparateur, virgule décimale) — une
  /// ligne malformée est ignorée plutôt que de faire échouer tout le
  /// fichier, même philosophie défensive que `GeoDvfClient.parseCsv`.
  static Map<String, RentEstimate> parseCsv(String csvContent) {
    if (csvContent.trim().isEmpty) return {};
    final rows = const CsvDecoder(
      fieldDelimiter: ';',
      parseHeaders: true,
    ).convert(csvContent);
    final result = <String, RentEstimate>{};
    for (final rawRow in rows) {
      if (rawRow is! CsvRow) continue;
      try {
        final communeCode = rawRow['INSEE_C'] as String?;
        final departmentCode = rawRow['DEP'] as String?;
        final loyerPredM2 = _toDouble(rawRow['loypredm2']);
        final lowerBound = _toDouble(rawRow['lwr.IPm2']);
        final upperBound = _toDouble(rawRow['upr.IPm2']);
        final predictionType = rawRow['TYPPRED'] as String?;
        final sampleSize = _toInt(rawRow['nbobs_com']);
        if (communeCode == null ||
            departmentCode == null ||
            loyerPredM2 == null ||
            lowerBound == null ||
            upperBound == null ||
            predictionType == null ||
            sampleSize == null) {
          continue;
        }
        result[communeCode] = RentEstimate(
          communeCode: communeCode,
          departmentCode: departmentCode,
          loyerPredM2: loyerPredM2,
          lowerBound: lowerBound,
          upperBound: upperBound,
          predictionType: predictionType,
          sampleSize: sampleSize,
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  static double? _toDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      if (raw.trim().isEmpty) return null;
      return double.tryParse(raw.trim().replaceAll(',', '.'));
    }
    return null;
  }

  static int? _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }
}

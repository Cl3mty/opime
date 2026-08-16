import 'dart:async' show TimeoutException;
import 'dart:convert' show utf8;
import 'dart:io' show SocketException, gzip;
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

/// Une vente immobilière issue des fichiers "geo-dvf" (Etalab, dérivés des
/// Demandes de Valeurs Foncières) — voir [GeoDvfClient] pour la source
/// exacte. Ne conserve que les champs utiles à l'estimation de prix/m² (voir
/// `price_estimator.dart`), pas la totalité des ~39 colonnes du CSV source.
class DvfSale {
  final String natureMutation;
  final double valeurFonciere;
  final String? typeLocal;
  final double surfaceReelleBati;
  final double longitude;
  final double latitude;
  final DateTime dateMutation;
  final String codeCommune;

  const DvfSale({
    required this.natureMutation,
    required this.valeurFonciere,
    this.typeLocal,
    required this.surfaceReelleBati,
    required this.longitude,
    required this.latitude,
    required this.dateMutation,
    required this.codeCommune,
  });

  /// Prix au m² de cette vente — `0` si la surface est inconnue (l'appelant
  /// filtre déjà `surfaceReelleBati > 0` avant d'agréger, voir
  /// `price_estimator.dart`).
  double get pricePerSqm => surfaceReelleBati > 0 ? valeurFonciere / surfaceReelleBati : 0;

  factory DvfSale.fromJson(Map<String, dynamic> json) => DvfSale(
    natureMutation: json['natureMutation'] as String,
    valeurFonciere: (json['valeurFonciere'] as num).toDouble(),
    typeLocal: json['typeLocal'] as String?,
    surfaceReelleBati: (json['surfaceReelleBati'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    latitude: (json['latitude'] as num).toDouble(),
    dateMutation: DateTime.parse(json['dateMutation'] as String),
    codeCommune: json['codeCommune'] as String,
  );

  Map<String, dynamic> toJson() => {
    'natureMutation': natureMutation,
    'valeurFonciere': valeurFonciere,
    if (typeLocal != null) 'typeLocal': typeLocal,
    'surfaceReelleBati': surfaceReelleBati,
    'longitude': longitude,
    'latitude': latitude,
    'dateMutation': dateMutation.toIso8601String(),
    'codeCommune': codeCommune,
  };
}

/// Département (code à 2-3 caractères, clé de chemin des fichiers geo-dvf)
/// depuis un code commune INSEE à 5 chiffres — gère la Corse (2A/2B, communes
/// commençant par "2A"/"2B") et les DOM (971-976, codes commune à 5 chiffres
/// commençant par le département à 3 chiffres).
String departmentCodeFromCommuneCode(String inseeCode) {
  if (inseeCode.startsWith('2A') || inseeCode.startsWith('2B')) {
    return inseeCode.substring(0, 2);
  }
  if (inseeCode.startsWith('97') || inseeCode.startsWith('98')) {
    return inseeCode.substring(0, 3);
  }
  return inseeCode.substring(0, 2);
}

/// Client pour les fichiers "geo-dvf" (Etalab, `files.data.gouv.fr`) —
/// dérivé public, gratuit et sans clé des Demandes de Valeurs Foncières, un
/// fichier CSV par commune et par année. Pas d'API de requête géographique
/// disponible pour les particuliers (voir la note dans le plan) : on
/// télécharge le fichier de la commune concernée et on filtre/agrège
/// localement (voir `price_estimator.dart`).
///
/// Même philosophie défensive que [MetalPriceClient]/`YahooFinanceClient` :
/// un échec réseau retourne `null` (jamais d'exception propagée). Une
/// réponse 404 (aucune vente cette année-là dans cette commune) est un cas
/// normal, pas un échec — elle retourne une liste vide, distincte de `null`,
/// pour que l'appelant sache qu'il peut mettre ce résultat en cache (voir
/// `real_estate_price_service.dart`).
class GeoDvfClient {
  static const _baseUrl = 'https://files.data.gouv.fr/geo-dvf/latest/csv';

  Future<List<DvfSale>?> fetchCommuneYear({
    required String citycode,
    required int year,
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final deptCode = departmentCodeFromCommuneCode(citycode);
    final uri = Uri.parse(
      '$_baseUrl/$year/communes/$deptCode/$citycode.csv',
    );
    try {
      final response = await http.get(uri);
      onNetworkSuccess?.call();
      if (response.statusCode == 404) return [];
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

  /// Comme [fetchCommuneYear], mais pour le fichier agrégeant **tout un
  /// département** — utilisé par la carte de chaleur nationale
  /// (`real_estate_heatmap_data.dart`) pour calculer une médiane par
  /// département sans avoir à récupérer chaque commune une par une.
  /// Ces fichiers sont distribués compressés en gzip (contrairement aux
  /// fichiers communaux, non compressés) — vérifié en direct.
  Future<List<DvfSale>?> fetchDepartment({
    required String deptCode,
    required int year,
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final uri = Uri.parse('$_baseUrl/$year/departements/$deptCode.csv.gz');
    try {
      final response = await http.get(uri);
      onNetworkSuccess?.call();
      if (response.statusCode == 404) return [];
      if (response.statusCode != 200) return null;
      final decompressed = gzip.decode(response.bodyBytes);
      return parseCsv(utf8.decode(decompressed));
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

  /// Parse le contenu CSV d'un fichier geo-dvf — chaque ligne est traitée
  /// indépendamment (`try/catch` par ligne) : une ligne malformée est
  /// ignorée plutôt que de faire échouer tout le fichier, un fichier vide ou
  /// sans en-tête donne une liste vide.
  static List<DvfSale> parseCsv(String csvContent) {
    if (csvContent.trim().isEmpty) return [];
    final rows = const CsvDecoder(parseHeaders: true).convert(csvContent);
    final result = <DvfSale>[];
    for (final rawRow in rows) {
      if (rawRow is! CsvRow) continue;
      final row = rawRow;
      try {
        final natureMutation = row['nature_mutation'] as String?;
        final valeurFonciereRaw = row['valeur_fonciere'];
        final surfaceRaw = row['surface_reelle_bati'];
        final longitudeRaw = row['longitude'];
        final latitudeRaw = row['latitude'];
        final dateRaw = row['date_mutation'] as String?;
        final codeCommune = row['code_commune'] as String?;
        if (natureMutation == null ||
            valeurFonciereRaw == null ||
            surfaceRaw == null ||
            longitudeRaw == null ||
            latitudeRaw == null ||
            dateRaw == null ||
            codeCommune == null) {
          continue;
        }
        final valeurFonciere = _toDouble(valeurFonciereRaw);
        final surface = _toDouble(surfaceRaw);
        final longitude = _toDouble(longitudeRaw);
        final latitude = _toDouble(latitudeRaw);
        if (valeurFonciere == null ||
            surface == null ||
            longitude == null ||
            latitude == null) {
          continue;
        }
        result.add(
          DvfSale(
            natureMutation: natureMutation,
            valeurFonciere: valeurFonciere,
            typeLocal: (row['type_local'] as String?)?.trim().isEmpty ?? true
                ? null
                : row['type_local'] as String,
            surfaceReelleBati: surface,
            longitude: longitude,
            latitude: latitude,
            dateMutation: DateTime.parse(dateRaw),
            codeCommune: codeCommune,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  /// Le décodage CSV type déjà les nombres quand c'est possible
  /// (`dynamicTyping`, désactivé ici pour éviter des surprises sur les codes
  /// commençant par un zéro) : les champs numériques arrivent donc en texte,
  /// avec parfois une chaîne vide pour une valeur absente.
  static double? _toDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      if (raw.trim().isEmpty) return null;
      return double.tryParse(raw.trim());
    }
    return null;
  }
}

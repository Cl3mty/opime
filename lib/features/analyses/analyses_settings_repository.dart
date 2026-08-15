import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Paramètres de l'écran Analyses propres à un profil — aujourd'hui
/// seulement le ticker du benchmark utilisé pour l'alpha (voir
/// `analyses_calculations.dart`'s `simpleAlpha`). Donnée de domaine liée au
/// vault, donc un fichier JSON du vault plutôt que `shared_preferences`
/// (réservé dans ce code à l'état device-local — thème, vault actif — jamais
/// à une donnée de domaine qui doit voyager avec le vault).
class AnalysesSettings {
  final String? benchmarkTicker;

  const AnalysesSettings({this.benchmarkTicker});

  factory AnalysesSettings.empty() => const AnalysesSettings();

  factory AnalysesSettings.fromJson(Map<String, dynamic> json) =>
      AnalysesSettings(benchmarkTicker: json['benchmarkTicker'] as String?);

  Map<String, dynamic> toJson() => {
    if (benchmarkTicker != null) 'benchmarkTicker': benchmarkTicker,
  };
}

class AnalysesSettingsRepository {
  final String vaultPath;
  AnalysesSettingsRepository(this.vaultPath);

  File get _file =>
      File(p.join(vaultPath, 'analyses', 'parametres.json'));

  Future<AnalysesSettings> load() async {
    if (!await _file.exists()) return AnalysesSettings.empty();
    final content = await _file.readAsString();
    if (content.trim().isEmpty) return AnalysesSettings.empty();
    try {
      return AnalysesSettings.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } catch (_) {
      return AnalysesSettings.empty();
    }
  }

  Future<void> save(AnalysesSettings settings) async {
    final dir = Directory(p.join(vaultPath, 'analyses'));
    if (!await dir.exists()) await dir.create(recursive: true);
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }
}

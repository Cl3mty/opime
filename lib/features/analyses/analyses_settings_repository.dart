import 'dart:convert';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';

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
  late final VaultFileStorage _storage;

  AnalysesSettingsRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _relativePath = 'analyses/parametres.json';

  Future<AnalysesSettings> load() async {
    if (!await _storage.exists(_relativePath)) return AnalysesSettings.empty();
    final content = await _storage.readString(_relativePath);
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
    await _storage.writeString(
      _relativePath,
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }
}

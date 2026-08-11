import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotesUrl;

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotesUrl,
  });
}

class UpdateCheckResult {
  final String currentVersion;
  final String? latestVersion;
  final UpdateInfo? update;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.currentVersion,
    this.latestVersion,
    this.update,
    this.errorMessage,
  });

  bool get hasUpdate => update != null;
  bool get isUpToDate =>
      update == null && errorMessage == null && latestVersion != null;
  bool get hasError => errorMessage != null;
}

class UpdateChecker {
  final String githubOwner;
  final String githubRepo;

  UpdateChecker({required this.githubOwner, required this.githubRepo});

  /// Retourne les infos de mise à jour si une version plus récente que
  /// l'app installée est publiée sur GitHub, sinon null (y compris en cas
  /// d'erreur réseau — on n'embête jamais l'utilisateur pour ça).
  Future<UpdateInfo?> checkForUpdate() async {
    final result = await checkForUpdateDetailed();
    return result.update;
  }

  /// Vérification détaillée pour l'UI Settings : permet de distinguer
  /// "à jour" de "impossible de vérifier".
  Future<UpdateCheckResult> checkForUpdateDetailed() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final tagsResponse = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$githubOwner/$githubRepo/tags?per_page=100',
        ),
        headers: {'Accept': 'application/vnd.github+json'},
      );
      if (tagsResponse.statusCode != 200) {
        return UpdateCheckResult(
          currentVersion: currentVersion,
          errorMessage:
              'GitHub API tags a répondu ${tagsResponse.statusCode}. Vérifie owner/repo et visibilité du dépôt.',
        );
      }

      final tagsJson = jsonDecode(tagsResponse.body);
      if (tagsJson is! List) {
        return UpdateCheckResult(
          currentVersion: currentVersion,
          errorMessage: 'Format de réponse GitHub tags inattendu.',
        );
      }

      String? bestTagName;
      String? bestVersion;
      for (final tag in tagsJson) {
        if (tag is! Map<String, dynamic>) continue;
        final name = tag['name'] as String?;
        if (name == null || name.trim().isEmpty) continue;
        final version = _stripLeadingV(name.trim());
        if (!_isParseableVersion(version)) continue;
        if (bestVersion == null || _compareVersions(version, bestVersion) > 0) {
          bestVersion = version;
          bestTagName = name.trim();
        }
      }

      if (bestTagName == null || bestVersion == null) {
        return UpdateCheckResult(
          currentVersion: currentVersion,
          errorMessage: 'Aucun tag de version exploitable trouvé sur GitHub.',
        );
      }

      final latestVersion = bestVersion;
      if (!_isNewer(latestVersion, currentVersion)) {
        return UpdateCheckResult(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
        );
      }

      var downloadUrl = 'https://github.com/$githubOwner/$githubRepo/tags';
      var releaseNotesUrl = 'https://github.com/$githubOwner/$githubRepo/tags';

      final releaseByTagResponse = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$githubOwner/$githubRepo/releases/tags/${Uri.encodeComponent(bestTagName)}',
        ),
        headers: {'Accept': 'application/vnd.github+json'},
      );
      if (releaseByTagResponse.statusCode == 200) {
        final releaseJson =
            jsonDecode(releaseByTagResponse.body) as Map<String, dynamic>;
        downloadUrl =
            _pickPlatformAssetDownloadUrl(releaseJson) ??
            (releaseJson['html_url'] as String? ?? downloadUrl);
        releaseNotesUrl =
            (releaseJson['html_url'] as String? ?? releaseNotesUrl);
      }

      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        update: UpdateInfo(
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          releaseNotesUrl: releaseNotesUrl,
        ),
      );
    } catch (e) {
      return UpdateCheckResult(
        currentVersion: currentVersion,
        errorMessage: 'Erreur réseau/API pendant la vérification: $e',
      );
    }
  }

  bool _isNewer(String remote, String current) {
    return _compareVersions(remote, current) > 0;
  }

  bool _isParseableVersion(String version) {
    final parts = _parseVersionParts(version);
    return parts.isNotEmpty;
  }

  int _compareVersions(String a, String b) {
    final r = _parseVersionParts(a);
    final c = _parseVersionParts(b);
    for (var i = 0; i < r.length || i < c.length; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv != cv) return rv > cv ? 1 : -1;
    }
    return 0;
  }

  List<int> _parseVersionParts(String version) {
    final cleaned = _stripLeadingV(version);
    final core = cleaned.split('-').first;
    final parts = core.split('.');
    final numbers = <int>[];
    for (final part in parts) {
      final match = RegExp(r'^\d+').firstMatch(part.trim());
      if (match == null) {
        numbers.add(0);
      } else {
        numbers.add(int.tryParse(match.group(0) ?? '0') ?? 0);
      }
    }
    return numbers;
  }

  String _stripLeadingV(String value) {
    if (value.startsWith('v') || value.startsWith('V')) {
      return value.substring(1);
    }
    return value;
  }

  String? _pickPlatformAssetDownloadUrl(Map<String, dynamic> releaseJson) {
    final assets = (releaseJson['assets'] as List?) ?? [];
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (Platform.isMacOS &&
          (name.endsWith('.dmg') || name.contains('macos'))) {
        return asset['browser_download_url'] as String?;
      }
      if (Platform.isWindows && name.endsWith('.exe')) {
        return asset['browser_download_url'] as String?;
      }
      if (Platform.isLinux &&
          (name.endsWith('.appimage') || name.endsWith('.deb'))) {
        return asset['browser_download_url'] as String?;
      }
    }
    return null;
  }
}

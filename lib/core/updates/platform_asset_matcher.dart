/// Choisit, parmi les "assets" d'une release GitHub, celui qui correspond à
/// la plateforme demandée — même convention de nommage partout dans le
/// projet (`.dmg`/"macos" pour macOS, `.exe` pour Windows, `.AppImage`/
/// `.deb` pour Linux) — pour que [UpdateChecker] (vérification de mise à
/// jour depuis l'app déjà installée) et la section téléchargement de la
/// landing page web (`features/landing/landing_screen.dart`, avant même
/// toute installation) choisissent toujours le même fichier pour une même
/// release plutôt que deux logiques de correspondance qui pourraient
/// diverger.
String? pickPlatformAssetDownloadUrl(
  List<dynamic> assets, {
  required bool isMacOS,
  required bool isWindows,
  required bool isLinux,
}) {
  for (final asset in assets) {
    if (asset is! Map<String, dynamic>) continue;
    final name = (asset['name'] as String? ?? '').toLowerCase();
    if (isMacOS && (name.endsWith('.dmg') || name.contains('macos'))) {
      return asset['browser_download_url'] as String?;
    }
    if (isWindows && name.endsWith('.exe')) {
      return asset['browser_download_url'] as String?;
    }
    if (isLinux && (name.endsWith('.appimage') || name.endsWith('.deb'))) {
      return asset['browser_download_url'] as String?;
    }
  }
  return null;
}

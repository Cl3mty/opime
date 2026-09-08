import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/updates/platform_asset_matcher.dart';

void main() {
  final assets = [
    {'name': 'Opime-1.2.0.dmg', 'browser_download_url': 'https://x/mac.dmg'},
    {'name': 'Opime-1.2.0.exe', 'browser_download_url': 'https://x/win.exe'},
    {
      'name': 'Opime-1.2.0.AppImage',
      'browser_download_url': 'https://x/linux.AppImage',
    },
  ];

  test('choisit le .dmg pour macOS', () {
    expect(
      pickPlatformAssetDownloadUrl(
        assets,
        isMacOS: true,
        isWindows: false,
        isLinux: false,
      ),
      'https://x/mac.dmg',
    );
  });

  test('choisit le .exe pour Windows', () {
    expect(
      pickPlatformAssetDownloadUrl(
        assets,
        isMacOS: false,
        isWindows: true,
        isLinux: false,
      ),
      'https://x/win.exe',
    );
  });

  test('choisit le .AppImage pour Linux', () {
    expect(
      pickPlatformAssetDownloadUrl(
        assets,
        isMacOS: false,
        isWindows: false,
        isLinux: true,
      ),
      'https://x/linux.AppImage',
    );
  });

  test('reconnaît aussi un nom contenant "macos" sans extension .dmg', () {
    final macoNamedAssets = [
      {
        'name': 'opime-macos-universal.zip',
        'browser_download_url': 'https://x/mac.zip',
      },
    ];
    expect(
      pickPlatformAssetDownloadUrl(
        macoNamedAssets,
        isMacOS: true,
        isWindows: false,
        isLinux: false,
      ),
      'https://x/mac.zip',
    );
  });

  test('renvoie null si aucun asset ne correspond à la plateforme', () {
    expect(
      pickPlatformAssetDownloadUrl(
        [
          {'name': 'README.md', 'browser_download_url': 'https://x/readme'},
        ],
        isMacOS: true,
        isWindows: false,
        isLinux: false,
      ),
      isNull,
    );
  });

  test('ignore les entrées mal formées sans planter', () {
    expect(
      pickPlatformAssetDownloadUrl(
        ['not a map', 42, null],
        isMacOS: true,
        isWindows: true,
        isLinux: true,
      ),
      isNull,
    );
  });

  test('aucune plateforme demandée : renvoie toujours null', () {
    expect(
      pickPlatformAssetDownloadUrl(
        assets,
        isMacOS: false,
        isWindows: false,
        isLinux: false,
      ),
      isNull,
    );
  });
}

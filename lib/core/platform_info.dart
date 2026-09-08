import 'package:flutter/foundation.dart' show kIsWeb;

import 'platform_info_io.dart' if (dart.library.js_interop) 'platform_info_web.dart'
    as host;

/// Remplaçants web-safe de `dart:io`'s `Platform.is*` — le backend est
/// choisi à la compilation : `dart:io` `Platform` sur desktop (sémantique
/// strictement identique à l'ancien code), `false` sur web (une app web ne
/// tourne jamais « sur macOS/Windows/Linux »). Ne jamais utiliser
/// `defaultTargetPlatform` ici : il vaut `TargetPlatform.android` sous
/// `flutter_tester` (y compris sur un host macOS), ce qui casserait les
/// raccourcis clavier et autres branchements plateforme des tests.
bool get isMacOS => !kIsWeb && host.isMacOS;

bool get isWindows => !kIsWeb && host.isWindows;

bool get isLinux => !kIsWeb && host.isLinux;

bool get isIOS => !kIsWeb && host.isIOS;

bool get isAndroid => !kIsWeb && host.isAndroid;

/// Desktop uniquement (macOS, Windows ou Linux) — jamais vrai sur web/mobile.
bool get isDesktopPlatform =>
    !kIsWeb && (host.isMacOS || host.isWindows || host.isLinux);
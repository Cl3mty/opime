/// Backend web des prédicats de plateforme : toujours `false` — une app web
/// n'est jamais « sur macOS/Windows/Linux », et `dart:io Platform` (backend
/// desktop) n'existe pas ici.
library;

bool get isMacOS => false;

bool get isWindows => false;

bool get isLinux => false;

bool get isIOS => false;

bool get isAndroid => false;
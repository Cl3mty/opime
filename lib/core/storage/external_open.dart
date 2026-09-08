/// Ouvre un fichier document (préalablement matérialisé hors du vault, voir
/// `temp_file.dart`) : avec l'application externe par défaut du système sur
/// desktop, par téléchargement dans le navigateur sur web.
library;

import 'external_open_io.dart' if (dart.library.js_interop) 'external_open_web.dart'
    as platform;

Future<void> openExternalFile(String path) => platform.openExternalFile(path);
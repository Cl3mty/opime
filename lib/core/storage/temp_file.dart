/// Matérialise des octets dans un fichier temporaire lisible, hors du
/// dossier du vault : vrai dossier temp du système sur desktop, sous-dossier
/// `.opime/tmp` d'OPFS sur web (le navigateur n'a pas de disque temp).
/// Choisi à la compilation via l'import conditionnel ci-dessous.
library;

import 'dart:typed_data';

import 'temp_file_io.dart' if (dart.library.js_interop) 'temp_file_web.dart'
    as platform;

/// Écrit [bytes] dans un nouveau fichier temporaire nommé [fileName] et
/// renvoie son chemin (chemin réel sur desktop, chemin virtuel OPFS sur
/// web). Un nouveau fichier à chaque appel, jamais réutilisé.
Future<String> createTempCopy({
  required String fileName,
  required Uint8List bytes,
  required String vaultPath,
}) => platform.createTempCopy(
  fileName: fileName,
  bytes: bytes,
  vaultPath: vaultPath,
);
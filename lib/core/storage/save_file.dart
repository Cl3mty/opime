/// Propose à l'utilisateur d'exporter des octets vers un emplacement de son
/// choix : vrai dialogue "Enregistrer sous" sur desktop (`file_picker`),
/// téléchargement par le navigateur sur web (aucun système de fichiers
/// local). Choisi à la compilation via l'import conditionnel ci-dessous.
library;

import 'dart:typed_data';

import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart'
    as platform;

/// Renvoie le chemin d'écriture effectif sur desktop (extension garantie),
/// le nom du fichier téléchargé sur web, ou `null` si l'utilisateur annule.
Future<String?> saveFileBytes({
  required String fileName,
  required Uint8List bytes,
  required String dialogTitle,
}) => platform.saveFileBytes(
  fileName: fileName,
  bytes: bytes,
  dialogTitle: dialogTitle,
);
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Backend web : le navigateur n'a pas de dialogue "Enregistrer sous" — on
/// déclenche un téléchargement via un Blob. Le "chemin" renvoyé est le nom
/// du fichier, pour l'affichage du message de succès.
Future<String?> saveFileBytes({
  required String fileName,
  required Uint8List bytes,
  required String dialogTitle,
}) async {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
  return fileName;
}
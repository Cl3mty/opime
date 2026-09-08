import 'dart:js_interop';

import 'package:path/path.dart' as p;
import 'package:web/web.dart' as web;

import 'vault_fs.dart';

/// Web : le navigateur ne peut pas ouvrir un fichier du disque local — on
/// lit les octets (déjà matérialisés sous OPFS, voir `temp_file_web.dart`)
/// et on déclenche un téléchargement via un Blob.
Future<void> openExternalFile(String path) async {
  final bytes = await VaultFile(path).readAsBytes();
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = p.basename(path);
  anchor.click();
  web.URL.revokeObjectURL(url);
}
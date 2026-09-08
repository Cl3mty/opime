import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Desktop : dossier temp réel du système (`Directory.systemTemp`).
Future<String> createTempCopy({
  required String fileName,
  required Uint8List bytes,
  required String vaultPath,
}) async {
  final dir = await Directory.systemTemp.createTemp('opime_document_');
  final file = File(p.join(dir.path, p.basename(fileName)));
  await file.writeAsBytes(bytes);
  return file.path;
}
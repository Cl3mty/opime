import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'vault_fs.dart';

/// Web : pas de disque temp natif — on écrit dans `.opime/tmp` sous OPFS,
/// le chemin renvoyé étant le chemin virtuel du vault (lu ensuite via
/// [VaultFile] pour générer le Blob de téléchargement).
Future<String> createTempCopy({
  required String fileName,
  required Uint8List bytes,
  required String vaultPath,
}) async {
  final dir = VaultDirectory(p.join(vaultPath, '.opime', 'tmp'));
  await dir.create(recursive: true);
  final token = DateTime.now().millisecondsSinceEpoch.toString();
  final file = VaultFile(p.join(dir.path, '$token-${p.basename(fileName)}'));
  await file.writeAsBytes(bytes);
  return file.path;
}
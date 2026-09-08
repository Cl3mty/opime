import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Backend desktop : dialogue "Enregistrer sous" natif — `file_picker`
/// écrit les [bytes] à l'emplacement choisi puis on garantit l'extension
/// demandée (bonne pratique : ne jamais laisser un `.pdf`-où un `.png`
/// sans extension).
Future<String?> saveFileBytes({
  required String fileName,
  required Uint8List bytes,
  required String dialogTitle,
}) async {
  final savePath = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    bytes: bytes,
  );
  if (savePath == null) return null;
  final extension = p.extension(fileName);
  final path = savePath.toLowerCase().endsWith(extension.toLowerCase())
      ? savePath
      : '$savePath$extension';
  await File(path).writeAsBytes(bytes);
  return path;
}
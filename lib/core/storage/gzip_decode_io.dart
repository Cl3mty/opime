import 'dart:io' show gzip;
import 'dart:typed_data';

/// Backend desktop : le codec gzip natif de `dart:io`.
Future<Uint8List> gzipDecode(Uint8List bytes) async =>
    Uint8List.fromList(gzip.decode(bytes));
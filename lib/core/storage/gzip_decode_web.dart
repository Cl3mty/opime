import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Backend web : le flux natif `DecompressionStream('gzip')` du navigateur.
/// Les octets compressés sont écrits côté "writable" du flux, et les
/// morceaux décompressés relus côté "readable" (un byte stream en produit
/// toujours des `Uint8Array`).
Future<Uint8List> gzipDecode(Uint8List bytes) async {
  final stream = web.DecompressionStream('gzip');
  final writer = stream.writable.getWriter();
  await writer.write(bytes.toJS).toDart;
  await writer.close().toDart;

  final reader = stream.readable.getReader() as web.ReadableStreamDefaultReader;
  final chunks = <Uint8List>[];
  while (true) {
    final result = await reader.read().toDart;
    if (result.done) break;
    final value = result.value;
    if (value == null) continue;
    chunks.add((value as JSUint8Array).toDart);
  }
  return Uint8List.fromList([for (final chunk in chunks) ...chunk]);
}
import 'dart:typed_data';

import 'gzip_decode_io.dart' if (dart.library.js_interop) 'gzip_decode_web.dart'
    as platform;

/// Décompresse des octets gzip de façon portable :
///  * desktop : codec natif `dart:io` (`gzip.decode`) ;
///  * web : flux natif `DecompressionStream('gzip')` du navigateur —
///    `dart:io` n'existe pas sur le web et `package:http` ne décompresse
///    pas les fichiers `.gz` servis comme ressources opaques.
Future<Uint8List> gzipDecode(Uint8List bytes) => platform.gzipDecode(bytes);
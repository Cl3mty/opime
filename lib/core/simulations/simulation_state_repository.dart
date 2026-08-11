import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class SimulationStateRepository {
  final String profileDataPath;

  const SimulationStateRepository(this.profileDataPath);

  File _fileFor(String key) =>
      File(p.join(profileDataPath, 'simulations', '$key.json'));

  Future<Map<String, dynamic>> read(String key) async {
    final file = _fileFor(key);
    if (!await file.exists()) return {};

    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> write(String key, Map<String, dynamic> data) async {
    final file = _fileFor(key);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<void> delete(String key) async {
    final file = _fileFor(key);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

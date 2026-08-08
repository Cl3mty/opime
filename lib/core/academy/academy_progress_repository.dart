import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class AcademyProgressRepository {
  final String profileDataPath;
  const AcademyProgressRepository(this.profileDataPath);

  File get _file => File(p.join(profileDataPath, 'academy', 'progress.json'));

  Future<Set<String>> read() async {
    if (!await _file.exists()) return {};
    try {
      final content = await _file.readAsString();
      if (content.trim().isEmpty) return {};
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        final completed = decoded['completed'];
        if (completed is List) return completed.map((e) => e.toString()).toSet();
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> write(Set<String> completed) async {
    final file = _file;
    final dir = file.parent;
    if (!await dir.exists()) await dir.create(recursive: true);
    final sorted = completed.toList()..sort();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert({'completed': sorted}));
  }
}

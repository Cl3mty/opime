import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'project_models.dart';

/// Persiste les projets réels de l'utilisateur — même pattern que
/// [LiabilitiesRepository] (`features/liabilities/liabilities_repository.dart`) :
/// un fichier JSON unique sous le dossier du profil, réécrit en entier à
/// chaque sauvegarde.
class ProjectRepository {
  final String vaultPath;
  ProjectRepository(this.vaultPath);

  File get _file => File(p.join(vaultPath, 'projets', 'projets.json'));

  Future<void> _ensureDir() async {
    final dir = Directory(p.join(vaultPath, 'projets'));
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  Future<List<Project>> _readAll() async {
    if (!await _file.exists()) return [];
    final content = await _file.readAsString();
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<Project> all) async {
    await _ensureDir();
    final jsonList = all.map((project) => project.toJson()).toList();
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
  }

  Future<List<Project>> listAll() => _readAll();

  Future<Project?> find(String id) async {
    final all = await _readAll();
    for (final project in all) {
      if (project.id == id) return project;
    }
    return null;
  }

  /// Ajoute un nouveau projet, ou remplace un projet existant de même id.
  Future<void> saveProject(Project project) async {
    final all = await _readAll();
    final idx = all.indexWhere((p) => p.id == project.id);
    if (idx == -1) {
      all.add(project);
    } else {
      all[idx] = project;
    }
    await _writeAll(all);
  }

  Future<void> deleteProject(String id) async {
    final all = await _readAll();
    all.removeWhere((project) => project.id == id);
    await _writeAll(all);
  }
}

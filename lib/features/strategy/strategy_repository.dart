import 'dart:io';
import 'package:path/path.dart' as p;

class StrategyNote {
  final String id;
  final String title;
  final DateTime updatedAt;
  final DateTime createdAt;

  StrategyNote({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.createdAt,
  });
}

class StrategyRepository {
  final String vaultPath;
  StrategyRepository(this.vaultPath);

  Directory get _dir => Directory(p.join(vaultPath, 'strategy'));

  Future<void> _ensureDir() async {
    try {
      if (!await _dir.exists()) {
        await _dir.create(recursive: true);
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('ERREUR création dossier strategy: $e');
      // ignore: avoid_print
      print(st);
      rethrow;
    }
  }

  /// Notes "modèle" créées au tout premier passage dans l'onglet
  /// Stratégie, pour inciter un nouvel utilisateur à prendre des notes :
  /// chacune ne contient qu'un emoji et un titre.
  static const List<(String, String)> _templateNotes = [
    ('👀', 'Watchlist'),
    ('💡', 'Thèse d\'investissement'),
    ('♟️', 'Stratégie'),
    ('🎯', 'Objectifs'),
    ('✅', 'Checklist'),
  ];

  String _titleFromMarkdown(String markdown) {
    final firstLine = markdown
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Nouvelle note');
    return firstLine.replaceFirst(RegExp(r'^#+\s*'), '').trim().isEmpty
        ? 'Nouvelle note'
        : firstLine.replaceFirst(RegExp(r'^#+\s*'), '').trim();
  }

  /// L'id est un timestamp de création (millisecondsSinceEpoch). On s'en sert
  /// comme clé de tri stable, plutôt que la date de modification du fichier
  /// (qui change à chaque autosave et ferait "sauter" les notes dans la liste).
  DateTime _createdAtFromId(String id) {
    final millis = int.tryParse(id);
    return millis != null
        ? DateTime.fromMillisecondsSinceEpoch(millis)
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<List<StrategyNote>> listNotes() async {
    await _ensureDir();
    final files = await _dir
        .list()
        .where((e) => e is File && e.path.endsWith('.md'))
        .cast<File>()
        .toList();
    final notes = <StrategyNote>[];
    for (final f in files) {
      final content = await f.readAsString();
      final stat = await f.stat();
      final id = p.basenameWithoutExtension(f.path);
      notes.add(
        StrategyNote(
          id: id,
          title: _titleFromMarkdown(content),
          updatedAt: stat.modified,
          createdAt: _createdAtFromId(id),
        ),
      );
    }
    // Tri stable : plus récent (par création) en haut, ne bouge pas au clic/édition.
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }

  Future<String> readNote(String id) async {
    final file = File(p.join(_dir.path, '$id.md'));
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  Future<void> writeNote(String id, String markdown) async {
    await _ensureDir();
    final file = File(p.join(_dir.path, '$id.md'));
    await file.writeAsString(markdown);
  }

  /// Crée les notes "modèle" au tout premier passage dans l'onglet
  /// Stratégie, puis ne fait plus rien ensuite — même si l'utilisateur
  /// supprime ensuite toutes ses notes (marqueur `.templates_created`
  /// dans le dossier strategy). Retourne `true` si les notes ont été
  /// créées, `false` si elles existent déjà.
  Future<bool> createTemplatesIfFirstVisit() async {
    await _ensureDir();
    final marker = File(p.join(_dir.path, '.templates_created'));
    if (await marker.exists()) return false;

    // Plusieurs notes sont créées quasi dans la même milliseconde : on
    // incrémente l'id (timestamp) pour garantir leur unicité.
    final baseMillis = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _templateNotes.length; i++) {
      final (emoji, title) = _templateNotes[i];
      final id = (baseMillis + i).toString();
      await writeNote(id, '# $emoji $title\n');
    }
    await marker.writeAsString(DateTime.now().toIso8601String());
    return true;
  }

  Future<StrategyNote> createNote() async {
    await _ensureDir();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await writeNote(id, '# Nouvelle note\n');
    final now = DateTime.now();
    return StrategyNote(
      id: id,
      title: 'Nouvelle note',
      updatedAt: now,
      createdAt: now,
    );
  }

  Future<void> deleteNote(String id) async {
    final file = File(p.join(_dir.path, '$id.md'));
    if (await file.exists()) await file.delete();
  }
}

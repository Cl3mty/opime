import 'package:flutter/foundation.dart';

import 'academy_progress_repository.dart';

/// Suit les notions de l'Académie marquées comme acquises par le compte actif.
class AcademyProgressController extends ChangeNotifier {
  final AcademyProgressRepository repository;
  AcademyProgressController(this.repository);

  Set<String> _completed = {};

  Future<void> load() async {
    _completed = await repository.read();
    notifyListeners();
  }

  bool isCompleted(String id) => _completed.contains(id);

  int completedCountAmong(Iterable<String> ids) =>
      ids.where(_completed.contains).length;

  Future<void> setCompleted(String id, bool value) async {
    final changed = value ? _completed.add(id) : _completed.remove(id);
    if (!changed) return;
    notifyListeners();
    await repository.write(_completed);
  }

  Future<void> toggle(String id) => setCompleted(id, !isCompleted(id));
}

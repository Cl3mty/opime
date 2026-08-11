import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'profile_controller.dart';

/// Gère, pour chaque compte, la liste des clés de navigation (postes Actifs /
/// Passifs) que l'utilisateur a choisi de masquer dans sa sidebar. Une seule
/// instance vit pour toute la durée de l'app ; elle garde un petit cache en
/// mémoire par id de compte pour ne pas avoir à recharger à chaque bascule.
class SidebarPrefsController extends ChangeNotifier {
  final ProfileController profileController;
  SidebarPrefsController(this.profileController);

  final Map<String, Set<String>> _cache = {};

  File _fileFor(String profileId) => File(
    p.join(
      profileController.repository.pathFor(profileId),
      'sidebar_prefs.json',
    ),
  );

  /// Clés actuellement masquées pour ce compte (vide si jamais chargé/aucune préférence).
  Set<String> hiddenKeysFor(String profileId) => _cache[profileId] ?? const {};

  Future<void> loadFor(String profileId) async {
    if (_cache.containsKey(profileId)) return; // déjà en cache
    final file = _fileFor(profileId);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final keys = (json['hiddenKeys'] as List? ?? [])
            .map((e) => e as String)
            .toSet();
        _cache[profileId] = keys;
      } catch (_) {
        _cache[profileId] = {};
      }
    } else {
      _cache[profileId] = {};
    }
    notifyListeners();
  }

  Future<void> setHidden(String profileId, String key, bool hidden) async {
    final current = {...(_cache[profileId] ?? const {})};
    if (hidden) {
      current.add(key);
    } else {
      current.remove(key);
    }
    _cache[profileId] = current;
    notifyListeners();
    await _save(profileId, current);
  }

  Future<void> _save(String profileId, Set<String> keys) async {
    final file = _fileFor(profileId);
    final dir = file.parent;
    if (!await dir.exists()) await dir.create(recursive: true);
    await file.writeAsString(jsonEncode({'hiddenKeys': keys.toList()}));
  }
}

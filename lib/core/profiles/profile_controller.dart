import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_models.dart';
import 'profile_repository.dart';

class ProfileController extends ChangeNotifier {
  final ProfileRepository repository;
  ProfileController(this.repository);

  static const _activeIdKey = 'active_profile_id';

  List<Profile> profiles = [];
  Profile? active;
  bool loading = true;

  Future<void> load() async {
    profiles = await repository.listAll();
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_activeIdKey);
    active = _findOrMaster(savedId);
    loading = false;
    notifyListeners();
  }

  Profile? _findOrMaster(String? id) {
    if (id != null) {
      for (final p in profiles) {
        if (p.id == id) return p;
      }
    }
    for (final p in profiles) {
      if (p.isMaster) return p;
    }
    return profiles.firstOrNull;
  }

  Future<void> switchTo(String id) async {
    Profile? found;
    for (final p in profiles) {
      if (p.id == id) found = p;
    }
    if (found == null) return;
    active = found;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeIdKey, id);
    notifyListeners();
  }

  Future<void> createProfile({
    required String name,
    required String relationship,
  }) async {
    final profile = await repository.create(
      name: name,
      relationship: relationship,
    );
    profiles = await repository.listAll();
    await switchTo(profile.id);
  }

  Future<void> renameProfile(
    String id, {
    required String name,
    required String relationship,
  }) async {
    await repository.rename(id, name: name, relationship: relationship);
    profiles = await repository.listAll();
    active = _findOrMaster(active?.id);
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    final wasActive = active?.id == id;
    await repository.delete(id);
    profiles = await repository.listAll();
    if (wasActive) {
      active = _findOrMaster(null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeIdKey, active!.id);
    }
    notifyListeners();
  }

  String get activeDataPath => repository.pathFor(active!.id);
}

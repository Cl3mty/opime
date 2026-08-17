import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../storage/vault_crypto.dart' show VaultCipher;
import '../storage/vault_session.dart';
import '../storage/vault_file_storage.dart';
import 'profile_models.dart';

const String masterProfileId = 'master';

class ProfileRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  /// [cipher] : `null` sur un vault en clair (comportement inchangé), une
  /// [VaultCipher] déverrouillée sur un vault chiffré — voir
  /// `vault_file_storage.dart`. `profiles.json` porte les noms des membres
  /// de la famille suivis dans ce vault, une donnée privée.
  ProfileRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  static const _profilesRelativePath = 'profiles.json';

  String pathFor(String profileId) => p.join(vaultPath, 'profiles', profileId);

  Future<List<Profile>> listAll() async {
    await _migrateLegacyDataIfNeeded();

    if (!await _storage.exists(_profilesRelativePath)) {
      final master = Profile(
        id: masterProfileId,
        name: 'Moi',
        relationship: 'Vous',
        isMaster: true,
        createdAt: DateTime.now().toUtc(),
      );
      await _writeAll([master]);
      await _ensureProfileFolder(master.id);
      return [master];
    }

    final content = await _storage.readString(_profilesRelativePath);
    if (content.trim().isEmpty) {
      // Un profiles.json existant mais vide n'est jamais un état légitime
      // (on n'écrit jamais un tableau vide nous-mêmes) : c'est le signe
      // d'un dossier Vault synchronisé (iCloud Drive...) pas encore
      // totalement téléchargé sur cet appareil. Le traiter comme "aucun
      // profil" écraserait silencieusement les vrais profils au prochain
      // appel de create()/rename() : on préfère un échec explicite,
      // rattrapable par l'appelant, plutôt qu'une perte de données.
      throw StateError(
        'profiles.json existe mais est vide : le dossier Vault est peut-être '
        'encore en cours de synchronisation.',
      );
    }
    final list = jsonDecode(content) as List;
    return list
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<Profile> profiles) async {
    await _storage.writeString(
      _profilesRelativePath,
      const JsonEncoder.withIndent(
        '  ',
      ).convert(profiles.map((p) => p.toJson()).toList()),
    );
  }

  Future<Profile> create({
    required String name,
    required String relationship,
  }) async {
    final all = await listAll();
    final profile = Profile(
      id: const Uuid().v4(),
      name: name,
      relationship: relationship,
      isMaster: false,
      createdAt: DateTime.now().toUtc(),
    );
    all.add(profile);
    await _writeAll(all);
    await _ensureProfileFolder(profile.id);
    return profile;
  }

  Future<void> rename(
    String id, {
    required String name,
    required String relationship,
  }) async {
    final all = await listAll();
    final idx = all.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    all[idx] = all[idx].copyWith(name: name, relationship: relationship);
    await _writeAll(all);
  }

  Future<void> delete(String id) async {
    final all = await listAll();
    all.removeWhere((p) => p.id == id && !p.isMaster);
    await _writeAll(all);
  }

  Future<void> _ensureProfileFolder(String id) async {
    final dir = Directory(pathFor(id));
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  Future<void> _migrateLegacyDataIfNeeded() async {
    if (await _storage.exists(_profilesRelativePath)) return;

    final masterDir = Directory(pathFor(masterProfileId));
    var hasLegacyData = false;
    for (final folderName in ['strategy', 'budget']) {
      final legacy = Directory(p.join(vaultPath, folderName));
      if (await legacy.exists()) hasLegacyData = true;
    }
    if (!hasLegacyData) return;

    if (!await masterDir.exists()) await masterDir.create(recursive: true);
    for (final folderName in ['strategy', 'budget']) {
      final legacy = Directory(p.join(vaultPath, folderName));
      if (await legacy.exists()) {
        final target = Directory(p.join(masterDir.path, folderName));
        await _moveDirectoryContents(legacy, target);
      }
    }
  }

  Future<void> _moveDirectoryContents(
    Directory source,
    Directory target,
  ) async {
    if (!await target.exists()) await target.create(recursive: true);
    await for (final entity in source.list()) {
      final newPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        try {
          await entity.rename(newPath);
        } catch (_) {
          final bytes = await entity.readAsBytes();
          await File(newPath).writeAsBytes(bytes);
          await entity.delete();
        }
      }
    }
    try {
      await source.delete(recursive: true);
    } catch (_) {}
  }
}

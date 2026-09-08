import 'dart:convert';

import 'package:path/path.dart' as p;

import '../storage/vault_crypto.dart' show VaultCipher;
import '../storage/vault_session.dart';
import '../storage/vault_file_storage.dart';

class SimulationStateRepository {
  final String profileDataPath;
  late final VaultFileStorage _storage;

  SimulationStateRepository(this.profileDataPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: profileDataPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  String _relativePathFor(String key) => p.join('simulations', '$key.json');

  Future<Map<String, dynamic>> read(String key) async {
    final relativePath = _relativePathFor(key);
    if (!await _storage.exists(relativePath)) return {};

    try {
      final content = await _storage.readString(relativePath);
      if (content.trim().isEmpty) return {};
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> write(String key, Map<String, dynamic> data) =>
      _storage.writeString(
        _relativePathFor(key),
        const JsonEncoder.withIndent('  ').convert(data),
      );

  Future<void> delete(String key) => _storage.delete(_relativePathFor(key));
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'vault_encryption_metadata.dart';

/// Lit/écrit `<vault>/.opime/vault_encryption.json` — le fichier de
/// métadonnées de chiffrement, dans le sous-dossier de configuration
/// réservé (voir `vault_folder_service.dart`'s `_configSubfolderName`).
/// Toujours en clair : ce fichier doit rester lisible pour même *tenter*
/// un déverrouillage — pas de [VaultFileStorage] ici, un simple
/// `dart:io` direct comme le reste de la configuration logicielle.
class VaultEncryptionRepository {
  final String vaultPath;
  const VaultEncryptionRepository(this.vaultPath);

  File get _file => File(p.join(vaultPath, '.opime', 'vault_encryption.json'));

  /// `null` si le fichier n'existe pas (vault jamais chiffré) ou est
  /// illisible/corrompu — dans les deux cas, l'appelant doit traiter le
  /// vault comme non chiffré plutôt que de bloquer l'accès.
  Future<VaultEncryptionMetadata?> load() async {
    if (!await _file.exists()) return null;
    try {
      final content = await _file.readAsString();
      if (content.trim().isEmpty) return null;
      return VaultEncryptionMetadata.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(VaultEncryptionMetadata metadata) async {
    final dir = _file.parent;
    if (!await dir.exists()) await dir.create(recursive: true);
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
    );
  }

  Future<void> delete() async {
    if (await _file.exists()) await _file.delete();
  }
}

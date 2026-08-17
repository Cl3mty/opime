import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Marqueur écrit avant toute migration chiffrer/déchiffrer-en-place (voir
/// `VaultEncryptionMigrationService`) et supprimé seulement une fois cette
/// migration intégralement terminée. Toujours en clair, hors du périmètre
/// du chiffrement (comme `vault_encryption.json`) : il doit rester lisible
/// même si l'app vient d'être tuée en plein milieu d'une opération.
///
/// Sans ce marqueur, une migration interrompue (app fermée avant la fin)
/// laisse le vault dans un état mixte — certains fichiers déjà réécrits
/// sous la nouvelle clé, d'autres encore sous l'ancienne — indétectable
/// jusqu'à ce qu'un fichier précis échoue au déchiffrement, bien plus tard
/// et sans lien évident avec sa cause réelle (voir `main.dart`'s
/// `_buildHome`, qui bloque tant que ce marqueur existe plutôt que de
/// charger silencieusement un vault potentiellement incohérent).
class VaultMigrationMarker {
  VaultMigrationMarker._();

  static String _path(String vaultPath) =>
      p.join(vaultPath, '.opime', 'migration_in_progress.json');

  static Future<void> write(String vaultPath, {required String operation}) async {
    final file = File(_path(vaultPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'operation': operation,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  static Future<void> clear(String vaultPath) async {
    final file = File(_path(vaultPath));
    if (await file.exists()) await file.delete();
  }

  static Future<bool> exists(String vaultPath) =>
      File(_path(vaultPath)).exists();
}

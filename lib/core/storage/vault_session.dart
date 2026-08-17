import 'vault_crypto.dart' show VaultCipher;

/// Porte le [VaultCipher] du vault déverrouillé pour la durée du process —
/// un seul vault actif à la fois dans l'app, donc un simple holder global
/// plutôt que de faire traverser la clé à travers des dizaines de sites de
/// construction de repository (`XxxRepository(vaultPath)`, inchangés par
/// ailleurs) : chaque repository privé (voir `vault_file_storage.dart`)
/// retombe sur [VaultSession.current] quand aucune clé n'est passée
/// explicitement à son constructeur.
///
/// Jamais persisté (ni sur disque, ni dans `shared_preferences`) : posé une
/// fois au déverrouillage (voir `main.dart`), effacé à la fermeture du
/// vault (`_resetVault`) — le mot de passe est donc bien redemandé à
/// chaque lancement de l'app, comme voulu.
class VaultSession {
  VaultSession._();

  static VaultCipher? current;

  /// Chemin du vault auquel appartient [current] — permet à `main.dart`'s
  /// `_initProfiles` de détecter un changement de vault (ex : bouton
  /// "Changer de dossier de vault") et d'invalider une clé devenue obsolète
  /// avant de construire les repositories du nouveau vault, plutôt que de
  /// risquer de (dé)chiffrer ses fichiers avec la clé de l'ancien.
  static String? vaultPath;
}

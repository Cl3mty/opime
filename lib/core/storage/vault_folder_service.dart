import 'dart:convert';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import 'vault_fs.dart';

/// Web uniquement : où sont réellement stockées les données d'un
/// coffre-fort web. Sans objet sur desktop (toujours un vrai dossier
/// disque) — un `SavedVault` desktop garde la valeur par défaut
/// [standard] sans jamais la lire.
enum VaultStorage {
  /// Zone privée du navigateur (OPFS, voir `vault_fs_web.dart`) — valeur par
  /// défaut historique de tous les coffres-forts web créés avant l'ajout du
  /// choix [webLocalFolder] ci-dessous, donc aussi le repli d'un JSON
  /// n'ayant pas encore ce champ.
  standard,

  /// Vrai dossier du disque de l'utilisateur, choisi via l'API File System
  /// Access (`showDirectoryPicker`) — peut être synchronisé par Google
  /// Drive Desktop, iCloud Drive, Dropbox... exactement comme un vault
  /// desktop, mais depuis le navigateur. Nécessite de redemander la
  /// permission au navigateur à chaque nouvelle session (voir
  /// `VaultFolderService.activeVaultNeedsReauthorization`).
  webLocalFolder;

  static VaultStorage fromName(String? name) => VaultStorage.values.firstWhere(
    (s) => s.name == name,
    orElse: () => VaultStorage.standard,
  );
}

class SavedVault {
  final String id;
  final String name;
  final String vaultPath;
  final String? bookmarkData;
  final bool bookmarkTargetsVault;
  final VaultStorage storage;

  const SavedVault({
    required this.id,
    required this.name,
    required this.vaultPath,
    this.bookmarkData,
    required this.bookmarkTargetsVault,
    this.storage = VaultStorage.standard,
  });

  SavedVault copyWith({
    String? id,
    String? name,
    String? vaultPath,
    Object? bookmarkData = _missingBookmarkData,
    bool? bookmarkTargetsVault,
    VaultStorage? storage,
  }) {
    return SavedVault(
      id: id ?? this.id,
      name: name ?? this.name,
      vaultPath: vaultPath ?? this.vaultPath,
      bookmarkData: identical(bookmarkData, _missingBookmarkData)
          ? this.bookmarkData
          : bookmarkData as String?,
      bookmarkTargetsVault: bookmarkTargetsVault ?? this.bookmarkTargetsVault,
      storage: storage ?? this.storage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'vaultPath': vaultPath,
    'bookmarkData': bookmarkData,
    'bookmarkTargetsVault': bookmarkTargetsVault,
    'storage': storage.name,
  };

  factory SavedVault.fromJson(Map<String, dynamic> json) => SavedVault(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Coffre-fort',
    vaultPath: json['vaultPath'] as String,
    bookmarkData: json['bookmarkData'] as String?,
    bookmarkTargetsVault: json['bookmarkTargetsVault'] as bool? ?? false,
    storage: VaultStorage.fromName(json['storage'] as String?),
  );
}

class _PickedVault {
  final String vaultPath;
  final String? bookmarkData;
  final bool bookmarkTargetsVault;

  const _PickedVault({
    required this.vaultPath,
    required this.bookmarkData,
    required this.bookmarkTargetsVault,
  });
}

const _missingBookmarkData = Object();

class VaultFolderService {
  static const _vaultsKey = 'saved_vaults_json';
  static const _activeVaultIdKey = 'active_vault_id';
  static const _pathKey = 'vault_folder_path';
  static const _bookmarkKey = 'vault_folder_bookmark';
  static const _channel = MethodChannel('com.opime/secure_bookmarks');

  /// Nom du dossier vault. Un vault `.freenary` créé avant le rebranding
  /// Freenary → Opime n'est plus reconnu. Visible (`Opime`) depuis la
  /// migration de renommage (voir [_migrateVaultFolderNameIfNeeded]) — les
  /// vaults `.opime` (caché) créés avant cette migration restent reconnus
  /// et renommés automatiquement, [_legacyHiddenVaultFolderName].
  static const _vaultFolderName = 'Opime';
  static const _legacyHiddenVaultFolderName = '.opime';

  /// Sous-dossier caché réservé, à l'intérieur du vault, à la
  /// configuration logicielle (distincte des données utilisateur portées
  /// par le reste du vault) — pas encore utilisé par une fonctionnalité,
  /// mais créé dès maintenant (nouveau vault ou migration) pour que le nom
  /// soit déjà pris et cohérent d'une installation à l'autre.
  static const _configSubfolderName = '.opime';

  /// Le nom de dossier [name] correspond-il déjà à un vault (actuel `Opime`
  /// ou ancien nom caché `.opime`) plutôt qu'à un simple dossier PARENT
  /// dans lequel il faudrait en créer/trouver un ? Logique pure, partagée
  /// par le sélecteur de dossier natif desktop ([_pickVaultFolder]) et le
  /// sélecteur de dossier local web ([pickAndCreateWebLocalFolderVault]) —
  /// sans elle, sélectionner directement le dossier `Opime` d'un vault
  /// existant (au lieu de son dossier PARENT) créait un sous-dossier
  /// `Opime/Opime` vide et l'utilisait à la place du vrai vault, qui
  /// semblait alors vide à tort (constaté sur la variante web : voir son
  /// commentaire pour le détail du bug).
  static bool isExistingVaultFolderName(String name) =>
      name == _vaultFolderName || name == _legacyHiddenVaultFolderName;

  /// Vrai si la dernière résolution d'un coffre-fort actif (voir
  /// [_resolveAccessibleVault], appelée par [getActiveVault]/
  /// [setActiveVault]) a trouvé un dossier local (voir [VaultStorage
  /// .webLocalFolder]) dont la permission navigateur a expiré — à consulter
  /// juste après un appel à [getActiveVault] (voir `main.dart`'s
  /// `_initProfiles`), avant toute tentative de lecture des données, sans
  /// quoi elles échoueraient silencieusement contre une racine de stockage
  /// non rebasculée (voir [reauthorizeActiveVault]).
  bool _lastActivationNeededReauth = false;
  bool get activeVaultNeedsReauthorization => _lastActivationNeededReauth;

  /// Le sélecteur de dossier local (API File System Access) est-il
  /// disponible dans ce navigateur ? Toujours `false` sur desktop, qui a
  /// déjà son propre sélecteur natif — voir [supportsLocalFolderPicker]
  /// (`vault_fs.dart`).
  bool get supportsWebLocalFolder => kIsWeb && supportsLocalFolderPicker;

  Future<String?> getSavedVaultPath() async {
    final activeVault = await getActiveVault();
    return activeVault?.vaultPath;
  }

  Future<List<SavedVault>> listVaults() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyVaultIfNeeded(prefs);
    await _migrateVaultFolderNameIfNeeded(prefs);
    final raw = prefs.getString(_vaultsKey);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SavedVault.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<SavedVault?> getActiveVault() async {
    final prefs = await SharedPreferences.getInstance();
    final vaults = await listVaults();
    if (vaults.isEmpty) return null;

    final activeId = prefs.getString(_activeVaultIdKey);
    var activeVault = vaults.where((vault) => vault.id == activeId).firstOrNull;
    activeVault ??= vaults.first;
    if (activeId != activeVault.id) {
      await prefs.setString(_activeVaultIdKey, activeVault.id);
    }

    return _resolveAccessibleVault(activeVault);
  }

  Future<SavedVault?> setActiveVault(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final vaults = await listVaults();
    final vault = vaults.where((entry) => entry.id == id).firstOrNull;
    if (vault == null) return null;
    await prefs.setString(_activeVaultIdKey, id);
    return _resolveAccessibleVault(vault);
  }

  Future<void> renameVault(String id, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final vaults = await listVaults();
    final updated = [
      for (final vault in vaults)
        if (vault.id == id) vault.copyWith(name: trimmedName) else vault,
    ];
    await _saveVaults(updated);
  }

  Future<SavedVault?> forgetVault(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final vaults = await listVaults();
    final target = vaults.where((vault) => vault.id == id).firstOrNull;
    final remaining = vaults.where((vault) => vault.id != id).toList();
    await _saveVaults(remaining);

    if (kIsWeb && target?.storage == VaultStorage.webLocalFolder) {
      // Nettoyage best-effort du handle IndexedDB : ce coffre-fort n'a plus
      // de `SavedVault`, donc plus personne ne relira jamais cette entrée,
      // mais autant ne pas la laisser traîner indéfiniment.
      await forgetLocalFolderRoot(id);
    }

    if (remaining.isEmpty) {
      await prefs.remove(_activeVaultIdKey);
      return null;
    }

    final activeId = prefs.getString(_activeVaultIdKey);
    final nextVault =
        remaining.where((vault) => vault.id == activeId).firstOrNull ??
        remaining.first;
    await prefs.setString(_activeVaultIdKey, nextVault.id);
    return _resolveAccessibleVault(nextVault);
  }

  Future<SavedVault?> pickAndRememberVault({
    String? dialogTitle,
    String? currentVaultPath,
    void Function(int copied, int total)? onMigrationProgress,
    String? name,
  }) async {
    final picked = await _pickVaultFolder(
      dialogTitle: dialogTitle,
      currentVaultPath: currentVaultPath,
      onMigrationProgress: onMigrationProgress,
      name: name,
    );
    if (picked == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final vaults = await listVaults();
    final existing = vaults
        .where((vault) => p.equals(vault.vaultPath, picked.vaultPath))
        .firstOrNull;
    if (existing != null) {
      await prefs.setString(_activeVaultIdKey, existing.id);
      return _resolveAccessibleVault(existing);
    }

    final savedVault = SavedVault(
      id: const Uuid().v4(),
      name: _effectiveVaultName(name, picked.vaultPath),
      vaultPath: picked.vaultPath,
      bookmarkData: picked.bookmarkData,
      bookmarkTargetsVault: picked.bookmarkTargetsVault,
    );
    await _saveVaults([...vaults, savedVault]);
    await prefs.setString(_activeVaultIdKey, savedVault.id);
    return savedVault;
  }

  /// Sélectionne un nouveau dossier de données.
  ///
  /// - Le dialogue demande normalement le dossier **parent** où sera créé
  ///   `Opime` (voir [_vaultFolderName]).
  /// - Protection : si l'utilisateur sélectionne directement un dossier déjà
  ///   nommé `Opime` ou `.opime` (erreur de manipulation fréquente, ou ancien
  ///   vault), on l'utilise tel quel comme vault au lieu d'en créer un autre
  ///   dedans — un `.opime` sélectionné ainsi est renommé en `Opime`.
  /// - Si le vault résultant existe déjà, on le charge tel quel (aucune
  ///   copie). Sinon, si [currentVaultPath] est fourni, on migre les
  ///   données existantes vers le nouvel emplacement.
  Future<String?> pickAndCreateVaultFolder({
    String? dialogTitle,
    String? currentVaultPath,
    void Function(int copied, int total)? onMigrationProgress,
    String? name,
  }) async {
    final vault = await pickAndRememberVault(
      dialogTitle: dialogTitle,
      currentVaultPath: currentVaultPath,
      onMigrationProgress: onMigrationProgress,
      name: name,
    );
    return vault?.vaultPath;
  }

  /// Web uniquement : crée (ou charge, si le dossier choisi est déjà un
  /// coffre-fort — voir plus bas) un coffre-fort adossé à un vrai dossier
  /// du disque de l'utilisateur (choisi via `showDirectoryPicker` — voir
  /// [supportsWebLocalFolder]) plutôt qu'à la zone privée du navigateur
  /// (OPFS, voir [_pickVaultFolderWeb]) : ce dossier peut lui-même être
  /// synchronisé par Google Drive Desktop, iCloud Drive, Dropbox...
  /// exactement comme un vault desktop. `null` si l'utilisateur annule le
  /// sélecteur. [name] prime sur le nom réel du dossier choisi s'il est
  /// renseigné ; sinon ce dernier sert de nom affiché par défaut.
  ///
  /// Comme sur desktop (voir [_pickVaultFolder]'s `selectedIsAlreadyVault`) :
  /// si le dossier choisi est déjà nommé `Opime` (ou l'ancien nom caché
  /// `.opime`), c'est déjà le vault lui-même — pas question d'en créer un
  /// second, vide, À L'INTÉRIEUR. Sans ce garde-fou, sélectionner
  /// directement le dossier `Opime` d'un vault existant (au lieu de son
  /// dossier PARENT, ce que l'app ne peut pas deviner à l'avance) créait un
  /// sous-dossier `Opime/Opime` vide et l'utilisait à la place du vrai
  /// vault — qui semblait alors vide à tort, alors que ses données étaient
  /// toujours là, juste un niveau au-dessus.
  Future<SavedVault?> pickAndCreateWebLocalFolderVault({String? name}) async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Réservé au web — voir pickAndCreateVaultFolder sur desktop.',
      );
    }
    // Généré AVANT le sélecteur plutôt qu'après : sert à la fois de future
    // `SavedVault.id` et de clé IndexedDB sous laquelle le handle choisi
    // est immédiatement persisté (voir `vault_fs_web.dart`'s
    // `pickLocalFolderRoot`) — les deux doivent rester le même identifiant.
    final id = const Uuid().v4();
    final folderName = await pickLocalFolderRoot(id);
    if (folderName == null) return null;

    final selectedIsAlreadyVault = isExistingVaultFolderName(folderName);
    final vaultDir = selectedIsAlreadyVault
        ? VaultDirectory('/')
        : VaultDirectory('/$_vaultFolderName');
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    final configDir = VaultDirectory(
      p.join(vaultDir.path, _configSubfolderName),
    );
    if (!await configDir.exists()) await configDir.create(recursive: true);

    final savedVault = SavedVault(
      id: id,
      name: (name?.trim().isNotEmpty ?? false) ? name!.trim() : folderName,
      vaultPath: vaultDir.path,
      bookmarkTargetsVault: false,
      storage: VaultStorage.webLocalFolder,
    );
    final prefs = await SharedPreferences.getInstance();
    final vaults = await listVaults();
    await _saveVaults([...vaults, savedVault]);
    await prefs.setString(_activeVaultIdKey, savedVault.id);
    return savedVault;
  }

  /// Web uniquement : redemande la permission sur le dossier du coffre-fort
  /// actif — DOIT être appelée depuis un geste utilisateur direct (ex.
  /// `onPressed` d'un bouton, voir `LocalFolderReauthScreen`), le navigateur
  /// rejette silencieusement l'appel sinon. Renvoie `true` si l'accès a été
  /// retrouvé, auquel cas [activeVaultNeedsReauthorization] repasse à
  /// `false`.
  Future<bool> reauthorizeActiveVault() async {
    final vault = await getActiveVault();
    if (vault == null || vault.storage != VaultStorage.webLocalFolder) {
      return false;
    }
    final ok = await reauthorizeLocalFolderRoot(vault.id);
    if (ok) _lastActivationNeededReauth = false;
    return ok;
  }

  Future<_PickedVault?> _pickVaultFolder({
    String? dialogTitle,
    String? currentVaultPath,
    void Function(int copied, int total)? onMigrationProgress,
    String? name,
  }) async {
    // Web : pas de sélecteur de vrai dossier au premier jalon (File System
    // Access = jalon 2) — le « coffre-fort » est un dossier virtuel sous
    // OPFS, nommé explicitement (voir `_pickVaultFolderWeb` et
    // `OnboardingScreen`).
    if (kIsWeb) return _pickVaultFolderWeb(name);

    String result;
    String? iosBookmarkData;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // file_picker ne renvoie sur iOS qu'un chemin texte brut : l'URL du
      // UIDocumentPickerViewController système a déjà perdu son "security
      // scope" au moment où on la reconstruit nous-mêmes pour créer un
      // bookmark, ce qui échoue silencieusement sur un vrai appareil (le
      // simulateur n'applique pas le bac à sable de la même façon, d'où
      // l'illusion que ça fonctionnait). Notre propre picker natif
      // (voir AppDelegate.swift) garde l'URL scopée assez longtemps pour
      // créer le bookmark dessus directement et nous renvoie les deux.
      final picked = await _channel.invokeMapMethod<String, dynamic>(
        'pickFolder',
      );
      if (picked == null) return null;
      final path = picked['path'] as String?;
      if (path == null) return null;
      result = path;
      iosBookmarkData = picked['bookmarkData'] as String?;
    } else {
      final picked = await FilePicker.getDirectoryPath(
        dialogTitle: dialogTitle,
      );
      if (picked == null) return null;
      result = picked;
    }

    final selectedIsAlreadyVault = isExistingVaultFolderName(p.basename(result));
    var vaultDir = selectedIsAlreadyVault
        ? VaultDirectory(result)
        : VaultDirectory(p.join(result, _vaultFolderName));
    final alreadyExists = await vaultDir.exists();

    if (!alreadyExists) {
      await vaultDir.create(recursive: true);

      if (currentVaultPath != null &&
          !p.equals(currentVaultPath, vaultDir.path)) {
        final oldDir = VaultDirectory(currentVaultPath);
        if (await oldDir.exists()) {
          final total = await _countFiles(oldDir);
          var copied = 0;
          onMigrationProgress?.call(0, total);

          final errors = await _copyDirectoryContents(oldDir, vaultDir, () {
            copied++;
            onMigrationProgress?.call(copied, total);
          });

          if (errors.isNotEmpty) {
            debugPrint(
              'Erreurs de migration (${errors.length} fichier(s) non copiés) :',
            );
            for (final e in errors) {
              debugPrint('  - $e');
            }
          }
        }
      }
    }

    // L'utilisateur a directement sélectionné un ancien dossier `.opime` :
    // le renommer tout de suite en `Opime` avant de créer le bookmark, pour
    // que celui-ci porte sur le chemin définitif plutôt que de dépendre de
    // la survie du bookmark à un renommage qu'on vient de faire nous-mêmes.
    vaultDir = await _ensureModernVaultFolder(vaultDir);
    if (selectedIsAlreadyVault) result = vaultDir.path;

    String? bookmarkData = iosBookmarkData;
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      bookmarkData = await _channel.invokeMethod<String>(
        'createBookmark',
        result,
      );
      if (bookmarkData == null) return null;
    } else if (defaultTargetPlatform == TargetPlatform.iOS &&
        bookmarkData == null) {
      return null;
    }

    return _PickedVault(
      vaultPath: vaultDir.path,
      bookmarkData: bookmarkData,
      bookmarkTargetsVault: selectedIsAlreadyVault,
    );
  }

  /// Assainit [name] pour en faire un **simple nom** de dossier OPFS valide
  /// (utilisé par [_pickVaultFolderWeb]).
  ///
  /// OPFS (`FileSystemDirectoryHandle.getDirectoryHandle`) impose les règles
  /// de nommage du système de fichiers hôte du navigateur — celles de
  /// Windows étant les plus restrictives, un nom acceptable partout en est la
  /// cible. Sans ce nettoyage, un nom saisi (typiquement un "drive" cloud :
  /// `iCloud/`, `..`, `CON`, `A:B`, …) faisait échouer la création du
  /// coffre-fort web avec « Name is not allowed ». Les séparateurs étant
  /// **retirés** (jamais remplacés), le résultat ne contient aucun `/` : un
  /// pur nom de dossier, jamais un chemin. Le nom affiché, lui, garde la
  /// saisie d'origine (voir [`SavedVault.name`]). Retombe sur `Coffre-fort`
  /// si rien ne survit au nettoyage.
  static String sanitizeOpfsFolderName(String name) {
    var out = name;
    out = out.replaceAll(RegExp(r'[/\\]'), '');
    out = out.replaceAll(RegExp(r'[:*?"<>|]'), '');
    out = out.replaceAll(RegExp(r'[\u0000-\u001f]'), '');
    out = out.trim().replaceAll(RegExp(r'[. ]+$'), '');
    const blocked = r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$';
    final ok =
        out.isNotEmpty &&
        out != '.' &&
        out != '..' &&
        !RegExp(blocked, caseSensitive: false).hasMatch(out);
    return ok ? out : 'Coffre-fort';
  }

  /// Web (jalon 1) — chaque utilisateur du navigateur dispose d'un unique
  /// OPFS (`navigator.storage.getDirectory()`), qui joue le rôle du disque
  /// d'une machine : un coffre-fort supplémentaire est donc un sous-chemin
  /// virtuel `/Opime/<nom>/Opime`. Le nom vient de [name] (saisi
  /// explicitement sur l'onboarding web, faute de dialogue de dossier), puis
  /// est assaini pour l'OPFS (voir [sanitizeOpfsFolderName]) — sans cela, un
  /// nom type "drive" saisi à la va-vite (`iCloud/`, `..`, `CON`, …)
  /// échoue par « Name is not allowed ». Sans nom, repli sur
  /// `/Opime/Coffre-fort/Opime` — un second "ajout" sans nom réactivera
  /// alors simplement le même coffre-fort.
  Future<_PickedVault?> _pickVaultFolderWeb(String? name) async {
    final vaultName = sanitizeOpfsFolderName(
      (name?.trim().isNotEmpty ?? false) ? name!.trim() : 'Coffre-fort',
    );
    final root = VaultDirectory(
      p.join('/Opime', vaultName),
    );
    final vaultDir = VaultDirectory(p.join(root.path, _vaultFolderName));
    await vaultDir.create(recursive: true);
    final configDir = VaultDirectory(
      p.join(vaultDir.path, _configSubfolderName),
    );
    if (!await configDir.exists()) await configDir.create(recursive: true);
    return _PickedVault(
      vaultPath: vaultDir.path,
      bookmarkData: null,
      bookmarkTargetsVault: true,
    );
  }

  Future<int> _countFiles(VaultDirectory dir) async {
    var count = 0;
    for (final entity in await dir.list(recursive: true)) {
      if (entity is VaultFile) count++;
    }
    return count == 0 ? 1 : count;
  }

  Future<List<String>> _copyDirectoryContents(
    VaultDirectory source,
    VaultDirectory destination,
    void Function() onFileCopied,
  ) async {
    final errors = <String>[];
    if (!await destination.exists()) await destination.create(recursive: true);

    for (final entity in await source.list()) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      try {
        if (entity is VaultDirectory) {
          errors.addAll(
            await _copyDirectoryContents(
              entity,
              VaultDirectory(newPath),
              onFileCopied,
            ),
          );
        } else if (entity is VaultFile) {
          await entity.copy(newPath);
          onFileCopied();
        }
      } catch (e) {
        errors.add('${entity.path} : $e');
        onFileCopied();
      }
    }
    return errors;
  }

  Future<void> clearSavedVaultPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_vaultsKey);
    await prefs.remove(_activeVaultIdKey);
    await prefs.remove(_pathKey);
    await prefs.remove(_bookmarkKey);
  }

  Future<void> _saveVaults(List<SavedVault> vaults) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _vaultsKey,
      const JsonEncoder.withIndent(
        '  ',
      ).convert(vaults.map((vault) => vault.toJson()).toList()),
    );
  }

  Future<void> _migrateLegacyVaultIfNeeded(SharedPreferences prefs) async {
    if (prefs.containsKey(_vaultsKey)) return;

    String? legacyPath;
    String? legacyBookmarkData;
    var bookmarkTargetsVault = false;

    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      legacyBookmarkData = prefs.getString(_bookmarkKey);
      if (legacyBookmarkData != null) {
        try {
          final parentPath = await _channel.invokeMethod<String>(
            'resolveAndAccess',
            legacyBookmarkData,
          );
          if (parentPath != null) {
            // Un vault pré-multi-vault (avant l'introduction de
            // `saved_vaults_json`) a forcément été créé sous l'ancien nom
            // caché : la migration de renommage (`_migrateVaultFolderNameIfNeeded`,
            // appelée juste après celle-ci dans `listVaults()`) le renommera
            // en `Opime` dans la foulée.
            legacyPath = p.join(parentPath, _legacyHiddenVaultFolderName);
          }
        } catch (_) {}
      }
    } else {
      legacyPath = prefs.getString(_pathKey);
    }

    if (legacyPath == null) return;

    final legacyVault = SavedVault(
      id: const Uuid().v4(),
      name: _effectiveVaultName('Coffre-fort principal', legacyPath),
      vaultPath: legacyPath,
      bookmarkData: legacyBookmarkData,
      bookmarkTargetsVault: bookmarkTargetsVault,
    );
    await _saveVaults([legacyVault]);
    await prefs.setString(_activeVaultIdKey, legacyVault.id);
    await prefs.remove(_pathKey);
    await prefs.remove(_bookmarkKey);
  }

  Future<SavedVault?> _resolveAccessibleVault(SavedVault vault) async {
    if (kIsWeb) {
      if (vault.storage == VaultStorage.webLocalFolder) {
        final restored = await restoreLocalFolderRoot(vault.id);
        // `null` (jamais eu de dossier persistant — ne devrait arriver que
        // si IndexedDB a été vidée) laisse `_lastActivationNeededReauth`
        // sur sa valeur précédente : sans intérêt puisque ce coffre-fort
        // est de toute façon traité comme inaccessible ci-dessous.
        if (restored != null) _lastActivationNeededReauth = !restored;
        if (restored == null) return null;
        // `restored == false` : permission perdue, à redemander via un
        // geste utilisateur (voir `reauthorizeActiveVault`). On renvoie
        // quand même `vault` (plutôt que `null`) pour que `main.dart` sache
        // QUEL coffre-fort a besoin d'être réautorisé au lieu de retomber
        // sur l'onboarding comme s'il n'existait plus — voir
        // `activeVaultNeedsReauthorization`, à vérifier par l'appelant
        // avant toute tentative de lecture.
        return vault;
      }
      _lastActivationNeededReauth = false;
      useOpfsRoot();
      return await VaultDirectory(vault.vaultPath).exists() ? vault : null;
    }

    // `defaultTargetPlatform` reflète le système d'exploitation SOUS le
    // navigateur sur le web (donc potentiellement `macOS`/`iOS` sur un Mac)
    // — le garde `kIsWeb` ci-dessus est indispensable pour ne jamais
    // atteindre le canal natif `_channel` ci-dessous depuis un navigateur,
    // où `MethodChannel` n'a aucune implémentation.
    final isMacIos =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMacIos) {
      return await VaultDirectory(vault.vaultPath).exists() ? vault : null;
    }
    final bookmarkData = vault.bookmarkData;
    if (bookmarkData == null) {
      return await VaultDirectory(vault.vaultPath).exists() ? vault : null;
    }

    try {
      final bookmarkTarget = await _channel.invokeMethod<String>(
        'resolveAndAccess',
        bookmarkData,
      );
      if (bookmarkTarget == null) return null;
      final resolvedVaultPath = vault.bookmarkTargetsVault
          ? bookmarkTarget
          : p.join(bookmarkTarget, p.basename(vault.vaultPath));
      final resolvedVault = vault.copyWith(vaultPath: resolvedVaultPath);
      if (!p.equals(resolvedVault.vaultPath, vault.vaultPath)) {
        final vaults = await listVaults();
        await _saveVaults([
          for (final entry in vaults)
            if (entry.id == resolvedVault.id) resolvedVault else entry,
        ]);
      }
      return await VaultDirectory(resolvedVault.vaultPath).exists()
          ? resolvedVault
          : null;
    } catch (_) {
      return null;
    }
  }

  String _effectiveVaultName(String? explicitName, String vaultPath) {
    final trimmed = explicitName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final base = p.basename(vaultPath);
    if (base == _vaultFolderName || base == _legacyHiddenVaultFolderName) {
      final parent = p.basename(p.dirname(vaultPath));
      if (parent.isNotEmpty && parent != '.') return parent;
    }
    return base.isNotEmpty ? base : 'Coffre-fort';
  }

  /// Renomme un dossier vault encore sous l'ancien nom caché (`.opime`) en
  /// `Opime`, crée le sous-dossier de configuration réservé
  /// ([_configSubfolderName]) s'il manque, et pose (sur macOS, au mieux)
  /// l'icône Opime sur le dossier — utilisé aussi bien à la création d'un
  /// nouveau vault qu'à la migration d'un vault déjà enregistré (voir
  /// [_migrateVaultFolderNameIfNeeded]). Si un dossier `Opime` existe déjà
  /// à l'emplacement cible (cas improbable), l'ancien dossier `.opime` est
  /// laissé tel quel plutôt que de risquer d'écraser des données — il sera
  /// retenté au prochain lancement.
  Future<VaultDirectory> _ensureModernVaultFolder(
    VaultDirectory vaultDir,
  ) async {
    var dir = vaultDir;
    if (p.basename(dir.path) == _legacyHiddenVaultFolderName) {
      final modernPath = p.join(p.dirname(dir.path), _vaultFolderName);
      if (!await VaultDirectory(modernPath).exists()) {
        try {
          dir = (await dir.rename(modernPath)) as VaultDirectory;
        } catch (_) {
          // Renommage impossible (ex. changement de volume) : repli sur une
          // copie intégrale puis suppression de l'original.
          final destination = VaultDirectory(modernPath);
          final errors = await _copyDirectoryContents(dir, destination, () {});
          if (errors.isEmpty) {
            try {
              await dir.delete(recursive: true);
            } catch (_) {}
            dir = destination;
          }
        }
      }
    }

    final configDir = VaultDirectory(p.join(dir.path, _configSubfolderName));
    if (!await configDir.exists()) await configDir.create(recursive: true);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        await _channel.invokeMethod('setFolderIcon', dir.path);
      } catch (_) {
        // Icône décorative uniquement : un échec ne doit jamais bloquer
        // l'accès au vault.
      }
    }

    return dir;
  }

  /// Migre chaque vault enregistré encore sous l'ancien nom caché
  /// (`.opime`) vers le nom moderne (`Opime`) — idempotent (relit
  /// directement `_vaultsKey` plutôt que de passer par [listVaults], pour
  /// éviter la récursion : cette méthode est elle-même appelée depuis
  /// [listVaults]), et tolérant à l'échec par vault (un vault qui ne peut
  /// pas être migré maintenant reste accessible sous son ancien nom, la
  /// migration sera retentée au prochain lancement).
  Future<void> _migrateVaultFolderNameIfNeeded(SharedPreferences prefs) async {
    final raw = prefs.getString(_vaultsKey);
    if (raw == null || raw.trim().isEmpty) return;

    List<SavedVault> vaults;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      vaults = list
          .whereType<Map<String, dynamic>>()
          .map(SavedVault.fromJson)
          .toList();
    } catch (_) {
      return;
    }

    final needsMigration = vaults.any(
      (vault) => p.basename(vault.vaultPath) == _legacyHiddenVaultFolderName,
    );
    if (!needsMigration) return;

    final migrated = <SavedVault>[];
    for (final vault in vaults) {
      if (p.basename(vault.vaultPath) != _legacyHiddenVaultFolderName) {
        migrated.add(vault);
        continue;
      }
      try {
        final dir = await _ensureModernVaultFolder(
          VaultDirectory(vault.vaultPath),
        );
        migrated.add(vault.copyWith(vaultPath: dir.path));
      } catch (_) {
        migrated.add(vault);
      }
    }
    await _saveVaults(migrated);
  }
}

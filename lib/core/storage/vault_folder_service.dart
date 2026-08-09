import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

class SavedVault {
  final String id;
  final String name;
  final String vaultPath;
  final String? bookmarkData;
  final bool bookmarkTargetsVault;

  const SavedVault({
    required this.id,
    required this.name,
    required this.vaultPath,
    this.bookmarkData,
    required this.bookmarkTargetsVault,
  });

  SavedVault copyWith({
    String? id,
    String? name,
    String? vaultPath,
    Object? bookmarkData = _missingBookmarkData,
    bool? bookmarkTargetsVault,
  }) {
    return SavedVault(
      id: id ?? this.id,
      name: name ?? this.name,
      vaultPath: vaultPath ?? this.vaultPath,
      bookmarkData: identical(bookmarkData, _missingBookmarkData)
          ? this.bookmarkData
          : bookmarkData as String?,
      bookmarkTargetsVault: bookmarkTargetsVault ?? this.bookmarkTargetsVault,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'vaultPath': vaultPath,
    'bookmarkData': bookmarkData,
    'bookmarkTargetsVault': bookmarkTargetsVault,
  };

  factory SavedVault.fromJson(Map<String, dynamic> json) => SavedVault(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Vault',
    vaultPath: json['vaultPath'] as String,
    bookmarkData: json['bookmarkData'] as String?,
    bookmarkTargetsVault: json['bookmarkTargetsVault'] as bool? ?? false,
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
  static const _channel = MethodChannel('com.freenary/secure_bookmarks');

  Future<String?> getSavedVaultPath() async {
    final activeVault = await getActiveVault();
    return activeVault?.vaultPath;
  }

  Future<List<SavedVault>> listVaults() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyVaultIfNeeded(prefs);
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
    final remaining = vaults.where((vault) => vault.id != id).toList();
    await _saveVaults(remaining);

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
  ///   `.freenary`.
  /// - Protection : si l'utilisateur sélectionne directement un dossier déjà
  ///   nommé `.freenary` (erreur de manipulation fréquente), on l'utilise
  ///   tel quel comme vault au lieu de créer `.freenary/.freenary` dedans.
  /// - Si le vault résultant existe déjà, on le charge tel quel (aucune
  ///   copie). Sinon, si [currentVaultPath] est fourni, on migre les
  ///   données existantes vers le nouvel emplacement.
  Future<String?> pickAndCreateVaultFolder({
    String? dialogTitle,
    String? currentVaultPath,
    void Function(int copied, int total)? onMigrationProgress,
  }) async {
    final vault = await pickAndRememberVault(
      dialogTitle: dialogTitle,
      currentVaultPath: currentVaultPath,
      onMigrationProgress: onMigrationProgress,
    );
    return vault?.vaultPath;
  }

  Future<_PickedVault?> _pickVaultFolder({
    String? dialogTitle,
    String? currentVaultPath,
    void Function(int copied, int total)? onMigrationProgress,
  }) async {
    String result;
    String? iosBookmarkData;

    if (Platform.isIOS) {
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

    final selectedIsAlreadyVault = p.basename(result) == '.freenary';
    final vaultDir = selectedIsAlreadyVault
        ? Directory(result)
        : Directory(p.join(result, '.freenary'));
    final alreadyExists = await vaultDir.exists();

    if (!alreadyExists) {
      await vaultDir.create(recursive: true);

      if (currentVaultPath != null &&
          !p.equals(currentVaultPath, vaultDir.path)) {
        final oldDir = Directory(currentVaultPath);
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

    String? bookmarkData = iosBookmarkData;
    if (Platform.isMacOS) {
      bookmarkData = await _channel.invokeMethod<String>(
        'createBookmark',
        result,
      );
      if (bookmarkData == null) return null;
    } else if (Platform.isIOS && bookmarkData == null) {
      return null;
    }

    return _PickedVault(
      vaultPath: vaultDir.path,
      bookmarkData: bookmarkData,
      bookmarkTargetsVault: selectedIsAlreadyVault,
    );
  }

  Future<int> _countFiles(Directory dir) async {
    var count = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) count++;
    }
    return count == 0 ? 1 : count;
  }

  Future<List<String>> _copyDirectoryContents(
    Directory source,
    Directory destination,
    void Function() onFileCopied,
  ) async {
    final errors = <String>[];
    if (!await destination.exists()) await destination.create(recursive: true);

    await for (final entity in source.list(followLinks: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      try {
        if (entity is Directory) {
          errors.addAll(
            await _copyDirectoryContents(
              entity,
              Directory(newPath),
              onFileCopied,
            ),
          );
        } else if (entity is File) {
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

    if (Platform.isMacOS || Platform.isIOS) {
      legacyBookmarkData = prefs.getString(_bookmarkKey);
      if (legacyBookmarkData != null) {
        try {
          final parentPath = await _channel.invokeMethod<String>(
            'resolveAndAccess',
            legacyBookmarkData,
          );
          if (parentPath != null) {
            legacyPath = p.join(parentPath, '.freenary');
          }
        } catch (_) {}
      }
    } else {
      legacyPath = prefs.getString(_pathKey);
    }

    if (legacyPath == null) return;

    final legacyVault = SavedVault(
      id: const Uuid().v4(),
      name: _effectiveVaultName('Vault principal', legacyPath),
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
    if (!Platform.isMacOS && !Platform.isIOS) {
      return await Directory(vault.vaultPath).exists() ? vault : null;
    }
    final bookmarkData = vault.bookmarkData;
    if (bookmarkData == null) {
      return await Directory(vault.vaultPath).exists() ? vault : null;
    }

    try {
      final bookmarkTarget = await _channel.invokeMethod<String>(
        'resolveAndAccess',
        bookmarkData,
      );
      if (bookmarkTarget == null) return null;
      final resolvedVaultPath = vault.bookmarkTargetsVault
          ? bookmarkTarget
          : p.join(bookmarkTarget, '.freenary');
      final resolvedVault = vault.copyWith(vaultPath: resolvedVaultPath);
      if (!p.equals(resolvedVault.vaultPath, vault.vaultPath)) {
        final vaults = await listVaults();
        await _saveVaults([
          for (final entry in vaults)
            if (entry.id == resolvedVault.id) resolvedVault else entry,
        ]);
      }
      return await Directory(resolvedVault.vaultPath).exists()
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
    if (base == '.freenary') {
      final parent = p.basename(p.dirname(vaultPath));
      if (parent.isNotEmpty && parent != '.') return parent;
    }
    return base.isNotEmpty ? base : 'Vault';
  }
}

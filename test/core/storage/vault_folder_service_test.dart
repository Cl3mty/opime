import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_folder_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

// Ces tests couvrent la gestion multi-vaults (liste, actif, renommage, oubli)
// sans passer par le sélecteur de dossier natif (FilePicker) ni par le canal
// de bookmarks sécurisés macOS (com.opime/secure_bookmarks), qui
// nécessiteraient de mocker des plugins de plateforme. On sème directement
// les préférences avec le même format JSON que celui écrit par le service
// (clé "saved_vaults_json" / "active_vault_id"), et on pointe chaque vault
// vers un vrai dossier temporaire pour que la résolution d'accessibilité
// (qui vérifie l'existence du dossier) réussisse.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory vaultADir;
  late Directory vaultBDir;
  late VaultFolderService service;

  Map<String, dynamic> vaultJson({
    required String id,
    required String name,
    required String path,
  }) => {
    'id': id,
    'name': name,
    'vaultPath': path,
    'bookmarkData': null,
    'bookmarkTargetsVault': false,
  };

  setUp(() async {
    vaultADir = await Directory.systemTemp.createTemp('opime_vault_a_');
    vaultBDir = await Directory.systemTemp.createTemp('opime_vault_b_');
    service = VaultFolderService();
  });

  tearDown(() async {
    if (await vaultADir.exists()) await vaultADir.delete(recursive: true);
    if (await vaultBDir.exists()) await vaultBDir.delete(recursive: true);
  });

  test('listVaults est vide sans préférence sauvegardée', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await service.listVaults(), isEmpty);
  });

  test('listVaults désérialise les vaults sauvegardés', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([
        vaultJson(id: 'a', name: 'Vault A', path: vaultADir.path),
        vaultJson(id: 'b', name: 'Vault B', path: vaultBDir.path),
      ]),
    });

    final vaults = await service.listVaults();
    expect(vaults.map((v) => v.id), ['a', 'b']);
    expect(vaults.map((v) => v.name), ['Vault A', 'Vault B']);
  });

  test(
    'listVaults retombe sur une liste vide si le JSON est corrompu',
    () async {
      SharedPreferences.setMockInitialValues({
        'saved_vaults_json': 'pas du json',
      });
      expect(await service.listVaults(), isEmpty);
    },
  );

  test(
    'getActiveVault utilise le premier vault si aucun actif n\'est défini',
    () async {
      SharedPreferences.setMockInitialValues({
        'saved_vaults_json': jsonEncode([
          vaultJson(id: 'a', name: 'Vault A', path: vaultADir.path),
          vaultJson(id: 'b', name: 'Vault B', path: vaultBDir.path),
        ]),
      });

      final active = await service.getActiveVault();
      expect(active?.id, 'a');
    },
  );

  test('getActiveVault respecte l\'id actif sauvegardé', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([
        vaultJson(id: 'a', name: 'Vault A', path: vaultADir.path),
        vaultJson(id: 'b', name: 'Vault B', path: vaultBDir.path),
      ]),
      'active_vault_id': 'b',
    });

    final active = await service.getActiveVault();
    expect(active?.id, 'b');
  });

  test(
    'getActiveVault retourne null si le dossier du vault actif n\'existe plus',
    () async {
      SharedPreferences.setMockInitialValues({
        'saved_vaults_json': jsonEncode([
          vaultJson(id: 'a', name: 'Disparu', path: '/chemin/qui/n/existe/pas'),
        ]),
      });

      expect(await service.getActiveVault(), isNull);
    },
  );

  test('setActiveVault change le vault actif et le persiste', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([
        vaultJson(id: 'a', name: 'Vault A', path: vaultADir.path),
        vaultJson(id: 'b', name: 'Vault B', path: vaultBDir.path),
      ]),
      'active_vault_id': 'a',
    });

    final switched = await service.setActiveVault('b');
    expect(switched?.id, 'b');
    expect((await service.getActiveVault())?.id, 'b');
  });

  test('renameVault met à jour le nom persisté', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([
        vaultJson(id: 'a', name: 'Ancien nom', path: vaultADir.path),
      ]),
    });

    await service.renameVault('a', 'Nouveau nom');
    final vaults = await service.listVaults();
    expect(vaults.single.name, 'Nouveau nom');
  });

  test('renameVault ignore un nom vide', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([
        vaultJson(id: 'a', name: 'Conservé', path: vaultADir.path),
      ]),
    });

    await service.renameVault('a', '   ');
    final vaults = await service.listVaults();
    expect(vaults.single.name, 'Conservé');
  });

  test(
    'forgetVault retire le vault et bascule sur un autre s\'il était actif',
    () async {
      SharedPreferences.setMockInitialValues({
        'saved_vaults_json': jsonEncode([
          vaultJson(id: 'a', name: 'Vault A', path: vaultADir.path),
          vaultJson(id: 'b', name: 'Vault B', path: vaultBDir.path),
        ]),
        'active_vault_id': 'a',
      });

      final next = await service.forgetVault('a');
      expect(next?.id, 'b');
      expect(await service.listVaults(), hasLength(1));
    },
  );

  test('forgetVault du dernier vault ne laisse plus de vault actif', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([
        vaultJson(id: 'a', name: 'Seul', path: vaultADir.path),
      ]),
      'active_vault_id': 'a',
    });

    final next = await service.forgetVault('a');
    expect(next, isNull);
    expect(await service.getActiveVault(), isNull);
  });

  test(
    'clearSavedVaultPath supprime toutes les préférences de vault',
    () async {
      SharedPreferences.setMockInitialValues({
        'saved_vaults_json': jsonEncode([
          vaultJson(id: 'a', name: 'Vault A', path: vaultADir.path),
        ]),
        'active_vault_id': 'a',
      });

      await service.clearSavedVaultPath();
      expect(await service.listVaults(), isEmpty);
      expect(await service.getActiveVault(), isNull);
    },
  );

  group('sanitizeOpfsFolderName', () {
    // Noms valides : la saisie est conservée telle quelle (le nom affiché,
    // lui, garde toujours la saisie d'origine — voir `_effectiveVaultName`).
    test('conserve les noms valides', () {
      expect(
        VaultFolderService.sanitizeOpfsFolderName('Coffre-fort'),
        'Coffre-fort',
      );
      expect(
        VaultFolderService.sanitizeOpfsFolderName('Mon Drive'),
        'Mon Drive',
      );
      expect(
        VaultFolderService.sanitizeOpfsFolderName('My Drive (Work)'),
        'My Drive (Work)',
      );
      expect(
        VaultFolderService.sanitizeOpfsFolderName('iCloud-Drive 2026'),
        'iCloud-Drive 2026',
      );
      expect(
        VaultFolderService.sanitizeOpfsFolderName('Épargne d’été'),
        'Épargne d’été',
      );
      // Un point initial (dossier caché, ex. `.opime`) est accepté par l'OPFS.
      expect(
        VaultFolderService.sanitizeOpfsFolderName('.perso'),
        '.perso',
      );
    });

    test('retire les séparateurs au lieu de produire un chemin', () {
      expect(VaultFolderService.sanitizeOpfsFolderName('iCloud/'), 'iCloud');
      expect(
        VaultFolderService.sanitizeOpfsFolderName('iCloud/Drive'),
        'iCloudDrive',
      );
      expect(
        VaultFolderService.sanitizeOpfsFolderName('Drive\\En ligne'),
        'DriveEn ligne',
      );
    });

    test('retombe sur Coffre-fort pour les noms réservés ou vides', () {
      // Noms réservés OPFS / Windows.
      for (final bad in ['', '.', '..', 'CON', 'con.txt', 'prn', 'aux', 'NUL', 'COM1', 'com3', 'LPT2']) {
        expect(VaultFolderService.sanitizeOpfsFolderName(bad), 'Coffre-fort',
            reason: 'doit rejeter "$bad"');
      }
      // Caractères interdits (règles Windows, les plus strictes d'OPFS).
      expect(VaultFolderService.sanitizeOpfsFolderName('A:B'), 'AB');
      expect(VaultFolderService.sanitizeOpfsFolderName('a*b'), 'ab');
      // Espace ou point en fin de nom (interdits sous Windows) : retirés.
      expect(VaultFolderService.sanitizeOpfsFolderName('Espace '), 'Espace');
      expect(VaultFolderService.sanitizeOpfsFolderName('nom.'), 'nom');
    });
  });

  group('VaultFolderService.isExistingVaultFolderName', () {
    test('reconnaît le nom moderne "Opime"', () {
      expect(VaultFolderService.isExistingVaultFolderName('Opime'), isTrue);
    });

    test('reconnaît l\'ancien nom caché ".opime"', () {
      expect(VaultFolderService.isExistingVaultFolderName('.opime'), isTrue);
    });

    test('un dossier quelconque (parent probable) n\'est pas reconnu', () {
      expect(VaultFolderService.isExistingVaultFolderName('Mon Drive'), isFalse);
      expect(VaultFolderService.isExistingVaultFolderName('Documents'), isFalse);
      expect(VaultFolderService.isExistingVaultFolderName(''), isFalse);
    });

    test('sensible à la casse (ne doit pas confondre "opime" et "Opime")', () {
      // Comportement volontairement strict : un vrai dossier de vault a
      // toujours exactement ce nom (créé par l'app elle-même), jamais une
      // variante de casse — un faux positif ici recréerait le bug qu'on
      // corrige (voir la doc de la méthode).
      expect(VaultFolderService.isExistingVaultFolderName('opime'), isFalse);
    });
  });

  group('VaultStorage', () {
    test('fromName : round-trip sur chaque valeur', () {
      for (final storage in VaultStorage.values) {
        expect(VaultStorage.fromName(storage.name), storage);
      }
    });

    test('fromName : nom absent ou inconnu retombe sur standard', () {
      expect(VaultStorage.fromName(null), VaultStorage.standard);
      expect(VaultStorage.fromName('inconnu'), VaultStorage.standard);
    });
  });

  group('SavedVault.storage', () {
    test('toJson/fromJson : round-trip pour chaque VaultStorage', () {
      for (final storage in VaultStorage.values) {
        final vault = SavedVault(
          id: 'v1',
          name: 'Test',
          vaultPath: '/tmp/x',
          bookmarkTargetsVault: false,
          storage: storage,
        );
        expect(SavedVault.fromJson(vault.toJson()).storage, storage);
      }
    });

    test(
      'fromJson : JSON sans champ storage (vault créé avant cette '
      'fonctionnalité) retombe sur standard',
      () {
        final json = {
          'id': 'v1',
          'name': 'Ancien coffre-fort',
          'vaultPath': '/tmp/x',
          'bookmarkTargetsVault': false,
        };
        expect(SavedVault.fromJson(json).storage, VaultStorage.standard);
      },
    );

    test('copyWith : storage peut être changé indépendamment', () {
      const vault = SavedVault(
        id: 'v1',
        name: 'Test',
        vaultPath: '/tmp/x',
        bookmarkTargetsVault: false,
      );
      final updated = vault.copyWith(storage: VaultStorage.webLocalFolder);
      expect(updated.storage, VaultStorage.webLocalFolder);
      expect(updated.id, vault.id);
    });
  });

  // Ces méthodes sont pensées pour le web (voir leur documentation) : hors
  // cible web, `kIsWeb` vaut `false` (y compris dans `flutter test`, qui
  // compile toujours sur la cible io — voir `vault_fs.dart`'s import
  // conditionnel), donc seul leur garde-fou "réservé au web" est
  // vérifiable ici. Le comportement réel (sélecteur de dossier, permissions
  // navigateur, IndexedDB) vit dans `vault_fs_web.dart`, non compilé par
  // cette suite, et n'est donc testable qu'à la main dans un vrai
  // navigateur.
  group('API web (hors cible web : garde-fous uniquement)', () {
    test('supportsWebLocalFolder est toujours faux hors web', () {
      expect(service.supportsWebLocalFolder, isFalse);
    });

    test('pickAndCreateWebLocalFolderVault lève UnsupportedError hors web', () {
      expect(
        () => service.pickAndCreateWebLocalFolderVault(),
        throwsUnsupportedError,
      );
    });

    test(
      'reauthorizeActiveVault renvoie faux sans coffre-fort actif',
      () async {
        SharedPreferences.setMockInitialValues({});
        expect(await service.reauthorizeActiveVault(), isFalse);
      },
    );

    test(
      'reauthorizeActiveVault renvoie faux pour un coffre-fort qui '
      "n'utilise pas de dossier local",
      () async {
        SharedPreferences.setMockInitialValues({
          'saved_vaults_json': jsonEncode([
            vaultJson(id: 'a', name: 'A', path: vaultADir.path),
          ]),
          'active_vault_id': 'a',
        });
        expect(await service.reauthorizeActiveVault(), isFalse);
      },
    );

    test('activeVaultNeedsReauthorization est faux par défaut', () {
      expect(service.activeVaultNeedsReauthorization, isFalse);
    });
  });

  group('migration de renommage .opime -> Opime', () {
    late Directory parentDir;
    late Directory legacyVaultDir;

    setUp(() async {
      parentDir = await Directory.systemTemp.createTemp('opime_rename_test_');
      legacyVaultDir = Directory(p.join(parentDir.path, '.opime'));
      await legacyVaultDir.create(recursive: true);
      await File(
        p.join(legacyVaultDir.path, 'profiles.json'),
      ).writeAsString('{"marker": true}');
    });

    tearDown(() async {
      if (await parentDir.exists()) await parentDir.delete(recursive: true);
    });

    test('un vault ".opime" est renommé en "Opime"', () async {
      SharedPreferences.setMockInitialValues({
        'saved_vaults_json': jsonEncode([
          vaultJson(id: 'a', name: 'Vault A', path: legacyVaultDir.path),
        ]),
      });

      final vaults = await service.listVaults();

      expect(vaults.single.vaultPath, p.join(parentDir.path, 'Opime'));
      expect(await legacyVaultDir.exists(), isFalse);
      expect(await Directory(p.join(parentDir.path, 'Opime')).exists(), isTrue);
      // Le contenu (pas seulement le dossier) a bien suivi le renommage.
      expect(
        await File(p.join(parentDir.path, 'Opime', 'profiles.json')).exists(),
        isTrue,
      );
    });

    test(
      'crée le sous-dossier de configuration ".opime" à l\'intérieur du vault renommé',
      () async {
        SharedPreferences.setMockInitialValues({
          'saved_vaults_json': jsonEncode([
            vaultJson(id: 'a', name: 'Vault A', path: legacyVaultDir.path),
          ]),
        });

        await service.listVaults();

        expect(
          await Directory(p.join(parentDir.path, 'Opime', '.opime')).exists(),
          isTrue,
        );
      },
    );

    test('idempotente : un second appel ne change plus rien', () async {
      SharedPreferences.setMockInitialValues({
        'saved_vaults_json': jsonEncode([
          vaultJson(id: 'a', name: 'Vault A', path: legacyVaultDir.path),
        ]),
      });

      final first = await service.listVaults();
      final second = await service.listVaults();

      expect(first.single.vaultPath, second.single.vaultPath);
      expect(second.single.vaultPath, p.join(parentDir.path, 'Opime'));
    });

    test('un vault déjà nommé "Opime" est laissé tel quel', () async {
      final modernDir = Directory(p.join(parentDir.path, 'Opime'));
      await modernDir.create(recursive: true);
      SharedPreferences.setMockInitialValues({
        'saved_vaults_json': jsonEncode([
          vaultJson(id: 'a', name: 'Vault A', path: modernDir.path),
        ]),
      });

      final vaults = await service.listVaults();

      expect(vaults.single.vaultPath, modernDir.path);
    });
  });
}

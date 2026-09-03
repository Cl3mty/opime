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
    String? kind,
  }) => {
    'id': id,
    'name': name,
    'vaultPath': path,
    'bookmarkData': null,
    'bookmarkTargetsVault': false,
    if (kind != null) 'kind': kind,
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

  test('listVaults désérialise le kind quand présent', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([
        vaultJson(
          id: 'a',
          name: 'Perso',
          path: vaultADir.path,
          kind: 'personal',
        ),
        vaultJson(
          id: 'b',
          name: 'Pro',
          path: vaultBDir.path,
          kind: 'professional',
        ),
      ]),
    });

    final vaults = await service.listVaults();
    expect(vaults.firstWhere((v) => v.id == 'a').kind, VaultKind.personal);
    expect(vaults.firstWhere((v) => v.id == 'b').kind, VaultKind.professional);
  });

  test(
    'un coffre-fort sans kind dans le JSON (créé avant cette fonctionnalité) '
    'est traité comme personnel',
    () async {
      SharedPreferences.setMockInitialValues({
        'saved_vaults_json': jsonEncode([
          vaultJson(id: 'a', name: 'Ancien vault', path: vaultADir.path),
        ]),
      });

      final vaults = await service.listVaults();
      expect(vaults.single.kind, VaultKind.personal);
    },
  );

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

  group('VaultKind', () {
    test('label distinct pour chaque valeur', () {
      final labels = VaultKind.values.map((k) => k.label).toSet();
      expect(labels, hasLength(VaultKind.values.length));
    });

    test('fromName : round-trip sur chaque valeur', () {
      for (final kind in VaultKind.values) {
        expect(VaultKind.fromName(kind.name), kind);
      }
    });

    test('fromName : nom absent ou inconnu retombe sur personal', () {
      expect(VaultKind.fromName(null), VaultKind.personal);
      expect(VaultKind.fromName('inconnu'), VaultKind.personal);
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

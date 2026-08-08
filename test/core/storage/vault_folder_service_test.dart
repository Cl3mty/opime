import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/core/storage/vault_folder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ces tests couvrent la gestion multi-vaults (liste, actif, renommage, oubli)
// sans passer par le sélecteur de dossier natif (FilePicker) ni par le canal
// de bookmarks sécurisés macOS (com.freenary/secure_bookmarks), qui
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

  Map<String, dynamic> vaultJson({required String id, required String name, required String path}) => {
        'id': id,
        'name': name,
        'vaultPath': path,
        'bookmarkData': null,
        'bookmarkTargetsVault': false,
      };

  setUp(() async {
    vaultADir = await Directory.systemTemp.createTemp('freenary_vault_a_');
    vaultBDir = await Directory.systemTemp.createTemp('freenary_vault_b_');
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

  test('listVaults retombe sur une liste vide si le JSON est corrompu', () async {
    SharedPreferences.setMockInitialValues({'saved_vaults_json': 'pas du json'});
    expect(await service.listVaults(), isEmpty);
  });

  test('getActiveVault utilise le premier vault si aucun actif n\'est défini', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([
        vaultJson(id: 'a', name: 'Vault A', path: vaultADir.path),
        vaultJson(id: 'b', name: 'Vault B', path: vaultBDir.path),
      ]),
    });

    final active = await service.getActiveVault();
    expect(active?.id, 'a');
  });

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

  test('getActiveVault retourne null si le dossier du vault actif n\'existe plus', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([
        vaultJson(id: 'a', name: 'Disparu', path: '/chemin/qui/n/existe/pas'),
      ]),
    });

    expect(await service.getActiveVault(), isNull);
  });

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
      'saved_vaults_json': jsonEncode([vaultJson(id: 'a', name: 'Ancien nom', path: vaultADir.path)]),
    });

    await service.renameVault('a', 'Nouveau nom');
    final vaults = await service.listVaults();
    expect(vaults.single.name, 'Nouveau nom');
  });

  test('renameVault ignore un nom vide', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([vaultJson(id: 'a', name: 'Conservé', path: vaultADir.path)]),
    });

    await service.renameVault('a', '   ');
    final vaults = await service.listVaults();
    expect(vaults.single.name, 'Conservé');
  });

  test('forgetVault retire le vault et bascule sur un autre s\'il était actif', () async {
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
  });

  test('forgetVault du dernier vault ne laisse plus de vault actif', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([vaultJson(id: 'a', name: 'Seul', path: vaultADir.path)]),
      'active_vault_id': 'a',
    });

    final next = await service.forgetVault('a');
    expect(next, isNull);
    expect(await service.getActiveVault(), isNull);
  });

  test('clearSavedVaultPath supprime toutes les préférences de vault', () async {
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([vaultJson(id: 'a', name: 'Vault A', path: vaultADir.path)]),
      'active_vault_id': 'a',
    });

    await service.clearSavedVaultPath();
    expect(await service.listVaults(), isEmpty);
    expect(await service.getActiveVault(), isNull);
  });
}

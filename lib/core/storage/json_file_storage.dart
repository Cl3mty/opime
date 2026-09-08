import 'dart:convert';
import 'package:path/path.dart' as p;
import 'storage_repository.dart';
import 'vault_fs.dart';

class JsonFileStorage implements StorageRepository {
  final String? vaultFolderPath;

  JsonFileStorage({this.vaultFolderPath});

  @override
  bool get hasVaultFolder => vaultFolderPath != null;

  String get _vaultFilePath => p.join(vaultFolderPath!, 'vault.json');

  @override
  Future<Map<String, dynamic>> readVault() async {
    final file = VaultFile(_vaultFilePath);
    if (!await file.exists()) {
      return {'patrimoine': [], 'investissements': []};
    }
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  @override
  Future<void> writeVault(Map<String, dynamic> data) async {
    final file = VaultFile(_vaultFilePath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }
}

abstract class StorageRepository {
  Future<Map<String, dynamic>> readVault();
  Future<void> writeVault(Map<String, dynamic> data);
  bool get hasVaultFolder;
}

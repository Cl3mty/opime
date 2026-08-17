import 'dart:convert';
import '../../core/storage/vault_crypto.dart' show VaultCipher;
import '../../core/storage/vault_session.dart';
import '../../core/storage/vault_file_storage.dart';
import 'budget_tracking_models.dart';

class BudgetTrackingRepository {
  final String vaultPath;
  late final VaultFileStorage _storage;

  BudgetTrackingRepository(this.vaultPath, {VaultCipher? cipher}) {
    _storage = VaultFileStorage(
      vaultPath: vaultPath,
      cipher: cipher ?? VaultSession.current,
    );
  }

  String _relativePathFor(int year, int month) =>
      'budget/tracking/${year}_${month.toString().padLeft(2, '0')}.json';

  Future<BudgetTrackingMonth> load(int year, int month) async {
    final relativePath = _relativePathFor(year, month);
    if (!await _storage.exists(relativePath)) {
      return BudgetTrackingMonth.empty(month, year);
    }
    final content = await _storage.readString(relativePath);
    if (content.trim().isEmpty) return BudgetTrackingMonth.empty(month, year);
    try {
      return BudgetTrackingMonth.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } catch (_) {
      return BudgetTrackingMonth.empty(month, year);
    }
  }

  Future<void> save(BudgetTrackingMonth data) async {
    await _storage.writeString(
      _relativePathFor(data.year, data.month),
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
    );
  }
}

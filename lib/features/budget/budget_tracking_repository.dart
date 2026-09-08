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
    final result = await loadWithStatus(year, month);
    return result.month;
  }

  /// Même chargement que [load], mais expose aussi si le mois vient d'être
  /// créé vide faute de fichier existant — plutôt que de l'inférer côté
  /// écran depuis des listes vides (un mois où l'utilisateur a
  /// effectivement tout supprimé serait alors, à tort, traité comme neuf).
  /// Utilisé par la relance "lignes récurrentes disponibles" de
  /// `budget_tracking_screen.dart`.
  Future<({BudgetTrackingMonth month, bool isNew})> loadWithStatus(
    int year,
    int month,
  ) async {
    final relativePath = _relativePathFor(year, month);
    if (!await _storage.exists(relativePath)) {
      return (month: BudgetTrackingMonth.empty(month, year), isNew: true);
    }
    final content = await _storage.readString(relativePath);
    if (content.trim().isEmpty) {
      return (month: BudgetTrackingMonth.empty(month, year), isNew: false);
    }
    try {
      return (
        month: BudgetTrackingMonth.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        ),
        isNew: false,
      );
    } catch (_) {
      return (month: BudgetTrackingMonth.empty(month, year), isNew: false);
    }
  }

  Future<void> save(BudgetTrackingMonth data) async {
    await _storage.writeString(
      _relativePathFor(data.year, data.month),
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
    );
  }
}

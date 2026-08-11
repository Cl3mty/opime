import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'budget_tracking_models.dart';

class BudgetTrackingRepository {
  final String vaultPath;
  BudgetTrackingRepository(this.vaultPath);

  File _fileFor(int year, int month) => File(
    p.join(
      vaultPath,
      'budget',
      'tracking',
      '${year}_${month.toString().padLeft(2, '0')}.json',
    ),
  );

  Future<BudgetTrackingMonth> load(int year, int month) async {
    final file = _fileFor(year, month);
    if (!await file.exists()) return BudgetTrackingMonth.empty(month, year);
    final content = await file.readAsString();
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
    final file = _fileFor(data.year, data.month);
    final dir = file.parent;
    if (!await dir.exists()) await dir.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
    );
  }
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/analyses/analyses_settings_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_analyses_settings_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('load sans fichier renvoie des paramètres vides', () async {
    final repo = AnalysesSettingsRepository(tempDir.path);
    expect((await repo.load()).benchmarkTicker, isNull);
  });

  test('save puis load restitue le ticker du benchmark', () async {
    final repo = AnalysesSettingsRepository(tempDir.path);
    await repo.save(const AnalysesSettings(benchmarkTicker: 'URTH'));

    final reloaded = await repo.load();
    expect(reloaded.benchmarkTicker, 'URTH');
  });
}

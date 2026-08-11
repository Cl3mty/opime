import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'liabilities_models.dart';

/// Persiste les passifs réels de l'utilisateur — même pattern que
/// [InvestmentsRepository] (`features/investments/investments_repository.dart`) :
/// un fichier JSON unique sous le dossier du profil, réécrit en entier à
/// chaque sauvegarde.
class LiabilitiesRepository {
  final String vaultPath;
  LiabilitiesRepository(this.vaultPath);

  File get _file => File(p.join(vaultPath, 'passifs', 'emprunts.json'));

  Future<void> _ensureDir() async {
    final dir = Directory(p.join(vaultPath, 'passifs'));
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  Future<List<Liability>> _readAll() async {
    if (!await _file.exists()) return [];
    final content = await _file.readAsString();
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list
        .map((e) => Liability.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<Liability> all) async {
    await _ensureDir();
    final jsonList = all.map((l) => l.toJson()).toList();
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
  }

  Future<List<Liability>> listAll() => _readAll();

  /// Ajoute un nouveau passif, ou remplace un passif existant de même id.
  Future<void> saveLiability(Liability liability) async {
    final all = await _readAll();
    final idx = all.indexWhere((l) => l.id == liability.id);
    if (idx == -1) {
      all.add(liability);
    } else {
      all[idx] = liability;
    }
    await _writeAll(all);
  }

  Future<void> deleteLiability(String id) async {
    final all = await _readAll();
    all.removeWhere((l) => l.id == id);
    await _writeAll(all);
  }
}

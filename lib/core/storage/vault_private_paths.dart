import 'dart:io';

import 'package:path/path.dart' as p;

/// Chemin, relatif à la racine du vault (pas au dossier d'un profil), du
/// fichier listant les profils — seul fichier privé qui vit hors du
/// dossier d'un profil (voir `ProfileRepository`).
const kProfilesJsonRelativePath = 'profiles.json';

/// Chemins, relatifs au dossier d'un profil (`ProfileController.
/// activeDataPath` ou équivalent), de tous les fichiers "privés" —
/// patrimoine de l'utilisateur — actuellement présents pour ce profil.
///
/// Construit explicitement fichier par fichier/dossier par dossier plutôt
/// que par un balayage récursif générique du dossier profil : plusieurs
/// caches publics (DVF, loyers, frontières géo) et le miroir lisible des
/// métaux précieux (voir `metal_mirror_repository.dart`, volontairement
/// laissé en clair) vivent dans les mêmes dossiers parents (`simulations/`,
/// `investissements/`) et ne doivent surtout pas être balayés par erreur —
/// voir le plan de chiffrement du vault pour la classification complète.
///
/// Utilisé par le service de migration chiffrer/déchiffrer en place.
Future<List<String>> privateRelativePathsForProfile(
  String profileDataPath,
) async {
  final paths = <String>[];

  Future<void> addIfExists(String relativePath) async {
    if (await File(p.join(profileDataPath, relativePath)).exists()) {
      paths.add(relativePath);
    }
  }

  Future<void> addMatchingFiles(
    String dirRelativePath,
    bool Function(String filename) matches,
  ) async {
    final dir = Directory(p.join(profileDataPath, dirRelativePath));
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File && matches(p.basename(entity.path))) {
        paths.add(p.join(dirRelativePath, p.basename(entity.path)));
      }
    }
  }

  await addIfExists('budget/budget_history.json');
  await addMatchingFiles('budget/tracking', (name) => name.endsWith('.json'));
  await addIfExists('investissements/comptes.json');
  await addMatchingFiles('investissements/documents', (_) => true);
  await addIfExists('passifs/emprunts.json');
  await addIfExists('projets/projets.json');
  await addMatchingFiles('strategy', (name) => name.endsWith('.md'));
  await addIfExists('analyses/parametres.json');
  // simulations/ contient aussi department_boundaries.json (cache DVF, en
  // clair) au même niveau que les fichiers d'état de simulation — exclu
  // explicitement. Les autres caches (commune_boundaries/, dvf_cache/,
  // dvf_department_cache/, rent_cache/) sont des sous-dossiers, jamais
  // atteints par ce listage non récursif (`dir.list()` sans `recursive`).
  await addMatchingFiles(
    'simulations',
    (name) => name.endsWith('.json') && name != 'department_boundaries.json',
  );

  return paths;
}

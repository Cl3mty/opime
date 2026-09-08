/// Niveau de difficulté d'une notion de l'Académie, en ordre croissant.
enum AcademyLevel { debutant, intermediaire, avance }

extension AcademyLevelLabel on AcademyLevel {
  String get label => switch (this) {
    AcademyLevel.debutant => 'Débutant',
    AcademyLevel.intermediaire => 'Intermédiaire',
    AcademyLevel.avance => 'Avancé',
  };
}

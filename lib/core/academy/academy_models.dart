import 'academy_level.dart';

/// Une notion unique de l'Académie (une leçon d'un parcours d'investissement
/// ou de formation).
///
/// [id] doit être stable et unique dans tout le module Académie : c'est la
/// clé utilisée pour la persistance de la progression.
class AcademyStep {
  final String id;
  final String title;
  final AcademyLevel level;
  final String tagline;
  final List<String> bullets;

  /// La phrase à retenir en un coup d'œil (esprit "carte de mémorisation").
  final String? takeaway;

  /// Termes techniques expliqués en contexte dans cette leçon.
  final List<GlossaryTerm> vocabulary;

  const AcademyStep({
    required this.id,
    required this.title,
    required this.level,
    required this.tagline,
    required this.bullets,
    this.takeaway,
    this.vocabulary = const [],
  });
}

class GlossaryTerm {
  final String term;
  final String definition;

  const GlossaryTerm({required this.term, required this.definition});
}

/// Une fiche récapitulative ("cheat sheet") pour une enveloppe financière.
class Envelope {
  final String id;
  final String name;
  final AcademyLevel level;
  final String tagline;
  final String ceiling;
  final String taxation;
  final String liquidity;
  final String idealFor;
  final List<String> goodToKnow;
  final String pitfall;

  const Envelope({
    required this.id,
    required this.name,
    required this.level,
    required this.tagline,
    required this.ceiling,
    required this.taxation,
    required this.liquidity,
    required this.idealFor,
    required this.goodToKnow,
    required this.pitfall,
  });
}

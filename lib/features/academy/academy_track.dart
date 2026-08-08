import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/academy/academy_level.dart';
import '../../core/academy/academy_models.dart';

/// Un parcours de la Formation (Bourse, Immobilier, ...), composé de
/// plusieurs notions ([AcademyStep]) à dérouler dans l'ordre.
class AcademyTrack {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<AcademyStep> steps;

  const AcademyTrack({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
  });

  /// Le niveau le plus élevé abordé dans ce parcours, affiché sur sa carte.
  AcademyLevel get level =>
      steps.map((s) => s.level).reduce((a, b) => a.index > b.index ? a : b);
}

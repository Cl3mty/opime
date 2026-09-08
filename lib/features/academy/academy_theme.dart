import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/academy/academy_level.dart';

/// Code couleur du niveau de difficulté, crescendo du plus simple (vert) au
/// plus avancé (rouge) — la même convention que les pistes de ski, immédiate
/// à comprendre.
extension AcademyLevelColor on AcademyLevel {
  Color get color => switch (this) {
    AcademyLevel.debutant => const Color(0xFF22C55E),
    AcademyLevel.intermediaire => const Color(0xFF7B8FE8),
    AcademyLevel.avance => const Color(0xFFE07A6B),
  };
}

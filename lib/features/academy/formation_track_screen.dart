import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/academy/academy_progress_controller.dart';
import '../../core/academy/academy_progress_repository.dart';
import '../../core/ui/frosted_card.dart';
import 'academy_track.dart';
import 'widgets/academy_course_view.dart';

/// Cursus complet d'un parcours de Formation (ex : Bourse), avec ses
/// leçons dans l'ordre et le vocabulaire technique expliqué en contexte.
class FormationTrackScreen extends StatefulWidget {
  final String vaultPath;
  final AcademyTrack track;

  const FormationTrackScreen({super.key, required this.vaultPath, required this.track});

  @override
  State<FormationTrackScreen> createState() => _FormationTrackScreenState();
}

class _FormationTrackScreenState extends State<FormationTrackScreen> {
  late final AcademyProgressController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AcademyProgressController(AcademyProgressRepository(widget.vaultPath));
    _progress.load();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FrostedCard(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AcademyCourseView(
            title: widget.track.title,
            subtitle: widget.track.description,
            steps: widget.track.steps,
            progress: _progress,
          ),
        ),
      ),
    );
  }
}

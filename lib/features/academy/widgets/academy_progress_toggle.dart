import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/academy/academy_level.dart';
import '../../../core/academy/academy_progress_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../academy_theme.dart';

/// Bouton "Marquer comme acquis" réutilisé sur chaque page de l'Académie.
class AcademyProgressToggle extends StatelessWidget {
  final AcademyProgressController progress;
  final String stepId;
  final AcademyLevel level;

  const AcademyProgressToggle({
    super.key,
    required this.progress,
    required this.stepId,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final done = progress.isCompleted(stepId);
        return done
            ? OutlineButton(
                onPressed: () => progress.toggle(stepId),
                leading: Icon(LucideIcons.circleCheck, color: level.color),
                child: shadcn.Text(l10n.academy_button_completed),
              )
            : PrimaryButton(
                onPressed: () => progress.toggle(stepId),
                leading: const Icon(LucideIcons.check),
                child: shadcn.Text(l10n.academy_button_mark_completed),
              );
      },
    );
  }
}

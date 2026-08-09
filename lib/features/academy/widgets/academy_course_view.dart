import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/academy/academy_models.dart';
import '../../../core/academy/academy_progress_controller.dart';
import '../academy_theme.dart';
import 'academy_level_badge.dart';
import 'academy_takeaway_box.dart';
import 'academy_vocabulary_box.dart';

/// Vue d'un cursus complet (une liste ordonnée de leçons, [AcademyStep]) :
/// une leçon à la fois, avec un [DotIndicator] pour naviguer et voir la
/// progression. Pas de composant Stepper "assistant" de shadcn_flutter —
/// il s'est montré peu fiable dans ce contexte précis (rendu défaillant
/// par intermittence) ; cette navigation maison, plus simple, offre la
/// même expérience "pas à pas" sans en dépendre. Utilisée pour chaque
/// parcours de Formation.
class AcademyCourseView extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<AcademyStep> steps;
  final AcademyProgressController progress;

  const AcademyCourseView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.progress,
  });

  @override
  State<AcademyCourseView> createState() => _AcademyCourseViewState();
}

class _AcademyCourseViewState extends State<AcademyCourseView> {
  int _currentIndex = 0;

  @override
  void didUpdateWidget(covariant AcademyCourseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps != widget.steps) {
      setState(() => _currentIndex = 0);
    }
  }

  void _jumpTo(int index) {
    setState(() => _currentIndex = index.clamp(0, widget.steps.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    return AnimatedBuilder(
      animation: widget.progress,
      builder: (context, _) {
        final currentIndex = _currentIndex.clamp(0, steps.length - 1);
        final currentStep = steps[currentIndex];
        final completedCount = widget.progress.completedCountAmong(
          steps.map((s) => s.id),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      shadcn.Text(widget.title).xLarge().bold(),
                      const SizedBox(height: 4),
                      shadcn.Text(widget.subtitle).muted(),
                    ],
                  ),
                ),
                shadcn.Text(
                  '$completedCount / ${steps.length} acquises',
                ).muted().small(),
              ],
            ),
            const SizedBox(height: 16),
            DotIndicator(
              index: currentIndex,
              length: steps.length,
              onChanged: _jumpTo,
              dotBuilder: (context, index, active) {
                final step = steps[index];
                final done = widget.progress.isCompleted(step.id);
                final color = done
                    ? step.level.color
                    : Theme.of(context).colorScheme.border;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: active ? 22 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: active ? step.level.color : color,
                    borderRadius: BorderRadius.circular(999),
                    border: done || active
                        ? null
                        : Border.all(
                            color: Theme.of(context).colorScheme.mutedForeground
                                .withValues(alpha: 0.4),
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Flexible(
                  child: shadcn.Text(currentStep.title).xLarge().semiBold(),
                ),
                const SizedBox(width: 8),
                AcademyLevelBadge(level: currentStep.level),
                if (widget.progress.isCompleted(currentStep.id)) ...[
                  const SizedBox(width: 6),
                  Icon(
                    LucideIcons.circleCheck,
                    size: 16,
                    color: currentStep.level.color,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _StepBody(
              step: currentStep,
              progress: widget.progress,
              onPrevious: currentIndex > 0
                  ? () => _jumpTo(currentIndex - 1)
                  : null,
              onNext: currentIndex < steps.length - 1
                  ? () => _jumpTo(currentIndex + 1)
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _StepBody extends StatelessWidget {
  final AcademyStep step;
  final AcademyProgressController progress;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _StepBody({
    required this.step,
    required this.progress,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final done = progress.isCompleted(step.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(step.tagline),
        const SizedBox(height: 12),
        for (final bullet in step.bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    LucideIcons.dot,
                    size: 18,
                    color: step.level.color,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(child: shadcn.Text(bullet).small()),
              ],
            ),
          ),
        if (step.vocabulary.isNotEmpty) ...[
          const SizedBox(height: 4),
          AcademyVocabularyBox(terms: step.vocabulary),
        ],
        if (step.takeaway != null) ...[
          const SizedBox(height: 12),
          AcademyTakeawayBox(text: step.takeaway!, level: step.level),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            done
                ? OutlineButton(
                    onPressed: () => progress.toggle(step.id),
                    leading: Icon(
                      LucideIcons.circleCheck,
                      color: step.level.color,
                    ),
                    child: const shadcn.Text('Acquis'),
                  )
                : PrimaryButton(
                    onPressed: () => progress.toggle(step.id),
                    leading: const Icon(LucideIcons.check),
                    child: const shadcn.Text('Marquer comme acquis'),
                  ),
            const Spacer(),
            IconButton.ghost(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: onPrevious,
            ),
            IconButton.ghost(
              icon: const Icon(LucideIcons.chevronRight),
              onPressed: onNext,
            ),
          ],
        ),
      ],
    );
  }
}

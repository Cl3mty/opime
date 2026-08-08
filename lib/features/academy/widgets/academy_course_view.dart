import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/academy/academy_models.dart';
import '../../../core/academy/academy_progress_controller.dart';
import '../academy_theme.dart';
import 'academy_level_badge.dart';
import 'academy_progress_toggle.dart';
import 'academy_takeaway_box.dart';
import 'academy_vocabulary_box.dart';

/// Vue d'un cursus complet (une liste ordonnée de leçons, [AcademyStep])
/// avec un [Stepper] pour progresser leçon par leçon et un [DotIndicator]
/// résumant la progression. Utilisée pour chaque parcours de Formation.
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
  late final StepperController _stepperController;

  @override
  void initState() {
    super.initState();
    _stepperController = StepperController();
  }

  @override
  void didUpdateWidget(covariant AcademyCourseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps != widget.steps) {
      _stepperController.jumpToStep(0);
    }
  }

  @override
  void dispose() {
    _stepperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    return AnimatedBuilder(
      animation: Listenable.merge([_stepperController, widget.progress]),
      builder: (context, _) {
        final currentIndex = _stepperController.value.currentStep.clamp(0, steps.length - 1);
        final completedCount = widget.progress.completedCountAmong(steps.map((s) => s.id));

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
                shadcn.Text('$completedCount / ${steps.length} acquises').muted().small(),
              ],
            ),
            const SizedBox(height: 16),
            DotIndicator(
              index: currentIndex,
              length: steps.length,
              onChanged: _stepperController.jumpToStep,
              dotBuilder: (context, index, active) {
                final step = steps[index];
                final done = widget.progress.isCompleted(step.id);
                final color = done ? step.level.color : Theme.of(context).colorScheme.border;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: active ? 22 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: active ? step.level.color : color,
                    borderRadius: BorderRadius.circular(999),
                    border: done || active ? null : Border.all(color: Theme.of(context).colorScheme.mutedForeground.withValues(alpha: 0.4)),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Stepper(
              controller: _stepperController,
              direction: Axis.vertical,
              variant: StepVariant.circle,
              steps: [
                for (final step in steps)
                  Step(
                    title: Row(
                      children: [
                        Flexible(child: shadcn.Text(step.title).semiBold()),
                        const SizedBox(width: 8),
                        AcademyLevelBadge(level: step.level),
                        if (widget.progress.isCompleted(step.id)) ...[
                          const SizedBox(width: 6),
                          Icon(LucideIcons.circleCheck, size: 16, color: step.level.color),
                        ],
                      ],
                    ),
                    contentBuilder: (context) => _StepBody(
                      step: step,
                      progress: widget.progress,
                      controller: _stepperController,
                      index: steps.indexOf(step),
                      total: steps.length,
                    ),
                  ),
              ],
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
  final StepperController controller;
  final int index;
  final int total;

  const _StepBody({
    required this.step,
    required this.progress,
    required this.controller,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
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
                    child: Icon(LucideIcons.dot, size: 18, color: step.level.color),
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
          const SizedBox(height: 12),
          Row(
            children: [
              AcademyProgressToggle(progress: progress, stepId: step.id, level: step.level),
              const Spacer(),
              if (index > 0)
                IconButton.ghost(
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: controller.previousStep,
                ),
              if (index < total - 1)
                IconButton.ghost(
                  icon: const Icon(LucideIcons.chevronRight),
                  onPressed: controller.nextStep,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

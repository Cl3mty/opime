import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/academy/academy_models.dart';
import '../../core/academy/academy_progress_controller.dart';
import '../../core/academy/academy_progress_repository.dart';
import '../../core/ui/frosted_card.dart';
import 'academy_theme.dart';
import 'widgets/academy_disclaimer.dart';
import 'widgets/academy_level_badge.dart';
import 'widgets/academy_progress_toggle.dart';
import 'widgets/academy_takeaway_box.dart';

/// Carte de mémorisation pour une notion clé d'investissement : une page
/// dédiée par notion, listée dans les sous-items de la sidebar.
class InvestissementCardScreen extends StatefulWidget {
  final String vaultPath;
  final AcademyStep card;

  const InvestissementCardScreen({
    super.key,
    required this.vaultPath,
    required this.card,
  });

  @override
  State<InvestissementCardScreen> createState() =>
      _InvestissementCardScreenState();
}

class _InvestissementCardScreenState extends State<InvestissementCardScreen> {
  late final AcademyProgressController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AcademyProgressController(
      AcademyProgressRepository(widget.vaultPath),
    );
    _progress.load();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final color = card.level.color;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FrostedCard(
        expand: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: shadcn.Text(card.title).xLarge().bold()),
                  AcademyLevelBadge(level: card.level),
                ],
              ),
              const SizedBox(height: 6),
              shadcn.Text(card.tagline).muted(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.border,
                  ),
                  borderRadius: BorderRadius.circular(
                    Theme.of(context).radiusMd,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final bullet in card.bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Icon(
                                LucideIcons.dot,
                                size: 18,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(child: shadcn.Text(bullet)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (card.takeaway != null) ...[
                const SizedBox(height: 16),
                AcademyTakeawayBox(text: card.takeaway!, level: card.level),
              ],
              const SizedBox(height: 24),
              AcademyProgressToggle(
                progress: _progress,
                stepId: card.id,
                level: card.level,
              ),
              const SizedBox(height: 20),
              const AcademyDisclaimer(),
            ],
          ),
        ),
      ),
    );
  }
}

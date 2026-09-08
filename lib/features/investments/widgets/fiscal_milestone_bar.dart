import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/date_format.dart';
import '../../../core/ui/gold_progress_bar.dart';
import '../investments_models.dart';

/// Barre de progression du jalon fiscal d'un compte PEA/PEG/PEE/assurance
/// vie — temps écoulé depuis [openingDate] jusqu'à [milestone.date], même
/// rendu visuel que [GoalProgressBar] (`features/projects/widgets/`) via la
/// primitive partagée [GoldProgressBar], mais proportionnée dans le temps
/// plutôt qu'en montant.
///
/// Voir [accountFiscalMilestone] pour le calcul du jalon lui-même.
class FiscalMilestoneBar extends StatelessWidget {
  final DateTime openingDate;
  final FiscalMilestone milestone;

  const FiscalMilestoneBar({
    super.key,
    required this.openingDate,
    required this.milestone,
  });

  @override
  Widget build(BuildContext context) {
    final totalDays = milestone.date.difference(openingDate).inDays;
    final elapsedDays = DateTime.now().difference(openingDate).inDays;
    final fraction = totalDays <= 0
        ? 1.0
        : (elapsedDays / totalDays).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GoldProgressBar(fraction: fraction, height: 6),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            shadcn.Text(formatDateDdMmYyyy(openingDate)).muted().xSmall(),
            shadcn.Text(formatDateDdMmYyyy(milestone.date)).muted().xSmall(),
          ],
        ),
      ],
    );
  }
}

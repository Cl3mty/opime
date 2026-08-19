import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/date_format.dart';
import '../../../core/money_format.dart';
import '../../../core/ui/gold_progress_bar.dart';
import '../investments_models.dart';

/// Résumé du déblocage d'un compte PEG/PEE — voir [pegPeeUnlockTranches].
/// Contrairement au PEA ou à l'assurance vie ([FiscalMilestoneBar], un seul
/// jalon sur le compte entier), chaque versement (intéressement,
/// participation, abondement...) se débloque séparément 5 ans après sa
/// propre date : la barre représente donc la part du capital déjà
/// déblocable, pas un temps écoulé.
class PegPeeUnlockCard extends StatelessWidget {
  final List<UnlockTranche> tranches;

  const PegPeeUnlockCard({super.key, required this.tranches});

  @override
  Widget build(BuildContext context) {
    if (tranches.isEmpty) return const SizedBox.shrink();

    final total = tranches.fold(0.0, (sum, t) => sum + t.amount);
    final unlocked = tranches
        .where((t) => t.unlocked)
        .fold(0.0, (sum, t) => sum + t.amount);
    final fraction = total <= 0 ? 0.0 : (unlocked / total).clamp(0.0, 1.0);
    final next = tranches.where((t) => !t.unlocked).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(
          'Déblocable : ${formatEuros(unlocked)} sur ${formatEuros(total)}',
        ).xSmall().semiBold(),
        const SizedBox(height: 6),
        GoldProgressBar(fraction: fraction, height: 6),
        if (next != null) ...[
          const SizedBox(height: 4),
          shadcn.Text(
            'Prochain déblocage : ${formatEuros(next.amount)} le '
            '${formatDateDdMmYyyy(next.unlockDate)}',
          ).muted().xSmall(),
        ],
      ],
    );
  }
}

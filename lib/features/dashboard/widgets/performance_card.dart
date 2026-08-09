import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/ui/frosted_card.dart';
import '../dashboard_dummy_data.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Carte "Performance" : plus-value latente en %, avec l'explication du
/// calcul. "En savoir plus" est un lien désactivé pour l'instant, comme
/// [AddMenuButton] — le vrai calcul de performance (coûts d'acquisition,
/// plus-values réalisées, comparaison à un indice) viendra avec le
/// module Patrimoine.
class PerformanceCard extends StatelessWidget {
  final DashboardSampleData data;

  const PerformanceCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changePercent = data.changePercentFor(data.netWorthHistory);
    final positive = changePercent >= 0;
    final color = positive ? _green : _red;

    return FrostedCard(
      expand: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                shadcn.Text('Performance').semiBold().large(),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: theme.colorScheme.mutedForeground,
                ),
              ],
            ),
            const SizedBox(height: 20),
            shadcn.Text('Plus-value — Tout').muted().small(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: shadcn.Text(
                '${positive ? '+' : ''}${changePercent.toStringAsFixed(2)} %',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            shadcn.Text(
              "La plus-value latente est la différence entre votre prix "
              "d'achat unitaire et le prix actuel à un instant donné. Ce "
              "montant ne tient pas compte des plus-values réalisées.",
            ).muted().small(),
            const Spacer(),
            Tooltip(
              // ignore: implicit_call_tearoffs
              tooltip: TooltipContainer(
                child: const shadcn.Text('Bientôt disponible'),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  shadcn.Text(
                    'En savoir plus',
                    style: TextStyle(color: theme.colorScheme.mutedForeground),
                  ).small(),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

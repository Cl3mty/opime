import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/academy/academy_models.dart';
import '../../core/academy/academy_progress_controller.dart';
import '../../core/academy/academy_progress_repository.dart';
import '../../core/ui/frosted_card.dart';
import '../../l10n/app_localizations.dart';
import 'academy_theme.dart';
import 'widgets/academy_disclaimer.dart';
import 'widgets/academy_level_badge.dart';
import 'widgets/academy_progress_toggle.dart';

/// Fiche récapitulative ("cheat sheet") d'une enveloppe financière : une
/// page dédiée par enveloppe, listée dans les sous-items de la sidebar.
class EnvelopeSheetScreen extends StatefulWidget {
  final String vaultPath;
  final Envelope envelope;

  const EnvelopeSheetScreen({
    super.key,
    required this.vaultPath,
    required this.envelope,
  });

  @override
  State<EnvelopeSheetScreen> createState() => _EnvelopeSheetScreenState();
}

class _EnvelopeSheetScreenState extends State<EnvelopeSheetScreen> {
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
    final envelope = widget.envelope;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = envelope.level.color;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FrostedCard(
        expand: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: shadcn.Text(envelope.name).xLarge().bold()),
                    AcademyLevelBadge(level: envelope.level),
                  ],
                ),
                const SizedBox(height: 6),
                shadcn.Text(envelope.tagline).muted(),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.border),
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FactRow(
                        label: l10n.academy_envelope_ceiling_label,
                        value: envelope.ceiling,
                      ),
                      const Divider(),
                      _FactRow(
                        label: l10n.academy_envelope_taxation_label,
                        value: envelope.taxation,
                      ),
                      const Divider(),
                      _FactRow(
                        label: l10n.academy_envelope_liquidity_label,
                        value: envelope.liquidity,
                      ),
                      const Divider(),
                      _FactRow(
                        label: l10n.academy_envelope_ideal_for_label,
                        value: envelope.idealFor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                shadcn.Text(l10n.academy_envelope_good_to_know_title).semiBold(),
                const SizedBox(height: 10),
                for (final point in envelope.goodToKnow)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Icon(LucideIcons.dot, size: 18, color: color),
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: shadcn.Text(point).small()),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.destructive.withValues(
                      alpha: 0.08,
                    ),
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                    border: Border.all(
                      color: theme.colorScheme.destructive.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.triangleAlert,
                        size: 16,
                        color: theme.colorScheme.destructive,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: shadcn.Text.rich(
                          TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(
                                text: l10n.academy_envelope_pitfall_label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: envelope.pitfall),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AcademyProgressToggle(
                  progress: _progress,
                  stepId: envelope.id,
                  level: envelope.level,
                ),
                const SizedBox(height: 20),
                const AcademyDisclaimer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En dessous de ce seuil (écran téléphone), une colonne de label
          // fixe à 110px laisse trop peu de place aux valeurs, qui sont
          // souvent des phrases complètes : le label passe au-dessus.
          final narrow = constraints.maxWidth < 340;

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(label).muted().small(),
                const SizedBox(height: 2),
                shadcn.Text(value).medium(),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: shadcn.Text(label).muted().small()),
              Expanded(child: shadcn.Text(value).medium()),
            ],
          );
        },
      ),
    );
  }
}

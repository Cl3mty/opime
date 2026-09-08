import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/ui/frosted_card.dart';

/// Aperçu illustratif de l'écran "Assistant IA" (Opime Premium) : ni vrai
/// client LLM ni contexte financier réel, juste une conversation factice
/// donnant une idée de la fonctionnalité. Affiché figé/flouté par
/// `LockedFeatureScreen` — voir `core/premium/premium_lock.dart`.
class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.mutedForeground;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _bubble(
            context,
            align: Alignment.centerRight,
            text: 'Quelle part de mon patrimoine est investie en actions ?',
          ),
          const SizedBox(height: 12),
          _bubble(
            context,
            align: Alignment.centerLeft,
            icon: LucideIcons.bot,
            text:
                'D\'après votre portefeuille, environ 42 % de votre patrimoine '
                'net est investi en actions et fonds actions, principalement '
                'via votre PEA et votre CTO.',
          ),
          const SizedBox(height: 12),
          _bubble(
            context,
            align: Alignment.centerRight,
            text: 'Et si je réduisais mes versements mensuels de 200 € ?',
          ),
          const SizedBox(height: 24),
          Icon(LucideIcons.messageCircle, size: 18, color: mutedColor),
        ],
      ),
    );
  }

  Widget _bubble(
    BuildContext context, {
    required Alignment align,
    required String text,
    IconData? icon,
  }) {
    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: 8),
                ],
                Flexible(child: shadcn.Text(text).small()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

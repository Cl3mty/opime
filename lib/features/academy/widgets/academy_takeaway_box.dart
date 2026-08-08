import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/academy/academy_level.dart';
import '../academy_theme.dart';

/// Encadré "à retenir" mis en valeur — l'essentiel d'une carte de
/// mémorisation en une phrase.
class AcademyTakeawayBox extends StatelessWidget {
  final String text;
  final AcademyLevel level;

  const AcademyTakeawayBox({super.key, required this.text, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Theme.of(context).radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.sparkles, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: shadcn.Text.rich(
              TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  const TextSpan(text: 'À retenir — ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

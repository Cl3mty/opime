import 'dart:ui' as ui;

import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:url_launcher/url_launcher.dart';
import '../ui/frosted_card.dart';
import 'premium_lock.dart';

/// Aperçu figé d'une fonctionnalité réservée à Opime Premium.
///
/// Construit la vraie page ([pageBuilder]) — avec les données réelles du
/// coffre-fort actif — pour donner une idée fidèle du rendu réel, mais la
/// rend inerte (`IgnorePointer`) et l'assombrit/floute derrière un panneau
/// central qui explique la limitation et propose de passer à la version
/// payante. Utilisé depuis `main.dart` pour envelopper chaque page listée
/// dans [premiumLockedKeys].
class LockedFeatureScreen extends StatelessWidget {
  final WidgetBuilder pageBuilder;
  final String title;
  final String description;

  const LockedFeatureScreen({
    super.key,
    required this.pageBuilder,
    required this.title,
    required this.description,
  });

  Future<void> _openUpgradeUrl() {
    return launchUrl(
      Uri.parse(premiumUpgradeUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Opacity(opacity: 0.45, child: pageBuilder(context)),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.background.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: FrostedCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.lock,
                        size: 28,
                        color: theme.colorScheme.mutedForeground,
                      ),
                      const SizedBox(height: 12),
                      shadcn.Text(
                        title,
                        textAlign: TextAlign.center,
                      ).large().semiBold(),
                      const SizedBox(height: 8),
                      shadcn.Text(
                        description,
                        textAlign: TextAlign.center,
                      ).muted().small(),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        onPressed: _openUpgradeUrl,
                        leading: const Icon(LucideIcons.sparkles, size: 16),
                        child: const shadcn.Text('Passer à Opime Premium'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

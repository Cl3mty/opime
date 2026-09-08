import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'app_background.dart';

/// Écran de chargement générique de l'app — logo Opime, indicateur
/// d'activité et message optionnel, sur le même fond que le reste de l'app
/// ([AppBackground]) plutôt qu'un simple spinner sur fond nu. Affiché aux
/// quelques points où l'app attend une opération asynchrone avant de
/// pouvoir montrer autre chose (vault en cours de résolution, profils en
/// cours de chargement) — particulièrement visible sur le web juste après
/// la création/le choix d'un coffre-fort, où cette attente est la première
/// chose qu'un nouvel utilisateur voit.
class AppLoadingScreen extends StatelessWidget {
  final String? message;

  const AppLoadingScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message!, textAlign: TextAlign.center).small().muted(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

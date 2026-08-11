import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/ui/frosted_card.dart';

/// Boîte de dialogue de confirmation avant une suppression irréversible
/// (compte, investissement, transaction) — retourne `true` si l'utilisateur
/// confirme, `false` sinon (annulé ou fermé sans choisir).
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(title).large().semiBold(),
                const SizedBox(height: 8),
                shadcn.Text(message).muted().small(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    DestructiveButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const shadcn.Text('Supprimer'),
                    ),
                    const SizedBox(width: 8),
                    OutlineButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const shadcn.Text('Annuler'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

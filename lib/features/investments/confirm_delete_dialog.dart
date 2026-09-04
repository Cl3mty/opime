import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/ui/frosted_card.dart';
import '../../l10n/app_localizations.dart';

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
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return Center(
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
                      child: shadcn.Text(l10n.common_delete),
                    ),
                    const SizedBox(width: 8),
                    OutlineButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: shadcn.Text(l10n.common_cancel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ));
    },
  );
  return result ?? false;
}

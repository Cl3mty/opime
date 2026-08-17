import 'dart:io' show Platform;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator;

/// Les raccourcis clavier globaux de l'application — actionnés par
/// `AppShell` (via `CallbackShortcuts`, voir son `_wrapWithShortcuts`) et
/// listés dans les Réglages (`settings_screen.dart`'s `_ShortcutsCard`).
/// Un seul endroit pour la combinaison de touches de chaque action évite
/// que les deux se désynchronisent. Combinaisons fixes (pas de remapping) :
/// Cmd sur macOS, Ctrl sur Windows/Linux.
enum AppShortcutAction {
  toggleSidebar(
    label: 'Basculer la barre latérale',
    description: 'Affiche ou masque la barre de navigation.',
    key: LogicalKeyboardKey.keyB,
  ),
  toggleAmountsHidden(
    label: 'Masquer les montants',
    description:
        'Bascule l\'affichage des montants (utile en partage d\'écran).',
    key: LogicalKeyboardKey.keyH,
  ),
  exportPdf(
    label: 'Exporter en PDF',
    description: 'Ouvre l\'export du patrimoine en PDF.',
    key: LogicalKeyboardKey.keyP,
  );

  final String label;
  final String description;
  final LogicalKeyboardKey key;

  const AppShortcutAction({
    required this.label,
    required this.description,
    required this.key,
  });

  SingleActivator get activator =>
      SingleActivator(key, meta: Platform.isMacOS, control: !Platform.isMacOS);

  /// Représentation textuelle affichée dans les Réglages — "⌘B" sur macOS,
  /// "Ctrl+B" sur Windows/Linux.
  String get displayLabel =>
      Platform.isMacOS ? '⌘${key.keyLabel}' : 'Ctrl+${key.keyLabel}';
}

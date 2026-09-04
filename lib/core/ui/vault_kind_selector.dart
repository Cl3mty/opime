import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:opime/l10n/app_localizations.dart';
import '../storage/vault_folder_service.dart' show VaultKind;
import 'frosted_card.dart';
import 'toggle_button_style.dart';

/// Libellé localisé d'un [VaultKind] — `VaultKind.label` (défini dans
/// `vault_folder_service.dart`, hors périmètre i18n car réutilisé ailleurs
/// tel quel) reste fixé en français ; ce sélecteur affiche donc sa propre
/// traduction plutôt que ce libellé brut. `nav_professional` est réutilisé
/// pour "Professionnel" : même mot que le libellé du groupe de navigation
/// "Entités" ([entitesGroup] dans `nav_models.dart`), déjà traduit.
String _kindLabel(BuildContext context, VaultKind kind) {
  final l10n = AppLocalizations.of(context);
  return switch (kind) {
    VaultKind.personal => l10n.core_ui_vault_kind_personal,
    VaultKind.professional => l10n.nav_professional,
  };
}

const _toggleButtonSize = ButtonSize(0.9);

/// Sélecteur "Personnel / Professionnel" affiché à la création d'un
/// coffre-fort (voir [VaultKind]) — réutilisé par `OnboardingScreen`
/// (premier coffre-fort) et `SettingsScreen` (bouton "Ajouter un
/// coffre-fort"). Même patron de bascule que le toggle Actifs/Passifs de
/// `features/dashboard/widgets/allocation_card.dart`.
class VaultKindSelector extends StatelessWidget {
  final VaultKind value;
  final ValueChanged<VaultKind> onChanged;

  const VaultKindSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ButtonGroup(
      children: [
        for (final kind in VaultKind.values)
          SelectedButton(
            value: value == kind,
            selectedStyle: const ButtonStyle.primary(size: _toggleButtonSize),
            style: toggleUnselectedStyle(context, size: _toggleButtonSize),
            onChanged: (_) => onChanged(kind),
            child: shadcn.Text(_kindLabel(context, kind)),
          ),
      ],
    );
  }
}

/// Boîte de dialogue "Personnel ou professionnel ?" affichée avant
/// d'ouvrir le sélecteur de dossier natif pour un nouveau coffre-fort
/// (voir `SettingsScreen`'s bouton "Ajouter un coffre-fort" —
/// `OnboardingScreen`, elle, affiche [VaultKindSelector] directement dans
/// son propre écran plutôt que dans une boîte de dialogue séparée).
/// Retourne `null` si l'utilisateur annule.
Future<VaultKind?> showVaultKindDialog(BuildContext context) {
  return showDialog<VaultKind>(
    context: context,
    builder: (context) => _VaultKindDialog(),
  );
}

class _VaultKindDialog extends StatefulWidget {
  @override
  State<_VaultKindDialog> createState() => _VaultKindDialogState();
}

class _VaultKindDialogState extends State<_VaultKindDialog> {
  VaultKind _kind = VaultKind.personal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(l10n.core_ui_new_vault_title).large().semiBold(),
                const SizedBox(height: 8),
                shadcn.Text(l10n.core_ui_new_vault_kind_prompt).muted().small(),
                const SizedBox(height: 12),
                VaultKindSelector(
                  value: _kind,
                  onChanged: (kind) => setState(() => _kind = kind),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    PrimaryButton(
                      onPressed: () => Navigator.of(context).pop(_kind),
                      child: shadcn.Text(l10n.common_continue),
                    ),
                    const SizedBox(width: 8),
                    OutlineButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: shadcn.Text(l10n.common_cancel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

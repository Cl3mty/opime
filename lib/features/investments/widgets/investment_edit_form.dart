import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/ui/frosted_card.dart';
import '../investment_identifier_field.dart';
import '../investments_models.dart';

/// Champ(s) d'identification d'une nouvelle position — un bien immobilier
/// n'a qu'un nom (pas d'identifiant), un actif à liste déroulante connue
/// (métaux physiques, épargne en devise, crypto) n'a besoin que du champ
/// identifiant (le libellé en découle automatiquement), tout le reste a
/// besoin des deux : identifiant libre (ISIN...) et libellé séparé — voir
/// [requiresLabelFieldFor]. Sans bouton propre : utilisé aussi bien pour
/// créer un investissement seul (`account_detail_screen.dart`'s
/// `_CreateInvestmentForm`) que pour créer une position en même temps que
/// sa première transaction (`stock_account/add_transaction_dialog.dart`).
class InvestmentIdentityFields extends StatelessWidget {
  final AssetClass assetClass;
  final AccountEnvelope? accountEnvelope;
  final TextEditingController isinController;
  final TextEditingController labelController;

  const InvestmentIdentityFields({
    super.key,
    required this.assetClass,
    this.accountEnvelope,
    required this.isinController,
    required this.labelController,
  });

  @override
  Widget build(BuildContext context) {
    if (assetClass == AssetClass.immobilier) {
      return TextField(
        controller: labelController,
        placeholder: const shadcn.Text('Nom du bien (ex: Appartement Lyon 6e)'),
      );
    }
    if (!requiresLabelFieldFor(assetClass, accountEnvelope: accountEnvelope)) {
      // Liste déroulante connue (métaux physiques, épargne en devise,
      // crypto) : le libellé découle de la sélection, inutile de le
      // demander séparément.
      return InvestmentIdentifierField(
        assetClass: assetClass,
        accountEnvelope: accountEnvelope,
        isinController: isinController,
        labelController: labelController,
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: labelController,
            placeholder: const shadcn.Text('Libellé (ex: TotalEnergies)'),
            // Le libellé d'abord, l'identifiant ensuite : on connaît
            // généralement le nom d'un titre avant son ISIN, plus intuitif à
            // saisir dans cet ordre.
            autofocus: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InvestmentIdentifierField(
            assetClass: assetClass,
            accountEnvelope: accountEnvelope,
            isinController: isinController,
            labelController: labelController,
            autofocus: false,
          ),
        ),
      ],
    );
  }
}

/// Formulaire d'édition de l'identifiant et du libellé d'un investissement
/// — mêmes champs que la création d'un investissement, remplis avec les
/// valeurs actuelles. Utilisé par la page d'un investissement
/// (`investment_detail_screen.dart`) et la popup de détail d'une position
/// (`stock_account/position_detail_dialog.dart`).
class InvestmentEditForm extends StatelessWidget {
  final AssetClass assetClass;
  final bool isImmobilier;
  final AccountEnvelope? accountEnvelope;
  final TextEditingController isinController;
  final TextEditingController labelController;
  final FundStyle? fundStyle;
  final ValueChanged<FundStyle?> onFundStyleChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const InvestmentEditForm({
    super.key,
    required this.assetClass,
    this.isImmobilier = false,
    this.accountEnvelope,
    required this.isinController,
    required this.labelController,
    required this.fundStyle,
    required this.onFundStyleChanged,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImmobilier)
              TextField(
                controller: labelController,
                placeholder: const shadcn.Text(
                  'Nom du bien (ex: Appartement Lyon 6e)',
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: labelController,
                      placeholder: const shadcn.Text(
                        'Libellé (ex: TotalEnergies)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InvestmentIdentifierField(
                      assetClass: assetClass,
                      accountEnvelope: accountEnvelope,
                      isinController: isinController,
                      labelController: labelController,
                      autofocus: false,
                    ),
                  ),
                ],
              ),
            if (assetClass == AssetClass.actionsEtFonds) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Select<FundStyle>(
                    value: fundStyle,
                    placeholder: const shadcn.Text('Style de gestion'),
                    onChanged: (style) {
                      if (style != null) onFundStyleChanged(style);
                    },
                    itemBuilder: (context, style) => shadcn.Text(style.label),
                    popup: (context) => SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final style in FundStyle.values)
                            SelectItemButton(
                              value: style,
                              child: shadcn.Text(style.label),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (fundStyle != null) ...[
                    const SizedBox(width: 4),
                    IconButton.ghost(
                      icon: const Icon(LucideIcons.x, size: 14),
                      onPressed: () => onFundStyleChanged(null),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                PrimaryButton(
                  onPressed: onSave,
                  child: const shadcn.Text('Enregistrer'),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  onPressed: onCancel,
                  child: const shadcn.Text('Annuler'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

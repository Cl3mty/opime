import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'investments_models.dart';

/// Champ "identifiant" d'un nouvel investissement, à la création : une
/// liste déroulante pour les classes qui n'ont qu'un nombre limité
/// d'options valides (voir [identifierOptionsFor] — crypto, épargne,
/// métaux précieux), un texte libre sinon (ISIN, ou libellé libre comme
/// une adresse). Choisir une option pré-remplit aussi [labelController]
/// avec le même texte (encore modifiable ensuite), pour ne pas laisser le
/// libellé vide.
class InvestmentIdentifierField extends StatelessWidget {
  final AssetClass assetClass;
  final TextEditingController isinController;
  final TextEditingController labelController;

  /// Enveloppe du compte porteur — un ETC métaux précieux détenu dans un
  /// CTO bascule ce champ en texte libre (vrai ISIN) plutôt que la liste
  /// déroulante de pièces/lingots physiques, voir [identifierOptionsFor].
  final AccountEnvelope? accountEnvelope;

  const InvestmentIdentifierField({
    super.key,
    required this.assetClass,
    required this.isinController,
    required this.labelController,
    this.accountEnvelope,
  });

  @override
  Widget build(BuildContext context) {
    final options = identifierOptionsFor(
      assetClass,
      accountEnvelope: accountEnvelope,
    );
    if (options == null) {
      return TextField(
        controller: isinController,
        placeholder: const shadcn.Text(
          'Identifiant (ISIN, ou libre : adresse, référence...)',
        ),
        autofocus: true,
      );
    }

    // isinController pilote directement le Select (plutôt qu'une variable
    // d'état séparée dans le parent) pour que le texte libre et la liste
    // déroulante partagent la même source de vérité sans rien changer aux
    // deux formulaires qui utilisent ce champ.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: isinController,
      builder: (context, value, _) => Select<String>(
        value: value.text.isEmpty ? null : value.text,
        constraints: const BoxConstraints(minWidth: 200),
        itemBuilder: (context, item) => shadcn.Text(item),
        popup: (context) => SelectPopup(
          items: SelectItemList(
            children: [
              for (final option in options)
                SelectItemButton(value: option, child: shadcn.Text(option)),
            ],
          ),
        ),
        onChanged: (selected) {
          if (selected == null) return;
          isinController.text = selected;
          if (labelController.text.isEmpty) labelController.text = selected;
        },
        placeholder: const shadcn.Text('Choisir...'),
      ),
    );
  }
}

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

  /// Options de la liste déroulante, en remplacement de celles dérivées de
  /// [identifierOptionsFor] quand [assetClass] n'en propose pas — ex : une
  /// devise (EUR, USD...) à créer dans un compte-titres, qui emprunte la
  /// liste de l'épargne (voir [kKnownCurrencies]) sans changer de classe.
  final List<String>? options;

  /// `false` quand un autre champ du même formulaire doit recevoir le focus
  /// initial à la place (ex : "Autres", où le nom précède la référence —
  /// voir `complete_patrimoine_dialog.dart`'s `_InvestmentStep`).
  final bool autofocus;

  const InvestmentIdentifierField({
    super.key,
    required this.assetClass,
    required this.isinController,
    required this.labelController,
    this.accountEnvelope,
    this.options,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final options =
        this.options ??
        identifierOptionsFor(
          assetClass,
          accountEnvelope: accountEnvelope,
        );
    if (options == null) {
      return TextField(
        controller: isinController,
        // "Autres" (montres, voitures de collection, art...) n'a pas
        // d'identifiant financier (ISIN) : "référence" couvre un numéro de
        // série ou une référence de fabricant. Un fonds PEE/PEG/PER (FCPE
        // ou unité de compte interne à l'entreprise/au contrat, voir
        // [isinOptionalFor]) n'a souvent pas d'ISIN public non plus, pas
        // plus qu'un club deal/FCPR de Private Equity (aucun ISIN pour une
        // participation non cotée — seul le nom du fonds, déjà saisi dans
        // le libellé, l'identifie). Tous restent facultatifs — voir
        // `_commitCreateInvestment`, qui en génère un si laissé vide.
        placeholder: shadcn.Text(
          assetClass == AssetClass.autres
              ? 'Référence (optionnelle : numéro de série, référence...)'
              : assetClass == AssetClass.privateEquity
              ? 'Identifiant (optionnel : laisse vide si le fonds n\'en a pas)'
              : assetClass == AssetClass.actionsEtFonds &&
                    isinOptionalFor(assetClass, accountEnvelope: accountEnvelope)
              ? 'ISIN (optionnel : laisse vide si le fonds n\'en a pas)'
              : 'Identifiant (ISIN, ou libre : adresse, référence...)',
        ),
        autofocus: autofocus,
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

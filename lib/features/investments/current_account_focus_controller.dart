import 'package:flutter/foundation.dart';
import 'investments_models.dart' show AssetClass;

/// Compte (et éventuellement investissement) actuellement affiché en plein
/// cadre par une page de détail (`StockAccountScreen`, `AccountDetailView`,
/// `InvestmentDetailView` — voir `real_category_detail_screen.dart`, qui
/// tient à jour cette valeur). Lu (jamais écouté) par [AddMenuButton] au
/// moment d'ouvrir le flux "Compléter mon patrimoine" : présélectionner ce
/// compte/investissement plutôt que de le faire rechoisir depuis zéro quand
/// l'utilisateur est déjà dessus. `null` en dehors de ces pages (Dashboard,
/// liste d'une catégorie sans compte sélectionné...).
class CurrentAccountFocusController extends ValueNotifier<AccountFocus?> {
  CurrentAccountFocusController() : super(null);
}

typedef AccountFocus = ({
  AssetClass assetClass,
  String accountId,
  String? investmentId,
});

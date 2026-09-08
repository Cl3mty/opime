import 'package:flutter/foundation.dart';

/// Signal minimal (pas d'état porté, juste `notifyListeners()`) pour
/// prévenir le Dashboard qu'il doit recharger ses comptes réels après une
/// écriture faite ailleurs dans l'app — typiquement depuis le flux
/// "Compléter mon patrimoine" de la TopBar, globale et donc découplée du
/// widget Dashboard qui affiche les cartes à rafraîchir.
class PatrimoineRefreshController extends ChangeNotifier {
  void notifyChanged() => notifyListeners();
}

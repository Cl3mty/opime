import 'package:flutter/foundation.dart';

/// Signale, à l'échelle de l'app, qu'aucune donnée réelle n'existe encore
/// pour le profil actif (aucun compte, aucun investissement, aucun
/// passif) — mis à jour par le Dashboard (`dashboard_screen.dart`) après
/// chargement, lu par le bouton "+ Compléter mon patrimoine" de la TopBar
/// (`navigation/top_bar_actions.dart`) pour se mettre en valeur, et par le
/// Dashboard lui-même pour afficher un conseil de démarrage à la place des
/// cartes (qui n'auraient de toute façon rien à montrer).
///
/// Toujours `false` sur le profil de démonstration ("Lou") : voir
/// `_RealDashboard`'s `dispose()`, qui réinitialise le drapeau en quittant
/// un profil réel, pour ne jamais le laisser actif par erreur en revenant
/// sur Lou.
class OnboardingHighlightController extends ChangeNotifier {
  bool _isEmpty = false;
  bool get isEmpty => _isEmpty;

  void setEmpty(bool value) {
    if (_isEmpty == value) return;
    _isEmpty = value;
    notifyListeners();
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// SystemChrome.setPreferredOrientations n'a d'effet réel que sur
/// iOS/Android : sur desktop/web, l'orientation de la fenêtre n'a pas de
/// sens, donc toute la logique de verrouillage ci-dessous se limite à ces
/// deux plateformes.
bool get isMobileOrientationPlatform =>
    !kIsWeb && (Platform.isIOS || Platform.isAndroid);

const _portraitOnly = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
];

const _allOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Verrouille l'app en mode portrait : comportement par défaut sur mobile
/// (appelé au démarrage), et à restaurer par tout écran qui a
/// temporairement autorisé le paysage via [allowLandscapeOnMobile] quand
/// il est quitté.
void lockPortraitOnMobile() {
  if (isMobileOrientationPlatform) {
    SystemChrome.setPreferredOrientations(_portraitOnly);
  }
}

/// Autorise temporairement la rotation en paysage sur mobile, réservé aux
/// écrans où c'est explicitement utile (ex : ventilation du budget, dont
/// le graphique de flux a besoin de largeur). Toujours annulé via
/// [lockPortraitOnMobile] à la sortie de l'écran.
void allowLandscapeOnMobile() {
  if (isMobileOrientationPlatform) {
    SystemChrome.setPreferredOrientations(_allOrientations);
  }
}

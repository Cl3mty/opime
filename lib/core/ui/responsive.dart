import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Seuil (en dp) en dessous duquel l'app bascule sur sa mise en page mobile
/// (barre d'onglets en bas, `AppBar` compacte) plutôt que la sidebar
/// desktop. Partagé entre `AppShell` et les écrans qui doivent adapter leur
/// contenu au même seuil (ex : Réglages, qui masque les sections sans
/// équivalent mobile).
const kWideLayoutBreakpoint = 800.0;

/// `shortestSide` (et non `width`) sur mobile/desktop natif : reste stable
/// quelle que soit l'orientation d'un téléphone donné, contrairement à
/// `width` qui dépasse 800 en paysage sur un iPhone large. Une vraie
/// tablette garde un `shortestSide >= 800` dans les deux orientations.
///
/// Sur le web en revanche, `shortestSide` est le mauvais critère : une
/// fenêtre de navigateur ne "tourne" jamais comme un téléphone, mais est
/// couramment plus large que haute (ex. 1280×720) — `shortestSide` y vaut
/// alors la HAUTEUR, qui descend très vite sous 800 et faisait basculer
/// l'app en mise en page mobile/tablette même sur une large fenêtre de
/// bureau. Le web utilise donc la largeur seule, comme n'importe quel site
/// responsive.
bool isWideLayout(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return kIsWeb
      ? size.width >= kWideLayoutBreakpoint
      : size.shortestSide >= kWideLayoutBreakpoint;
}

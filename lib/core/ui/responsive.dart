import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Seuil (en dp) en dessous duquel l'app bascule sur sa mise en page mobile
/// (barre d'onglets en bas, `AppBar` compacte) plutôt que la sidebar
/// desktop. Partagé entre `AppShell` et les écrans qui doivent adapter leur
/// contenu au même seuil (ex : Réglages, qui masque les sections sans
/// équivalent mobile).
const kWideLayoutBreakpoint = 800.0;

/// `shortestSide` (et non `width`) : reste stable quelle que soit
/// l'orientation d'un téléphone donné, contrairement à `width` qui dépasse
/// 800 en paysage sur un iPhone large. Une vraie tablette garde un
/// `shortestSide >= 800` dans les deux orientations.
bool isWideLayout(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= kWideLayoutBreakpoint;

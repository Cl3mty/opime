import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Vrai uniquement sur les plateformes desktop réellement supportées
/// (macOS, Windows, Linux) — jamais web, iOS ou Android, même sur une
/// tablette dont la largeur d'écran déclenche par ailleurs la mise en page
/// "large" (sidebar). Sert à réserver des fonctionnalités au poste de
/// travail (window_manager, l'Assistant...), indépendamment de la largeur.
bool get isDesktopPlatform =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

/// Mise à jour de l'URL affichée par le navigateur sans recharger la page —
/// voir `main.dart`'s bascule entre la landing page (`/`) et l'app (`/home`).
/// Sans effet hors web (voir `web_navigation_io.dart`).
library;

import 'web_navigation_io.dart'
    if (dart.library.js_interop) 'web_navigation_web.dart'
    as platform;

/// Remplace l'URL courante par [path] sans recharger la page ni ajouter
/// d'entrée dans l'historique (`history.replaceState`) — volontaire : passer
/// de la landing page à l'app n'est pas une "vraie" navigation que
/// l'utilisateur voudrait annuler avec le bouton retour du navigateur.
void replaceUrlPath(String path) => platform.replaceUrlPath(path);

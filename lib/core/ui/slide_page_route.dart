import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Route avec une animation de glissement depuis la droite, utilisée en
/// navigation mobile pour passer d'une page "liste" (ex: notes de
/// stratégie, historique de budget) à une page "détail" plein écran, avec
/// un bouton retour dans l'[AppBar] de la page poussée.
Route<T> slidePageRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: offsetAnimation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 260),
  );
}

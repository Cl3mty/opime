import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Expose la fonction de navigation entre pages (même sémantique que
/// `_select` dans `AppShell`) aux widgets descendants du contenu de page,
/// pour qu'un widget profondément imbriqué (ex : une ligne de catégorie
/// sur le Dashboard) puisse déclencher un changement de page sans que
/// l'appelant n'ait à faire transiter un callback à travers chaque
/// constructeur intermédiaire.
///
/// [dashboardEpoch] s'incrémente à chaque sélection du poste "Tableau de
/// bord" de la sidebar, y compris quand il est déjà actif : une page qui
/// gère elle-même un drill-down local (ex : comptes de placement réels,
/// sans passer par un `Navigator.push`) peut s'y abonner pour revenir à sa
/// racine quand l'utilisateur reclique "Tableau de bord" alors qu'il est
/// déjà dessus — un simple changement de clé de page ne suffit pas dans ce
/// cas, puisque le widget n'est alors pas remonté.
class NavigationScope extends InheritedWidget {
  final ValueChanged<String> onSelect;
  final int dashboardEpoch;

  const NavigationScope({
    super.key,
    required this.onSelect,
    required this.dashboardEpoch,
    required super.child,
  });

  static ValueChanged<String>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NavigationScope>()
        ?.onSelect;
  }

  static int dashboardEpochOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<NavigationScope>()
            ?.dashboardEpoch ??
        0;
  }

  @override
  bool updateShouldNotify(NavigationScope oldWidget) =>
      onSelect != oldWidget.onSelect ||
      dashboardEpoch != oldWidget.dashboardEpoch;
}

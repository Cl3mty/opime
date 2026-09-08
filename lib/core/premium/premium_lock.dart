import '../../features/academy/formation_data.dart' show formationTracks;

/// Clés de navigation ([NavItem.key] / clé de `pages` dans `main.dart`)
/// réservées à Opime Premium dans cette édition gratuite et open-source.
///
/// Elles restent visibles dans la navigation (griséées, voir
/// `app_sidebar.dart`/`mobile_nav_hub.dart`) : un clic dessus affiche un
/// aperçu figé de la vraie page plutôt que de la masquer complètement, voir
/// [LockedFeatureScreen] dans `locked_feature_screen.dart`.
///
/// Tout le reste (Tableau de bord, Placements/Dettes sans limite de nombre
/// de comptes ni de classes d'actifs, Budget, Stratégie, Simulation,
/// Académie > Fondamentaux/Enveloppes) reste entièrement gratuit et
/// débloqué.
final Set<String> premiumLockedKeys = {
  'analyses',
  'projets',
  // Entités (holdings, sociétés commerciales, SCI) — "comptes pro" : pas de
  // groupe de navigation dédié (voir `app_sidebar.dart`), atteint depuis le
  // bouton "Gérer les entités" du Dashboard (`entities_overview_section
  // .dart`).
  'entites',
  'assistant',
  // Le groupe "Formation" de l'Académie n'a pas de page propre (seuls ses
  // enfants — les parcours ci-dessous — en ont une), mais sa clé sert à
  // griser l'entrée dans la sidebar/le hub mobile.
  'formation',
  for (final track in formationTracks) track.id,
};

bool isPremiumLocked(String key) => premiumLockedKeys.contains(key);

/// URL ouverte par le bouton "Passer à Opime Premium" affiché sur les
/// aperçus figés des fonctionnalités verrouillées.
const premiumUpgradeUrl = 'https://opime.vercel.app';

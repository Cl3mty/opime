import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, Color;
import '../dashboard/patrimoine_models.dart';
import 'entities_models.dart';

/// Identifiant de catégorie de la valeur nette détenue via les entités
/// professionnelles — réutilise volontairement la même clé que la page
/// `main.dart` enregistre pour `EntitiesScreen` : cliquer la catégorie
/// depuis `AllocationCard`/`CategoryBreakdownCard` (qui route via
/// `NavigationScope.call(category.id)`) ouvre directement l'écran dédié,
/// sans route supplémentaire à déclarer.
const kEntitiesCategoryId = 'entites';

/// Adapte les entités professionnelles (`BusinessEntity`, un coffre-fort
/// pro uniquement) vers le modèle générique du Dashboard
/// (`dashboard/patrimoine_models.dart`) pour qu'elles apparaissent comme
/// une catégorie de patrimoine à part entière (Allocation, répartition
/// Actifs du Dashboard) — voir [dashboard_screen.dart]'s `_loadFromDisk`,
/// qui n'appelle cette fonction que pour un coffre-fort `VaultKind
/// .professional`.
///
/// Chaque entité devient une ligne dont la valeur est [BusinessEntity.
/// ownedNetValue] (déjà nette du passif propre de l'entité ET pondérée par
/// le pourcentage de détention) — pas de catégorie Passifs miroir : ce
/// serait compter une seconde fois une dette déjà nettée dans [BusinessEntity
/// .netValue]. Sans historique de valorisation (une entité n'a que des
/// lignes actif/passif figées, pas de série temporelle) : ni `pru` ni
/// `periodChangeFor`/`periodPnlFor`, dégradant proprement en "—" comme un
/// compte sans historique aujourd'hui — cette catégorie alimente donc les
/// totaux instantanés du Dashboard mais pas la courbe "Patrimoine net" dans
/// le temps.
PatrimoineCategory buildEntitiesCategory(List<BusinessEntity> entities) {
  return PatrimoineCategory(
    id: kEntitiesCategoryId,
    label: 'Entités professionnelles',
    icon: LucideIcons.building2,
    // Sarcelle : seule couleur de `_categoryMeta` (real_patrimoine_adapter
    // .dart) pas déjà prise par les 7 classes réelles.
    color: const Color(0xFF14B8A6),
    tier: AllocationTier.opportuniste,
    description:
        'Holdings, sociétés commerciales, SCI et comptes pro détenus, au '
        'prorata de votre pourcentage de détention dans chacun.',
    accounts: [
      for (final entity in entities)
        PatrimoineAccount(
          id: entity.id,
          name: entity.name,
          subtitle: entity.type.label,
          valeur: entity.ownedNetValue,
          plusValueAbs: null,
          plusValuePercent: null,
        ),
    ],
  );
}

import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, Color;
import '../dashboard/patrimoine_models.dart';
import '../investments/investments_models.dart' show InvestmentAccount;
import '../liabilities/liabilities_models.dart' show Liability;
import 'entities_models.dart';

/// Identifiant de catégorie de la valeur nette détenue via les entités
/// professionnelles — réutilise volontairement la même clé que la page
/// `main.dart` enregistre pour `EntitiesScreen` : cliquer la catégorie
/// depuis `AllocationCard`/`CategoryBreakdownCard` (qui route via
/// `NavigationScope.call(category.id)`) ouvre directement l'écran dédié,
/// sans route supplémentaire à déclarer.
const kEntitiesCategoryId = 'entites';

/// Valeur nette PROPRE d'une entité (avant pondération par sa détention) —
/// somme de la valeur de marché de ses comptes ([InvestmentAccount
/// .totalMarketValue]/[InvestmentAccount.totalLeveragedValue], filtrés par
/// [InvestmentAccount.entityId]) moins le capital restant dû de ses passifs
/// ([Liability.remainingBalance], filtrés par [Liability.entityId]) — les
/// mêmes comptes/passifs réels que le patrimoine personnel, simplement
/// rattachés à cette entité plutôt qu'à aucune. Une entité elle-même ne
/// porte plus aucune donnée financière (voir la doc de tête de
/// `entities_models.dart`) : cette fonction est la seule source de vérité
/// pour "combien vaut cette entité", partagée par [buildEntitiesCategory]
/// et `entities_screen.dart`'s affichage, pour que les deux restent
/// toujours cohérents entre eux.
double entityNetValue(
  String entityId,
  List<InvestmentAccount> accounts,
  List<Liability> liabilities,
) {
  final grossAssets = accounts
      .where((a) => a.entityId == entityId)
      .fold(0.0, (sum, a) => sum + a.totalMarketValue + a.totalLeveragedValue);
  final grossLiabilities = liabilities
      .where((l) => l.entityId == entityId)
      .fold(0.0, (sum, l) => sum + l.remainingBalance);
  return grossAssets - grossLiabilities;
}

/// Adapte les entités professionnelles (`BusinessEntity`, un coffre-fort
/// pro uniquement) vers le modèle générique du Dashboard
/// (`dashboard/patrimoine_models.dart`) pour qu'elles apparaissent comme
/// une catégorie de patrimoine à part entière (Allocation, répartition
/// Actifs du Dashboard) — voir [dashboard_screen.dart]'s `_loadFromDisk`,
/// qui n'appelle cette fonction que pour un coffre-fort `VaultKind
/// .professional`, avec [accounts]/[liabilities] déjà filtrés à
/// `entityId != null` (les comptes/passifs personnels du même coffre-fort
/// passent par `real_patrimoine_adapter.dart`/`real_passifs_adapter.dart`
/// à la place, filtrés à `entityId == null`).
///
/// Chaque entité devient une ligne dont la valeur est sa part *diluée*
/// jusqu'à l'utilisateur ([effectiveOwnedNetValue], qui remonte toute la
/// chaîne de [BusinessEntity.parentEntityId]) — sur sa valeur nette propre
/// ([entityNetValue], déjà nette de ses propres passifs). Pas de catégorie
/// Passifs miroir : ce serait compter une seconde fois une dette déjà
/// nettée. Une filiale liée à un holding et le holding lui-même restent
/// deux lignes distinctes portant chacune leurs propres comptes/passifs
/// (disjoints, chacun ayant son propre `entityId`) : sommer leurs valeurs
/// diluées ne double-compte donc rien.
PatrimoineCategory buildEntitiesCategory(
  List<BusinessEntity> entities,
  List<InvestmentAccount> accounts,
  List<Liability> liabilities,
) {
  final effectivePercents = effectiveOwnershipPercents(entities);
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
        'prorata de votre pourcentage de détention réellement diluée '
        'jusqu\'à vous (y compris via les liens holding → filiale).',
    accounts: [
      for (final entity in entities)
        PatrimoineAccount(
          id: entity.id,
          name: entity.name,
          subtitle: entity.type.label,
          valeur: effectiveOwnedNetValue(
            entity.id,
            entityNetValue(entity.id, accounts, liabilities),
            effectivePercents,
          ),
          plusValueAbs: null,
          plusValuePercent: null,
        ),
    ],
  );
}

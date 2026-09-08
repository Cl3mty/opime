import '../dashboard/patrimoine_models.dart';
import '../investments/investments_models.dart' show InvestmentAccount;
import '../investments/real_patrimoine_adapter.dart'
    show
        buildRealCategories,
        buildRealCategoriesByAccount,
        earliestOfDates,
        earliestTransactionDateAcrossAccounts;
import '../investments/yahoo_finance_client.dart' show PricePoint;
import '../liabilities/liabilities_models.dart' show Liability;
import '../liabilities/real_passifs_adapter.dart'
    show buildRealPassifCategories, earliestLiabilityStart;
import 'entities_models.dart';

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

/// Une entité, prête à afficher comme sa propre section du Dashboard
/// (voir `dashboard/widgets/entities_overview_section.dart`) : ses Placements
/// et ses Dettes, construits avec les mêmes fonctions que pour le
/// patrimoine personnel (`real_patrimoine_adapter.dart`/
/// `real_passifs_adapter.dart`), juste appliquées aux comptes/passifs
/// filtrés sur `entityId == entity.id` plutôt que `== null` — voir
/// [buildEntityDashboardSections].
///
/// [avoirsByAccount]/[avoirsByInvestment] utilisent les variantes NON
/// paddées (`buildRealCategories`/`buildRealCategoriesByAccount`, pas leurs
/// équivalents `buildAllReal...`) : une entité n'a en général qu'une ou
/// deux classes d'actifs réellement utilisées (ex. une SCI n'a que de
/// l'immobilier) — lui montrer les 7 classes d'actif réelles, vides pour
/// la plupart, comme le Dashboard personnel le fait volontairement, ne
/// ferait que noyer sa carte.
class EntityDashboardData {
  final BusinessEntity entity;

  /// Toutes les entités du coffre-fort, par id — pour résoudre le nom du
  /// (ou des) propriétaire(s) de [entity] (voir `entityOwnershipSummary`
  /// dans `entity_ownership_summary.dart`, qui décrit toutes les parts de
  /// [BusinessEntity.stakes], pas un unique parent).
  final Map<String, BusinessEntity> entitiesById;

  /// Valeur nette PROPRE de l'entité (voir [entityNetValue]), avant
  /// pondération par [effectivePercent].
  final double netValue;

  /// Part réellement détenue par l'utilisateur une fois toute la chaîne de
  /// liens de possession prise en compte (voir [effectiveOwnershipPercents]).
  final double effectivePercent;
  final List<PatrimoineCategory> avoirsByAccount;
  final List<PatrimoineCategory> avoirsByInvestment;
  final List<PatrimoineCategory> dettes;

  /// Comptes/passifs PROPRES à l'entité (déjà filtrés par `entityId`), et
  /// [earliest] la date la plus ancienne parmi eux — conservés à l'état
  /// brut (pas seulement les [PatrimoineCategory] qui en découlent) pour
  /// que `EntitiesOverviewSection`/`EntityDetailScreen` puissent recalculer
  /// l'historique "Patrimoine net" de cette entité à la demande (voir
  /// `real_patrimoine_adapter.dart`'s `assetClassHistoriesFor`), à chaque
  /// changement de période, sans relire le disque — même principe que
  /// `dashboard_screen.dart`'s `_accounts`/`_liabilities`/`_earliest` côté
  /// personnel.
  final List<InvestmentAccount> accounts;
  final List<Liability> liabilities;
  final Map<String, List<PricePoint>> priceHistories;
  final DateTime? earliest;

  const EntityDashboardData({
    required this.entity,
    required this.entitiesById,
    required this.netValue,
    required this.effectivePercent,
    required this.avoirsByAccount,
    required this.avoirsByInvestment,
    required this.dettes,
    required this.accounts,
    required this.liabilities,
    required this.priceHistories,
    required this.earliest,
  });
}

/// Construit la section Dashboard de chaque entité — une par entité, dans
/// l'ordre hiérarchique de [orderedEntityHierarchy] (tête, puis
/// descendantes). [accounts]/[liabilities] sont la liste COMPLÈTE du
/// coffre-fort (pas encore filtrée par entité) : le filtrage sur
/// `entityId == entity.id` se fait ici, entité par entité — même principe
/// que le filtrage `entityId == null` déjà fait par l'appelant pour le
/// patrimoine personnel (voir `dashboard_screen.dart`'s `_loadFromDisk`).
List<EntityDashboardData> buildEntityDashboardSections(
  List<BusinessEntity> entities,
  List<InvestmentAccount> accounts,
  List<Liability> liabilities,
  Map<String, List<PricePoint>> priceHistories,
  String vaultPath,
) {
  final effectivePercents = effectiveOwnershipPercents(entities);
  final byId = {for (final e in entities) e.id: e};
  return [
    for (final (entity, _) in orderedEntityHierarchy(entities))
      () {
        final ownAccounts = accounts
            .where((a) => a.entityId == entity.id)
            .toList();
        final ownLiabilities = liabilities
            .where((l) => l.entityId == entity.id)
            .toList();
        final earliest = earliestOfDates(
          earliestTransactionDateAcrossAccounts(ownAccounts),
          earliestLiabilityStart(ownLiabilities),
        );
        return EntityDashboardData(
          entity: entity,
          entitiesById: byId,
          netValue: entityNetValue(entity.id, accounts, liabilities),
          effectivePercent: effectivePercents[entity.id] ?? 100,
          avoirsByAccount: buildRealCategoriesByAccount(
            ownAccounts,
            priceHistories,
            vaultPath,
          ),
          avoirsByInvestment: buildRealCategories(
            ownAccounts,
            priceHistories,
            vaultPath,
          ),
          dettes: buildRealPassifCategories(ownLiabilities),
          accounts: ownAccounts,
          liabilities: ownLiabilities,
          priceHistories: priceHistories,
          earliest: earliest,
        );
      }(),
  ];
}

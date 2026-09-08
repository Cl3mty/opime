import '../../l10n/app_localizations.dart';
import 'entities_models.dart';

/// Résumé lisible de la structure de détention d'une entité — une fragment
/// par part (voir [BusinessEntity.stakes]), joints par une virgule quand il
/// y en a plusieurs (ex. une société détenue à 40 % directement et à 60 %
/// via un holding : "40 % par vous, 60 % via Holding Dupont"). Partagé
/// entre `entities_screen.dart` (`_EntityCard`), `entity_detail_screen.dart`
/// (son en-tête) et `dashboard/widgets/entities_overview_section.dart`
/// (`_EntitySection`) pour rester cohérent partout.
String entityOwnershipSummary(
  AppLocalizations l10n,
  BusinessEntity entity,
  Map<String, BusinessEntity> entitiesById,
) {
  if (entity.stakes.isEmpty) {
    // Ne devrait pas arriver via l'UI (l'éditeur exige au moins une part),
    // mais une entité sans part est traitée comme détenue à 100 % par
    // l'utilisateur, cohérent avec le repli de [primaryOwnerId].
    return l10n.entities_stake_direct(_formatPercent(100));
  }
  return [
    for (final stake in entity.stakes)
      stake.ownerId == null
          ? l10n.entities_stake_direct(_formatPercent(stake.percent))
          : l10n.entities_stake_via_owner(
              _formatPercent(stake.percent),
              entitiesById[stake.ownerId]?.name ??
                  l10n.entities_parent_company_fallback,
            ),
  ].join(', ');
}

/// `true` si la part réellement diluée jusqu'à l'utilisateur ([effectivePercent],
/// voir [effectiveOwnershipPercents]) diffère du total des parts DIRECTEMENT
/// enregistrées sur l'entité (ex. 40 % direct + 60 % via un holding détenu
/// à 80 % : total local 100 %, mais 40 + 60 × 0.8 = 88 % réellement diluée)
/// — seule une part détenue via une autre entité peut créer cet écart.
bool entityOwnershipIsDiluted(BusinessEntity entity, double effectivePercent) {
  final localTotal = entity.stakes.fold<double>(0, (sum, s) => sum + s.percent);
  return (effectivePercent - localTotal).abs() > 0.01;
}

String _formatPercent(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart' show displayEuros;
import '../../../core/premium/premium_lock.dart';
import '../../../core/ui/frosted_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../entities/entities_models.dart' show BusinessEntity;
import '../../entities/entities_patrimoine_adapter.dart' show EntityDashboardData;
import '../../entities/entity_ownership_summary.dart';
import '../../investments/real_patrimoine_adapter.dart'
    show assetClassHistoriesFor;
import '../../investments/real_patrimoine_card.dart';
import '../../liabilities/real_passifs_adapter.dart' show totalPassifHistoryFor;
import '../../navigation/navigation_scope.dart';
import '../patrimoine_models.dart';
import 'allocation_card.dart';
import 'category_breakdown_card.dart';

/// Section "Entités professionnelles" du Dashboard : plus de catégorie
/// unique regroupant toutes les entités en une seule ligne (voir l'ancien
/// `buildEntitiesCategory`, retiré) — chaque entité obtient sa propre carte
/// Placements/Dettes complète, empilée sous celle de "Moi-même" (voir
/// `dashboard_screen.dart`, qui garde cette dernière inchangée). Le bouton
/// "Gérer les entités" (création, édition du %/du parent, suppression,
/// schéma de la structure — voir `entities_screen.dart`) reste toujours
/// visible, y compris avant la toute première entité : aucune autre nav
/// n'y mène (voir `app_sidebar.dart`, qui ne rend plus de groupe Entités
/// dédié).
class EntitiesOverviewSection extends StatelessWidget {
  final List<EntityDashboardData> entities;
  final bool hidden;

  /// Ouvre le détail d'une entité en local (voir `dashboard_screen.dart`'s
  /// `_openEntityDetail`) — déclenché par un clic sur une catégorie de sa
  /// carte Placements/Dettes (voir `CategoryBreakdownCard.onCategoryTap`), qui
  /// route ici plutôt que vers la page de catégorie personnelle habituelle.
  final ValueChanged<BusinessEntity> onOpenEntity;

  const EntitiesOverviewSection({
    super.key,
    required this.entities,
    required this.hidden,
    required this.onOpenEntity,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            shadcn.Text(l10n.dashboard_entities_section_title).large().semiBold(),
            OutlineButton(
              onPressed: () => NavigationScope.maybeOf(context)?.call('entites'),
              leading: const Icon(LucideIcons.building2, size: 16),
              // Comptes professionnels réservés à Opime Premium dans cette
              // édition gratuite (voir `core/premium/premium_lock.dart`) —
              // un clic mène quand même à un aperçu figé de la vraie page.
              trailing: isPremiumLocked('entites')
                  ? const Icon(LucideIcons.lock, size: 14)
                  : null,
              child: shadcn.Text(l10n.dashboard_entities_manage_button),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (entities.isEmpty)
          FrostedCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: shadcn.Text(
                      l10n.entities_empty_list_hint,
                    ).muted().small(),
                  ),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    onPressed: () =>
                        NavigationScope.maybeOf(context)?.call('entites'),
                    leading: const Icon(LucideIcons.plus, size: 16),
                    trailing: isPremiumLocked('entites')
                        ? const Icon(LucideIcons.lock, size: 14)
                        : null,
                    child: shadcn.Text(l10n.entities_add_button),
                  ),
                ],
              ),
            ),
          )
        else
          for (final data in entities) ...[
            _EntitySection(
              data: data,
              hidden: hidden,
              onOpen: () => onOpenEntity(data.entity),
            ),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _EntitySection extends StatefulWidget {
  final EntityDashboardData data;
  final bool hidden;
  final VoidCallback onOpen;

  const _EntitySection({
    required this.data,
    required this.hidden,
    required this.onOpen,
  });

  @override
  State<_EntitySection> createState() => _EntitySectionState();
}

class _EntitySectionState extends State<_EntitySection> {
  /// Période de la carte "Patrimoine" de CETTE entité — indépendante de
  /// celle du patrimoine personnel (`dashboard_screen.dart`'s
  /// `_periodIndex`) : chaque entité explore sa propre historique à son
  /// rythme, sans changer le graphique personnel juste au-dessus ni celui
  /// des autres entités. Pilote aussi les colonnes "Évolution"/"+/- value"
  /// des cartes Placements/Dettes juste en dessous — même principe que côté
  /// personnel (un seul sélecteur, sur le graphique, pilote les deux).
  int _periodIndex = 5;

  Map<String, List<NetWorthPoint>> _actifsHistoryFor(DashboardPeriod period) =>
      assetClassHistoriesFor(
        widget.data.accounts,
        widget.data.priceHistories,
        period,
        widget.data.earliest,
      );

  List<NetWorthPoint> _totalPassifHistoryFor(DashboardPeriod period) =>
      totalPassifHistoryFor(widget.data.liabilities, period, widget.data.earliest);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = widget.data;
    final hidden = widget.hidden;
    final entity = data.entity;
    final diluted = entityOwnershipIsDiluted(entity, data.effectivePercent);
    final ownershipLine =
        '${entity.type.label} · '
        '${entityOwnershipSummary(l10n, entity, data.entitiesById)}'
        '${diluted ? ' · ${l10n.entities_card_diluted_suffix(_formatPercent(data.effectivePercent))}' : ''}';
    final period = DashboardPeriod.values[_periodIndex];
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onOpen,
                child: Row(
                  children: [
                    Icon(LucideIcons.building2, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          shadcn.Text(entity.name).medium(),
                          shadcn.Text(ownershipLine).muted().xSmall(),
                        ],
                      ),
                    ),
                    shadcn.Text(
                      displayEuros(
                        data.netValue * data.effectivePercent / 100,
                        hidden,
                      ),
                    ).medium().semiBold(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 800;
                final patrimoineCard = RealPatrimoineCard(
                  actifs: data.avoirsByInvestment,
                  actifsHistoryFor: _actifsHistoryFor,
                  totalPassifHistoryFor: _totalPassifHistoryFor,
                  hidden: hidden,
                  periodIndex: _periodIndex,
                  onPeriodChanged: (i) => setState(() => _periodIndex = i),
                );
                final allocationCard = AllocationCard(
                  actifs: data.avoirsByInvestment,
                  passifs: data.dettes,
                  hidden: hidden,
                );
                if (narrow) {
                  return Column(
                    children: [
                      SizedBox(height: 460, child: patrimoineCard),
                      const SizedBox(height: 16),
                      SizedBox(height: 320, child: allocationCard),
                    ],
                  );
                }
                return SizedBox(
                  height: 460,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 2, child: patrimoineCard),
                      const SizedBox(width: 16),
                      Expanded(child: allocationCard),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            CategoryBreakdownCard(
              title: l10n.dashboard_assets_label,
              categories: data.avoirsByAccount,
              categoriesByInvestment: data.avoirsByInvestment,
              hidden: hidden,
              showPru: false,
              period: period,
              // Une catégorie ici appartient à CETTE entité (`entityId`) —
              // la page de catégorie personnelle habituelle (destination
              // par défaut) ne la connaît pas et semblerait vide à tort,
              // voir la doc de `CategoryBreakdownCard.onCategoryTap`.
              onCategoryTap: (_) => widget.onOpen(),
            ),
            const SizedBox(height: 16),
            CategoryBreakdownCard(
              title: l10n.dashboard_liabilities_label,
              categories: data.dettes,
              hidden: hidden,
              showPru: false,
              period: period,
              onCategoryTap: (_) => widget.onOpen(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPercent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

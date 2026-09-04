import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/ui/frosted_card.dart';
import '../../../core/ui/toggle_button_style.dart';
import '../../../l10n/app_localizations.dart';
import '../patrimoine_models.dart';
import 'allocation_blocks_view.dart';
import 'allocation_donut_view.dart';
import 'allocation_pyramid_view.dart';

enum _AllocationViewMode { blocs, pyramide, donut }

enum _Kind { actifs, passifs }

/// Carte "Allocation" : répartition du patrimoine par catégorie, avec un
/// choix Actifs/Passifs et 3 modes d'affichage (blocs, pyramide, anneau) —
/// mêmes 3 vues que sur les captures Finary fournies. Survoler une
/// catégorie l'isole (les autres s'estompent) et affiche son nom et son
/// pourcentage.
class AllocationCard extends StatefulWidget {
  final List<PatrimoineCategory> actifs;
  final List<PatrimoineCategory> passifs;
  final bool hidden;

  const AllocationCard({
    super.key,
    required this.actifs,
    required this.passifs,
    required this.hidden,
  });

  @override
  State<AllocationCard> createState() => _AllocationCardState();
}

// Les 3 boutons de mode et le toggle Actifs/Passifs prenaient trop de place
// sur les très grands écrans (le bouton le plus à droite devenait
// inaccessible) et restaient écrasés contre le titre "Allocation" même
// après une première réduction (-5%) : on les réduit un peu plus (-15% au
// total) plutôt que de sauter directement à la densité "compact", beaucoup
// trop petite.
const _toggleButtonSize = ButtonSize(0.85);
const _toggleFontSize = 14.0 * 0.85;
const _toggleIconSize = 16.0 * 0.85;

class _AllocationCardState extends State<AllocationCard> {
  _AllocationViewMode _mode = _AllocationViewMode.blocs;
  _Kind _kind = _Kind.actifs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = _kind == _Kind.actifs ? widget.actifs : widget.passifs;
    // `montantPatrimoine` (pas `montant`) : cette carte représente le
    // patrimoine global, le seul agrégat où un investissement/compte exclu
    // (voir `PatrimoineAccount.excludedFromPatrimoine`) ne compte pas.
    final total = categories.fold(0.0, (sum, c) => sum + c.montantPatrimoine);
    final slices = [
      for (final c in categories)
        (c, total == 0 ? 0.0 : c.montantPatrimoine / total * 100),
    ];

    return FrostedCard(
      expand: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 340;
                final title = shadcn.Text(
                  l10n.dashboard_allocation_title,
                ).semiBold().large();
                final kindToggle = ButtonGroup(
                  children: [
                    SelectedButton(
                      value: _kind == _Kind.actifs,
                      selectedStyle: const ButtonStyle.primary(
                        size: _toggleButtonSize,
                      ),
                      style: toggleUnselectedStyle(
                        context,
                        size: _toggleButtonSize,
                      ),
                      onChanged: (_) => setState(() {
                        _kind = _Kind.actifs;
                        if (_mode == _AllocationViewMode.pyramide) {
                          _mode = _AllocationViewMode.blocs;
                        }
                      }),
                      child: shadcn.Text(
                        l10n.dashboard_assets_label,
                        style: const TextStyle(fontSize: _toggleFontSize),
                      ),
                    ),
                    SelectedButton(
                      value: _kind == _Kind.passifs,
                      selectedStyle: const ButtonStyle.primary(
                        size: _toggleButtonSize,
                      ),
                      style: toggleUnselectedStyle(
                        context,
                        size: _toggleButtonSize,
                      ),
                      onChanged: (_) => setState(() {
                        _kind = _Kind.passifs;
                        if (_mode == _AllocationViewMode.pyramide) {
                          _mode = _AllocationViewMode.blocs;
                        }
                      }),
                      child: shadcn.Text(
                        l10n.dashboard_liabilities_label,
                        style: const TextStyle(fontSize: _toggleFontSize),
                      ),
                    ),
                  ],
                );
                final modeButtons = [
                  _modeButton(
                    LucideIcons.layoutGrid,
                    _AllocationViewMode.blocs,
                  ),
                  if (_kind == _Kind.actifs)
                    _modeButton(
                      LucideIcons.pyramid,
                      _AllocationViewMode.pyramide,
                    ),
                  _modeButton(LucideIcons.chartPie, _AllocationViewMode.donut),
                ];
                final modeToggle = ButtonGroup(children: modeButtons);
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [kindToggle, modeToggle],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    title,
                    const Spacer(),
                    kindToggle,
                    const SizedBox(width: 12),
                    modeToggle,
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildView(slices, total)),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(IconData icon, _AllocationViewMode value) {
    return SelectedButton(
      value: _mode == value,
      selectedStyle: const ButtonStyle.primary(size: _toggleButtonSize),
      style: toggleUnselectedStyle(context, size: _toggleButtonSize),
      onChanged: (_) => setState(() => _mode = value),
      child: Icon(icon, size: _toggleIconSize),
    );
  }

  Widget _buildView(List<(PatrimoineCategory, double)> slices, double total) {
    switch (_mode) {
      case _AllocationViewMode.blocs:
        return AllocationBlocksView(
          slices: [
            for (final (c, p) in slices)
              AllocationSlice(
                id: c.id,
                label: c.label,
                color: c.color,
                percent: p,
              ),
          ],
        );
      case _AllocationViewMode.pyramide:
        return AllocationPyramidView(slices: slices);
      case _AllocationViewMode.donut:
        return AllocationDonutView(
          slices: [
            for (final (c, p) in slices)
              AllocationSlice(
                id: c.id,
                label: c.label,
                color: c.color,
                percent: p,
              ),
          ],
          total: total,
          hidden: widget.hidden,
        );
    }
  }
}

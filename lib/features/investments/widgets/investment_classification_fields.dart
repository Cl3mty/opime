import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:opime/l10n/app_localizations.dart';
import '../../../core/money_format.dart' show parseDecimal;
import '../investments_models.dart';

/// Champs de classement sectoriel/géographique d'un investissement
/// `actionsEtFonds` — un secteur et un pays uniques par défaut (comme pour
/// un titre individuel), ou une répartition pondérée pour un ETF/fonds
/// multi-pays/secteurs (voir [Investment.sectorBreakdown]/
/// [Investment.countryBreakdown]). Partagé entre `investment_edit_form
/// .dart` et `complete_patrimoine_dialog.dart`, jusqu'ici deux blocs de
/// code dupliqués à l'identique pour le classement simple.
class InvestmentClassificationFields extends StatelessWidget {
  final Sector? sector;
  final ValueChanged<Sector?> onSectorChanged;
  final List<SectorWeight> sectorBreakdown;
  final ValueChanged<List<SectorWeight>> onSectorBreakdownChanged;

  final String? countryCode;
  final ValueChanged<String?> onCountryCodeChanged;
  final List<CountryWeight> countryBreakdown;
  final ValueChanged<List<CountryWeight>> onCountryBreakdownChanged;

  const InvestmentClassificationFields({
    super.key,
    required this.sector,
    required this.onSectorChanged,
    this.sectorBreakdown = const [],
    required this.onSectorBreakdownChanged,
    required this.countryCode,
    required this.onCountryCodeChanged,
    this.countryBreakdown = const [],
    required this.onCountryBreakdownChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (sectorBreakdown.isEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Select<Sector>(
                    value: sector,
                    placeholder: shadcn.Text(l10n.investments_sector_placeholder),
                    onChanged: (value) {
                      if (value != null) onSectorChanged(value);
                    },
                    itemBuilder: (context, value) => shadcn.Text(value.label),
                    popup: (context) => SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final value in Sector.values)
                            SelectItemButton(
                              value: value,
                              child: shadcn.Text(value.label),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (sector != null) ...[
                    const SizedBox(width: 4),
                    IconButton.ghost(
                      icon: const Icon(LucideIcons.x, size: 14),
                      onPressed: () => onSectorChanged(null),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton.ghost(
                    key: const ValueKey('switch_to_multi_sector'),
                    icon: const Icon(LucideIcons.chartPie, size: 14),
                    onPressed: () => onSectorBreakdownChanged([
                      SectorWeight(sector: sector ?? Sector.values.first, percent: 100),
                    ]),
                  ),
                ],
              ),
            if (countryBreakdown.isEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Select<String>(
                    value: countryCode,
                    placeholder: shadcn.Text(l10n.investments_country_placeholder),
                    onChanged: (value) {
                      if (value != null) onCountryCodeChanged(value);
                    },
                    itemBuilder: (context, value) =>
                        shadcn.Text(kInvestmentCountries[value] ?? value),
                    popup: (context) => SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final entry in kInvestmentCountries.entries)
                            SelectItemButton(
                              value: entry.key,
                              child: shadcn.Text(entry.value),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (countryCode != null) ...[
                    const SizedBox(width: 4),
                    IconButton.ghost(
                      icon: const Icon(LucideIcons.x, size: 14),
                      onPressed: () => onCountryCodeChanged(null),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton.ghost(
                    key: const ValueKey('switch_to_multi_country'),
                    icon: const Icon(LucideIcons.globe, size: 14),
                    onPressed: () => onCountryBreakdownChanged([
                      CountryWeight(
                        countryCode: countryCode ?? 'US',
                        percent: 100,
                      ),
                    ]),
                  ),
                ],
              ),
          ],
        ),
        if (sectorBreakdown.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectorWeightEditor(
            weights: sectorBreakdown,
            onChanged: onSectorBreakdownChanged,
          ),
        ],
        if (countryBreakdown.isNotEmpty) ...[
          const SizedBox(height: 8),
          _CountryWeightEditor(
            weights: countryBreakdown,
            onChanged: onCountryBreakdownChanged,
          ),
        ],
      ],
    );
  }
}

/// En-tête commun aux deux éditeurs de répartition pondérée ci-dessous —
/// titre, bouton "+" pour ajouter une ligne, lien pour revenir au
/// classement simple (vide la répartition).
class _WeightEditorHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  final VoidCallback onRevertToSingle;

  const _WeightEditorHeader({
    required this.title,
    required this.onAdd,
    required this.onRevertToSingle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        shadcn.Text(title).medium().small(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Button.text(
              onPressed: onRevertToSingle,
              child: shadcn.Text(l10n.investments_revert_to_single_value_label).xSmall(),
            ),
            IconButton.ghost(
              key: ValueKey('add_weight_$title'),
              icon: const Icon(LucideIcons.plus, size: 14),
              onPressed: onAdd,
            ),
          ],
        ),
      ],
    );
  }
}

/// Éditeur de répartition sectorielle pondérée d'un ETF/fonds multi-secteurs
/// — même structure de liste dynamique que `entities_screen.dart`'s
/// `_buildLinesEditor` (bouton "+" en en-tête, une ligne par entrée avec un
/// champ et un bouton de suppression), adaptée à un `Select<Sector>` + un
/// pourcentage plutôt qu'un libellé + un montant.
class _SectorWeightEditor extends StatelessWidget {
  final List<SectorWeight> weights;
  final ValueChanged<List<SectorWeight>> onChanged;

  const _SectorWeightEditor({required this.weights, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeightEditorHeader(
          title: l10n.investments_sector_breakdown_title,
          onAdd: () => onChanged([
            ...weights,
            SectorWeight(sector: Sector.values.first, percent: 0),
          ]),
          onRevertToSingle: () => onChanged(const []),
        ),
        for (final weight in weights)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Select<Sector>(
                    value: weight.sector,
                    onChanged: (value) {
                      if (value == null) return;
                      onChanged([
                        for (final w in weights)
                          if (w.id == weight.id) w.copyWith(sector: value) else w,
                      ]);
                    },
                    itemBuilder: (context, value) => shadcn.Text(value.label),
                    popup: (context) => SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final value in Sector.values)
                            SelectItemButton(
                              value: value,
                              child: shadcn.Text(value.label),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: ValueKey('${weight.id}-percent'),
                    initialValue: weight.percent == 0
                        ? ''
                        : weight.percent.toString(),
                    placeholder: const shadcn.Text('%'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => onChanged([
                      for (final w in weights)
                        if (w.id == weight.id)
                          w.copyWith(percent: parseDecimal(v) ?? 0)
                        else
                          w,
                    ]),
                  ),
                ),
                IconButton.ghost(
                  key: ValueKey('${weight.id}-remove'),
                  icon: const Icon(LucideIcons.x, size: 14),
                  onPressed: () =>
                      onChanged([...weights]..removeWhere((w) => w.id == weight.id)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Même principe que [_SectorWeightEditor], pour la répartition
/// géographique pondérée — voir [Investment.countryBreakdown].
class _CountryWeightEditor extends StatelessWidget {
  final List<CountryWeight> weights;
  final ValueChanged<List<CountryWeight>> onChanged;

  const _CountryWeightEditor({
    required this.weights,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeightEditorHeader(
          title: l10n.investments_country_breakdown_title,
          onAdd: () => onChanged([
            ...weights,
            CountryWeight(countryCode: 'US', percent: 0),
          ]),
          onRevertToSingle: () => onChanged(const []),
        ),
        for (final weight in weights)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Select<String>(
                    value: weight.countryCode,
                    onChanged: (value) {
                      if (value == null) return;
                      onChanged([
                        for (final w in weights)
                          if (w.id == weight.id)
                            w.copyWith(countryCode: value)
                          else
                            w,
                      ]);
                    },
                    itemBuilder: (context, value) =>
                        shadcn.Text(kInvestmentCountries[value] ?? value),
                    popup: (context) => SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final entry in kInvestmentCountries.entries)
                            SelectItemButton(
                              value: entry.key,
                              child: shadcn.Text(entry.value),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: ValueKey('${weight.id}-percent'),
                    initialValue: weight.percent == 0
                        ? ''
                        : weight.percent.toString(),
                    placeholder: const shadcn.Text('%'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => onChanged([
                      for (final w in weights)
                        if (w.id == weight.id)
                          w.copyWith(percent: parseDecimal(v) ?? 0)
                        else
                          w,
                    ]),
                  ),
                ),
                IconButton.ghost(
                  key: ValueKey('${weight.id}-remove'),
                  icon: const Icon(LucideIcons.x, size: 14),
                  onPressed: () =>
                      onChanged([...weights]..removeWhere((w) => w.id == weight.id)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

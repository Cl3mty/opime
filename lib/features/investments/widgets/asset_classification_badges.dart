import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../investments_models.dart'
    show
        CountryWeight,
        Sector,
        SectorWeight,
        countryFlagEmoji,
        kInvestmentCountries;
import '../sector_style.dart' show sectorColor, sectorIcon;

/// Drapeau du pays de cotation d'un investissement (voir
/// `Investment.countryCode`) affiché à côté de son libellé dans les
/// tableaux de positions (`positions_table.dart`, `account_detail_screen
/// .dart`) — un simple emoji (voir [countryFlagEmoji], aucun asset à
/// embarquer), avec le nom du pays en bulle au survol.
class CountryFlagBadge extends StatelessWidget {
  final String countryCode;

  const CountryFlagBadge({super.key, required this.countryCode});

  @override
  Widget build(BuildContext context) {
    final flag = countryFlagEmoji(countryCode);
    if (flag == null) return const SizedBox.shrink();
    return Tooltip(
      // ignore: implicit_call_tearoffs
      tooltip: TooltipContainer(
        child: shadcn.Text(kInvestmentCountries[countryCode] ?? countryCode),
      ),
      child: shadcn.Text(flag, style: const TextStyle(fontSize: 14)),
    );
  }
}

/// Icône représentative du secteur d'activité d'un investissement (voir
/// `Investment.sector`) affichée à côté de son libellé dans les tableaux
/// de positions — pas de vraie base de logos par secteur (voir
/// [sectorIcon]), le nom du secteur s'affiche en bulle au survol.
class SectorBadge extends StatelessWidget {
  final Sector sector;

  const SectorBadge({super.key, required this.sector});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // ignore: implicit_call_tearoffs
      tooltip: TooltipContainer(child: shadcn.Text(sector.label)),
      child: Icon(sectorIcon(sector), size: 14, color: sectorColor(sector)),
    );
  }
}

/// Variante de [CountryFlagBadge] pour un investissement multi-pays (ETF
/// diversifié — voir `Investment.countryBreakdown`) : une seule icône
/// générique (pas de drapeau unique possible) avec la répartition complète
/// listée en bulle au survol, triée par poids décroissant.
class MultiCountryBadge extends StatelessWidget {
  final List<CountryWeight> breakdown;

  const MultiCountryBadge({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final sorted = [...breakdown]..sort((a, b) => b.percent.compareTo(a.percent));
    return Tooltip(
      // ignore: implicit_call_tearoffs
      tooltip: TooltipContainer(
        child: shadcn.Text(
          sorted
              .map(
                (w) =>
                    '${w.percent.toStringAsFixed(0)} % '
                    '${kInvestmentCountries[w.countryCode] ?? w.countryCode}',
              )
              .join('\n'),
        ),
      ),
      child: const Icon(LucideIcons.globe, size: 14),
    );
  }
}

/// Variante de [SectorBadge] pour un investissement multi-secteurs (ETF
/// diversifié — voir `Investment.sectorBreakdown`) : une seule icône
/// générique avec la répartition complète listée en bulle au survol, triée
/// par poids décroissant.
class MultiSectorBadge extends StatelessWidget {
  final List<SectorWeight> breakdown;

  const MultiSectorBadge({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final sorted = [...breakdown]..sort((a, b) => b.percent.compareTo(a.percent));
    return Tooltip(
      // ignore: implicit_call_tearoffs
      tooltip: TooltipContainer(
        child: shadcn.Text(
          sorted
              .map((w) => '${w.percent.toStringAsFixed(0)} % ${w.sector.label}')
              .join('\n'),
        ),
      ),
      child: const Icon(LucideIcons.chartPie, size: 14),
    );
  }
}

import 'package:shadcn_flutter/shadcn_flutter.dart';

class NavItem {
  final String key;
  final String label;
  final IconData icon; // redevient IconData standard
  final List<NavItem> children;

  const NavItem({
    required this.key,
    required this.label,
    required this.icon,
    this.children = const [],
  });
}

class NavGroup {
  final String label;
  final List<NavItem> items;
  const NavGroup({required this.label, required this.items});
}

const patrimoineGroup = NavGroup(
  label: 'Patrimoine',
  items: [
    NavItem(
      key: 'dashboard',
      label: 'Tableau de bord',
      icon: LucideIcons.gauge,
    ),
    NavItem(
      key: 'actifs',
      label: 'Actifs',
      icon: LucideIcons.circlePlus,
      children: [
        NavItem(
          key: 'actifs_actions_fonds',
          label: 'Actions & Fonds',
          icon: LucideIcons.chartLine,
        ),
        NavItem(
          key: 'actifs_private_equity',
          label: 'Private Equity',
          icon: LucideIcons.rocket,
        ),
        NavItem(
          key: 'actifs_immobilier',
          label: 'Immobilier',
          icon: LucideIcons.house,
        ),
        NavItem(
          key: 'actifs_crypto',
          label: 'Crypto',
          icon: LucideIcons.bitcoin,
        ),
        NavItem(
          key: 'actifs_metaux_precieux',
          label: 'Métaux précieux',
          icon: LucideIcons.gem,
        ),
        NavItem(
          key: 'actifs_epargne',
          label: 'Épargne',
          icon: LucideIcons.piggyBank,
        ),
        NavItem(key: 'actifs_autres', label: 'Autres', icon: LucideIcons.boxes),
      ],
    ),
    NavItem(
      key: 'passifs',
      label: 'Passifs',
      icon: LucideIcons.circleMinus,
      children: [
        NavItem(
          key: 'passifs_emprunts',
          label: 'Emprunts',
          icon: LucideIcons.handCoins,
        ),
        NavItem(
          key: 'passifs_prets_immobiliers',
          label: 'Crédits immobiliers',
          icon: LucideIcons.house,
        ),
      ],
    ),
  ],
);

const academieGroup = NavGroup(
  label: 'Académie',
  items: [
    NavItem(
      key: 'enveloppes',
      label: 'Enveloppes',
      icon: LucideIcons.library,
      children: [
        NavItem(
          key: 'envelope_compte_courant',
          label: 'Compte courant',
          icon: LucideIcons.landmark,
        ),
        NavItem(
          key: 'envelope_livret_a',
          label: 'Livret A',
          icon: LucideIcons.piggyBank,
        ),
        NavItem(key: 'envelope_ldds', label: 'LDDS', icon: LucideIcons.sprout),
        NavItem(key: 'envelope_lep', label: 'LEP', icon: LucideIcons.coins),
        NavItem(key: 'envelope_pel', label: 'PEL', icon: LucideIcons.house),
        NavItem(key: 'envelope_cto', label: 'CTO', icon: LucideIcons.briefcase),
        NavItem(
          key: 'envelope_pea',
          label: 'PEA',
          icon: LucideIcons.trendingUp,
        ),
        NavItem(
          key: 'envelope_assurance_vie',
          label: 'Assurance-vie',
          icon: LucideIcons.heartHandshake,
        ),
        NavItem(
          key: 'envelope_pee_peg',
          label: 'PEE / PEG',
          icon: LucideIcons.users,
        ),
        NavItem(key: 'envelope_per', label: 'PER', icon: LucideIcons.sunset),
      ],
    ),
    NavItem(
      key: 'investissement',
      label: 'Investissement',
      icon: LucideIcons.university,
      children: [
        NavItem(
          key: 'invest_pourquoi',
          label: 'Pourquoi investir ?',
          icon: LucideIcons.lightbulb,
        ),
        NavItem(
          key: 'invest_inflation',
          label: 'L\'inflation',
          icon: LucideIcons.trendingDown,
        ),
        NavItem(
          key: 'invest_risque',
          label: 'Le risque',
          icon: LucideIcons.shieldAlert,
        ),
        NavItem(
          key: 'invest_diversification',
          label: 'Diversification',
          icon: LucideIcons.shuffle,
        ),
        NavItem(key: 'invest_etf', label: 'Les ETF', icon: LucideIcons.layers),
        NavItem(
          key: 'invest_frais',
          label: 'Les frais',
          icon: LucideIcons.percent,
        ),
        NavItem(
          key: 'invest_pyramide',
          label: 'Pyramide de l\'investissement',
          icon: LucideIcons.pyramid,
        ),
        NavItem(
          key: 'invest_allocation',
          label: 'Allocation stratégique/dynamique',
          icon: LucideIcons.scale,
        ),
        NavItem(
          key: 'invest_temps_long',
          label: 'Le temps long',
          icon: LucideIcons.hourglass,
        ),
      ],
    ),
    NavItem(
      key: 'formation',
      label: 'Formation',
      icon: LucideIcons.graduationCap,
      children: [
        NavItem(
          key: 'formation_bourse',
          label: 'Bourse',
          icon: LucideIcons.chartCandlestick,
        ),
        NavItem(
          key: 'formation_metaux',
          label: 'Métaux précieux',
          icon: LucideIcons.gem,
        ),
        NavItem(
          key: 'formation_immobilier',
          label: 'Immobilier',
          icon: LucideIcons.house,
        ),
        NavItem(
          key: 'formation_comptes',
          label: 'Lire les comptes',
          icon: LucideIcons.fileSpreadsheet,
        ),
      ],
    ),
  ],
);

/// Items du groupe Patrimoine pour l'onglet "Portfolio" de la navigation
/// mobile (le tableau de bord a déjà son propre onglet "Home").
final portfolioTabItems = [
  for (final item in patrimoineGroup.items)
    if (item.key != 'dashboard') item,
];

const outilsGroup = NavGroup(
  label: 'Outils',
  items: [
    NavItem(
      key: 'strategie',
      label: 'Stratégie',
      icon: LucideIcons.notebookPen,
    ),
    NavItem(
      key: 'budget',
      label: 'Budget',
      icon: LucideIcons.wallet,
      children: [
        NavItem(
          key: 'budget_ventilation',
          label: 'Ventilation',
          icon: LucideIcons.workflow,
        ),
        NavItem(
          key: 'budget_suivi',
          label: 'Suivi',
          icon: LucideIcons.listChecks,
        ),
      ],
    ),
    NavItem(
      key: 'simulation',
      label: 'Simulation',
      icon: LucideIcons.cpu,
      children: [
        NavItem(
          key: 'simulation_patrimoine',
          label: 'Patrimoine',
          icon: LucideIcons.trendingUp,
        ),
        NavItem(
          key: 'simulation_pret',
          label: 'Prêt',
          icon: LucideIcons.handCoins,
        ),
        NavItem(
          key: 'simulation_taxation',
          label: 'Fiscalité',
          icon: LucideIcons.flame,
        ),
        NavItem(
          key: 'simulation_transmission',
          label: 'Transmission',
          icon: LucideIcons.users,
        ),
      ],
    ),
    NavItem(key: 'assistant', label: 'Assistant', icon: LucideIcons.bot),
  ],
);

/// Items du groupe Outils pour l'onglet "Tools" de la navigation mobile
/// (pas d'assistant en version mobile).
final toolsTabItems = [
  for (final item in outilsGroup.items)
    if (item.key != 'assistant') item,
];

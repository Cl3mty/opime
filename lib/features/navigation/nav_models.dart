import 'package:shadcn_flutter/shadcn_flutter.dart';

class NavItem {
  final String key;
  final String label;
  final IconData icon;   // redevient IconData standard
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
    NavItem(key: 'dashboard', label: 'Tableau de bord', icon: LucideIcons.gauge),
    NavItem(
      key: 'actifs',
      label: 'Actifs',
      icon: LucideIcons.circlePlus,
      children: [
        NavItem(key: 'actifs_actions_fonds', label: 'Actions & Fonds', icon: LucideIcons.chartLine),
        NavItem(key: 'actifs_private_equity', label: 'Private Equity', icon: LucideIcons.rocket),
        NavItem(key: 'actifs_immobilier', label: 'Immobilier', icon: LucideIcons.house),
        NavItem(key: 'actifs_crypto', label: 'Crypto', icon: LucideIcons.bitcoin),
        NavItem(key: 'actifs_metaux_precieux', label: 'Métaux précieux', icon: LucideIcons.gem),
        NavItem(key: 'actifs_epargne', label: 'Épargne', icon: LucideIcons.piggyBank),
        NavItem(key: 'actifs_autres', label: 'Autres', icon: LucideIcons.boxes),
      ],
    ),
    NavItem(
      key: 'passifs',
      label: 'Passifs',
      icon: LucideIcons.circleMinus,
      children: [
        NavItem(key: 'passifs_emprunts', label: 'Emprunts', icon: LucideIcons.handCoins),
        NavItem(key: 'passifs_prets_immobiliers', label: 'Crédits immobiliers', icon: LucideIcons.house),
      ],
    ),
  ],
);

const academieGroup = NavGroup(
  label: 'Académie',
  items: [
    NavItem(key: 'enveloppes', label: 'Enveloppes', icon: LucideIcons.library),
    NavItem(key: 'investissement', label: 'Investissement', icon: LucideIcons.university),
    NavItem(key: 'formation', label: 'Formation', icon: LucideIcons.graduationCap),    
  ],
);

const outilsGroup = NavGroup(
  label: 'Outils',
  items: [
    NavItem(key: 'strategie', label: 'Stratégie', icon: LucideIcons.notebookPen),
    NavItem(
      key: 'budget',
      label: 'Budget',
      icon: LucideIcons.wallet,
      children: [
        NavItem(key: 'budget_ventilation', label: 'Ventilation', icon: LucideIcons.workflow),
        NavItem(key: 'budget_suivi', label: 'Suivi', icon: LucideIcons.listChecks),
      ],
    ),
    NavItem(
      key: 'simulation',
      label: 'Simulation',
      icon: LucideIcons.cpu,
      children: [
        NavItem(key: 'simulation_patrimoine', label: 'Patrimoine', icon: LucideIcons.trendingUp),
        NavItem(key: 'simulation_pret', label: 'Prêt', icon: LucideIcons.handCoins),
        NavItem(key: 'simulation_taxation', label: 'Fiscalité', icon: LucideIcons.flame),
        NavItem(key: 'simulation_transmission', label: 'Transmission', icon: LucideIcons.users),
      ],
    ),
    NavItem(key: 'assistant', label: 'Assistant', icon: LucideIcons.bot),
  ],
);
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'investments_models.dart' show Sector;

/// Une couleur par [Sector] (même ordre que [Sector.values]) — 11 secteurs
/// avec une seule teinte de base (ex : `allocationSliceColor`,
/// `dashboard/category_detail_screen.dart`, une teinte éclaircie par
/// palier) auraient rendu tout affichage groupant les 11 quasi monochrome :
/// chaque secteur a donc sa propre couleur reconnaissable, réutilisée
/// partout où un secteur est affiché (donut de `analyses_screen.dart`,
/// icône de `positions_table.dart`...).
const sectorColors = <Color>[
  Color(0xFF6366F1), // Technologie — indigo
  Color(0xFFEC4899), // Santé — rose
  Color(0xFF22C55E), // Finance — vert
  Color(0xFFF59E0B), // Consommation discrétionnaire — ambre
  Color(0xFF84CC16), // Consommation de base — citron vert
  Color(0xFF64748B), // Industrie — ardoise
  Color(0xFFEF4444), // Énergie — rouge
  Color(0xFFA855F7), // Matériaux — violet
  Color(0xFF06B6D4), // Services publics — cyan
  Color(0xFFF97316), // Immobilier — orange
  Color(0xFF3B82F6), // Communication — bleu
];

/// Couleur du secteur "Non classé" (`sector == null`) — gris neutre
/// distinct de toutes les couleurs de [sectorColors].
const unclassifiedSectorColor = Color(0xFF9CA3AF);

/// Couleur d'un [Sector] (ou d'un investissement non classé, `null`).
Color sectorColor(Sector? sector) =>
    sector == null ? unclassifiedSectorColor : sectorColors[sector.index];

/// Icône représentative d'un [Sector] — affichée à la place d'un vrai logo
/// (aucune source de logos par secteur d'activité, contrairement aux
/// logos de banque déjà gérés par `bank_logo_repository.dart` pour un
/// établissement précis) dans `positions_table.dart`, avec le nom du
/// secteur au survol (voir son `Tooltip`).
IconData sectorIcon(Sector sector) => switch (sector) {
  Sector.technologie => LucideIcons.cpu,
  Sector.sante => LucideIcons.heartPulse,
  Sector.finance => LucideIcons.landmark,
  Sector.consommationDiscretionnaire => LucideIcons.shoppingBag,
  Sector.consommationBase => LucideIcons.shoppingCart,
  Sector.industrie => LucideIcons.factory,
  Sector.energie => LucideIcons.zap,
  Sector.materiaux => LucideIcons.mountain,
  Sector.servicesPublics => LucideIcons.droplets,
  Sector.immobilier => LucideIcons.building2,
  Sector.communication => LucideIcons.radio,
};

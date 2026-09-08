import 'package:shadcn_flutter/shadcn_flutter.dart' show IconData, LucideIcons;

/// Métadonnées (titre, icône) des parcours de Formation d'Opime Premium —
/// utilisées pour peupler la sidebar/le hub mobile et générer une clé de
/// page par parcours dans `main.dart`. Le contenu réel des leçons (steps,
/// vocabulaire) est une fonctionnalité Premium et ne vit pas dans ce dépôt
/// — voir `formation_track_screen.dart` (aperçu illustratif) et
/// `core/premium/premium_lock.dart`.
class FormationTrackInfo {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const FormationTrackInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

const formationTracks = [
  FormationTrackInfo(
    id: 'formation_bourse',
    title: 'Bourse',
    description: 'Actions, obligations, ordres et marchés financiers.',
    icon: LucideIcons.chartCandlestick,
  ),
  FormationTrackInfo(
    id: 'formation_metaux',
    title: 'Métaux précieux',
    description: 'Or, argent, comment s\'y exposer et leur fiscalité.',
    icon: LucideIcons.gem,
  ),
  FormationTrackInfo(
    id: 'formation_crypto',
    title: 'Crypto',
    description: 'Blockchain, Bitcoin, Ethereum et autres cryptomonnaies.',
    icon: LucideIcons.bitcoin,
  ),
  FormationTrackInfo(
    id: 'formation_immobilier',
    title: 'Immobilier',
    description: 'Locatif direct, SCPI, effet de levier et fiscalité.',
    icon: LucideIcons.house,
  ),
  FormationTrackInfo(
    id: 'formation_structuration',
    title: 'Structuration patrimoniale',
    description:
        'Statuts d\'entreprise, holding, SCI, pacte Dutreil, démembrement et donation.',
    icon: LucideIcons.network,
  ),
];

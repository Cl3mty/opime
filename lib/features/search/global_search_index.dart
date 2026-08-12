import 'package:flutter/widgets.dart' show IconData;
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import '../../core/academy/academy_models.dart';
import '../academy/envelopes_data.dart';
import '../academy/formation_data.dart';
import '../academy/investissement_data.dart';
import '../investments/investments_models.dart';
import '../investments/investments_repository.dart';
import '../navigation/nav_models.dart';

/// Grandes familles de résultats de la recherche globale, affichées comme
/// en-têtes de groupe dans le panneau de résultats (dans cet ordre).
enum SearchCategory {
  page('Pages'),
  fondamentaux('Fondamentaux'),
  enveloppe('Enveloppes'),
  formation('Formation'),
  vocabulaire('Vocabulaire'),
  patrimoine('Patrimoine');

  final String label;
  const SearchCategory(this.label);
}

/// Une entrée de l'index de recherche globale : un titre, un sous-titre
/// facultatif, une icône, et [extra] — du texte additionnel cherchable mais
/// non affiché (définition d'un terme, ISIN, puces d'une leçon...).
///
/// [key] est la clé de navigation à activer quand l'entrée est choisie (une
/// clé de la map `pages` de `main.dart`, ex : `actifs_crypto`, `invest_etf`,
/// ou une catégorie de patrimoine réel). [scoreFor] classe la pertinence
/// d'une requête, utilisé par [GlobalSearchIndex.search].
class SearchEntry {
  final String key;
  final SearchCategory category;
  final String title;
  final String? subtitle;
  final IconData icon;
  final String extra;

  const SearchEntry({
    required this.key,
    required this.category,
    required this.title,
    this.subtitle,
    required this.icon,
    this.extra = '',
  });

  /// Calcule le score de [query] contre cette entrée.
  ///
  /// Règles déterministes et lisibles :
  ///  - la requête est normalisée (minuscules, accents ôtés, tirets → espaces),
  ///    puis découpée en termes ;
  ///  - chaque terme doit correspondre au moins une fois (titre, sous-titre
  ///    ou texte additionnel), sinon le score est 0 ;
  ///  - le titre pèse plus que le sous-titre, lui-même plus que [extra]
  ///    (voir [_matchScore]) ; les scores s'additionnent sur les termes.
  int scoreFor(String query) {
    final terms = _normalize(query).split(' ').where((t) => t.isNotEmpty);
    if (terms.isEmpty) return 0;
    var total = 0;
    for (final term in terms) {
      final titleScore = _matchScore(term, _normTitle) * 3;
      final subtitleScore = _matchScore(term, _normSubtitle) * 2;
      final extraScore = _matchScore(term, _normExtra);
      final best = [titleScore, subtitleScore, extraScore]
          .reduce((a, b) => a > b ? a : b);
      if (best == 0) return 0;
      total += best;
    }
    return total;
  }

  String get _normTitle => _normalize(title);
  String get _normSubtitle => _normalize(subtitle ?? '');
  String get _normExtra => _normalize(extra);
}

/// Index global : construit la liste complète des entrées cherchables (en
/// une passe, la seule opération disque étant la lecture du patrimoine réel)
/// et fournit le filtrage par requête.
class GlobalSearchIndex {
  /// Construit toutes les entrées indexables :
  ///  - pages de navigation (feuilles uniquement, voir [_navItemEntries]) ;
  ///  - cartes Fondamentaux, enveloppes et pas de la Formation ;
  ///  - glossaire (termes des leçons) ;
  ///  - comptes et investissements du patrimoine réel ([vaultPath]).
  static Future<List<SearchEntry>> build({required String vaultPath}) async {
    return [
      ..._pageEntries(),
      ..._fondamentauxEntries(),
      ..._enveloppeEntries(),
      ..._formationEntries(),
      ..._vocabulaireEntries(),
      ...await _patrimoineEntries(vaultPath),
    ];
  }

  /// Filtre [entries] par [query] et trie par score décroissant, groupé par
  /// catégorie dans l'ordre de [SearchCategory.values], en retenant au plus
  /// [maxPerCategory] entrées par catégorie pour garder le panneau lisible.
  static List<SearchEntry> search(
    List<SearchEntry> entries,
    String query, {
    int maxPerCategory = 6,
  }) {
    final grouped = <SearchCategory, List<(SearchEntry, int)>>{};
    for (final entry in entries) {
      final score = entry.scoreFor(query);
      if (score <= 0) continue;
      grouped.putIfAbsent(entry.category, () => []).add((entry, score));
    }
    return [
      for (final category in SearchCategory.values)
        if (grouped[category] case final items?)
          for (final (entry, _) in _sortedByScore(items, maxPerCategory)) entry,
    ];
  }

  static List<(SearchEntry, int)> _sortedByScore(
    List<(SearchEntry, int)> items,
    int max,
  ) {
    final sorted = [...items]..sort((a, b) => b.$2.compareTo(a.$2));
    return sorted.take(max).toList();
  }

  /// Feuilles de la navigation. Les items-parents (ex : "Budget") n'ont pas
  /// de page derrière eux : seules leurs feuilles sont indexées, avec le
  /// libellé du parent en sous-titre — cohérent avec [navLabelForKey], qui
  /// affiche aussi le libellé du parent comme titre de page.
  static List<SearchEntry> _pageEntries() {
    return [
      for (final group in [patrimoineGroup, academieGroup, outilsGroup])
        for (final item in group.items)
          ..._navItemEntries(item, parentLabel: group.label),
      // Actifs/Passifs ne vivent pas dans un NavGroup (partagés entre
      // desktop et mobile) : le label du groupe Patrimoine leur tient lieu
      // de sous-titre.
      for (final item in patrimoineCategoryItems)
        ..._navItemEntries(item, parentLabel: patrimoineGroup.label),
    ];
  }

  static List<SearchEntry> _navItemEntries(
    NavItem item, {
    required String parentLabel,
  }) {
    if (item.children.isEmpty) {
      return [
        SearchEntry(
          key: item.key,
          category: SearchCategory.page,
          title: item.label,
          subtitle: parentLabel,
          icon: item.icon,
        ),
      ];
    }
    return [
      for (final child in item.children)
        SearchEntry(
          key: child.key,
          category: SearchCategory.page,
          title: child.label,
          subtitle: item.label,
          icon: child.icon,
        ),
    ];
  }

  static List<SearchEntry> _fondamentauxEntries() {
    return [
      for (final card in investissementCards)
        SearchEntry(
          key: card.id,
          category: SearchCategory.fondamentaux,
          title: card.title,
          subtitle: card.tagline,
          icon: _navIconFor(card.id),
          extra: _stepText(card),
        ),
    ];
  }

  static List<SearchEntry> _enveloppeEntries() {
    return [
      for (final envelope in envelopes)
        SearchEntry(
          key: envelope.id,
          category: SearchCategory.enveloppe,
          title: envelope.name,
          subtitle: envelope.tagline,
          icon: _navIconFor(envelope.id),
          extra: [
            envelope.ceiling,
            envelope.taxation,
            envelope.liquidity,
            envelope.idealFor,
            ...envelope.goodToKnow,
            envelope.pitfall,
          ].join(' '),
        ),
    ];
  }

  /// Pas de la Formation : chaque pas navigue vers le parcours qui le
  /// contient ([AcademyTrack.id], la seule page réelle du module).
  static List<SearchEntry> _formationEntries() {
    return [
      for (final track in formationTracks)
        for (final step in track.steps)
          SearchEntry(
            key: track.id,
            category: SearchCategory.formation,
            title: step.title,
            subtitle: track.title,
            icon: track.icon,
            extra: _stepText(step),
          ),
    ];
  }

  /// Termes du glossaire expliqués dans les leçons (Fondamentaux et
  /// Formation) : le sous-titre rappelle la leçon d'origine, [extra] porte
  /// la définition pour la recherche.
  static List<SearchEntry> _vocabulaireEntries() {
    return [
      // Les cartes Fondamentaux sont des leçons autonomes : le terme navigue
      // vers la carte elle-même.
      ..._vocabFor(investissementCards, targetKey: (step) => step.id),
      // Les pas de la Formation naviguent vers le parcours porteur.
      for (final track in formationTracks)
        ..._vocabFor(track.steps, targetKey: (_) => track.id),
    ];
  }

  static List<SearchEntry> _vocabFor(
    List<AcademyStep> steps, {
    required String Function(AcademyStep step) targetKey,
  }) {
    return [
      for (final step in steps)
        for (final term in step.vocabulary)
          SearchEntry(
            key: targetKey(step),
            category: SearchCategory.vocabulaire,
            title: term.term,
            subtitle: step.title,
            icon: LucideIcons.bookOpen,
            extra: term.definition,
          ),
    ];
  }

  /// Comptes et investissements du patrimoine réel : chaque entrée navigue
  /// vers la catégorie (classe d'actif effective) qui l'affiche. La lecture
  /// disque est le seul coût asynchrone de la construction de l'index.
  static Future<List<SearchEntry>> _patrimoineEntries(String vaultPath) async {
    final accounts = await InvestmentsRepository(vaultPath).listAll();
    return [
      for (final account in accounts) ...[
        SearchEntry(
          key: account.assetClass.categoryId,
          category: SearchCategory.patrimoine,
          title: account.name,
          subtitle: account.bankName ?? account.envelope?.label,
          icon: _assetClassIcon(account.assetClass),
          extra: account.description ?? '',
        ),
        for (final investment in account.investments)
          SearchEntry(
            key: (investment.assetClass ?? account.assetClass).categoryId,
            category: SearchCategory.patrimoine,
            title: investment.label,
            subtitle: account.name,
            icon: _assetClassIcon(
              investment.assetClass ?? account.assetClass,
            ),
            extra: investment.isin,
          ),
      ],
    ];
  }

  /// Icône de la sidebar pour une clé de navigation connue (cartes
  /// Fondamentaux, enveloppes, parcours de formation) — les icônes par clé
  /// sont déjà définies dans `nav_models.dart`, autant les réutiliser.
  static IconData _navIconFor(String key) {
    for (final group in [patrimoineGroup, academieGroup, outilsGroup]) {
      for (final item in group.items) {
        if (item.key == key) return item.icon;
        for (final child in item.children) {
          if (child.key == key) return child.icon;
        }
      }
    }
    return LucideIcons.circle;
  }

  static IconData _assetClassIcon(AssetClass assetClass) {
    switch (assetClass) {
      case AssetClass.immobilier:
        return LucideIcons.house;
      case AssetClass.actionsEtFonds:
        return LucideIcons.chartLine;
      case AssetClass.epargne:
        return LucideIcons.piggyBank;
      case AssetClass.crypto:
        return LucideIcons.bitcoin;
      case AssetClass.privateEquity:
        return LucideIcons.rocket;
      case AssetClass.metauxPrecieux:
        return LucideIcons.gem;
      case AssetClass.autres:
        return LucideIcons.boxes;
    }
  }

  /// Texte cherchable d'une leçon : accroche, puces et phrase à retenir.
  static String _stepText(AcademyStep step) => [
    step.tagline,
    ...step.bullets,
    if (step.takeaway != null) step.takeaway!,
  ].join(' ');
}

/// Minuscules, accents ôtés, tirets/apostrophes → espaces : "Assurance-vie"
/// est ainsi retrouvé aussi bien par "assurance vie" que par "vie".
String _normalize(String input) {
  const replacements = {
    'à': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i',
    'ô': 'o', 'ö': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
    'œ': 'oe',
    '-': ' ',
    "'": ' ',
  };
  var s = input.toLowerCase().trim();
  for (final entry in replacements.entries) {
    s = s.replaceAll(entry.key, entry.value);
  }
  return s;
}

/// Score de correspondance d'un terme unique (normalisé) contre un texte
/// normalisé : égalité > préfixe du texte > mot entier > préfixe de mot >
/// simple sous-chaîne. 0 si aucune correspondance.
int _matchScore(String term, String text) {
  if (text.isEmpty) return 0;
  if (text == term) return 100;
  if (text.startsWith(term)) return 90;
  final words = text.split(' ');
  if (words.contains(term)) return 85;
  if (words.any((w) => w.startsWith(term))) return 75;
  if (text.contains(term)) return 60;
  return 0;
}

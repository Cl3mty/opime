import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../l10n/app_localizations.dart';
import 'global_search_index.dart';

/// Champ de recherche globale de la TopBar (desktop/tablette), qui remplace
/// l'ancien champ "Demander à l'assistant" : en tapant, un panneau ancré au
/// champ liste les résultats groupés par catégorie (Pages, Fondamentaux,
/// Enveloppes, Formation, Vocabulaire, Patrimoine réel), triés par
/// pertinence. Le choix d'un résultat active sa clé de navigation via
/// [onSelect] — la page remplace le contenu, comme un clic dans la sidebar.
///
/// L'index est reconstruit à chaque changement de profil/vault : l'AppShell
/// remonte ce widget avec un [ValueKey] basé sur
/// `ProfileController.activeDataPath`, donc un état neuf à chaque profil.
class GlobalSearchBar extends StatefulWidget {
  final String vaultPath;
  final ValueChanged<String> onSelect;

  const GlobalSearchBar({
    super.key,
    required this.vaultPath,
    required this.onSelect,
  });

  @override
  State<GlobalSearchBar> createState() => _GlobalSearchBarState();
}

/// Sélection clavier dans le panneau de résultats.
class _NavigateIntent extends Intent {
  final int delta;
  const _NavigateIntent(this.delta);
}

class _AcceptIntent extends Intent {
  const _AcceptIntent();
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

class _GlobalSearchBarState extends State<GlobalSearchBar> {
  /// Nombre de requête : permet d'ignorer la réponse d'un index devenu
  /// obsolète (profil changé pendant la lecture disque).
  int _requestEpoch = 0;

  /// Au plus [maxPerCategory] résultats par catégorie dans le panneau.
  static const _maxPerCategory = 6;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final OverlayController _popoverController = OverlayController();

  List<SearchEntry> _index = const [];
  final ValueNotifier<List<SearchEntry>> _results = ValueNotifier(const []);
  final ValueNotifier<int> _selectedIndex = ValueNotifier(-1);

  /// Source de la dernière sélection : `true` quand elle vient du clavier
  /// (flèches ↑/↓), `false` quand elle vient du survol. Seule la navigation
  /// clavier fait défiler le panneau — le survol ne doit pas le faire
  /// « sauter » sous le curseur.
  bool _selectionFromKeyboard = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    // `overlayOpen` est relu dans `build` pour activer les raccourcis
    // clavier : sans ce rebuild, le panneau s'ouvre mais les flèches
    // restent inactives (l'état n'était jamais rafraîchi à l'ouverture).
    _popoverController.addListener(_onPopoverChanged);
    _rebuildIndex();
  }

  @override
  void didUpdateWidget(covariant GlobalSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) _rebuildIndex();
  }

  void _onPopoverChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _popoverController.removeListener(_onPopoverChanged);
    _controller.dispose();
    _focusNode.dispose();
    _results.dispose();
    _selectedIndex.dispose();
    _popoverController.close();
    super.dispose();
  }

  Future<void> _rebuildIndex() async {
    final epoch = ++_requestEpoch;
    final path = widget.vaultPath;
    final entries = await GlobalSearchIndex.build(vaultPath: path);
    if (!mounted || epoch != _requestEpoch || path != widget.vaultPath) return;
    setState(() {
      _index = entries;
      _applyQuery();
    });
  }

  void _onQueryChanged() {
    _applyQuery();
    _syncPopover();
  }

  /// Recalcule les résultats pour la requête courante. La barre de sélection
  /// clavier repart toujours sur le premier résultat.
  void _applyQuery() {
    final query = _controller.text;
    final results = query.trim().length < 2
        ? const <SearchEntry>[]
        : GlobalSearchIndex.search(
            _index,
            query,
            maxPerCategory: _maxPerCategory,
          );
    _results.value = results;
    _selectedIndex.value = results.isEmpty ? -1 : 0;
  }

  /// Ouvre ou ferme le panneau pour refléter l'état courant (champ focus et
  /// résultats disponibles).
  void _syncPopover() {
    final shouldShow = _focusNode.hasFocus && _results.value.isNotEmpty;
    if (shouldShow && !_popoverController.hasOpenOverlay) {
      _popoverController.show(
        context,
        PopoverConfiguration(
          handler: const PopoverOverlayHandler(),
          builder: _buildPanel,
          // Largeur du champ, aligné sur son bord gauche (comme les
          // suggestions d'AutoComplete) ; le panneau borne lui-même sa
          // hauteur et sa largeur maximale.
          widthConstraint: PopoverConstraint.anchorFixedSize,
          anchorAlignment: AlignmentDirectional.bottomStart,
          alignment: AlignmentDirectional.topStart,
          // Le focus du champ pilote la visibilité du panneau : le clic sur
          // un résultat ne doit pas dérober ce focus, sinon le panneau se
          // fermerait avant que le clic ne soit traité.
          dismissBackdropFocus: false,
        ),
      );
    } else if (!shouldShow && _popoverController.hasOpenOverlay) {
      _popoverController.close();
    }
  }

  void _moveSelection(int delta) {
    final results = _results.value;
    if (results.isEmpty) return;
    var next = _selectedIndex.value + delta;
    if (next < 0) next = results.length - 1;
    if (next >= results.length) next = 0;
    _selectionFromKeyboard = true;
    _selectedIndex.value = next;
  }

  void _acceptSelection() {
    final results = _results.value;
    final index = _selectedIndex.value;
    if (index < 0 || index >= results.length) return;
    _select(results[index]);
  }

  void _dismiss() {
    _focusNode.unfocus();
    _popoverController.close();
  }

  void _select(SearchEntry entry) {
    _popoverController.close();
    _focusNode.unfocus();
    // Efface la requête : le champ retrouve son placeholder à la prochaine
    // ouverture (le texte effacé déclenche _onQueryChanged, qui vide _results).
    _controller.clear();
    widget.onSelect(entry.key);
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      // Largeur plafonnée même si le champ est très large (TopBar étendue) ;
      // hauteur plafonnée pour que la liste défile à l'intérieur du panneau.
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 400),
      child: SurfaceCard(
        padding: EdgeInsets.all(theme.density.baseGap * theme.scaling * 0.5),
        child: AnimatedBuilder(
          animation: Listenable.merge([_results, _selectedIndex]),
          builder: (context, _) {
            final results = _results.value;
            if (results.isEmpty) {
              return shadcn.Text(l10n.search_no_results).muted.small.withPadding(
                vertical: theme.density.baseContainerPadding * theme.scaling,
              );
            }
            // Regroupe les résultats par catégorie, dans l'ordre des
            // catégories (le filtrage de GlobalSearchIndex.search l'assure
            // déjà : on regroupe pour afficher les en-têtes).
            final groups = <SearchCategory, List<SearchEntry>>{};
            for (final entry in results) {
              groups.putIfAbsent(entry.category, () => []).add(entry);
            }
            var rowIndex = 0;
            final children = <Widget>[];
            for (final category in SearchCategory.values) {
              final entries = groups[category];
              if (entries == null) continue;
              children.add(
                shadcn.Text(
                  searchCategoryLabel(l10n, category),
                ).muted.small.withPadding(horizontal: 8, vertical: 6),
              );
              for (final entry in entries) {
                final index = rowIndex++;
                children.add(
                  _SearchResultRow(
                    entry: entry,
                    selected: index == _selectedIndex.value,
                    autoScrollOnSelect: _selectionFromKeyboard,
                    onHover: () {
                      if (_selectedIndex.value != index) {
                        _selectionFromKeyboard = false;
                        _selectedIndex.value = index;
                      }
                    },
                    onTap: () => _select(entry),
                  ),
                );
              }
            }
            return ListView(
              shrinkWrap: true,
              children: children,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlayOpen = _popoverController.hasOpenOverlay;
    // Raccourcis actifs seulement quand le panneau est ouvert : sans ça, les
    // flèches restent dans le champ quand il n'y a rien à naviguer.
    return FocusableActionDetector(
      onFocusChange: (_) => _syncPopover(),
      shortcuts: overlayOpen
          ? {
              LogicalKeySet(LogicalKeyboardKey.arrowDown):
                  const _NavigateIntent(1),
              LogicalKeySet(LogicalKeyboardKey.arrowUp):
                  const _NavigateIntent(-1),
              LogicalKeySet(LogicalKeyboardKey.enter): const _AcceptIntent(),
              LogicalKeySet(LogicalKeyboardKey.escape): const _DismissIntent(),
            }
          : null,
      actions: overlayOpen
          ? {
              _NavigateIntent: CallbackAction<_NavigateIntent>(
                onInvoke: (intent) {
                  _moveSelection(intent.delta);
                  return null;
                },
              ),
              _AcceptIntent: CallbackAction<_AcceptIntent>(
                onInvoke: (intent) {
                  _acceptSelection();
                  return null;
                },
              ),
              _DismissIntent: CallbackAction<_DismissIntent>(
                onInvoke: (intent) {
                  _dismiss();
                  return null;
                },
              ),
            }
          : null,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        placeholder: shadcn.Text(AppLocalizations.of(context).search_placeholder),
        border: Border.all(color: Colors.transparent),
        features: [
          InputFeature.leading(
            Icon(
              LucideIcons.search,
              size: 16,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          // Croix "tout effacer", visible dès que le champ n'est plus vide.
          InputFeature.clear(),
        ],
      ),
    );
  }
}

/// Ligne de résultat du panneau : icône, titre, sous-titre facultatif. La
/// sélection (surlignage + défilement dans le viewport) est pilotée par
/// [_selectedIndex] ; le survol la met aussi à jour, comme dans une palette.
class _SearchResultRow extends StatefulWidget {
  final SearchEntry entry;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  /// `true` quand la sélection vient du clavier : la ligne devient
  /// sélectionnée, elle doit être défilée dans le viewport. Le survol ne
  /// doit pas déclencher de défilement (le panneau sauterait sous le
  /// curseur).
  final bool autoScrollOnSelect;

  const _SearchResultRow({
    required this.entry,
    required this.selected,
    required this.onHover,
    this.autoScrollOnSelect = false,
    required this.onTap,
  });

  @override
  State<_SearchResultRow> createState() => _SearchResultRowState();
}

class _SearchResultRowState extends State<_SearchResultRow> {
  @override
  void didUpdateWidget(covariant _SearchResultRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Devenu sélectionné via le clavier : s'assurer que la ligne est
    // visible dans le panneau défilant — centrée (alignment 0.5) pour ne
    // pas la coller contre le bord du panneau.
    if (oldWidget.selected != widget.selected &&
        widget.selected &&
        widget.autoScrollOnSelect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(context, alignment: 0.5);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    return SelectedButton(
      value: widget.selected,
      alignment: AlignmentDirectional.centerStart,
      onChanged: (_) => widget.onTap(),
      onHover: (_) => widget.onHover(),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.density.baseContentPadding * theme.scaling * 0.5,
          vertical: theme.density.baseGap * theme.scaling * 0.5,
        ),
        child: Row(
          children: [
            Icon(
              entry.icon,
              size: 16,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  shadcn.Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ).small,
                  if (entry.subtitle != null)
                    shadcn.Text(
                      entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ).muted.xSmall,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

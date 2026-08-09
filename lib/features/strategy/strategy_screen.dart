import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../../core/ui/slide_page_route.dart';
import '../../core/date_format.dart';
import 'strategy_repository.dart';
import 'note_editor.dart';

/// Largeur en dessous de laquelle il n'y a plus assez de place pour la
/// liste de notes ET l'éditeur côte à côte (mode desktop) : la liste
/// devient alors sa propre page, avec un éditeur poussé en plein écran
/// (glissement depuis la droite, retour via un chevron dans l'AppBar).
const _splitThreshold = 700.0;

class StrategyScreen extends StatefulWidget {
  final String vaultPath;
  const StrategyScreen({super.key, required this.vaultPath});

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen> {
  late StrategyRepository _repo;

  final ValueNotifier<List<StrategyNote>> _notes = ValueNotifier([]);
  String? _selectedId;
  bool _loading = true;
  bool _loadError = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _repo = StrategyRepository(widget.vaultPath);
    _loadNotes();
  }

  @override
  void didUpdateWidget(covariant StrategyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) {
      _repo = StrategyRepository(widget.vaultPath);
      _selectedId = null;
      _loading = true;
      _loadError = false;
      _notes.value = const [];
      _loadNotes();
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final generation = ++_loadGeneration;
    try {
      // Un dossier Vault sur un emplacement synchronisé (iCloud Drive...)
      // peut mettre du temps à répondre, voire ne jamais répondre si le
      // fournisseur cloud est indisponible : un délai borné évite un
      // spinner infini et silencieux, remplacé par un état d'erreur
      // explicite avec bouton "Réessayer".
      final notes = await _repo.listNotes().timeout(
        const Duration(seconds: 15),
      );
      if (!mounted || generation != _loadGeneration) return;
      _notes.value = notes;
      if (_loading || _loadError) {
        setState(() {
          _selectedId ??= notes.isNotEmpty ? notes.first.id : null;
          _loading = false;
          _loadError = false;
        });
      }
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<void> _deleteNote(String id) async {
    await _repo.deleteNote(id);
    if (!mounted) return;
    if (_selectedId == id) {
      setState(() => _selectedId = null);
    }
    await _loadNotes();
  }

  void _selectNote(String id) {
    if (id == _selectedId) return;
    setState(() => _selectedId = id);
  }

  Future<void> _createNoteDesktop() async {
    final note = await _repo.createNote();
    await _loadNotes();
    if (!mounted) return;
    setState(() => _selectedId = note.id);
  }

  Future<void> _createNoteMobile(BuildContext context) async {
    final note = await _repo.createNote();
    await _loadNotes();
    if (!mounted || !context.mounted) return;
    setState(() => _selectedId = note.id);
    _openNoteDetail(context, note);
  }

  void _openNoteDetail(BuildContext context, StrategyNote note) {
    setState(() => _selectedId = note.id);
    Navigator.of(context).push(
      slidePageRoute(
        (context) => _NoteDetailPage(
          title: note.title,
          repository: _repo,
          noteId: note.id,
          onSaved: _loadNotes,
        ),
      ),
    );
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError) {
      return LoadErrorView(
        message:
            'Impossible de charger les notes. Vérifiez que le dossier '
            'Vault est accessible.',
        onRetry: _retryLoad,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FrostedCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= _splitThreshold) {
              return _buildDesktopSplit();
            }
            return _NotesListPanel(
              notes: _notes,
              selectedId: _selectedId,
              showSearch: true,
              onCreate: () => _createNoteMobile(context),
              onDelete: _deleteNote,
              onOpen: (note) => _openNoteDetail(context, note),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopSplit() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 280,
          child: _NotesListPanel(
            notes: _notes,
            selectedId: _selectedId,
            onCreate: _createNoteDesktop,
            onDelete: _deleteNote,
            onOpen: (note) => _selectNote(note.id),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedId == null
              ? const Center(child: shadcn.Text('Sélectionne ou crée une note'))
              : NoteEditor(
                  key: ValueKey(_selectedId),
                  repository: _repo,
                  noteId: _selectedId!,
                  onSaved: _loadNotes,
                ),
        ),
      ],
    );
  }
}

/// Liste des notes, réutilisée en colonne fixe (desktop, à côté de
/// l'éditeur) et en page pleine largeur avec recherche (mobile, avant de
/// pousser vers l'éditeur).
class _NotesListPanel extends StatefulWidget {
  final ValueListenable<List<StrategyNote>> notes;
  final String? selectedId;
  final ValueChanged<StrategyNote> onOpen;
  final ValueChanged<String> onDelete;
  final VoidCallback onCreate;
  final bool showSearch;

  const _NotesListPanel({
    required this.notes,
    required this.selectedId,
    required this.onOpen,
    required this.onDelete,
    required this.onCreate,
    this.showSearch = false,
  });

  @override
  State<_NotesListPanel> createState() => _NotesListPanelState();
}

class _NotesListPanelState extends State<_NotesListPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(child: shadcn.Text('Notes')),
              IconButton.ghost(
                icon: const Icon(LucideIcons.filePlus),
                onPressed: widget.onCreate,
              ),
            ],
          ),
        ),
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              placeholder: const shadcn.Text('Rechercher une note...'),
              features: const [
                InputFeature.leading(Icon(LucideIcons.search, size: 16)),
              ],
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: ValueListenableBuilder<List<StrategyNote>>(
            valueListenable: widget.notes,
            builder: (context, notes, _) {
              final query = _query.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? notes
                  : notes
                        .where((n) => n.title.toLowerCase().contains(query))
                        .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: shadcn.Text(
                    notes.isEmpty ? 'Aucune note' : 'Aucun résultat',
                  ).muted().small(),
                );
              }

              return ListView.builder(
                // Sans padding explicite, ListView hérite automatiquement
                // du padding de sécurité (MediaQuery, encoche/Dynamic
                // Island) en haut de la liste : un grand vide qui donne
                // l'impression qu'une note manque. L'AppBar gère déjà la
                // zone de sécurité au-dessus, donc ce padding est superflu.
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final note = filtered[i];
                  final selected = note.id == widget.selectedId;
                  final theme = Theme.of(context);
                  return GestureDetector(
                    key: ValueKey(note.id),
                    onTap: () => widget.onOpen(note),
                    child: Container(
                      color: selected
                          ? theme.colorScheme.accent
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                shadcn.Text(
                                  note.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                shadcn.Text(
                                  formatDateDdMmYyyy(note.updatedAt),
                                ).muted().small(),
                              ],
                            ),
                          ),
                          IconButton.ghost(
                            icon: const Icon(LucideIcons.trash2, size: 16),
                            onPressed: () => widget.onDelete(note.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Page plein écran (mobile) pour éditer une note, poussée depuis la liste
/// avec un retour via le chevron gauche de l'AppBar.
class _NoteDetailPage extends StatelessWidget {
  final String title;
  final StrategyRepository repository;
  final String noteId;
  final VoidCallback onSaved;

  const _NoteDetailPage({
    required this.title,
    required this.repository,
    required this.noteId,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: shadcn.Text(title),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: NoteEditor(
          key: ValueKey(noteId),
          repository: repository,
          noteId: noteId,
          onSaved: onSaved,
        ),
      ),
    );
  }
}

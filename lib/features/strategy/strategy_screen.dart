import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../../core/ui/slide_page_route.dart';
import '../../core/date_format.dart';
import '../investments/confirm_delete_dialog.dart';
import 'strategy_documents_repository.dart';
import 'strategy_folders_repository.dart';
import 'strategy_repository.dart';
import 'note_editor.dart';

/// Largeur en dessous de laquelle il n'y a plus assez de place pour la
/// liste de notes ET l'éditeur côte à côte (mode desktop) : la liste
/// devient alors sa propre page, avec un éditeur poussé en plein écran
/// (glissement depuis la droite, retour via un chevron dans l'AppBar).
const _splitThreshold = 700.0;

/// État des dossiers et de leur contenu — chargés/rechargés ensemble (voir
/// [_StrategyScreenState._loadFolders]), portés par un seul
/// [ValueNotifier] plutôt que deux pour ne jamais les désynchroniser (une
/// note rangée dans un dossier qui vient d'être supprimé, par exemple).
typedef _FolderState = ({
  List<StrategyFolder> folders,
  Map<String, String> noteFolders,
});

const _emptyFolderState = (
  folders: <StrategyFolder>[],
  noteFolders: <String, String>{},
);

/// Palette proposée à la création d'un dossier ou pour en changer la
/// couleur — un choix restreint de teintes bien distinctes plutôt qu'un
/// sélecteur de couleur libre, largement suffisant pour distinguer
/// quelques dossiers d'un coup d'œil.
const _folderColorPalette = <int>[
  0xFFEF5350,
  0xFFFFA726,
  0xFFFFEE58,
  0xFF66BB6A,
  0xFF26C6DA,
  0xFF42A5F5,
  0xFF7E57C2,
  0xFFEC407A,
  0xFF8D6E63,
  0xFF78909C,
];

class StrategyScreen extends StatefulWidget {
  final String vaultPath;
  const StrategyScreen({super.key, required this.vaultPath});

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen> {
  late StrategyRepository _repo;
  late StrategyDocumentsRepository _documentsRepo;
  late StrategyFoldersRepository _foldersRepo;

  final ValueNotifier<List<StrategyNote>> _notes = ValueNotifier([]);
  final ValueNotifier<_FolderState> _folderState = ValueNotifier(
    _emptyFolderState,
  );
  String? _selectedId;
  bool _loading = true;
  bool _loadError = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _repo = StrategyRepository(widget.vaultPath);
    _documentsRepo = StrategyDocumentsRepository(widget.vaultPath);
    _foldersRepo = StrategyFoldersRepository(widget.vaultPath);
    _loadNotes();
    _loadFolders();
  }

  @override
  void didUpdateWidget(covariant StrategyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) {
      _repo = StrategyRepository(widget.vaultPath);
      _documentsRepo = StrategyDocumentsRepository(widget.vaultPath);
      _foldersRepo = StrategyFoldersRepository(widget.vaultPath);
      _selectedId = null;
      _loading = true;
      _loadError = false;
      _notes.value = const [];
      _folderState.value = _emptyFolderState;
      _loadNotes();
      _loadFolders();
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _folderState.dispose();
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
      var notes = await _repo.listNotes().timeout(const Duration(seconds: 15));
      // Premier passage dans l'onglet Stratégie : on crée les notes
      // modèle (Watchlist, Thèse, ...) pour inciter à prendre des notes.
      // La création est sans effet si elle a déjà eu lieu une fois.
      if (notes.isEmpty) {
        final created = await _repo.createTemplatesIfFirstVisit().timeout(
          const Duration(seconds: 15),
        );
        if (created) {
          notes = await _repo.listNotes();
        }
      }
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

  /// Chargée à part de [_loadNotes] : les dossiers sont une commodité
  /// d'organisation, pas vitale — une erreur ici ne doit jamais empêcher
  /// d'utiliser les notes elles-mêmes (protégées par leur propre borne de
  /// temps/état d'erreur ci-dessus).
  Future<void> _loadFolders() async {
    try {
      final folders = await _foldersRepo.listFolders();
      final noteFolders = await _foldersRepo.noteFolders();
      if (!mounted) return;
      _folderState.value = (folders: folders, noteFolders: noteFolders);
    } catch (_) {
      // Silencieux, voir la doc ci-dessus.
    }
  }

  Future<void> _deleteNote(String id) async {
    // Les documents rattachés (voir `NoteEditor`'s bouton "Documents") ne
    // sont pas dans le fichier `.md` de la note : sans ce nettoyage
    // explicite, leurs octets resteraient orphelins dans le vault après
    // la suppression de la note elle-même. Même raisonnement pour son
    // éventuelle affectation à un dossier.
    await _documentsRepo.deleteAllFor(id);
    await _foldersRepo.moveNoteToFolder(id, null);
    await _repo.deleteNote(id);
    if (!mounted) return;
    if (_selectedId == id) {
      setState(() => _selectedId = null);
    }
    await _loadNotes();
    await _loadFolders();
  }

  Future<void> _createFolder(String name, int color) async {
    await _foldersRepo.createFolder(name, color);
    await _loadFolders();
  }

  Future<void> _renameFolder(String id, String name) async {
    await _foldersRepo.renameFolder(id, name);
    await _loadFolders();
  }

  Future<void> _setFolderColor(String id, int color) async {
    await _foldersRepo.setFolderColor(id, color);
    await _loadFolders();
  }

  Future<void> _deleteFolder(String id) async {
    await _foldersRepo.deleteFolder(id);
    await _loadFolders();
  }

  Future<void> _moveNoteToFolder(String noteId, String? folderId) async {
    await _foldersRepo.moveNoteToFolder(noteId, folderId);
    await _loadFolders();
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
              folderState: _folderState,
              selectedId: _selectedId,
              showSearch: true,
              onCreate: () => _createNoteMobile(context),
              onDelete: _deleteNote,
              onOpen: (note) => _openNoteDetail(context, note),
              onCreateFolder: _createFolder,
              onRenameFolder: _renameFolder,
              onChangeFolderColor: _setFolderColor,
              onDeleteFolder: _deleteFolder,
              onMoveNoteToFolder: _moveNoteToFolder,
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
            folderState: _folderState,
            selectedId: _selectedId,
            onCreate: _createNoteDesktop,
            onDelete: _deleteNote,
            onOpen: (note) => _selectNote(note.id),
            onCreateFolder: _createFolder,
            onRenameFolder: _renameFolder,
            onChangeFolderColor: _setFolderColor,
            onDeleteFolder: _deleteFolder,
            onMoveNoteToFolder: _moveNoteToFolder,
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
/// pousser vers l'éditeur). Groupée par dossier (voir [StrategyFolder]) —
/// une recherche active bascule sur une liste plate de résultats, tous
/// dossiers confondus, pour ne jamais cacher une note qui correspond dans
/// un dossier replié.
class _NotesListPanel extends StatefulWidget {
  final ValueListenable<List<StrategyNote>> notes;
  final ValueListenable<_FolderState> folderState;
  final String? selectedId;
  final ValueChanged<StrategyNote> onOpen;
  final ValueChanged<String> onDelete;
  final VoidCallback onCreate;
  final bool showSearch;

  final Future<void> Function(String name, int color) onCreateFolder;
  final Future<void> Function(String id, String name) onRenameFolder;
  final Future<void> Function(String id, int color) onChangeFolderColor;
  final Future<void> Function(String id) onDeleteFolder;
  final Future<void> Function(String noteId, String? folderId)
  onMoveNoteToFolder;

  const _NotesListPanel({
    required this.notes,
    required this.folderState,
    required this.selectedId,
    required this.onOpen,
    required this.onDelete,
    required this.onCreate,
    this.showSearch = false,
    required this.onCreateFolder,
    required this.onRenameFolder,
    required this.onChangeFolderColor,
    required this.onDeleteFolder,
    required this.onMoveNoteToFolder,
  });

  @override
  State<_NotesListPanel> createState() => _NotesListPanelState();
}

/// Valeur retournée par le sélecteur de dossier (voir [_promptMoveToFolder])
/// pour "Sans dossier" — distincte de `null`, qui signale plutôt que la
/// popup a été fermée sans choix (barrière cliquée, "Annuler").
const _noFolderSentinel = '__none__';

class _NotesListPanelState extends State<_NotesListPanel> {
  String _query = '';

  /// Dossiers repliés — un simple identifiant par dossier replié, jamais
  /// persisté (état de session, comme les accordéons de
  /// `category_detail_screen.dart`) : tout dossier nouvellement créé
  /// démarre donc déplié.
  final Set<String> _collapsedFolderIds = {};

  void _toggleFolder(String folderId) {
    setState(() {
      if (!_collapsedFolderIds.remove(folderId)) {
        _collapsedFolderIds.add(folderId);
      }
    });
  }

  Future<void> _promptCreateFolder(BuildContext context) async {
    final nameController = TextEditingController();
    final result = await showDialog<({String name, int color})>(
      context: context,
      builder: (context) => _FolderEditDialog(
        title: 'Nouveau dossier',
        nameController: nameController,
        initialColor: _folderColorPalette.first,
        submitLabel: 'Créer',
      ),
    );
    nameController.dispose();
    if (result == null) return;
    await widget.onCreateFolder(result.name, result.color);
  }

  Future<void> _promptRenameFolder(
    BuildContext context,
    StrategyFolder folder,
  ) async {
    final nameController = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: FrostedCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const shadcn.Text('Renommer le dossier').large().semiBold(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    placeholder: const shadcn.Text('Nom du dossier'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      PrimaryButton(
                        onPressed: () {
                          final trimmed = nameController.text.trim();
                          if (trimmed.isEmpty) return;
                          Navigator.of(context).pop(trimmed);
                        },
                        child: const shadcn.Text('Renommer'),
                      ),
                      const SizedBox(width: 8),
                      OutlineButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const shadcn.Text('Annuler'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameController.dispose();
    if (name == null) return;
    await widget.onRenameFolder(folder.id, name);
  }

  Future<void> _promptChangeFolderColor(
    BuildContext context,
    StrategyFolder folder,
  ) async {
    final color = await showDialog<int>(
      context: context,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: FrostedCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const shadcn.Text('Couleur du dossier').large().semiBold(),
                  const SizedBox(height: 12),
                  _ColorSwatchPicker(
                    selected: folder.color,
                    // Choisir une couleur referme directement la popup, pas
                    // de bouton "Valider" séparé — un seul geste.
                    onChanged: (color) => Navigator.of(context).pop(color),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlineButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const shadcn.Text('Annuler'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (color == null) return;
    await widget.onChangeFolderColor(folder.id, color);
  }

  Future<void> _confirmDeleteFolder(
    BuildContext context,
    StrategyFolder folder,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer "${folder.name}" ?',
      message:
          'Les notes qu\'il contient ne seront pas supprimées, seulement '
          'rangées de nouveau hors dossier.',
    );
    if (!confirmed) return;
    await widget.onDeleteFolder(folder.id);
  }

  Future<void> _promptMoveToFolder(
    BuildContext context,
    StrategyNote note,
    List<StrategyFolder> folders,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 480),
          child: FrostedCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const shadcn.Text(
                    'Déplacer vers un dossier',
                  ).large().semiBold(),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _FolderOptionTile(
                            label: 'Sans dossier',
                            color: null,
                            onTap: () =>
                                Navigator.of(context).pop(_noFolderSentinel),
                          ),
                          for (final folder in folders) ...[
                            const SizedBox(height: 6),
                            _FolderOptionTile(
                              label: folder.name,
                              color: Color(folder.color),
                              onTap: () => Navigator.of(context).pop(folder.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlineButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const shadcn.Text('Annuler'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    await widget.onMoveNoteToFolder(
      note.id,
      result == _noFolderSentinel ? null : result,
    );
  }

  void _openNoteMenu(
    BuildContext anchorContext,
    StrategyNote note,
    List<StrategyFolder> folders,
  ) {
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.folderInput, size: 14),
              child: const shadcn.Text('Déplacer vers un dossier'),
              onPressed: (_) => _promptMoveToFolder(context, note, folders),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.trash2, size: 14),
              child: const shadcn.Text('Supprimer'),
              onPressed: (_) => widget.onDelete(note.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteRow(
    BuildContext context,
    StrategyNote note, {
    required List<StrategyFolder> folders,
  }) {
    final selected = note.id == widget.selectedId;
    final theme = Theme.of(context);
    return GestureDetector(
      key: ValueKey(note.id),
      onTap: () => widget.onOpen(note),
      child: Container(
        color: selected ? theme.colorScheme.accent : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            Builder(
              builder: (context) => IconButton.ghost(
                icon: const Icon(LucideIcons.ellipsisVertical, size: 16),
                onPressed: () => _openNoteMenu(context, note, folders),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                icon: const Icon(LucideIcons.folderPlus),
                onPressed: () => _promptCreateFolder(context),
              ),
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

              if (query.isNotEmpty) {
                final filtered = notes
                    .where((n) => n.title.toLowerCase().contains(query))
                    .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: shadcn.Text('Aucun résultat').muted().small(),
                  );
                }
                return ValueListenableBuilder<_FolderState>(
                  valueListenable: widget.folderState,
                  builder: (context, folderState, _) => ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final note in filtered)
                        _noteRow(context, note, folders: folderState.folders),
                    ],
                  ),
                );
              }

              if (notes.isEmpty) {
                return Center(
                  child: shadcn.Text('Aucune note').muted().small(),
                );
              }

              return ValueListenableBuilder<_FolderState>(
                valueListenable: widget.folderState,
                builder: (context, folderState, _) {
                  final folders = folderState.folders;
                  final noteFolders = folderState.noteFolders;
                  final folderIds = {for (final f in folders) f.id};
                  final byFolder = <String, List<StrategyNote>>{};
                  final unfiled = <StrategyNote>[];
                  for (final note in notes) {
                    final folderId = noteFolders[note.id];
                    // Un dossier a pu être supprimé sans que cette note
                    // n'ait encore été rechargée : traitée comme sans
                    // dossier plutôt que de disparaître de la liste.
                    if (folderId != null && folderIds.contains(folderId)) {
                      byFolder.putIfAbsent(folderId, () => []).add(note);
                    } else {
                      unfiled.add(note);
                    }
                  }

                  return ListView(
                    // Voir le commentaire équivalent plus bas dans ce
                    // fichier (mode recherche) : pas de padding de sécurité
                    // superflu ici non plus.
                    padding: EdgeInsets.zero,
                    children: [
                      for (final folder in folders) ...[
                        _FolderHeader(
                          folder: folder,
                          noteCount: (byFolder[folder.id] ?? const []).length,
                          collapsed: _collapsedFolderIds.contains(folder.id),
                          onToggle: () => _toggleFolder(folder.id),
                          onRename: () => _promptRenameFolder(context, folder),
                          onChangeColor: () =>
                              _promptChangeFolderColor(context, folder),
                          onDelete: () => _confirmDeleteFolder(context, folder),
                        ),
                        if (!_collapsedFolderIds.contains(folder.id))
                          for (final note in byFolder[folder.id] ?? const [])
                            _noteRow(context, note, folders: folders),
                      ],
                      if (folders.isNotEmpty && unfiled.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: shadcn.Text('Sans dossier').muted().xSmall(),
                        ),
                      for (final note in unfiled)
                        _noteRow(context, note, folders: folders),
                    ],
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

/// En-tête d'un dossier dans la liste des notes : nom, pastille de couleur,
/// nombre de notes, et un chevron dédié pour déplier/replier — même
/// principe que les accordéons de `category_detail_screen.dart` (voir sa
/// doc de classe pour le raisonnement) : le chevron est le seul
/// déclencheur du dépli/repli, jamais la ligne entière, qui n'a d'ailleurs
/// aucune action au clic (un dossier n'a pas de page propre à ouvrir) — le
/// menu "⋮" porte les actions (renommer/changer la couleur/supprimer).
class _FolderHeader extends StatelessWidget {
  final StrategyFolder folder;
  final int noteCount;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onChangeColor;
  final VoidCallback onDelete;

  const _FolderHeader({
    required this.folder,
    required this.noteCount,
    required this.collapsed,
    required this.onToggle,
    required this.onRename,
    required this.onChangeColor,
    required this.onDelete,
  });

  void _openMenu(BuildContext anchorContext) {
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.pencil, size: 14),
              child: const shadcn.Text('Renommer'),
              onPressed: (_) => onRename(),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.palette, size: 14),
              child: const shadcn.Text('Changer la couleur'),
              onPressed: (_) => onChangeColor(),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.trash2, size: 14),
              child: const shadcn.Text('Supprimer'),
              onPressed: (_) => onDelete(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton.ghost(
            icon: AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(LucideIcons.chevronDown, size: 16),
            ),
            onPressed: onToggle,
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Color(folder.color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: shadcn.Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ).medium().small(),
          ),
          shadcn.Text('$noteCount').muted().xSmall(),
          const SizedBox(width: 4),
          Builder(
            builder: (context) => IconButton.ghost(
              icon: const Icon(LucideIcons.ellipsisVertical, size: 16),
              onPressed: () => _openMenu(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne sélectionnable d'un dossier (ou "Sans dossier", [color] `null`)
/// dans le sélecteur de `_promptMoveToFolder`.
class _FolderOptionTile extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _FolderOptionTile({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color ?? Colors.transparent,
                    shape: BoxShape.circle,
                    border: color == null
                        ? Border.all(
                            color: Theme.of(context).colorScheme.border,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                shadcn.Text(label).small(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de couleur de dossier — la [_folderColorPalette], en pastilles
/// cliquables, celle sélectionnée cerclée.
class _ColorSwatchPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _ColorSwatchPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final color in _folderColorPalette)
          MouseRegion(
            key: ValueKey('folder-color-swatch-$color'),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onChanged(color),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == selected
                        ? theme.colorScheme.foreground
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: color == selected
                    ? const Icon(
                        LucideIcons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Dialogue de création d'un dossier : nom + couleur, dans un seul geste
/// ("Créer") — voir [_NotesListPanelState._promptCreateFolder].
class _FolderEditDialog extends StatefulWidget {
  final String title;
  final TextEditingController nameController;
  final int initialColor;
  final String submitLabel;

  const _FolderEditDialog({
    required this.title,
    required this.nameController,
    required this.initialColor,
    required this.submitLabel,
  });

  @override
  State<_FolderEditDialog> createState() => _FolderEditDialogState();
}

class _FolderEditDialogState extends State<_FolderEditDialog> {
  late int _color = widget.initialColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(widget.title).large().semiBold(),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.nameController,
                  placeholder: const shadcn.Text('Nom du dossier'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                _ColorSwatchPicker(
                  selected: _color,
                  onChanged: (color) => setState(() => _color = color),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    PrimaryButton(
                      onPressed: () {
                        final name = widget.nameController.text.trim();
                        if (name.isEmpty) return;
                        Navigator.of(context).pop((name: name, color: _color));
                      },
                      child: shadcn.Text(widget.submitLabel),
                    ),
                    const SizedBox(width: 8),
                    OutlineButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const shadcn.Text('Annuler'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

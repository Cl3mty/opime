import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/ui/frosted_card.dart';
import '../../core/ui/load_error_view.dart';
import '../../core/ui/slide_page_route.dart';
import '../investments/investments_models.dart' show InvestmentAccount;
import '../investments/investments_repository.dart';
import '../liabilities/liabilities_models.dart' show Liability;
import '../liabilities/liabilities_repository.dart';
import 'project_editor.dart';
import 'project_models.dart';
import 'project_progress.dart';
import 'project_repository.dart';

/// Largeur en dessous de laquelle il n'y a plus assez de place pour la
/// liste de projets ET l'éditeur côte à côte (mode desktop) — même seuil et
/// même bascule liste/éditeur que `strategy_screen.dart`.
const _splitThreshold = 700.0;

/// Écran "Projets" : projets financiers créés par l'utilisateur (échéance,
/// rendement attendu, montant cible optionnel), avec des actifs et passifs
/// existants rattachés pour en suivre l'avancement — voir
/// `project_progress.dart`.
class ProjectsScreen extends StatefulWidget {
  final String vaultPath;
  const ProjectsScreen({super.key, required this.vaultPath});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late ProjectRepository _repo;

  final ValueNotifier<List<Project>> _projects = ValueNotifier([]);
  List<InvestmentAccount> _accounts = [];
  List<Liability> _liabilities = [];
  String? _selectedId;
  bool _creatingNew = false;
  bool _loading = true;
  bool _loadError = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _repo = ProjectRepository(widget.vaultPath);
    _load();
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) {
      _repo = ProjectRepository(widget.vaultPath);
      _selectedId = null;
      _creatingNew = false;
      _loading = true;
      _loadError = false;
      _projects.value = const [];
      _load();
    }
  }

  @override
  void dispose() {
    _projects.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final results = await Future.wait([
        _repo.listAll(),
        InvestmentsRepository(widget.vaultPath).listAll(),
        LiabilitiesRepository(widget.vaultPath).listAll(),
      ]).timeout(const Duration(seconds: 15));
      if (!mounted || generation != _loadGeneration) return;
      final projects = results[0] as List<Project>;
      _projects.value = projects;
      setState(() {
        _accounts = results[1] as List<InvestmentAccount>;
        _liabilities = results[2] as List<Liability>;
        if (_loading || _loadError) {
          _selectedId ??= projects.isNotEmpty ? projects.first.id : null;
        }
        _loading = false;
        _loadError = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<void> _deleteProject(String id) async {
    await _repo.deleteProject(id);
    if (!mounted) return;
    if (_selectedId == id) setState(() => _selectedId = null);
    await _load();
  }

  void _selectProject(String id) {
    setState(() {
      _selectedId = id;
      _creatingNew = false;
    });
  }

  void _startCreateDesktop() {
    setState(() {
      _creatingNew = true;
      _selectedId = null;
    });
  }

  void _openEditorMobile(BuildContext context, {Project? project}) {
    Navigator.of(context).push(
      slidePageRoute(
        (context) => _ProjectEditorPage(
          title: project == null ? 'Nouveau projet' : project.name,
          vaultPath: widget.vaultPath,
          project: project,
          onSaved: () async {
            await _load();
            if (context.mounted) Navigator.of(context).pop();
          },
          onDeleted: () async {
            await _load();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError) {
      return LoadErrorView(
        message:
            'Impossible de charger les projets. Vérifiez que le dossier '
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
            return _ProjectsListPanel(
              projects: _projects,
              accounts: _accounts,
              liabilities: _liabilities,
              selectedId: _selectedId,
              onCreate: () => _openEditorMobile(context),
              onDelete: _deleteProject,
              onOpen: (project) => _openEditorMobile(context, project: project),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopSplit() {
    final selected = _selectedId == null
        ? null
        : _projects.value.where((p) => p.id == _selectedId).firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 320,
          child: _ProjectsListPanel(
            projects: _projects,
            accounts: _accounts,
            liabilities: _liabilities,
            selectedId: _selectedId,
            onCreate: _startCreateDesktop,
            onDelete: _deleteProject,
            onOpen: (project) => _selectProject(project.id),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: (selected == null && !_creatingNew)
              ? const Center(
                  child: shadcn.Text('Sélectionne ou crée un projet'),
                )
              : ProjectEditor(
                  key: ValueKey(_creatingNew ? 'new' : _selectedId),
                  vaultPath: widget.vaultPath,
                  project: _creatingNew ? null : selected,
                  onSaved: () async {
                    await _load();
                    setState(() => _creatingNew = false);
                  },
                  onDeleted: () async {
                    setState(() => _selectedId = null);
                    await _load();
                  },
                ),
        ),
      ],
    );
  }
}

/// Liste des projets, réutilisée en colonne fixe (desktop, à côté de
/// l'éditeur) et en page pleine largeur (mobile, avant de pousser vers
/// l'éditeur) — même structure que `_NotesListPanel` de
/// `strategy_screen.dart`.
class _ProjectsListPanel extends StatelessWidget {
  final ValueListenable<List<Project>> projects;
  final List<InvestmentAccount> accounts;
  final List<Liability> liabilities;
  final String? selectedId;
  final ValueChanged<Project> onOpen;
  final ValueChanged<String> onDelete;
  final VoidCallback onCreate;

  const _ProjectsListPanel({
    required this.projects,
    required this.accounts,
    required this.liabilities,
    required this.selectedId,
    required this.onOpen,
    required this.onDelete,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(child: shadcn.Text('Projets')),
              IconButton.ghost(
                icon: const Icon(LucideIcons.plus),
                onPressed: onCreate,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ValueListenableBuilder<List<Project>>(
            valueListenable: projects,
            builder: (context, all, _) {
              if (all.isEmpty) {
                return Center(
                  child: shadcn.Text('Aucun projet').muted().small(),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: all.length,
                itemBuilder: (context, i) {
                  final project = all[i];
                  final selected = project.id == selectedId;
                  final progress = computeProjectProgress(
                    project: project,
                    accounts: accounts,
                    liabilities: liabilities,
                    today: today,
                  );
                  final theme = Theme.of(context);
                  return GestureDetector(
                    key: ValueKey(project.id),
                    onTap: () => onOpen(project),
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
                                  project.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                shadcn.Text(
                                  formatEcheanceRelative(project.echeance, today),
                                ).muted().small(),
                                if (progress.percent != null) ...[
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: (progress.percent! / 100).clamp(0, 1),
                                      minHeight: 4,
                                      backgroundColor: theme.colorScheme.muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton.ghost(
                            icon: const Icon(LucideIcons.trash2, size: 16),
                            onPressed: () => onDelete(project.id),
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

/// Page plein écran (mobile) pour créer/éditer un projet, poussée depuis la
/// liste avec un retour via le chevron gauche de l'AppBar — même structure
/// que `_NoteDetailPage` de `strategy_screen.dart`.
class _ProjectEditorPage extends StatelessWidget {
  final String title;
  final String vaultPath;
  final Project? project;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  const _ProjectEditorPage({
    required this.title,
    required this.vaultPath,
    required this.project,
    required this.onSaved,
    required this.onDeleted,
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
      child: ProjectEditor(
        key: ValueKey(project?.id ?? 'new'),
        vaultPath: vaultPath,
        project: project,
        onSaved: onSaved,
        onDeleted: onDeleted,
      ),
    );
  }
}

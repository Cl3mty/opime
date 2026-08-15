import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/date_format.dart';
import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import '../investments/investments_models.dart'
    show InvestmentAccount;
import '../investments/investments_repository.dart';
import '../liabilities/liabilities_models.dart' show Liability;
import '../liabilities/liabilities_repository.dart';
import 'project_models.dart';
import 'project_progress.dart';
import 'project_repository.dart';

String _assetKey(String accountId, String investmentId) =>
    '$accountId|$investmentId';

/// Formulaire de création/édition d'un projet — charge lui-même la liste
/// des comptes/investissements et des passifs pour ses sélecteurs de liens,
/// comme `note_editor.dart` charge sa propre note. `project` à `null`
/// démarre un nouveau projet vierge ; sinon l'édite.
class ProjectEditor extends StatefulWidget {
  final String vaultPath;
  final Project? project;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  const ProjectEditor({
    super.key,
    required this.vaultPath,
    required this.project,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  State<ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<ProjectEditor> {
  late ProjectRepository _repo;
  bool _loading = true;
  List<InvestmentAccount> _accounts = [];
  List<Liability> _liabilities = [];

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rendementController = TextEditingController();
  final _montantCibleController = TextEditingController();
  DateTime? _echeance;
  late Set<String> _selectedAssetKeys;
  late Set<String> _selectedLiabilityIds;

  @override
  void initState() {
    super.initState();
    _repo = ProjectRepository(widget.vaultPath);
    _resetFromProject();
    _loadPickerData();
  }

  @override
  void didUpdateWidget(covariant ProjectEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath ||
        oldWidget.project?.id != widget.project?.id) {
      _repo = ProjectRepository(widget.vaultPath);
      _resetFromProject();
      _loadPickerData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _rendementController.dispose();
    _montantCibleController.dispose();
    super.dispose();
  }

  void _resetFromProject() {
    final project = widget.project;
    _nameController.text = project?.name ?? '';
    _descriptionController.text = project?.description ?? '';
    _rendementController.text = project == null
        ? ''
        : project.rendementAttendu.toString();
    _montantCibleController.text = project?.montantCible?.toString() ?? '';
    _echeance = project?.echeance ??
        DateTime.now().add(const Duration(days: 365));
    _selectedAssetKeys = {
      for (final link in project?.assetLinks ?? const <ProjectAssetLink>[])
        _assetKey(link.accountId, link.investmentId),
    };
    _selectedLiabilityIds = {
      for (final link in project?.liabilityLinks ?? const <ProjectLiabilityLink>[])
        link.liabilityId,
    };
  }

  Future<void> _loadPickerData() async {
    setState(() => _loading = true);
    final accounts = await InvestmentsRepository(widget.vaultPath).listAll();
    final liabilities = await LiabilitiesRepository(widget.vaultPath).listAll();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _liabilities = liabilities;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final echeance = _echeance;
    if (name.isEmpty || echeance == null) return;

    final assetLinks = [
      for (final key in _selectedAssetKeys)
        ProjectAssetLink(
          accountId: key.split('|')[0],
          investmentId: key.split('|')[1],
        ),
    ];
    final liabilityLinks = [
      for (final id in _selectedLiabilityIds) ProjectLiabilityLink(liabilityId: id),
    ];
    final montantCible = double.tryParse(
      _montantCibleController.text.trim().replaceAll(',', '.'),
    );
    final rendementAttendu =
        double.tryParse(_rendementController.text.trim().replaceAll(',', '.')) ?? 0;

    final project = Project(
      id: widget.project?.id,
      name: name,
      description: _descriptionController.text.trim(),
      echeance: echeance,
      rendementAttendu: rendementAttendu,
      montantCible: montantCible,
      assetLinks: assetLinks,
      liabilityLinks: liabilityLinks,
    );
    await _repo.saveProject(project);
    widget.onSaved();
  }

  Future<void> _delete() async {
    final project = widget.project;
    if (project == null) return;
    await _repo.deleteProject(project.id);
    widget.onDeleted();
  }

  void _toggleAsset(String key) {
    setState(() {
      if (_selectedAssetKeys.contains(key)) {
        _selectedAssetKeys.remove(key);
      } else {
        _selectedAssetKeys.add(key);
      }
    });
  }

  void _toggleLiability(String id) {
    setState(() {
      if (_selectedLiabilityIds.contains(id)) {
        _selectedLiabilityIds.remove(id);
      } else {
        _selectedLiabilityIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final isEditing = widget.project != null;
    final danglingLinks = isEditing
        ? hasDanglingLinks(
            project: widget.project!,
            accounts: _accounts,
            liabilities: _liabilities,
          )
        : false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shadcn.Text(isEditing ? 'Modifier le projet' : 'Nouveau projet')
              .large()
              .semiBold(),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            placeholder: const shadcn.Text('Nom du projet (ex: Achat résidence principale)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            placeholder: const shadcn.Text('Description (facultatif)'),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          DatePicker(
            value: _echeance,
            onChanged: (date) => setState(() => _echeance = date),
            placeholder: const shadcn.Text('Échéance'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rendementController,
                  placeholder: const shadcn.Text('Rendement attendu (% / an)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _montantCibleController,
                  placeholder: const shadcn.Text('Montant cible en € (facultatif)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          shadcn.Text('Actifs liés').semiBold().small(),
          const SizedBox(height: 8),
          _AssetPicker(
            accounts: _accounts,
            selectedKeys: _selectedAssetKeys,
            onToggle: _toggleAsset,
          ),
          const SizedBox(height: 16),
          shadcn.Text('Passifs liés').semiBold().small(),
          const SizedBox(height: 8),
          _LiabilityPicker(
            liabilities: _liabilities,
            selectedIds: _selectedLiabilityIds,
            onToggle: _toggleLiability,
          ),
          if (danglingLinks) ...[
            const SizedBox(height: 8),
            shadcn.Text(
              '1 lien ou plus ne se résout plus (élément supprimé depuis).',
            ).muted().xSmall(),
          ],
          if (isEditing) ...[
            const SizedBox(height: 16),
            _ProgressPreview(
              project: widget.project!,
              accounts: _accounts,
              liabilities: _liabilities,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              PrimaryButton(
                onPressed: _save,
                child: const shadcn.Text('Enregistrer'),
              ),
              if (isEditing) ...[
                const SizedBox(width: 8),
                OutlineButton(
                  onPressed: _delete,
                  child: const shadcn.Text('Supprimer'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AssetPicker extends StatelessWidget {
  final List<InvestmentAccount> accounts;
  final Set<String> selectedKeys;
  final ValueChanged<String> onToggle;

  const _AssetPicker({
    required this.accounts,
    required this.selectedKeys,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final account in accounts)
        for (final investment in account.investments)
          (
            key: _assetKey(account.id, investment.id),
            label: '${investment.label} (${account.name})',
          ),
    ];
    if (entries.isEmpty) {
      return shadcn.Text('Aucun investissement disponible.').muted().small();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          _SelectableChip(
            label: entry.label,
            selected: selectedKeys.contains(entry.key),
            onTap: () => onToggle(entry.key),
          ),
      ],
    );
  }
}

class _LiabilityPicker extends StatelessWidget {
  final List<Liability> liabilities;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _LiabilityPicker({
    required this.liabilities,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (liabilities.isEmpty) {
      return shadcn.Text('Aucun passif disponible.').muted().small();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final liability in liabilities)
          _SelectableChip(
            label: liability.name,
            selected: selectedIds.contains(liability.id),
            onTap: () => onToggle(liability.id),
          ),
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: shadcn.Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected
                ? theme.colorScheme.primaryForeground
                : theme.colorScheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _ProgressPreview extends StatelessWidget {
  final Project project;
  final List<InvestmentAccount> accounts;
  final List<Liability> liabilities;

  const _ProgressPreview({
    required this.project,
    required this.accounts,
    required this.liabilities,
  });

  @override
  Widget build(BuildContext context) {
    final progress = computeProjectProgress(
      project: project,
      accounts: accounts,
      liabilities: liabilities,
      today: DateTime.now(),
    );
    final days = progress.timeRemaining.inDays;
    final timeLabel = days >= 0
        ? 'Échéance dans $days jours'
        : 'Échéance dépassée depuis ${-days} jours';

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shadcn.Text('Avancement').muted().small(),
            const SizedBox(height: 4),
            shadcn.Text(formatEuros(progress.currentNetValue)).large().semiBold(),
            if (progress.percent != null) ...[
              const SizedBox(height: 4),
              shadcn.Text(
                '${progress.percent!.toStringAsFixed(1)} % du montant cible',
              ).muted().small(),
            ],
            const SizedBox(height: 4),
            shadcn.Text(timeLabel).muted().small(),
          ],
        ),
      ),
    );
  }
}

/// Format court de l'échéance pour les lignes de liste — voir
/// [formatDateDdMmYyyy] pour la date brute complète.
String formatEcheanceRelative(DateTime echeance, DateTime today) {
  final days = echeance.difference(today).inDays;
  if (days < 0) return 'Échéance dépassée';
  if (days == 0) return 'Échéance aujourd\'hui';
  if (days < 31) return 'Dans $days jours';
  if (days < 365) return 'Dans ${(days / 30).round()} mois';
  return 'Dans ${(days / 365).round()} ans';
}

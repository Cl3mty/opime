import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/date_format.dart';
import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import '../dashboard/widgets/net_worth_chart.dart';
import '../investments/investments_models.dart' show InvestmentAccount;
import '../investments/investments_repository.dart';
import '../liabilities/liabilities_models.dart' show Liability;
import '../liabilities/liabilities_repository.dart';
import 'project_models.dart';
import 'project_progress.dart';
import 'project_repository.dart';
import 'project_trajectory.dart';
import 'widgets/goal_progress_bar.dart';

/// Formulaire de création/édition d'un projet — charge lui-même la liste
/// des comptes et des passifs pour ses sélecteurs de liens, comme
/// `note_editor.dart` charge sa propre note. `project` à `null` démarre un
/// nouveau projet vierge ; sinon l'édite.
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
  final _apportMensuelController = TextEditingController();
  final _montantCibleController = TextEditingController();
  DateTime? _echeance;
  late Set<String> _selectedAccountIds;
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
    _apportMensuelController.dispose();
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
    _apportMensuelController.text =
        project == null || project.apportMensuel == 0
        ? ''
        : project.apportMensuel.toString();
    _montantCibleController.text = project?.montantCible?.toString() ?? '';
    _echeance =
        project?.echeance ?? DateTime.now().add(const Duration(days: 365));
    _selectedAccountIds = {
      for (final link in project?.accountLinks ?? const <ProjectAccountLink>[])
        link.accountId,
    };
    _selectedLiabilityIds = {
      for (final link
          in project?.liabilityLinks ?? const <ProjectLiabilityLink>[])
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

    final accountLinks = [
      for (final accountId in _selectedAccountIds)
        ProjectAccountLink(accountId: accountId),
    ];
    final liabilityLinks = [
      for (final id in _selectedLiabilityIds)
        ProjectLiabilityLink(liabilityId: id),
    ];
    final montantCible = double.tryParse(
      _montantCibleController.text.trim().replaceAll(',', '.'),
    );
    final rendementAttendu =
        double.tryParse(
          _rendementController.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    final apportMensuel =
        double.tryParse(
          _apportMensuelController.text.trim().replaceAll(',', '.'),
        ) ??
        0;

    final project = Project(
      id: widget.project?.id,
      name: name,
      description: _descriptionController.text.trim(),
      echeance: echeance,
      rendementAttendu: rendementAttendu,
      apportMensuel: apportMensuel,
      montantCible: montantCible,
      accountLinks: accountLinks,
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

  void _toggleAccount(String accountId) {
    setState(() {
      if (_selectedAccountIds.contains(accountId)) {
        _selectedAccountIds.remove(accountId);
      } else {
        _selectedAccountIds.add(accountId);
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
          if (isEditing) ...[
            _ProjectDetailSection(
              project: widget.project!,
              accounts: _accounts,
              liabilities: _liabilities,
            ),
            const SizedBox(height: 20),
          ],
          shadcn.Text(
            isEditing ? 'Modifier le projet' : 'Nouveau projet',
          ).large().semiBold(),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            placeholder: const shadcn.Text(
              'Nom du projet (ex: Achat résidence principale)',
            ),
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
                  controller: _apportMensuelController,
                  placeholder: const shadcn.Text(
                    'Apport mensuel en € (facultatif)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _montantCibleController,
            placeholder: const shadcn.Text('Montant cible en € (facultatif)'),
          ),
          const SizedBox(height: 16),
          shadcn.Text('Comptes liés').semiBold().small(),
          const SizedBox(height: 8),
          _AccountPicker(
            accounts: _accounts,
            selectedIds: _selectedAccountIds,
            onToggle: _toggleAccount,
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

/// Sélecteur de comptes liés à un projet — un compte entier (ex : "PEA
/// Boursorama"), pas une position précise en son sein : les positions d'un
/// compte changent au fil des arbitrages, alors que le compte qui finance
/// un projet reste le même (voir `ProjectAccountLink`).
class _AccountPicker extends StatelessWidget {
  final List<InvestmentAccount> accounts;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _AccountPicker({
    required this.accounts,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return shadcn.Text('Aucun compte disponible.').muted().small();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final account in accounts)
          _SelectableChip(
            label: account.bankName != null
                ? '${account.name} (${account.bankName})'
                : account.name,
            selected: selectedIds.contains(account.id),
            onTap: () => onToggle(account.id),
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

/// Vue détail riche d'un projet — barre de progression (montant actuel /
/// montant cible), badge "En bonne voie"/"En retard", graphique de
/// trajectoire projetée (croissance composée au rendement attendu, avec
/// apport mensuel s'il y en a un — voir `project_trajectory.dart`), tuiles
/// de statistiques, et détail des comptes/passifs liés avec leur valeur.
/// Remplace l'ancien petit encart "Avancement" — inspirée de la page
/// "Objectifs" de Finary.
class _ProjectDetailSection extends StatelessWidget {
  final Project project;
  final List<InvestmentAccount> accounts;
  final List<Liability> liabilities;

  const _ProjectDetailSection({
    required this.project,
    required this.accounts,
    required this.liabilities,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final progress = computeProjectProgress(
      project: project,
      accounts: accounts,
      liabilities: liabilities,
      today: today,
    );
    final onTrack = isProjectOnTrack(
      currentValue: progress.currentNetValue,
      rendementAttenduPercent: project.rendementAttendu,
      montantCible: project.montantCible,
      today: today,
      echeance: project.echeance,
      apportMensuelEur: project.apportMensuel,
    );
    final trajectory = computeProjectTrajectory(
      currentValue: progress.currentNetValue,
      rendementAttenduPercent: project.rendementAttendu,
      today: today,
      echeance: project.echeance,
      apportMensuelEur: project.apportMensuel,
    );
    final days = progress.timeRemaining.inDays;
    final montantCible = project.montantCible;

    final linkedAssets = <(String, double)>[
      for (final link in project.accountLinks)
        for (final account in accounts)
          if (account.id == link.accountId)
            (
              account.name,
              account.investments.fold(
                0.0,
                (sum, i) => sum + (i.effectiveMarketValue ?? i.investedAmount),
              ),
            ),
    ];
    final linkedLiabilities = <(String, double)>[
      for (final link in project.liabilityLinks)
        for (final liability in liabilities)
          if (liability.id == link.liabilityId)
            (liability.name, -liability.remainingBalance),
    ];

    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: shadcn.Text(project.name).large().bold()),
                ProjectOnTrackBadge(onTrack: onTrack),
              ],
            ),
            const SizedBox(height: 2),
            shadcn.Text(
              formatEcheanceRelative(project.echeance, today),
            ).muted().small(),
            const SizedBox(height: 20),
            GoalProgressBar(
              currentValue: progress.currentNetValue,
              montantCible: montantCible,
              height: 14,
            ),
            if (trajectory.length >= 2) ...[
              const SizedBox(height: 24),
              shadcn.Text('Trajectoire projetée').semiBold().small(),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: NetWorthChart(
                  points: trajectory,
                  formatValue: formatEuros,
                  axisLabelFormat: formatEurosCompact,
                  lineColor: theme.colorScheme.primary,
                  gridColor: theme.colorScheme.border,
                  textColor: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatTile(
                  label: 'Rendement attendu',
                  value: '${project.rendementAttendu.toStringAsFixed(2)} %/an',
                ),
                if (project.apportMensuel != 0)
                  _StatTile(
                    label: 'Apport mensuel',
                    value: formatEuros(project.apportMensuel),
                  ),
                _StatTile(
                  label: 'Temps restant',
                  value: days >= 0 ? '$days jours' : 'Échéance dépassée',
                ),
                _StatTile(
                  label: 'Montant actuel',
                  value: formatEuros(progress.currentNetValue),
                ),
                if (montantCible != null)
                  _StatTile(
                    label: 'Reste à atteindre',
                    value: formatEuros(
                      (montantCible - progress.currentNetValue).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                  ),
              ],
            ),
            if (linkedAssets.isNotEmpty || linkedLiabilities.isNotEmpty) ...[
              const SizedBox(height: 20),
              shadcn.Text('Comptes et passifs liés').semiBold().small(),
              const SizedBox(height: 8),
              for (final (label, value) in linkedAssets)
                _LinkedItemRow(label: label, value: value),
              for (final (label, value) in linkedLiabilities)
                _LinkedItemRow(label: label, value: value),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          shadcn.Text(label).muted().xSmall(),
          const SizedBox(height: 2),
          shadcn.Text(value).semiBold(),
        ],
      ),
    );
  }
}

/// Ligne d'un actif/passif lié, avec sa valeur — un passif est déjà passé
/// en négatif par l'appelant (voir [_ProjectDetailSection]), affiché en
/// rouge pour le distinguer d'un actif au premier coup d'œil.
class _LinkedItemRow extends StatelessWidget {
  final String label;
  final double value;

  const _LinkedItemRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final negative = value < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: shadcn.Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ).small(),
          ),
          shadcn.Text(
            formatEuros(value.abs()),
            style: TextStyle(color: negative ? const Color(0xFFEF4444) : null),
          ).small(),
        ],
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

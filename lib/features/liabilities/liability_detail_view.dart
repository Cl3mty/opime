import 'dart:typed_data';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/toggle_button_style.dart';
import '../dashboard/widgets/net_worth_chart.dart';
import '../investments/confirm_delete_dialog.dart';
import '../investments/document_storage.dart';
import '../investments/documents_section.dart';
import '../investments/investments_models.dart' show VaultDocument;
import '../simulations/loan_calculator.dart';
import '../simulations/loan_chart.dart';
import 'liabilities_models.dart';
import 'liabilities_repository.dart';
import 'liability_form_fields.dart';
import 'real_passifs_adapter.dart' show remainingBalanceHistoryFor;

const _red = Color(0xFFEF4444);
const _blue = Color(0xFF7B8FE8);

enum _ChartMode { capitalRestant, repartitionMensualites }

// Même correctif que les autres toggles du Dashboard (`allocation_card.dart`,
// `category_detail_screen.dart`) : la densité "compact" rendait ces boutons
// illisibles/trop petits.
const _toggleButtonSize = ButtonSize(0.95);
const _toggleFontSize = 14.0 * 0.95;

/// Détail d'un passif réel : capital restant dû, mensualité, édition et
/// suppression. Le graphique bascule entre deux vues du même tableau
/// d'amortissement (dérivé via [simulateLoan]) : la courbe de décroissance
/// du capital restant dû, ou (comme dans la simulation de prêt, voir
/// `simulations/loan_chart.dart`) les barres empilées capital/intérêts/
/// assurance par année, qui montrent la part des intérêts diminuer dans la
/// mensualité au fil du remboursement. Vue embarquée dans
/// `RealPassifDetailScreen` (pas de `Navigator.push`), atteinte en
/// cliquant sur une ligne de la page de détail d'une catégorie de passifs.
class LiabilityDetailView extends StatefulWidget {
  final String vaultPath;
  final Liability liability;
  final bool hidden;
  final VoidCallback onBack;
  final VoidCallback onChanged;

  const LiabilityDetailView({
    super.key,
    required this.vaultPath,
    required this.liability,
    required this.hidden,
    required this.onBack,
    required this.onChanged,
  });

  @override
  State<LiabilityDetailView> createState() => _LiabilityDetailViewState();
}

class _LiabilityDetailViewState extends State<LiabilityDetailView> {
  late LiabilitiesRepository _repo;
  bool _editing = false;
  _ChartMode _chartMode = _ChartMode.capitalRestant;

  final _nameController = TextEditingController();
  final _prixController = TextEditingController();
  final _apportController = TextEditingController();
  final _tauxController = TextEditingController();
  final _assuranceMensuelleController = TextEditingController();
  final _nbrEcheancesController = TextEditingController();
  final _dureeDiffereController = TextEditingController();
  DateTime? _dateDebut;
  LoanType _loanType = LoanType.amortissable;
  bool _differeActif = false;
  DeferType _typeDiffere = DeferType.partielle;

  @override
  void initState() {
    super.initState();
    _repo = LiabilitiesRepository(widget.vaultPath);
  }

  @override
  void didUpdateWidget(covariant LiabilityDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultPath != widget.vaultPath) {
      _repo = LiabilitiesRepository(widget.vaultPath);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _prixController.dispose();
    _apportController.dispose();
    _tauxController.dispose();
    _assuranceMensuelleController.dispose();
    _nbrEcheancesController.dispose();
    _dureeDiffereController.dispose();
    super.dispose();
  }

  void _startEdit() {
    final liability = widget.liability;
    setState(() {
      _editing = true;
      _nameController.text = liability.name;
      _prixController.text = (liability.montantEmprunte + liability.apport)
          .toStringAsFixed(0);
      _apportController.text = liability.apport.toStringAsFixed(0);
      _tauxController.text = liability.tauxInteret.toString();
      _assuranceMensuelleController.text = liability.assuranceMensuelle
          .toString();
      _nbrEcheancesController.text = liability.nbrEcheances.toString();
      _dureeDiffereController.text = liability.dureeDiffereMois.toString();
      _dateDebut = liability.dateDebut;
      _loanType = liability.loanType;
      _differeActif = liability.differeActif;
      _typeDiffere = liability.typeDiffere;
    });
  }

  Future<void> _commitEdit() async {
    final name = _nameController.text.trim();
    final prix = parseDecimal(_prixController.text);
    final apport = parseDecimal(_apportController.text) ?? 0;
    final taux = parseDecimal(_tauxController.text);
    final assuranceMensuelle = parseDecimal(_assuranceMensuelleController.text);
    final nbrEcheances = int.tryParse(_nbrEcheancesController.text.trim());
    final dureeDiffere = int.tryParse(_dureeDiffereController.text.trim()) ?? 0;
    final dateDebut = _dateDebut;
    if (name.isEmpty ||
        prix == null ||
        prix <= 0 ||
        apport < 0 ||
        apport >= prix ||
        taux == null ||
        taux < 0 ||
        assuranceMensuelle == null ||
        assuranceMensuelle < 0 ||
        nbrEcheances == null ||
        nbrEcheances <= 0 ||
        dureeDiffere < 0 ||
        dateDebut == null) {
      return;
    }
    final updated = Liability(
      id: widget.liability.id,
      type: widget.liability.type,
      name: name,
      montantEmprunte: prix - apport,
      apport: apport,
      tauxInteret: taux,
      assuranceMensuelle: assuranceMensuelle,
      fraisDossier: widget.liability.fraisDossier,
      fraisGarantie: widget.liability.fraisGarantie,
      nbrEcheances: nbrEcheances,
      dateDebut: dateDebut,
      loanType: _loanType,
      differeActif: _differeActif,
      dureeDiffereMois: _differeActif ? dureeDiffere : 0,
      typeDiffere: _typeDiffere,
      documents: widget.liability.documents,
      // Construction via le constructeur brut (pas `copyWith`, qui
      // régénère `amortissement` sans savoir doser correctement les
      // champs à recalculer ici) : les champs non montrés par ce
      // formulaire d'édition doivent être reportés explicitement, sous
      // peine d'être effacés silencieusement à chaque modification —
      // `linkedInvestmentId` avait ce bug avant ce correctif.
      linkedInvestmentId: widget.liability.linkedInvestmentId,
      entityId: widget.liability.entityId,
    );
    await _repo.saveLiability(updated);
    setState(() => _editing = false);
    widget.onChanged();
  }

  Future<void> _delete() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer "${widget.liability.name}" ?',
      message: 'Ce passif sera définitivement supprimé.',
    );
    if (!confirmed) return;
    await _repo.deleteLiability(widget.liability.id);
    widget.onBack();
    widget.onChanged();
  }

  void _openMenu(BuildContext anchorContext) {
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 200),
        child: DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.pencil, size: 14),
              child: const shadcn.Text('Modifier'),
              onPressed: (_) => _startEdit(),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.trash2, size: 14),
              child: const shadcn.Text('Supprimer'),
              onPressed: (_) => _delete(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addDocument(
    String fileName,
    Uint8List bytes,
    String? transactionId,
    String? name,
  ) async {
    // Un passif n'a pas de notion de transaction (celles-ci n'existent que
    // pour les investissements) — voir `DocumentsSection`'s `transactions`.
    final document = VaultDocument(fileName: fileName, note: name);
    await DocumentStorage(widget.vaultPath).save(document, bytes);
    await _repo.saveLiability(
      widget.liability.copyWith(
        documents: [...widget.liability.documents, document],
      ),
    );
    widget.onChanged();
  }

  Future<void> _deleteDocument(VaultDocument document) async {
    await DocumentStorage(widget.vaultPath).delete(document);
    await _repo.saveLiability(
      widget.liability.copyWith(
        documents: [
          for (final d in widget.liability.documents)
            if (d.id != document.id) d,
        ],
      ),
    );
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final liability = widget.liability;
    final theme = Theme.of(context);
    final points = remainingBalanceHistoryFor([liability]);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onBack,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.chevronLeft, size: 20),
                        const SizedBox(width: 4),
                        shadcn.Text(liability.name).x2Large().semiBold(),
                      ],
                    ),
                  ),
                ),
              ),
              Builder(
                builder: (context) => IconButton.ghost(
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                  onPressed: () => _openMenu(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_editing)
            _EditLiabilityForm(
              nameController: _nameController,
              prixController: _prixController,
              apportController: _apportController,
              tauxController: _tauxController,
              assuranceMensuelleController: _assuranceMensuelleController,
              nbrEcheancesController: _nbrEcheancesController,
              dureeDiffereController: _dureeDiffereController,
              dateDebut: _dateDebut,
              loanType: _loanType,
              differeActif: _differeActif,
              typeDiffere: _typeDiffere,
              onDateChanged: (d) => setState(() => _dateDebut = d),
              onLoanTypeChanged: (t) => setState(() => _loanType = t),
              onDiffereActifChanged: (v) => setState(() => _differeActif = v),
              onTypeDiffereChanged: (t) => setState(() => _typeDiffere = t),
              onSave: _commitEdit,
              onCancel: () => setState(() => _editing = false),
            )
          else ...[
            shadcn.Text(liability.type.label).muted().small(),
            const SizedBox(height: 4),
            shadcn.Text(
              displayEuros(liability.remainingBalance, widget.hidden),
            ).x2Large().bold(),
            const SizedBox(height: 2),
            shadcn.Text(
              liability.isPaidOff
                  ? 'Soldé'
                  : 'Capital restant dû, sur '
                        '${displayEuros(liability.montantEmprunte, widget.hidden)} '
                        'empruntés',
              style: TextStyle(color: _red),
            ).muted().xSmall(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatChip(
                  label: 'Mensualité',
                  value: displayEuros(liability.mensualite, widget.hidden),
                ),
                _StatChip(label: 'Taux', value: '${liability.tauxInteret} %'),
                _StatChip(
                  label: 'Échéances',
                  value: '${liability.nbrEcheances} mensualités',
                ),
                _StatChip(
                  label: 'Début',
                  value: _formatDate(liability.dateDebut),
                ),
              ],
            ),
            if (points.length >= 2 || liability.years.isNotEmpty) ...[
              const SizedBox(height: 20),
              ButtonGroup(
                children: [
                  SelectedButton(
                    value: _chartMode == _ChartMode.capitalRestant,
                    selectedStyle: const ButtonStyle.primary(
                      size: _toggleButtonSize,
                    ),
                    style: toggleUnselectedStyle(
                      context,
                      size: _toggleButtonSize,
                    ),
                    onChanged: (_) =>
                        setState(() => _chartMode = _ChartMode.capitalRestant),
                    child: shadcn.Text(
                      'Capital restant dû',
                      style: const TextStyle(fontSize: _toggleFontSize),
                    ),
                  ),
                  SelectedButton(
                    value: _chartMode == _ChartMode.repartitionMensualites,
                    selectedStyle: const ButtonStyle.primary(
                      size: _toggleButtonSize,
                    ),
                    style: toggleUnselectedStyle(
                      context,
                      size: _toggleButtonSize,
                    ),
                    onChanged: (_) => setState(
                      () => _chartMode = _ChartMode.repartitionMensualites,
                    ),
                    child: shadcn.Text(
                      'Répartition des mensualités',
                      style: const TextStyle(fontSize: _toggleFontSize),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_chartMode == _ChartMode.capitalRestant && points.length >= 2)
                SizedBox(
                  height: 240,
                  child: NetWorthChart(
                    points: points,
                    formatValue: (v) => displayEuros(v, widget.hidden),
                    axisLabelFormat: (v) =>
                        displayEurosCompact(v, widget.hidden),
                    lineColor: _red,
                    gridColor: theme.colorScheme.border,
                    textColor: theme.colorScheme.mutedForeground,
                  ),
                )
              else if (_chartMode == _ChartMode.repartitionMensualites &&
                  liability.years.isNotEmpty)
                SizedBox(
                  height: 280,
                  child: LoanChart(
                    years: liability.years,
                    red: _red,
                    blue: _blue,
                    gold: theme.colorScheme.primary,
                    textColor: theme.colorScheme.mutedForeground,
                    gridColor: theme.colorScheme.border,
                    cardColor: theme.colorScheme.popover,
                    hidden: widget.hidden,
                  ),
                ),
            ],
          ],
          const SizedBox(height: 24),
          DocumentsSection(
            vaultPath: widget.vaultPath,
            documents: liability.documents,
            onAdd: _addDocument,
            onDelete: _deleteDocument,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          shadcn.Text(label).muted().xSmall(),
          shadcn.Text(value).medium(),
        ],
      ),
    );
  }
}

class _EditLiabilityForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController prixController;
  final TextEditingController apportController;
  final TextEditingController tauxController;
  final TextEditingController assuranceMensuelleController;
  final TextEditingController nbrEcheancesController;
  final TextEditingController dureeDiffereController;
  final DateTime? dateDebut;
  final LoanType loanType;
  final bool differeActif;
  final DeferType typeDiffere;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<LoanType> onLoanTypeChanged;
  final ValueChanged<bool> onDiffereActifChanged;
  final ValueChanged<DeferType> onTypeDiffereChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditLiabilityForm({
    required this.nameController,
    required this.prixController,
    required this.apportController,
    required this.tauxController,
    required this.assuranceMensuelleController,
    required this.nbrEcheancesController,
    required this.dureeDiffereController,
    required this.dateDebut,
    required this.loanType,
    required this.differeActif,
    required this.typeDiffere,
    required this.onDateChanged,
    required this.onLoanTypeChanged,
    required this.onDiffereActifChanged,
    required this.onTypeDiffereChanged,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LiabilityFormFields(
              nameController: nameController,
              prixController: prixController,
              apportController: apportController,
              tauxController: tauxController,
              assuranceMensuelleController: assuranceMensuelleController,
              nbrEcheancesController: nbrEcheancesController,
              dureeDiffereController: dureeDiffereController,
              dateDebut: dateDebut,
              loanType: loanType,
              differeActif: differeActif,
              typeDiffere: typeDiffere,
              onDateChanged: onDateChanged,
              onLoanTypeChanged: onLoanTypeChanged,
              onDiffereActifChanged: onDiffereActifChanged,
              onTypeDiffereChanged: onTypeDiffereChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                PrimaryButton(
                  onPressed: onSave,
                  child: const shadcn.Text('Enregistrer'),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  onPressed: onCancel,
                  child: const shadcn.Text('Annuler'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

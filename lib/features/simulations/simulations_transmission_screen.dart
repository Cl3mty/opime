import 'dart:math';

import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/simulations/simulation_state_repository.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/toggle_button_style.dart';

class TransmissionSimulationScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const TransmissionSimulationScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<TransmissionSimulationScreen> createState() =>
      _TransmissionSimulationScreenState();
}

class _TransmissionSimulationScreenState
    extends State<TransmissionSimulationScreen> {
  int _tabIndex = 0;
  late final SimulationStateRepository _stateRepo;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
    widget.amountVisibility.addListener(_onAmountVisibilityChanged);
  }

  void _onAmountVisibilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.amountVisibility.removeListener(_onAmountVisibilityChanged);
    super.dispose();
  }

  Future<void> _loadState() async {
    final data = await _stateRepo.read('transmission');
    if (!mounted) return;
    setState(() {
      final value = data['tabIndex'];
      if (value is int) {
        _tabIndex = value.clamp(0, 2);
      } else if (value is num) {
        _tabIndex = value.round().clamp(0, 2);
      }
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('transmission', {'tabIndex': _tabIndex});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Align + scroll horizontal plutôt qu'un simple Row centré : sur
          // téléphone étroit, "Démembrement" force sinon les tabs à passer
          // sur deux lignes (le Row leur donne une largeur non bornée dans
          // laquelle Text s'enroule). Centré quand tout tient, défilable
          // sinon.
          Align(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TabList(
                index: _tabIndex,
                onChanged: (value) {
                  setState(() => _tabIndex = value);
                  _saveState();
                },
                children: const [
                  TabItem(child: shadcn.Text('Démembrement')),
                  TabItem(child: shadcn.Text('Donation')),
                  TabItem(child: shadcn.Text('Héritage')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tabIndex == 0
                ? _DemembrementTab(
                    vaultPath: widget.vaultPath,
                    amountVisibility: widget.amountVisibility,
                  )
                : _tabIndex == 1
                ? _DonationTab(
                    vaultPath: widget.vaultPath,
                    amountVisibility: widget.amountVisibility,
                  )
                : _InheritanceTab(
                    vaultPath: widget.vaultPath,
                    amountVisibility: widget.amountVisibility,
                  ),
          ),
        ],
      ),
    );
  }
}

class _TransmissionSplitCard extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _TransmissionSplitCard({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;

          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(padding: const EdgeInsets.all(20), child: left),
                  const Divider(height: 1),
                  Padding(padding: const EdgeInsets.all(20), child: right),
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 340,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(child: left),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(child: right),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DemembrementTab extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const _DemembrementTab({
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<_DemembrementTab> createState() => _DemembrementTabState();
}

class _DemembrementTabState extends State<_DemembrementTab> {
  double _valeurPleinePropriete = 1000000;
  int _ageUsufruitier = 62;
  int _nombreEnfants = 2;
  double _abattementParEnfant = 100000;

  late final SimulationStateRepository _stateRepo;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
    widget.amountVisibility.addListener(_onAmountVisibilityChanged);
  }

  void _onAmountVisibilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.amountVisibility.removeListener(_onAmountVisibilityChanged);
    super.dispose();
  }

  Future<void> _loadState() async {
    final data = await _stateRepo.read('transmission_demembrement');
    if (!mounted || data.isEmpty) return;
    setState(() {
      _valeurPleinePropriete = _readDouble(
        data,
        'valeurPleinePropriete',
        _valeurPleinePropriete,
      );
      _ageUsufruitier = _readInt(
        data,
        'ageUsufruitier',
        _ageUsufruitier,
      ).clamp(18, 110);
      _nombreEnfants = _readInt(
        data,
        'nombreEnfants',
        _nombreEnfants,
      ).clamp(1, 10);
      _abattementParEnfant = _readDouble(
        data,
        'abattementParEnfant',
        _abattementParEnfant,
      );
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('transmission_demembrement', {
      'valeurPleinePropriete': _valeurPleinePropriete,
      'ageUsufruitier': _ageUsufruitier,
      'nombreEnfants': _nombreEnfants,
      'abattementParEnfant': _abattementParEnfant,
    });
  }

  void _update(void Function() fn) {
    setState(fn);
    _saveState();
  }

  Future<void> _resetState() async {
    await _stateRepo.delete('transmission_demembrement');
    if (!mounted) return;
    setState(() {
      _valeurPleinePropriete = 1000000;
      _ageUsufruitier = 62;
      _nombreEnfants = 2;
      _abattementParEnfant = 100000;
    });
  }

  DemembrementResult _compute() => computeDemembrement(
    valeurPleinePropriete: _valeurPleinePropriete,
    ageUsufruitier: _ageUsufruitier,
    nombreEnfants: _nombreEnfants,
    abattementParEnfant: _abattementParEnfant,
  );

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    final accent = Theme.of(context).colorScheme.primary;
    final hidden = widget.amountVisibility.hidden;

    return _TransmissionSplitCard(
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NumberField(
            label: 'Valeur en pleine propriété',
            suffix: '€',
            value: _valeurPleinePropriete,
            step: 10000,
            onChanged: (v) => _update(() => _valeurPleinePropriete = max(0, v)),
          ),
          _NumberField(
            label: "Âge de l'usufruitier",
            suffix: 'ans',
            value: _ageUsufruitier.toDouble(),
            step: 1,
            decimals: 0,
            onChanged: (v) =>
                _update(() => _ageUsufruitier = v.round().clamp(18, 110)),
          ),
          _NumberField(
            label: "Nombre d'enfants bénéficiaires",
            suffix: '',
            value: _nombreEnfants.toDouble(),
            step: 1,
            decimals: 0,
            onChanged: (v) =>
                _update(() => _nombreEnfants = v.round().clamp(1, 10)),
          ),
          _NumberField(
            label: 'Abattement par enfant (restant)',
            suffix: '€',
            value: _abattementParEnfant,
            step: 5000,
            onChanged: (v) => _update(() => _abattementParEnfant = max(0, v)),
          ),
          const SizedBox(height: 8),
          OutlineButton(
            onPressed: _resetState,
            leading: const Icon(LucideIcons.refreshCw),
            child: const shadcn.Text('Réinitialiser les paramètres'),
          ),
        ],
      ),
      right: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProjectionHeader(
            title: 'Projection des droits en démembrement',
            value: displayEuros(result.droitsTotauxNue, hidden),
            subtitle: shadcn.Text.rich(
              TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  const TextSpan(text: 'Hypothèse 2026 : nue-propriété '),
                  TextSpan(
                    text: '${result.nueProprietePct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: ' / usufruit '),
                  TextSpan(
                    text: '${result.usufruitPct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ).muted(),
          ),
          const SizedBox(height: 20),
          _MiniBarChart(
            hidden: hidden,
            title: 'Comparaison des scénarios',
            items: [
              _BarItem(
                label: 'Droits pleine propriété',
                value: result.droitsTotauxPleine,
                color: const Color(0xFFE07A6B),
              ),
              _BarItem(
                label: 'Droits démembrement',
                value: result.droitsTotauxNue,
                color: const Color(0xFF7B8FE8),
              ),
              _BarItem(
                label: 'Économie potentielle',
                value: max(0, result.economiePotentielle),
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatRow(
            items: [
              ('Valeur NP', displayEuros(result.valeurNuePropriete, hidden)),
              (
                'Taxable NP / enfant',
                displayEuros(result.taxableParEnfantNue, hidden),
              ),
              (
                'Droits NP / enfant',
                displayEuros(result.droitsParEnfantNue, hidden),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StatRow(
            items: [
              (
                'Droits si pleine propriété',
                displayEuros(result.droitsTotauxPleine, hidden),
              ),
              (
                'Droits en démembrement',
                displayEuros(result.droitsTotauxNue, hidden),
              ),
              (
                'Économie potentielle',
                displayEuros(result.economiePotentielle, hidden),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _TransmissionDisclaimer(
            text:
                "Barème de valorisation usufruit/nue-propriété selon l'article 669 CGI (référentiel 2026). "
                'Simulation indicative, hors clauses civiles spécifiques, réserve/usufruit successif et optimisation notariale personnalisée.',
          ),
        ],
      ),
    );
  }
}

class _DonationTab extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const _DonationTab({required this.vaultPath, required this.amountVisibility});

  @override
  State<_DonationTab> createState() => _DonationTabState();
}

class _DonationTabState extends State<_DonationTab> {
  double _montantDonation = 400000;
  int _nombreDonataires = 2;
  DonationRelation _relation = DonationRelation.enfant;

  late final SimulationStateRepository _stateRepo;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
    widget.amountVisibility.addListener(_onAmountVisibilityChanged);
  }

  void _onAmountVisibilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.amountVisibility.removeListener(_onAmountVisibilityChanged);
    super.dispose();
  }

  Future<void> _loadState() async {
    final data = await _stateRepo.read('transmission_donation');
    if (!mounted || data.isEmpty) return;
    setState(() {
      _montantDonation = _readDouble(data, 'montantDonation', _montantDonation);
      _nombreDonataires = _readInt(
        data,
        'nombreDonataires',
        _nombreDonataires,
      ).clamp(1, 20);
      final relation = data['relation'];
      if (relation is String) {
        _relation = DonationRelation.values.firstWhere(
          (r) => r.name == relation,
          orElse: () => _relation,
        );
      }
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('transmission_donation', {
      'montantDonation': _montantDonation,
      'nombreDonataires': _nombreDonataires,
      'relation': _relation.name,
    });
  }

  void _update(void Function() fn) {
    setState(fn);
    _saveState();
  }

  Future<void> _resetState() async {
    await _stateRepo.delete('transmission_donation');
    if (!mounted) return;
    setState(() {
      _montantDonation = 400000;
      _nombreDonataires = 2;
      _relation = DonationRelation.enfant;
    });
  }

  DonationResult _compute() => computeDonation(
    montantDonation: _montantDonation,
    nombreDonataires: _nombreDonataires,
    relation: _relation,
  );

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    final accent = Theme.of(context).colorScheme.primary;
    final hidden = widget.amountVisibility.hidden;

    return _TransmissionSplitCard(
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NumberField(
            label: 'Montant de la donation',
            suffix: '€',
            value: _montantDonation,
            step: 5000,
            onChanged: (v) => _update(() => _montantDonation = max(0, v)),
          ),
          _NumberField(
            label: 'Nombre de bénéficiaires',
            suffix: '',
            value: _nombreDonataires.toDouble(),
            step: 1,
            decimals: 0,
            onChanged: (v) =>
                _update(() => _nombreDonataires = v.round().clamp(1, 20)),
          ),
          shadcn.Text('Lien donateur / donataire').muted().small(),
          const SizedBox(height: 8),
          ButtonGroup(
            children: [
              SelectedButton(
                value: _relation == DonationRelation.enfant,
                onChanged: (_) =>
                    _update(() => _relation = DonationRelation.enfant),
                selectedStyle: const ButtonStyle.primary(),
                style: toggleUnselectedStyle(context),
                child: const shadcn.Text('Enfant'),
              ),
              SelectedButton(
                value: _relation == DonationRelation.petitEnfant,
                onChanged: (_) =>
                    _update(() => _relation = DonationRelation.petitEnfant),
                selectedStyle: const ButtonStyle.primary(),
                style: toggleUnselectedStyle(context),
                child: const shadcn.Text('Petit-enfant'),
              ),
              SelectedButton(
                value: _relation == DonationRelation.conjoint,
                onChanged: (_) =>
                    _update(() => _relation = DonationRelation.conjoint),
                selectedStyle: const ButtonStyle.primary(),
                style: toggleUnselectedStyle(context),
                child: const shadcn.Text('Conjoint/PACS'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          shadcn.Text(
            'Abattement pris en compte : ${displayEuros(result.abattementParDonataire, hidden)} / bénéficiaire',
          ).muted().small(),
          const SizedBox(height: 8),
          OutlineButton(
            onPressed: _resetState,
            leading: const Icon(LucideIcons.refreshCw),
            child: const shadcn.Text('Réinitialiser les paramètres'),
          ),
        ],
      ),
      right: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProjectionHeader(
            title: 'Droits de donation estimés',
            value: displayEuros(result.droitsTotaux, hidden),
            subtitle: shadcn.Text.rich(
              TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  const TextSpan(text: 'Taux effectif '),
                  TextSpan(
                    text: '${result.tauxEffectif.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: ' sur le montant transmis.'),
                ],
              ),
            ).muted(),
          ),
          const SizedBox(height: 20),
          _MiniBarChart(
            hidden: hidden,
            title: 'Répartition fiscale',
            items: [
              _BarItem(
                label: 'Montant total transmis',
                value: _montantDonation,
                color: const Color(0xFF6B7280),
              ),
              _BarItem(
                label: 'Base taxable totale',
                value: result.taxableParDonataire * _nombreDonataires,
                color: const Color(0xFF7B8FE8),
              ),
              _BarItem(
                label: 'Droits totaux',
                value: result.droitsTotaux,
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatRow(
            items: [
              (
                'Montant / bénéficiaire',
                displayEuros(result.montantParDonataire, hidden),
              ),
              (
                'Taxable / bénéficiaire',
                displayEuros(result.taxableParDonataire, hidden),
              ),
              (
                'Droits / bénéficiaire',
                displayEuros(result.droitsParDonataire, hidden),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _TransmissionDisclaimer(
            text:
                'Barèmes simplifiés de droits de donation 2026. Abattements simulés par lien de parenté, '
                'hors dons familiaux de sommes d\'argent, rapport fiscal, réductions spécifiques ou passif déductible.',
          ),
        ],
      ),
    );
  }
}

class _InheritanceTab extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const _InheritanceTab({
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<_InheritanceTab> createState() => _InheritanceTabState();
}

class _InheritanceTabState extends State<_InheritanceTab> {
  double _actifNetSuccessoral = 1200000;
  bool _conjointSurvivant = true;
  double _partConjointPct = 25;
  int _nombreEnfants = 2;
  double _abattementParEnfant = 100000;

  late final SimulationStateRepository _stateRepo;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
    widget.amountVisibility.addListener(_onAmountVisibilityChanged);
  }

  void _onAmountVisibilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.amountVisibility.removeListener(_onAmountVisibilityChanged);
    super.dispose();
  }

  Future<void> _loadState() async {
    final data = await _stateRepo.read('transmission_heritage');
    if (!mounted || data.isEmpty) return;
    setState(() {
      _actifNetSuccessoral = _readDouble(
        data,
        'actifNetSuccessoral',
        _actifNetSuccessoral,
      );
      _conjointSurvivant = _readBool(
        data,
        'conjointSurvivant',
        _conjointSurvivant,
      );
      _partConjointPct = _readDouble(
        data,
        'partConjointPct',
        _partConjointPct,
      ).clamp(0, 100);
      _nombreEnfants = _readInt(
        data,
        'nombreEnfants',
        _nombreEnfants,
      ).clamp(1, 10);
      _abattementParEnfant = _readDouble(
        data,
        'abattementParEnfant',
        _abattementParEnfant,
      );
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('transmission_heritage', {
      'actifNetSuccessoral': _actifNetSuccessoral,
      'conjointSurvivant': _conjointSurvivant,
      'partConjointPct': _partConjointPct,
      'nombreEnfants': _nombreEnfants,
      'abattementParEnfant': _abattementParEnfant,
    });
  }

  void _update(void Function() fn) {
    setState(fn);
    _saveState();
  }

  Future<void> _resetState() async {
    await _stateRepo.delete('transmission_heritage');
    if (!mounted) return;
    setState(() {
      _actifNetSuccessoral = 1200000;
      _conjointSurvivant = true;
      _partConjointPct = 25;
      _nombreEnfants = 2;
      _abattementParEnfant = 100000;
    });
  }

  InheritanceResult _compute() => computeInheritance(
    actifNetSuccessoral: _actifNetSuccessoral,
    conjointSurvivant: _conjointSurvivant,
    partConjointPct: _partConjointPct,
    nombreEnfants: _nombreEnfants,
    abattementParEnfant: _abattementParEnfant,
  );

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    final hidden = widget.amountVisibility.hidden;

    return _TransmissionSplitCard(
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NumberField(
            label: 'Actif net successoral',
            suffix: '€',
            value: _actifNetSuccessoral,
            step: 10000,
            onChanged: (v) => _update(() => _actifNetSuccessoral = max(0, v)),
          ),
          Row(
            children: [
              Expanded(
                child: shadcn.Text('Conjoint survivant').muted().small(),
              ),
              _SimpleSwitch(
                value: _conjointSurvivant,
                onChanged: (v) => _update(() => _conjointSurvivant = v),
              ),
            ],
          ),
          if (_conjointSurvivant) ...[
            const SizedBox(height: 12),
            _NumberField(
              label: 'Part attribuée au conjoint',
              suffix: '%',
              value: _partConjointPct,
              step: 1,
              decimals: 0,
              onChanged: (v) =>
                  _update(() => _partConjointPct = v.clamp(0, 100)),
            ),
          ],
          _NumberField(
            label: "Nombre d'enfants héritiers",
            suffix: '',
            value: _nombreEnfants.toDouble(),
            step: 1,
            decimals: 0,
            onChanged: (v) =>
                _update(() => _nombreEnfants = v.round().clamp(1, 10)),
          ),
          _NumberField(
            label: 'Abattement par enfant',
            suffix: '€',
            value: _abattementParEnfant,
            step: 5000,
            onChanged: (v) => _update(() => _abattementParEnfant = max(0, v)),
          ),
          const SizedBox(height: 8),
          OutlineButton(
            onPressed: _resetState,
            leading: const Icon(LucideIcons.refreshCw),
            child: const shadcn.Text('Réinitialiser les paramètres'),
          ),
        ],
      ),
      right: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProjectionHeader(
            title: 'Droits de succession estimés',
            value: displayEuros(result.droitsTotauxEnfants, hidden),
          ),
          const SizedBox(height: 20),
          _MiniBarChart(
            hidden: hidden,
            title: 'Répartition de la succession',
            items: [
              _BarItem(
                label: 'Part conjoint exonérée',
                value: result.partConjointExoneree,
                color: const Color(0xFF6B7280),
              ),
              _BarItem(
                label: 'Masse enfants',
                value: result.masseTaxableEnfants,
                color: const Color(0xFF7B8FE8),
              ),
              _BarItem(
                label: 'Droits totaux enfants',
                value: result.droitsTotauxEnfants,
                color: const Color(0xFFE07A6B),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatRow(
            items: [
              (
                'Part conjoint exonérée',
                displayEuros(result.partConjointExoneree, hidden),
              ),
              (
                'Masse transmise aux enfants',
                displayEuros(result.masseTaxableEnfants, hidden),
              ),
              (
                'Part brute / enfant',
                displayEuros(result.partParEnfant, hidden),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StatRow(
            items: [
              (
                'Taxable / enfant',
                displayEuros(result.taxableParEnfant, hidden),
              ),
              ('Droits / enfant', displayEuros(result.droitsParEnfant, hidden)),
              ('Net / enfant', displayEuros(result.netParEnfant, hidden)),
            ],
          ),
          const SizedBox(height: 16),
          const _TransmissionDisclaimer(
            text:
                'Référentiel succession 2026 simplifié : conjoint/PACS exonéré, barème ligne directe pour enfants. '
                'Ne tient pas compte des options civiles détaillées (usufruit légal du conjoint, quotité disponible, testament, assurance-vie).',
          ),
        ],
      ),
    );
  }
}

class DemembrementResult {
  final double nueProprietePct;
  final double usufruitPct;
  final double valeurNuePropriete;
  final double droitsTotauxNue;
  final double droitsTotauxPleine;
  final double economiePotentielle;
  final double droitsParEnfantNue;
  final double taxableParEnfantNue;

  DemembrementResult({
    required this.nueProprietePct,
    required this.usufruitPct,
    required this.valeurNuePropriete,
    required this.droitsTotauxNue,
    required this.droitsTotauxPleine,
    required this.economiePotentielle,
    required this.droitsParEnfantNue,
    required this.taxableParEnfantNue,
  });
}

class DonationResult {
  final double abattementParDonataire;
  final double montantParDonataire;
  final double taxableParDonataire;
  final double droitsParDonataire;
  final double droitsTotaux;
  final double tauxEffectif;

  DonationResult({
    required this.abattementParDonataire,
    required this.montantParDonataire,
    required this.taxableParDonataire,
    required this.droitsParDonataire,
    required this.droitsTotaux,
    required this.tauxEffectif,
  });
}

class InheritanceResult {
  final double partConjointExoneree;
  final double masseTaxableEnfants;
  final double partParEnfant;
  final double taxableParEnfant;
  final double droitsParEnfant;
  final double droitsTotauxEnfants;
  final double netParEnfant;

  InheritanceResult({
    required this.partConjointExoneree,
    required this.masseTaxableEnfants,
    required this.partParEnfant,
    required this.taxableParEnfant,
    required this.droitsParEnfant,
    required this.droitsTotauxEnfants,
    required this.netParEnfant,
  });
}

/// Donation avec réserve d'usufruit : seule la nue-propriété (valorisée selon
/// l'âge de l'usufruitier, cf. [nueProprietePct]) est transmise et taxée,
/// l'abattement s'appliquant sur cette base réduite — d'où l'économie fiscale
/// par rapport à une transmission en pleine propriété.
DemembrementResult computeDemembrement({
  required double valeurPleinePropriete,
  required int ageUsufruitier,
  required int nombreEnfants,
  required double abattementParEnfant,
}) {
  final nuePct = nueProprietePct(ageUsufruitier);
  final usufruitPct = 100 - nuePct;

  final valeurNuePropriete = valeurPleinePropriete * nuePct / 100;
  final valeurNueProprieteParEnfant = valeurNuePropriete / nombreEnfants;
  final valeurPleineParEnfant = valeurPleinePropriete / nombreEnfants;

  final taxableNueParEnfant = max(
    0.0,
    valeurNueProprieteParEnfant - abattementParEnfant,
  );
  final taxablePleineParEnfant = max(
    0.0,
    valeurPleineParEnfant - abattementParEnfant,
  );

  final droitsNueParEnfant = directLineRights(taxableNueParEnfant);
  final droitsPleineParEnfant = directLineRights(taxablePleineParEnfant);

  final droitsTotauxNue = droitsNueParEnfant * nombreEnfants;
  final droitsTotauxPleine = droitsPleineParEnfant * nombreEnfants;

  return DemembrementResult(
    nueProprietePct: nuePct,
    usufruitPct: usufruitPct,
    valeurNuePropriete: valeurNuePropriete,
    droitsTotauxNue: droitsTotauxNue,
    droitsTotauxPleine: droitsTotauxPleine,
    economiePotentielle: droitsTotauxPleine - droitsTotauxNue,
    droitsParEnfantNue: droitsNueParEnfant,
    taxableParEnfantNue: taxableNueParEnfant,
  );
}

/// Donation simple répartie à parts égales entre bénéficiaires, avec
/// abattement et barème dépendant du lien de parenté avec le donateur.
DonationResult computeDonation({
  required double montantDonation,
  required int nombreDonataires,
  required DonationRelation relation,
}) {
  final montantParDonataire = montantDonation / nombreDonataires;
  final abattement = abattementFor(relation);
  final taxableParDonataire = max(0.0, montantParDonataire - abattement);
  final droitsParDonataire = relation == DonationRelation.conjoint
      ? spouseRights(taxableParDonataire)
      : directLineRights(taxableParDonataire);

  final droitsTotaux = droitsParDonataire * nombreDonataires;

  return DonationResult(
    abattementParDonataire: abattement,
    montantParDonataire: montantParDonataire,
    taxableParDonataire: taxableParDonataire,
    droitsParDonataire: droitsParDonataire,
    droitsTotaux: droitsTotaux,
    tauxEffectif: montantDonation <= 0
        ? 0
        : droitsTotaux / montantDonation * 100,
  );
}

/// Succession simplifiée : la part attribuée au conjoint survivant est
/// totalement exonérée (loi TEPA 2007) et retranchée de la masse taxable ;
/// le solde est réparti à parts égales entre les enfants, chacun bénéficiant
/// de son propre abattement en ligne directe.
InheritanceResult computeInheritance({
  required double actifNetSuccessoral,
  required bool conjointSurvivant,
  required double partConjointPct,
  required int nombreEnfants,
  required double abattementParEnfant,
}) {
  final partConjoint = conjointSurvivant
      ? actifNetSuccessoral * partConjointPct / 100
      : 0.0;
  final masseEnfants = max(0.0, actifNetSuccessoral - partConjoint);
  final partParEnfant = masseEnfants / nombreEnfants;
  final taxableParEnfant = max(0.0, partParEnfant - abattementParEnfant);
  final droitsParEnfant = directLineRights(taxableParEnfant);

  return InheritanceResult(
    partConjointExoneree: partConjoint,
    masseTaxableEnfants: masseEnfants,
    partParEnfant: partParEnfant,
    taxableParEnfant: taxableParEnfant,
    droitsParEnfant: droitsParEnfant,
    droitsTotauxEnfants: droitsParEnfant * nombreEnfants,
    netParEnfant: partParEnfant - droitsParEnfant,
  );
}

enum DonationRelation { enfant, petitEnfant, conjoint }

class TaxBracket {
  final double upper;
  final double rate;

  const TaxBracket(this.upper, this.rate);
}

/// Barème des droits de mutation à titre gratuit en ligne directe
/// (parent/enfant), article 777 CGI. Inchangé depuis 2011 (non indexé).
const directLineBrackets = [
  TaxBracket(8072, 0.05),
  TaxBracket(12109, 0.10),
  TaxBracket(15932, 0.15),
  TaxBracket(552324, 0.20),
  TaxBracket(902838, 0.30),
  TaxBracket(1805677, 0.40),
  TaxBracket(double.infinity, 0.45),
];

/// Barème des droits de donation entre époux ou partenaires de PACS,
/// article 777 CGI (la succession entre époux est, elle, totalement
/// exonérée depuis la loi TEPA de 2007 — ce barème ne s'applique donc
/// qu'aux donations).
const spouseBrackets = [
  TaxBracket(8072, 0.05),
  TaxBracket(15932, 0.10),
  TaxBracket(31865, 0.15),
  TaxBracket(552324, 0.20),
  TaxBracket(902838, 0.30),
  TaxBracket(1805677, 0.40),
  TaxBracket(double.infinity, 0.45),
];

double directLineRights(double taxable) =>
    computeRights(taxable, directLineBrackets);

double spouseRights(double taxable) => computeRights(taxable, spouseBrackets);

double computeRights(double taxable, List<TaxBracket> brackets) {
  var remaining = max(0.0, taxable);
  var previousUpper = 0.0;
  var tax = 0.0;

  for (final bracket in brackets) {
    if (remaining <= 0) break;
    final width = bracket.upper - previousUpper;
    final taxableInBracket = min(remaining, width);
    tax += taxableInBracket * bracket.rate;
    remaining -= taxableInBracket;
    previousUpper = bracket.upper;
  }
  return tax;
}

double abattementFor(DonationRelation relation) {
  switch (relation) {
    case DonationRelation.enfant:
      return 100000;
    case DonationRelation.petitEnfant:
      return 31865;
    case DonationRelation.conjoint:
      return 80724;
  }
}

double nueProprietePct(int ageUsufruitier) {
  if (ageUsufruitier <= 20) return 10;
  if (ageUsufruitier <= 30) return 20;
  if (ageUsufruitier <= 40) return 30;
  if (ageUsufruitier <= 50) return 40;
  if (ageUsufruitier <= 60) return 50;
  if (ageUsufruitier <= 70) return 60;
  if (ageUsufruitier <= 80) return 70;
  if (ageUsufruitier <= 90) return 80;
  return 90;
}

double _readDouble(Map<String, dynamic> json, String key, double fallback) {
  final value = json[key];
  if (value is num) return value.toDouble();
  return fallback;
}

int _readInt(Map<String, dynamic> json, String key, int fallback) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.round();
  return fallback;
}

bool _readBool(Map<String, dynamic> json, String key, bool fallback) {
  final value = json[key];
  if (value is bool) return value;
  return fallback;
}

class _NumberField extends StatefulWidget {
  final String label;
  final String suffix;
  final double value;
  final double step;
  final int decimals;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.label,
    required this.suffix,
    required this.value,
    required this.step,
    required this.onChanged,
    this.decimals = 0,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textFor(widget.value));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = _textFor(widget.value);
    if (!_focusNode.hasFocus && _controller.text != nextText) {
      _controller.text = nextText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _textFor(double value) => widget.decimals == 0
      ? value.round().toString()
      : value.toStringAsFixed(widget.decimals).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(widget.label).muted().small(),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                border: Border.all(color: Colors.transparent),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (text) {
                  final parsed = parseDecimal(text);
                  if (parsed != null) widget.onChanged(parsed);
                },
                onSubmitted: (_) => _controller.text = _textFor(widget.value),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.ghost(
                  icon: const Icon(LucideIcons.chevronUp, size: 14),
                  onPressed: () => widget.onChanged(widget.value + widget.step),
                ),
                IconButton.ghost(
                  icon: const Icon(LucideIcons.chevronDown, size: 14),
                  onPressed: () => widget.onChanged(widget.value - widget.step),
                ),
              ],
            ),
            const SizedBox(width: 4),
            shadcn.Text(widget.suffix).muted(),
          ],
        ),
        const Divider(),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final bool expand;

  const _StatColumn({
    required this.label,
    required this.value,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: expand
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        shadcn.Text(label).muted().small(),
        const SizedBox(height: 4),
        shadcn.Text(value).medium(),
      ],
    );
    return expand ? Expanded(child: content) : content;
  }
}

/// Ligne de statistiques sous un graphique : côte à côte si la largeur le
/// permet, sinon empilées en colonne pour ne pas écraser des montants qui
/// peuvent être grands (notamment sur mobile).
class _StatRow extends StatelessWidget {
  final List<(String, String)> items;
  const _StatRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            children: [
              for (final item in items)
                _StatColumn(label: item.$1, value: item.$2),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _StatColumn(
                label: items[i].$1,
                value: items[i].$2,
                expand: false,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProjectionHeader extends StatelessWidget {
  final String title;
  final String value;
  final Widget? subtitle;

  const _ProjectionHeader({
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          shadcn.Text(title, textAlign: TextAlign.center).muted(),
          const SizedBox(height: 8),
          shadcn.Text(
            value,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            DefaultTextStyle.merge(
              textAlign: TextAlign.center,
              child: subtitle!,
            ),
          ],
        ],
      ),
    );
  }
}

class _BarItem {
  final String label;
  final double value;
  final Color color;

  const _BarItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _MiniBarChart extends StatelessWidget {
  final String title;
  final List<_BarItem> items;
  final bool hidden;

  const _MiniBarChart({
    required this.title,
    required this.items,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<double>(
      0,
      (maxSoFar, item) => max(maxSoFar, item.value),
    );
    final denominator = maxValue <= 0 ? 1.0 : maxValue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted,
        borderRadius: BorderRadius.circular(Theme.of(context).radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shadcn.Text(title).semiBold().small(),
          const SizedBox(height: 12),
          for (final item in items) ...[
            Row(
              children: [
                Expanded(child: shadcn.Text(item.label).small()),
                const SizedBox(width: 8),
                shadcn.Text(displayEuros(item.value, hidden)).small(),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (item.value / denominator).clamp(0.0, 1.0),
                minHeight: 8,
                color: item.color,
                backgroundColor: Theme.of(context).colorScheme.border,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TransmissionDisclaimer extends StatelessWidget {
  final String text;

  const _TransmissionDisclaimer({required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.mutedForeground;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.border),
        borderRadius: BorderRadius.circular(Theme.of(context).radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: muted),
          const SizedBox(width: 10),
          Expanded(child: shadcn.Text(text).muted().small()),
        ],
      ),
    );
  }
}

class _SimpleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SimpleSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final track = Theme.of(context).colorScheme.border;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 22,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? accent : track,
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

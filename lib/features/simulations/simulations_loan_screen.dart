import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/simulations/simulation_state_repository.dart';
import '../../core/ui/frosted_card.dart';

enum LoanType { amortissable, inFine }

enum DeferType { totale, partielle }

class LoanSimulationScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const LoanSimulationScreen({super.key, required this.vaultPath, required this.amountVisibility});

  @override
  State<LoanSimulationScreen> createState() => _LoanSimulationScreenState();
}

class _LoanSimulationScreenState extends State<LoanSimulationScreen> {
  double _montantEmprunte = 100000;
  int _dureeAnnees = 20;
  double _tauxInteret = 3.5;
  double _tauxAssurance = 0.15;
  double _fraisDossier = 800;
  double _fraisGarantie = 1200;

  LoanType _type = LoanType.amortissable;
  bool _differeActif = false;
  int _dureeDiffereMois = 12;
  DeferType _typeDiffere = DeferType.partielle;
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
    final data = await _stateRepo.read('loan');
    if (!mounted || data.isEmpty) return;

    setState(() {
      _montantEmprunte = _readDouble(data, 'montantEmprunte', fallback: _montantEmprunte);
      _dureeAnnees = _readInt(data, 'dureeAnnees', fallback: _dureeAnnees).clamp(1, 35);
      _tauxInteret = _readDouble(data, 'tauxInteret', fallback: _tauxInteret);
      _tauxAssurance = _readDouble(data, 'tauxAssurance', fallback: _tauxAssurance);
      _fraisDossier = _readDouble(data, 'fraisDossier', fallback: _fraisDossier);
      _fraisGarantie = _readDouble(data, 'fraisGarantie', fallback: _fraisGarantie);
      _type = _readLoanType(data, 'type', fallback: _type);
      _differeActif = _readBool(data, 'differeActif', fallback: _differeActif);
      _dureeDiffereMois = _readInt(data, 'dureeDiffereMois', fallback: _dureeDiffereMois).clamp(1, _dureeAnnees * 12 - 1);
      _typeDiffere = _readDeferType(data, 'typeDiffere', fallback: _typeDiffere);
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('loan', {
      'montantEmprunte': _montantEmprunte,
      'dureeAnnees': _dureeAnnees,
      'tauxInteret': _tauxInteret,
      'tauxAssurance': _tauxAssurance,
      'fraisDossier': _fraisDossier,
      'fraisGarantie': _fraisGarantie,
      'type': _type.name,
      'differeActif': _differeActif,
      'dureeDiffereMois': _dureeDiffereMois,
      'typeDiffere': _typeDiffere.name,
    });
  }

  void _update(void Function() change) {
    setState(change);
    _saveState();
  }

  double _readDouble(Map<String, dynamic> json, String key, {required double fallback}) {
    final value = json[key];
    if (value is num) return value.toDouble();
    return fallback;
  }

  int _readInt(Map<String, dynamic> json, String key, {required int fallback}) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.round();
    return fallback;
  }

  bool _readBool(Map<String, dynamic> json, String key, {required bool fallback}) {
    final value = json[key];
    if (value is bool) return value;
    return fallback;
  }

  LoanType _readLoanType(Map<String, dynamic> json, String key, {required LoanType fallback}) {
    final value = json[key];
    if (value is String) {
      for (final t in LoanType.values) {
        if (t.name == value) return t;
      }
    }
    return fallback;
  }

  DeferType _readDeferType(Map<String, dynamic> json, String key, {required DeferType fallback}) {
    final value = json[key];
    if (value is String) {
      for (final t in DeferType.values) {
        if (t.name == value) return t;
      }
    }
    return fallback;
  }

  Future<void> _resetState() async {
    await _stateRepo.delete('loan');
    if (!mounted) return;
    setState(() {
      _montantEmprunte = 100000;
      _dureeAnnees = 20;
      _tauxInteret = 3.5;
      _tauxAssurance = 0.15;
      _fraisDossier = 800;
      _fraisGarantie = 1200;
      _type = LoanType.amortissable;
      _differeActif = false;
      _dureeDiffereMois = 12;
      _typeDiffere = DeferType.partielle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _simulate();
    final hidden = widget.amountVisibility.hidden;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FrostedCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 360,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(child: _buildInputsContent()),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(child: _buildResultsContent(result, hidden)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LoanResult _simulate() => simulateLoan(
        montantEmprunte: _montantEmprunte,
        dureeAnnees: _dureeAnnees,
        tauxInteret: _tauxInteret,
        tauxAssurance: _tauxAssurance,
        fraisDossier: _fraisDossier,
        fraisGarantie: _fraisGarantie,
        type: _type,
        differeActif: _differeActif,
        dureeDiffereMois: _dureeDiffereMois,
        typeDiffere: _typeDiffere,
      );

  // ---------------------------------------------------------------------
  // Colonne de gauche : formulaire
  // ---------------------------------------------------------------------

  Widget _buildInputsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text('Type de crédit').muted().small(),
        const SizedBox(height: 8),
        ButtonGroup(
          children: [
            SelectedButton(
              value: _type == LoanType.amortissable,
              onChanged: (_) => _update(() => _type = LoanType.amortissable),
              child: const shadcn.Text('Amortissable'),
            ),
            SelectedButton(
              value: _type == LoanType.inFine,
              onChanged: (_) => _update(() => _type = LoanType.inFine),
              child: const shadcn.Text('In fine'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _NumberField(
          label: 'Montant emprunté',
          suffix: '€',
          value: _montantEmprunte,
          step: 1000,
          onChanged: (v) => _update(() => _montantEmprunte = v),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Durée de remboursement',
          suffix: 'ans',
          value: _dureeAnnees.toDouble(),
          step: 1,
          decimals: 0,
          onChanged: (v) => _update(() => _dureeAnnees = v.round().clamp(1, 35)),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: "Taux d'intérêt",
                suffix: '%',
                value: _tauxInteret,
                step: 0.1,
                decimals: 2,
                onChanged: (v) => _update(() => _tauxInteret = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: "Taux d'assurance",
                suffix: '%',
                value: _tauxAssurance,
                step: 0.05,
                decimals: 2,
                onChanged: (v) => _update(() => _tauxAssurance = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                label: 'Frais de dossier',
                suffix: '€',
                value: _fraisDossier,
                step: 50,
                decimals: 0,
                onChanged: (v) => _update(() => _fraisDossier = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: 'Frais de garantie',
                suffix: '€',
                value: _fraisGarantie,
                step: 50,
                decimals: 0,
                onChanged: (v) => _update(() => _fraisGarantie = v),
              ),
            ),
          ],
        ),
        if (_type == LoanType.amortissable) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: shadcn.Text('Différé de remboursement').semiBold().small()),
              _SimpleSwitch(
                value: _differeActif,
                onChanged: (v) => _update(() => _differeActif = v),
              ),
            ],
          ),
          if (_differeActif) ...[
            const SizedBox(height: 12),
            ButtonGroup(
              children: [
                SelectedButton(
                  value: _typeDiffere == DeferType.partielle,
                  onChanged: (_) => _update(() => _typeDiffere = DeferType.partielle),
                  child: const shadcn.Text('Franchise partielle'),
                ),
                SelectedButton(
                  value: _typeDiffere == DeferType.totale,
                  onChanged: (_) => _update(() => _typeDiffere = DeferType.totale),
                  child: const shadcn.Text('Franchise totale'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            shadcn.Text(
              _typeDiffere == DeferType.partielle
                  ? "Seuls les intérêts sont payés pendant le différé, le capital ne bouge pas."
                  : "Aucun paiement pendant le différé, les intérêts s'ajoutent au capital restant dû.",
            ).muted().small(),
            const SizedBox(height: 12),
            _NumberField(
              label: 'Durée du différé',
              suffix: 'mois',
              value: _dureeDiffereMois.toDouble(),
              step: 1,
              decimals: 0,
              onChanged: (v) => _update(() => _dureeDiffereMois = v.round().clamp(1, _dureeAnnees * 12 - 1)),
            ),
          ],
        ],
        const SizedBox(height: 12),
        OutlineButton(
          onPressed: _resetState,
          leading: const Icon(LucideIcons.refreshCw),
          child: const shadcn.Text('Réinitialiser les paramètres'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Colonne de droite : résultats
  // ---------------------------------------------------------------------

  Widget _buildResultsContent(LoanResult result, bool hidden) {
    final accent = Theme.of(context).colorScheme.primary;
    final red = const Color(0xFFE07A6B);
    final blue = const Color(0xFF7B8FE8);

    return Column(
      children: [
        shadcn.Text('Mensualités').muted(),
        const SizedBox(height: 8),
        shadcn.Text(
          displayEuros(result.mensualite, hidden),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        shadcn.Text.rich(
          TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: 'Dont assurance '),
              TextSpan(
                text: '${displayEuros(result.assuranceMensuelle, hidden)}/mois',
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ).muted(),
        if (result.mensualiteDifferee != null) ...[
          const SizedBox(height: 2),
          shadcn.Text(
            'Pendant le différé : ${displayEuros(result.mensualiteDifferee!, hidden)}/mois',
          ).muted().small(),
        ],
        if (result.capitalRembourseInFine != null) ...[
          const SizedBox(height: 2),
          shadcn.Text(
            'Capital remboursé en une fois à l\'échéance : ${displayEuros(result.capitalRembourseInFine!, hidden)}',
          ).muted().small(),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                shadcn.Text('Coût total du crédit').muted().small(),
                const SizedBox(height: 4),
                shadcn.Text(displayEuros(result.coutTotalCredit, hidden)).large().semiBold(),
              ],
            ),
            const SizedBox(width: 40),
            Column(
              children: [
                shadcn.Text('Dont assurance').muted().small(),
                const SizedBox(height: 4),
                shadcn.Text(displayEuros(result.totalAssurance, hidden)).large().semiBold(),
              ],
            ),
            const SizedBox(width: 40),
            Column(
              children: [
                shadcn.Text('Coût total (frais inclus)').muted().small(),
                const SizedBox(height: 4),
                shadcn.Text(displayEuros(result.coutTotalAvecFrais, hidden)).large().semiBold(),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _LegendPill(color: red, label: 'Capital', value: displayEuros(result.montantEmprunte, hidden)),
            _LegendPill(color: blue, label: 'Intérêts', value: displayEuros(result.coutTotalCredit - result.totalAssurance, hidden)),
            _LegendPill(color: accent, label: 'Assurance', value: displayEuros(result.totalAssurance, hidden)),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 280,
          child: _LoanChart(
            years: result.years,
            red: red,
            blue: blue,
            gold: accent,
            textColor: Theme.of(context).colorScheme.mutedForeground,
            gridColor: Theme.of(context).colorScheme.border,
            cardColor: Theme.of(context).colorScheme.popover,
            hidden: hidden,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        shadcn.Text.rich(
          TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: 'Pour un emprunt de '),
              TextSpan(text: displayEuros(result.montantEmprunte, hidden), style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ' sur '),
              TextSpan(text: '$_dureeAnnees ans', style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ', votre mensualité s\'élève à '),
              TextSpan(
                text: displayEuros(result.mensualite, hidden),
                style: TextStyle(fontWeight: FontWeight.bold, color: accent),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const _LoanDisclaimer(),
      ],
    );
  }
}

class _LoanDisclaimer extends StatelessWidget {
  const _LoanDisclaimer();

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
          Expanded(
            child: shadcn.Text(
              "Simulation de prêt indicative: les résultats reposent sur des hypothèses simplifiées "
              "(taux constants, assurance linéaire, frais fixes). Les conditions bancaires réelles, "
              "garanties et clauses contractuelles peuvent modifier le coût total du crédit.",
            ).muted().small(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Modèles
// ---------------------------------------------------------------------

class MonthEntry {
  final double capital;
  final double interest;
  final double insurance;
  MonthEntry({required this.capital, required this.interest, required this.insurance});
}

class YearBar {
  final int year;
  final double capital;
  final double interest;
  final double insurance;
  YearBar({required this.year, required this.capital, required this.interest, required this.insurance});
}

class LoanResult {
  final List<YearBar> years;
  final double mensualite;
  final double? mensualiteDifferee;
  final double assuranceMensuelle;
  final double coutTotalCredit;
  final double totalAssurance;
  final double coutTotalAvecFrais;
  final double montantEmprunte;
  final double? capitalRembourseInFine;

  LoanResult({
    required this.years,
    required this.mensualite,
    required this.mensualiteDifferee,
    required this.assuranceMensuelle,
    required this.coutTotalCredit,
    required this.totalAssurance,
    required this.coutTotalAvecFrais,
    required this.montantEmprunte,
    required this.capitalRembourseInFine,
  });
}

/// Construit la table d'amortissement mois par mois, puis l'agrège.
///
/// - In fine : intérêts constants sur le capital initial chaque mois,
///   capital remboursé en une fois au dernier mois.
/// - Amortissable : mensualité constante calculée par la formule standard
///   `M = C·i / (1 - (1+i)^-n)`, avec un différé optionnel où le capital
///   restant dû n'est pas encore amorti (franchise partielle : seuls les
///   intérêts sont payés ; franchise totale : les intérêts s'ajoutent au
///   capital restant dû, rien n'est décaissé).
LoanResult simulateLoan({
  required double montantEmprunte,
  required int dureeAnnees,
  required double tauxInteret,
  required double tauxAssurance,
  required double fraisDossier,
  required double fraisGarantie,
  required LoanType type,
  required bool differeActif,
  required int dureeDiffereMois,
  required DeferType typeDiffere,
}) {
  final i = tauxInteret / 100 / 12;
  final totalMonths = dureeAnnees * 12;
  final insuranceMonthly = montantEmprunte * tauxAssurance / 100 / 12;
  final months = <MonthEntry>[];

  if (type == LoanType.inFine) {
    for (var m = 1; m <= totalMonths; m++) {
      final interest = montantEmprunte * i;
      final capital = (m == totalMonths) ? montantEmprunte : 0.0;
      months.add(MonthEntry(capital: capital, interest: interest, insurance: insuranceMonthly));
    }
  } else {
    var remaining = montantEmprunte;
    final deferMonths = differeActif ? dureeDiffereMois.clamp(0, totalMonths - 1) : 0;

    for (var m = 1; m <= deferMonths; m++) {
      final interest = remaining * i;
      if (typeDiffere == DeferType.totale) {
        remaining += interest; // intérêts capitalisés, rien n'est décaissé
      }
      months.add(MonthEntry(capital: 0, interest: interest, insurance: insuranceMonthly));
    }

    final remainingMonths = totalMonths - deferMonths;
    if (remainingMonths > 0) {
      final monthlyPayment = i == 0
          ? remaining / remainingMonths
          : remaining * i / (1 - pow(1 + i, -remainingMonths));
      for (var m = 1; m <= remainingMonths; m++) {
        final interest = remaining * i;
        final capital = monthlyPayment - interest;
        remaining -= capital;
        months.add(MonthEntry(capital: capital, interest: interest, insurance: insuranceMonthly));
      }
    }
  }

  // Agrégation par année (moyenne mensuelle de l'année, pour le graphique).
  final years = <YearBar>[];
  for (var y = 0; y < dureeAnnees; y++) {
    final slice = months.skip(y * 12).take(12).toList();
    if (slice.isEmpty) continue;
    final capital = slice.map((m) => m.capital).reduce((a, b) => a + b) / slice.length;
    final interest = slice.map((m) => m.interest).reduce((a, b) => a + b) / slice.length;
    final insurance = slice.map((m) => m.insurance).reduce((a, b) => a + b) / slice.length;
    years.add(YearBar(year: y, capital: capital, interest: interest, insurance: insurance));
  }

  final totalInterest = months.fold<double>(0, (s, m) => s + m.interest);
  final totalInsurance = months.fold<double>(0, (s, m) => s + m.insurance);
  final coutTotalCredit = totalInterest + totalInsurance;
  final coutTotalAvecFrais = coutTotalCredit + fraisDossier + fraisGarantie;

  final deferMonths = (type == LoanType.amortissable && differeActif) ? dureeDiffereMois.clamp(0, totalMonths - 1) : 0;
  // Pour un amortissable classique, la mensualité est constante hors dernier mois d'arrondi :
  // on prend plutôt le paiement du premier mois de la phase d'amortissement.
  final mensualiteAffichee = type == LoanType.inFine
      ? montantEmprunte * i + insuranceMonthly
      : (deferMonths < months.length ? (months[deferMonths].capital + months[deferMonths].interest + months[deferMonths].insurance) : 0.0);

  // En franchise totale, les intérêts du différé sont capitalisés (ajoutés au
  // capital restant dû) et non décaissés : seule l'assurance est réellement
  // payée chaque mois. En franchise partielle, les intérêts sont, eux, payés.
  final mensualiteDifferee = deferMonths > 0
      ? (typeDiffere == DeferType.totale ? insuranceMonthly : months[0].capital + months[0].interest + months[0].insurance)
      : null;

  return LoanResult(
    years: years,
    mensualite: mensualiteAffichee,
    mensualiteDifferee: mensualiteDifferee,
    assuranceMensuelle: insuranceMonthly,
    coutTotalCredit: coutTotalCredit,
    totalAssurance: totalInsurance,
    coutTotalAvecFrais: coutTotalAvecFrais,
    montantEmprunte: montantEmprunte,
    capitalRembourseInFine: type == LoanType.inFine ? montantEmprunte : null,
  );
}

// ---------------------------------------------------------------------
// Interrupteur simple (maison, pour éviter de deviner l'API Switch de shadcn)
// ---------------------------------------------------------------------

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
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Champ numérique (identique en esprit à celui de la page Simulation)
// ---------------------------------------------------------------------

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
    final newText = _textFor(widget.value);
    if (!_focusNode.hasFocus && _controller.text != newText) {
      _controller.text = newText;
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
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (text) {
                  final parsed = double.tryParse(text.replaceAll(',', '.'));
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

class _LegendPill extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendPill({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          shadcn.Text(label).small(),
          const SizedBox(width: 6),
          shadcn.Text(value, style: const TextStyle(fontWeight: FontWeight.bold)).small(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Graphique en barres empilées (capital / intérêts / assurance par année)
// ---------------------------------------------------------------------

class _LoanChart extends StatefulWidget {
  final List<YearBar> years;
  final Color red;
  final Color blue;
  final Color gold;
  final Color textColor;
  final Color gridColor;
  final Color cardColor;
  final bool hidden;

  const _LoanChart({
    required this.years,
    required this.red,
    required this.blue,
    required this.gold,
    required this.textColor,
    required this.gridColor,
    required this.cardColor,
    required this.hidden,
  });

  @override
  State<_LoanChart> createState() => _LoanChartState();
}

class _LoanChartState extends State<_LoanChart> {
  int? _hoveredYear;

  static const double _leftAxisWidth = 60;
  static const double _bottomAxisHeight = 24;

  @override
  Widget build(BuildContext context) {
    if (widget.years.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final chartWidth = width - _leftAxisWidth;
        final chartHeight = height - _bottomAxisHeight;
        final n = widget.years.length;
        final barSlot = chartWidth / n;

        void updateHover(Offset local) {
          final idx = ((local.dx - _leftAxisWidth) / barSlot).floor().clamp(0, n - 1);
          if (idx != _hoveredYear) setState(() => _hoveredYear = idx);
        }

        YearBar? hovered = _hoveredYear != null ? widget.years[_hoveredYear!] : null;

        return MouseRegion(
          onHover: (e) => updateHover(e.localPosition),
          onExit: (_) => setState(() => _hoveredYear = null),
          child: Stack(
            children: [
              CustomPaint(
                size: Size(width, height),
                painter: _LoanChartPainter(
                  years: widget.years,
                  red: widget.red,
                  blue: widget.blue,
                  gold: widget.gold,
                  textColor: widget.textColor,
                  gridColor: widget.gridColor,
                  hoveredYear: _hoveredYear,
                  hidden: widget.hidden,
                ),
              ),
              if (hovered != null)
                Positioned(
                  left: (_leftAxisWidth + barSlot * _hoveredYear! - 130).clamp(_leftAxisWidth, width - 280),
                  top: (chartHeight / 2 - 90).clamp(0, chartHeight - 180),
                  child: _ChartTooltip(
                    title: 'Année ${hovered.year + 1}',
                    capital: hovered.capital,
                    interest: hovered.interest,
                    insurance: hovered.insurance,
                    red: widget.red,
                    blue: widget.blue,
                    gold: widget.gold,
                    cardColor: widget.cardColor,
                    hidden: widget.hidden,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChartTooltip extends StatelessWidget {
  final String title;
  final double capital;
  final double interest;
  final double insurance;
  final Color red;
  final Color blue;
  final Color gold;
  final Color cardColor;
  final bool hidden;

  const _ChartTooltip({
    required this.title,
    required this.capital,
    required this.interest,
    required this.insurance,
    required this.red,
    required this.blue,
    required this.gold,
    required this.cardColor,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(title).muted(),
                const SizedBox(height: 8),
                shadcn.Text(
                  displayEuros(capital + interest + insurance, hidden),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                shadcn.Text('mensualité moyenne').muted().small(),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 8),
                _row('Capital', capital, red),
                const SizedBox(height: 6),
                _row('Intérêts', interest, blue),
                const SizedBox(height: 6),
                _row('Assurance', insurance, gold),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, double value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: shadcn.Text(label)),
        shadcn.Text(displayEuros(value, hidden), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _LoanChartPainter extends CustomPainter {
  final List<YearBar> years;
  final Color red;
  final Color blue;
  final Color gold;
  final Color textColor;
  final Color gridColor;
  final int? hoveredYear;
  final bool hidden;

  _LoanChartPainter({
    required this.years,
    required this.red,
    required this.blue,
    required this.gold,
    required this.textColor,
    required this.gridColor,
    required this.hoveredYear,
    required this.hidden,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxisWidth = 60.0;
    const bottomAxisHeight = 24.0;
    final chartWidth = size.width - leftAxisWidth;
    final chartHeight = size.height - bottomAxisHeight;
    final n = years.length;
    final barSlot = chartWidth / n;
    final barWidth = barSlot * 0.6;

    final maxTotal = years.map((y) => y.capital + y.interest + y.insurance).reduce((a, b) => a > b ? a : b);
    final axisMax = _niceCeil(maxTotal * 1.15);
    const gridLines = 4;
    final step = axisMax / gridLines;

    double yFor(double value) => chartHeight - (value / axisMax) * chartHeight;

    for (var i = 0; i <= gridLines; i++) {
      final v = step * i;
      final y = yFor(v);
      canvas.drawLine(Offset(leftAxisWidth, y), Offset(size.width, y), Paint()
        ..color = gridColor.withValues(alpha: 0.4)
        ..strokeWidth = 1);
      final tp = TextPainter(
        text: TextSpan(text: displayEurosCompact(v, hidden), style: TextStyle(color: textColor, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftAxisWidth - tp.width - 8, y - tp.height / 2));
    }

    for (var idx = 0; idx < n; idx++) {
      final bar = years[idx];
      final x = leftAxisWidth + barSlot * idx + (barSlot - barWidth) / 2;
      final isHovered = hoveredYear == idx;
      final opacity = isHovered ? 1.0 : 0.85;

      var yCursor = chartHeight;
      // Capital (bas).
      final capitalTop = yFor(bar.capital);
      final capitalHeight = yCursor - capitalTop;
      _drawBarSegment(canvas, x, capitalTop, barWidth, capitalHeight, red.withValues(alpha: opacity), topRadius: bar.interest == 0 && bar.insurance == 0);
      yCursor = capitalTop;

      // Intérêts (milieu).
      final interestTop = yFor(bar.capital + bar.interest);
      final interestHeight = yCursor - interestTop;
      _drawBarSegment(canvas, x, interestTop, barWidth, interestHeight, blue.withValues(alpha: opacity), topRadius: bar.insurance == 0);
      yCursor = interestTop;

      // Assurance (haut).
      final insuranceTop = yFor(bar.capital + bar.interest + bar.insurance);
      final insuranceHeight = yCursor - insuranceTop;
      _drawBarSegment(canvas, x, insuranceTop, barWidth, insuranceHeight, gold.withValues(alpha: opacity), topRadius: true);
    }

    _drawXLabel(canvas, "Aujourd'hui", leftAxisWidth, chartHeight, textColor, alignLeft: true);
    _drawXLabel(canvas, '${years.length} ans', size.width, chartHeight, textColor, alignLeft: false);
  }

  void _drawBarSegment(Canvas canvas, double x, double top, double width, double height, Color color, {bool topRadius = false}) {
    if (height <= 0) return;
    final rect = Rect.fromLTWH(x, top, width, height);
    if (topRadius) {
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rrect, Paint()..color = color);
    } else {
      canvas.drawRect(rect, Paint()..color = color);
    }
  }

  void _drawXLabel(Canvas canvas, String text, double x, double y, Color color, {bool? alignLeft}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx;
    if (alignLeft == true) {
      dx = x;
    } else if (alignLeft == false) {
      dx = x - tp.width;
    } else {
      dx = x - tp.width / 2;
    }
    tp.paint(canvas, Offset(dx, y + 6));
  }

  double _niceCeil(double value) {
    if (value <= 0) return 100;
    var magnitude = 1.0;
    while (magnitude * 10 <= value) {
      magnitude *= 10;
    }
    final normalized = value / magnitude;
    double niceNormalized;
    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }
    return niceNormalized * magnitude;
  }

  @override
  bool shouldRepaint(covariant _LoanChartPainter oldDelegate) =>
      oldDelegate.hoveredYear != hoveredYear || oldDelegate.years != years || oldDelegate.hidden != hidden;
}
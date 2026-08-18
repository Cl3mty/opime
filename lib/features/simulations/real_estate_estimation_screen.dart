import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/simulations/simulation_state_repository.dart';
import '../../core/ui/frosted_card.dart';
import '../real_estate_pricing/dvf_cache_repository.dart';
import '../real_estate_pricing/geo_dvf_client.dart';
import '../real_estate_pricing/price_estimator.dart';
import '../real_estate_pricing/real_estate_address_picker.dart';
import '../real_estate_pricing/real_estate_heatmap_map.dart';
import '../real_estate_pricing/real_estate_price_service.dart';
import '../real_estate_pricing/rent_price_client.dart';
import '../real_estate_pricing/rent_price_repository.dart';
import 'loan_calculator.dart';
import 'real_estate_profitability_calculator.dart';
import 'real_estate_rental_models.dart';

/// Usage prévu du bien estimé — [locatif] simule la rentabilité complète
/// (unités locatives, rendement, autofinancement) ; [residence] (résidence
/// principale ou secondaire) n'a pas de notion de loyer, les résultats se
/// limitent alors au coût du projet et, si financé, à la mensualité de
/// crédit (le calcul de prêt lui-même est identique, voir
/// `_simulateLoan`).
enum _UsageType { locatif, residence }

/// Onglet "Estimation" de Simulation : estime le prix d'un bien à partir
/// d'une adresse (BAN + geo-dvf, voir `real_estate_pricing/`) puis, pour un
/// projet locatif, simule sa rentabilité globale — travaux, apport, prêt lié
/// (`loan_calculator.dart`), unités locatives multi-stratégies
/// (`real_estate_rental_models.dart`) ; pour une résidence principale ou
/// secondaire ([_UsageType.residence]), se limite au coût du projet et au
/// financement. Même "onglet = NavItem sœur", pas un `TabBar`, que le
/// précédent Analyses/Projets de cette session (voir `nav_models.dart`).
class RealEstateEstimationScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const RealEstateEstimationScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<RealEstateEstimationScreen> createState() =>
      _RealEstateEstimationScreenState();
}

class _RealEstateEstimationScreenState
    extends State<RealEstateEstimationScreen> {
  late final SimulationStateRepository _stateRepo;
  late final RealEstatePriceService _priceService;
  late final RentPriceService _rentService;
  late final RealEstateAddressPickerController _addressController;

  HeatmapMetric _mapMetric = HeatmapMetric.pricePerSqm;

  RealEstateAddressPickResult? _address;
  PropertyTypeFilter _propertyType = PropertyTypeFilter.maison;
  double _surfaceM2 = 50;
  _UsageType _usage = _UsageType.locatif;

  PriceEstimate? _priceEstimate;
  bool _loadingEstimate = false;
  double? _manualPricePerSqm;

  RentEstimate? _rentEstimate;
  bool _loadingRent = false;

  static final _defaultUnit = RentalUnit(
    label: 'Bien entier',
    strategy: RentalStrategy.longTerm(monthlyRent: 800),
  );
  List<RentalUnit> _units = [_defaultUnit];

  double _travaux = 0;
  double _fraisNotairePercent = 7.5;
  double _chargesAnnuelles = 1500;

  bool _cashPurchase = false;

  /// Paramètres de taux/durée/assurance/frais/type — lus depuis l'onglet
  /// Prêt (clé `'loan'` de [SimulationStateRepository], voir
  /// `simulations_loan_screen.dart`) à chaque rebuild plutôt que dupliqués
  /// ici : un seul jeu de paramètres de prêt pour toute la simulation
  /// Immobilier, conformément à la conception validée pour la liaison
  /// Prêt/Estimation.
  _LoanParams _loanParams = const _LoanParams();

  /// Requête d'estimation en cours : ignore une réponse devenue obsolète si
  /// l'adresse/le type a changé entre-temps (même garde-fou que
  /// `_GlobalSearchBarState._requestEpoch`).
  int _estimateEpoch = 0;
  int _rentEpoch = 0;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _priceService = RealEstatePriceService(
      client: GeoDvfClient(),
      cache: DvfCacheRepository(widget.vaultPath),
    );
    _rentService = RentPriceService(
      client: RentPriceClient(),
      cache: RentPriceRepository(widget.vaultPath),
    );
    _addressController = RealEstateAddressPickerController()
      ..onChanged = _onAddressChanged;
    widget.amountVisibility.addListener(_onAmountVisibilityChanged);
    _loadState();
    _loadLoanParams();
  }

  /// Relit les paramètres de taux/durée/assurance/frais/type persistés par
  /// l'onglet Prêt — appelé à chaque montage de cet écran (donc à chaque
  /// retour depuis l'onglet Prêt, `simulations_real_estate_screen.dart` ne
  /// gardant que l'onglet actif monté) pour rester à jour si l'utilisateur
  /// les a modifiés entre-temps.
  Future<void> _loadLoanParams() async {
    final data = await _stateRepo.read('loan');
    if (!mounted || data.isEmpty) return;
    setState(() => _loanParams = _LoanParams.fromJson(data));
  }

  void _onAmountVisibilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.amountVisibility.removeListener(_onAmountVisibilityChanged);
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final data = await _stateRepo.read('real_estate_estimation');
    if (!mounted || data.isEmpty) return;
    setState(() {
      final addressJson = data['address'] as Map<String, dynamic>?;
      if (addressJson != null) {
        _address = RealEstateAddressPickResult(
          label: addressJson['label'] as String? ?? '',
          lat: (addressJson['lat'] as num?)?.toDouble() ?? 0,
          lon: (addressJson['lon'] as num?)?.toDouble() ?? 0,
          cityCode: addressJson['cityCode'] as String? ?? '',
        );
      }
      _propertyType = PropertyTypeFilter.values.firstWhere(
        (t) => t.name == data['propertyType'],
        orElse: () => PropertyTypeFilter.maison,
      );
      _usage = _UsageType.values.firstWhere(
        (u) => u.name == data['usage'],
        orElse: () => _UsageType.locatif,
      );
      _surfaceM2 = (data['surfaceM2'] as num?)?.toDouble() ?? _surfaceM2;
      _manualPricePerSqm = (data['manualPricePerSqm'] as num?)?.toDouble();
      final unitsJson = data['units'] as List?;
      if (unitsJson != null && unitsJson.isNotEmpty) {
        _units = [
          for (final u in unitsJson) RentalUnit.fromJson(u as Map<String, dynamic>),
        ];
      }
      _travaux = (data['travaux'] as num?)?.toDouble() ?? _travaux;
      _fraisNotairePercent =
          (data['fraisNotairePercent'] as num?)?.toDouble() ?? _fraisNotairePercent;
      _chargesAnnuelles =
          (data['chargesAnnuelles'] as num?)?.toDouble() ?? _chargesAnnuelles;
      _cashPurchase = data['cashPurchase'] as bool? ?? _cashPurchase;
    });
    final address = _address;
    if (address != null) {
      // Restaure le champ de recherche/la carte à partir de l'adresse
      // rechargée — le contrôleur a été créé (vide) dans `initState`, avant
      // que cette lecture disque asynchrone ne se termine.
      _addressController.setAddressSilently(address);
      _fetchEstimate();
      _fetchRent();
    }
  }

  Future<void> _saveState() => _stateRepo.write('real_estate_estimation', {
    if (_address != null)
      'address': {
        'label': _address!.label,
        'lat': _address!.lat,
        'lon': _address!.lon,
        'cityCode': _address!.cityCode,
      },
    'propertyType': _propertyType.name,
    'usage': _usage.name,
    'surfaceM2': _surfaceM2,
    if (_manualPricePerSqm != null) 'manualPricePerSqm': _manualPricePerSqm,
    'units': [for (final u in _units) u.toJson()],
    'travaux': _travaux,
    // Pas d'apport ici : réglé exclusivement dans l'onglet Prêt (voir
    // [_LoanParams]), pour ne plus avoir deux champs éditables indépendants
    // pouvant diverger entre les deux onglets.
    'fraisNotairePercent': _fraisNotairePercent,
    'chargesAnnuelles': _chargesAnnuelles,
    'cashPurchase': _cashPurchase,
  });

  void _update(void Function() change) {
    setState(change);
    _saveState();
  }

  void _onAddressChanged(RealEstateAddressPickResult result) {
    _update(() {
      _address = result;
      _manualPricePerSqm = null;
    });
    _fetchEstimate();
    _fetchRent();
  }

  Future<void> _fetchEstimate() async {
    final address = _address;
    if (address == null) return;
    final epoch = ++_estimateEpoch;
    setState(() => _loadingEstimate = true);
    final estimate = await _priceService.estimate(
      citycode: address.cityCode,
      lat: address.lat,
      lon: address.lon,
      propertyType: _propertyType,
    );
    if (!mounted || epoch != _estimateEpoch) return;
    setState(() {
      _priceEstimate = estimate;
      _loadingEstimate = false;
    });
  }

  /// Loyer/m² pour l'adresse choisie — simple lecture dans la table
  /// nationale des loyers (pas de calcul par rayon, voir
  /// `rent_price_client.dart`). Si la première unité locative est encore à
  /// sa valeur par défaut (jamais modifiée par l'utilisateur), son loyer
  /// mensuel est pré-rempli à partir de ce loyer/m² — l'utilisateur reste
  /// libre de le corriger ensuite, exactement comme le prix/m² du bien.
  Future<void> _fetchRent() async {
    final address = _address;
    if (address == null || _propertyType == PropertyTypeFilter.any) return;
    final epoch = ++_rentEpoch;
    setState(() => _loadingRent = true);
    final rentType = _propertyType == PropertyTypeFilter.maison
        ? RentPropertyType.maison
        : RentPropertyType.appartement;
    final estimate = await _rentService.estimateForCommune(
      address.cityCode,
      rentType,
    );
    if (!mounted || epoch != _rentEpoch) return;
    final stillDefaultUnit =
        _usage == _UsageType.locatif &&
        _units.length == 1 &&
        _units.first.label == _defaultUnit.label &&
        _units.first.strategy.kind == RentalStrategyKind.longTerm &&
        _units.first.strategy.monthlyRent == _defaultUnit.strategy.monthlyRent;
    setState(() {
      _rentEstimate = estimate;
      _loadingRent = false;
      if (estimate != null && stillDefaultUnit) {
        _units = [
          _defaultUnit.copyWith(
            strategy: RentalStrategy.longTerm(
              monthlyRent: (_surfaceM2 * estimate.loyerPredM2).roundToDouble(),
            ),
          ),
        ];
      }
    });
    if (estimate != null && stillDefaultUnit) _saveState();
  }

  double get _effectivePricePerSqm =>
      _manualPricePerSqm ?? _priceEstimate?.medianPricePerSqm ?? 0;

  double get _prixAchat => _surfaceM2 * _effectivePricePerSqm;

  double get _coutTotalProjet =>
      _prixAchat * (1 + _fraisNotairePercent / 100) + _travaux;

  LoanResult? _simulateLoan() {
    if (_cashPurchase) return null;
    final montantEmprunte =
        (_coutTotalProjet - _loanParams.apport).clamp(0.0, double.infinity);
    if (montantEmprunte <= 0) return null;
    return simulateLoan(
      montantEmprunte: montantEmprunte,
      dureeAnnees: _loanParams.dureeAnnees,
      tauxInteret: _loanParams.tauxInteret,
      assuranceMensuelle: _loanParams.assuranceMensuelle,
      fraisDossier: _loanParams.fraisDossier,
      fraisGarantie: _loanParams.fraisGarantie,
      type: _loanParams.loanType,
      differeActif: false,
      dureeDiffereMois: 0,
      typeDiffere: DeferType.partielle,
    );
  }

  bool _loanJustSynced = false;

  /// Copie le coût total du projet courant vers l'onglet Prêt (clé
  /// `montantEmprunte` de sa clé de persistance `'loan'`), sans écraser ses
  /// autres réglages (différé...) ni son apport — l'apport est réglé
  /// exclusivement dans l'onglet Prêt (voir [_LoanParams]), cet écran ne
  /// fait que lui fournir le coût du projet qu'il évalue. Lit l'état
  /// complet existant, ne remplace que cette clé, puis réécrit. Voir la
  /// documentation de [_loanParams] pour le sens inverse (Estimation lit
  /// les paramètres de taux et l'apport depuis Prêt).
  Future<void> _useConfiguredLoan() async {
    final current = await _stateRepo.read('loan');
    await _stateRepo.write('loan', {
      ...current,
      'montantEmprunte': _coutTotalProjet,
    });
    if (!mounted) return;
    _update(() => _cashPurchase = false);
    setState(() => _loanJustSynced = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _loanJustSynced = false);
    });
  }

  RealEstateProfitabilityResult _simulateProfitability(LoanResult? loan) =>
      simulateRealEstateProfitability(
        prixAchat: _prixAchat,
        fraisNotairePercent: _fraisNotairePercent,
        travaux: _travaux,
        apport: _loanParams.apport,
        units: _units,
        chargesAnnuelles: _chargesAnnuelles,
        loan: loan,
      );

  @override
  Widget build(BuildContext context) {
    final loan = _simulateLoan();
    final result = _usage == _UsageType.locatif ? _simulateProfitability(loan) : null;
    final hidden = widget.amountVisibility.hidden;

    return FrostedCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final left = _buildInputsContent();
          final right = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMapSection(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              _buildResultsContent(result, loan, hidden),
            ],
          );
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
                width: 420,
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

  // ---------------------------------------------------------------------
  // Colonne de droite (au-dessus des résultats) : carte
  // ---------------------------------------------------------------------

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text('Adresse du bien').semiBold().small(),
        const SizedBox(height: 8),
        // Toujours visible, quelle que soit la carte de chaleur affichée en
        // dessous — la recherche d'une adresse précise reste possible à
        // tout moment, indépendamment du choix "Prix / Loyer" ci-dessous.
        RealEstateAddressSearchField(controller: _addressController),
        const SizedBox(height: 12),
        ButtonGroup(
          children: [
            SelectedButton(
              value: _mapMetric == HeatmapMetric.pricePerSqm,
              onChanged: (_) =>
                  setState(() => _mapMetric = HeatmapMetric.pricePerSqm),
              selectedStyle: const ButtonStyle.primary(),
              child: const shadcn.Text('Prix au m²'),
            ),
            SelectedButton(
              value: _mapMetric == HeatmapMetric.rentPerSqm,
              onChanged: (_) =>
                  setState(() => _mapMetric = HeatmapMetric.rentPerSqm),
              selectedStyle: const ButtonStyle.primary(),
              child: const shadcn.Text('Loyer au m²'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RealEstateHeatmapMap(
          vaultPath: widget.vaultPath,
          metric: _mapMetric,
          propertyType: _propertyType,
          addressController: _addressController,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Colonne de gauche : formulaire
  // ---------------------------------------------------------------------

  Widget _buildInputsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text('Usage du bien').muted().small(),
        const SizedBox(height: 8),
        ButtonGroup(
          children: [
            SelectedButton(
              value: _usage == _UsageType.locatif,
              onChanged: (_) => _update(() => _usage = _UsageType.locatif),
              selectedStyle: const ButtonStyle.primary(),
              child: const shadcn.Text('Investissement locatif'),
            ),
            SelectedButton(
              value: _usage == _UsageType.residence,
              onChanged: (_) => _update(() => _usage = _UsageType.residence),
              selectedStyle: const ButtonStyle.primary(),
              child: const shadcn.Text('Résidence principale/secondaire'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        shadcn.Text('Type de bien').muted().small(),
        const SizedBox(height: 8),
        ButtonGroup(
          children: [
            SelectedButton(
              value: _propertyType == PropertyTypeFilter.maison,
              onChanged: (_) {
                _update(() => _propertyType = PropertyTypeFilter.maison);
                _fetchEstimate();
                _fetchRent();
              },
              selectedStyle: const ButtonStyle.primary(),
              child: const shadcn.Text('Maison'),
            ),
            SelectedButton(
              value: _propertyType == PropertyTypeFilter.appartement,
              onChanged: (_) {
                _update(() => _propertyType = PropertyTypeFilter.appartement);
                _fetchEstimate();
                _fetchRent();
              },
              selectedStyle: const ButtonStyle.primary(),
              child: const shadcn.Text('Appartement'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Surface',
          suffix: 'm²',
          value: _surfaceM2,
          step: 1,
          onChanged: (v) => _update(() => _surfaceM2 = v),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Prix au m² (corrigeable)',
          suffix: '€/m²',
          value: _effectivePricePerSqm,
          step: 50,
          onChanged: (v) => _update(() => _manualPricePerSqm = v),
        ),
        if (_usage == _UsageType.locatif) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: shadcn.Text('Unités locatives').semiBold().small()),
              IconButton.ghost(
                icon: const Icon(LucideIcons.plus, size: 16),
                onPressed: () => _update(
                  () => _units = [
                    ..._units,
                    RentalUnit(
                      label: 'Unité ${_units.length + 1}',
                      strategy: RentalStrategy.longTerm(monthlyRent: 500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (var i = 0; i < _units.length; i++)
            _RentalUnitEditor(
              key: ValueKey(_units[i].id),
              unit: _units[i],
              canRemove: _units.length > 1,
              onChanged: (updated) => _update(() {
                _units = [..._units];
                _units[i] = updated;
              }),
              onRemove: () => _update(() {
                _units = [..._units]..removeAt(i);
              }),
            ),
        ],
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        shadcn.Text('Financement').semiBold().small(),
        const SizedBox(height: 12),
        _NumberField(
          label: 'Travaux',
          suffix: '€',
          value: _travaux,
          step: 1000,
          onChanged: (v) => _update(() => _travaux = v),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Frais de notaire',
          suffix: '%',
          value: _fraisNotairePercent,
          step: 0.5,
          decimals: 1,
          onChanged: (v) => _update(() => _fraisNotairePercent = v),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Charges annuelles (copro, taxe foncière, assurance...)',
          suffix: '€/an',
          value: _chargesAnnuelles,
          step: 100,
          onChanged: (v) => _update(() => _chargesAnnuelles = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: shadcn.Text('Achat comptant (sans crédit)').small()),
            _SimpleSwitch(
              value: _cashPurchase,
              onChanged: (v) => _update(() => _cashPurchase = v),
            ),
          ],
        ),
        if (!_cashPurchase) ...[
          const SizedBox(height: 12),
          shadcn.Text(
            'Montant emprunté (dérivé) : ${displayEuros((_coutTotalProjet - _loanParams.apport).clamp(0.0, double.infinity), widget.amountVisibility.hidden)}',
          ).muted().small(),
          const SizedBox(height: 4),
          shadcn.Text(
            // Apport réglé exclusivement dans l'onglet Prêt (voir
            // [_LoanParams]) — plus de champ dupliqué ici.
            "Apport ${displayEuros(_loanParams.apport, widget.amountVisibility.hidden)}, "
            "taux ${_loanParams.tauxInteret.toStringAsFixed(2)} % sur ${_loanParams.dureeAnnees} ans, "
            "assurance ${displayEuros(_loanParams.assuranceMensuelle, widget.amountVisibility.hidden)}/mois "
            "— réglés dans l'onglet Prêt.",
          ).muted().xSmall(),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlineButton(
                onPressed: _useConfiguredLoan,
                leading: const Icon(LucideIcons.link),
                child: const shadcn.Text('Utiliser le prêt configuré'),
              ),
              if (_loanJustSynced) ...[
                const SizedBox(width: 8),
                Icon(LucideIcons.check, size: 16, color: Colors.green),
              ],
            ],
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Colonne de droite : résultats
  // ---------------------------------------------------------------------

  Widget _buildResultsContent(
    RealEstateProfitabilityResult? result,
    LoanResult? loan,
    bool hidden,
  ) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text('Prix estimé du bien').muted(),
        const SizedBox(height: 8),
        shadcn.Text(
          displayEuros(_prixAchat, hidden),
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        if (_loadingEstimate)
          shadcn.Text('Estimation en cours...').muted().small()
        else if (_priceEstimate != null)
          shadcn.Text(
            'Basé sur ${_priceEstimate!.sampleSize} vente(s) comparable(s)'
            '${_priceEstimate!.radiusKmUsed != null ? ' dans un rayon de ${_priceEstimate!.radiusKmUsed!.toStringAsFixed(1)} km' : ' (commune entière)'}'
            ', ${_priceEstimate!.yearsUsed.join('-')}.',
          ).muted().small()
        else if (_address != null)
          shadcn.Text('Aucune vente comparable trouvée — prix à ajuster manuellement.').muted().small(),
        if (_loadingRent) ...[
          const SizedBox(height: 4),
          shadcn.Text('Estimation du loyer en cours...').muted().small(),
        ] else if (_rentEstimate != null) ...[
          const SizedBox(height: 4),
          shadcn.Text.rich(
            TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                const TextSpan(text: 'Loyer estimé : '),
                TextSpan(
                  text: '${_rentEstimate!.loyerPredM2.toStringAsFixed(1)} €/m²',
                  style: TextStyle(fontWeight: FontWeight.bold, color: accent),
                ),
                TextSpan(
                  text: _rentEstimate!.predictionType == 'commune'
                      ? ' (commune)'
                      : ' (zone élargie)',
                ),
              ],
            ),
          ).muted().small(),
        ],
        const SizedBox(height: 24),
        if (result != null) ...[
          _ProfitabilityStats(
            items: [
              ('Revenu locatif brut', displayEuros(result.revenuLocatifAnnuelBrut, hidden), '/an'),
              ('Revenu locatif net', displayEuros(result.revenuLocatifAnnuelNet, hidden), '/an'),
              if (!_cashPurchase)
                ('Mensualité crédit', displayEuros(result.mensualiteCredit, hidden), '/mois'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (result.autofinance ? Colors.green : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(
                color: result.autofinance ? Colors.green : Colors.red,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  result.autofinance ? LucideIcons.circleCheck : LucideIcons.triangleAlert,
                  color: result.autofinance ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      shadcn.Text(
                        result.autofinance ? 'Projet autofinancé' : 'Projet non autofinancé',
                      ).semiBold(),
                      shadcn.Text(
                        'Cash-flow mensuel : ${displayEuros(result.cashFlowMensuel, hidden)}',
                      ).small(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _StatChip(
                label: 'Rendement brut',
                value: '${result.rendementBrutPercent.toStringAsFixed(2)} %',
                accent: accent,
              ),
              _StatChip(
                label: 'Rendement net',
                value: '${result.rendementNetPercent.toStringAsFixed(2)} %',
                accent: accent,
              ),
              _StatChip(
                label: 'Coût total du projet',
                value: displayEuros(result.coutTotalProjet, hidden),
                accent: accent,
              ),
            ],
          ),
        ] else ...[
          // Résidence principale/secondaire : pas de loyer, donc pas de
          // rentabilité — seulement le coût du projet et, si financé, la
          // mensualité de crédit (même calcul de prêt que le mode locatif).
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _StatChip(
                label: 'Coût total du projet',
                value: displayEuros(_coutTotalProjet, hidden),
                accent: accent,
              ),
              if (loan != null)
                _StatChip(
                  label: 'Mensualité crédit',
                  value: '${displayEuros(loan.mensualite, hidden)}/mois',
                  accent: accent,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Sous-ensemble en lecture seule des paramètres persistés par l'onglet
/// Prêt (`simulations_loan_screen.dart`, clé `'loan'`) utilisé par cet
/// écran pour son propre calcul de mensualité — les valeurs par défaut
/// reprennent celles de `_LoanSimulationScreenState` tant que l'onglet Prêt
/// n'a jamais été configuré. [apport] en fait partie au même titre que le
/// taux/la durée : un seul apport pour toute la simulation Immobilier,
/// réglé dans l'onglet Prêt — avant, chaque onglet avait son propre champ
/// éditable, pouvant diverger l'un de l'autre sans que ce soit visible.
class _LoanParams {
  final double tauxInteret;
  final int dureeAnnees;
  final double assuranceMensuelle;
  final double fraisDossier;
  final double fraisGarantie;
  final LoanType loanType;
  final double apport;

  const _LoanParams({
    this.tauxInteret = 3.5,
    this.dureeAnnees = 20,
    this.assuranceMensuelle = 20,
    this.fraisDossier = 800,
    this.fraisGarantie = 1200,
    this.loanType = LoanType.amortissable,
    this.apport = 0,
  });

  factory _LoanParams.fromJson(Map<String, dynamic> json) => _LoanParams(
    tauxInteret: (json['tauxInteret'] as num?)?.toDouble() ?? 3.5,
    dureeAnnees: (json['dureeAnnees'] as num?)?.toInt() ?? 20,
    assuranceMensuelle: (json['assuranceMensuelle'] as num?)?.toDouble() ?? 20,
    fraisDossier: (json['fraisDossier'] as num?)?.toDouble() ?? 800,
    fraisGarantie: (json['fraisGarantie'] as num?)?.toDouble() ?? 1200,
    loanType: LoanType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => LoanType.amortissable,
    ),
    apport: (json['apport'] as num?)?.toDouble() ?? 0,
  );
}

// ---------------------------------------------------------------------
// Éditeur d'une unité locative
// ---------------------------------------------------------------------

class _RentalUnitEditor extends StatelessWidget {
  final RentalUnit unit;
  final bool canRemove;
  final ValueChanged<RentalUnit> onChanged;
  final VoidCallback onRemove;

  const _RentalUnitEditor({
    super.key,
    required this.unit,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: shadcn.Text(unit.label).semiBold().small(),
              ),
              shadcn.Text(
                '${unit.annualGrossRevenue.round()} €/an',
              ).muted().xSmall(),
              if (canRemove) ...[
                const SizedBox(width: 4),
                IconButton.ghost(
                  icon: const Icon(LucideIcons.trash2, size: 14),
                  onPressed: onRemove,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Select<RentalStrategyKind>(
            value: unit.strategy.kind,
            placeholder: const shadcn.Text('Stratégie'),
            onChanged: (kind) {
              if (kind == null) return;
              onChanged(unit.copyWith(strategy: _defaultStrategyFor(kind, unit.strategy)));
            },
            itemBuilder: (context, kind) => shadcn.Text(_strategyLabel(kind)),
            popup: (context) => SelectPopup(
              items: SelectItemList(
                children: [
                  for (final kind in RentalStrategyKind.values)
                    SelectItemButton(
                      value: kind,
                      child: shadcn.Text(_strategyLabel(kind)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildStrategyFields(unit.strategy, (s) => onChanged(unit.copyWith(strategy: s))),
        ],
      ),
    );
  }

  static String _strategyLabel(RentalStrategyKind kind) => switch (kind) {
    RentalStrategyKind.longTerm => 'Longue durée',
    RentalStrategyKind.shortTerm => 'Courte durée',
    RentalStrategyKind.seasonalMix => 'Mixte saisonnier',
    RentalStrategyKind.colocation => 'Colocation',
  };

  static RentalStrategy _defaultStrategyFor(
    RentalStrategyKind kind,
    RentalStrategy current,
  ) => switch (kind) {
    RentalStrategyKind.longTerm =>
      RentalStrategy.longTerm(monthlyRent: current.monthlyRent ?? 500),
    RentalStrategyKind.shortTerm => RentalStrategy.shortTerm(
      nightlyRate: current.nightlyRate ?? 70,
      occupancyRatePercent: current.occupancyRatePercent ?? 60,
    ),
    RentalStrategyKind.seasonalMix => RentalStrategy.seasonalMix(
      longTermMonths: current.longTermMonths ?? 9,
      longTermMonthlyRent: current.longTermMonthlyRent ?? 500,
      shortTermMonths: current.shortTermMonths ?? 3,
      shortTermNightlyRate: current.shortTermNightlyRate ?? 80,
      shortTermOccupancyRatePercent: current.shortTermOccupancyRatePercent ?? 60,
    ),
    RentalStrategyKind.colocation => RentalStrategy.colocation(
      rooms: current.rooms.isEmpty
          ? [RentalRoom(label: 'Chambre 1', monthlyRent: 450)]
          : current.rooms,
    ),
  };

  Widget _buildStrategyFields(
    RentalStrategy strategy,
    ValueChanged<RentalStrategy> onStrategyChanged,
  ) {
    switch (strategy.kind) {
      case RentalStrategyKind.longTerm:
        return _CompactNumberField(
          label: 'Loyer mensuel (€)',
          value: strategy.monthlyRent ?? 0,
          onChanged: (v) => onStrategyChanged(RentalStrategy.longTerm(monthlyRent: v)),
        );
      case RentalStrategyKind.shortTerm:
        return Row(
          children: [
            Expanded(
              child: _CompactNumberField(
                label: 'Tarif/nuit (€)',
                value: strategy.nightlyRate ?? 0,
                onChanged: (v) => onStrategyChanged(
                  RentalStrategy.shortTerm(
                    nightlyRate: v,
                    occupancyRatePercent: strategy.occupancyRatePercent ?? 60,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactNumberField(
                label: 'Occupation (%)',
                value: strategy.occupancyRatePercent ?? 0,
                onChanged: (v) => onStrategyChanged(
                  RentalStrategy.shortTerm(
                    nightlyRate: strategy.nightlyRate ?? 70,
                    occupancyRatePercent: v,
                  ),
                ),
              ),
            ),
          ],
        );
      case RentalStrategyKind.seasonalMix:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _CompactNumberField(
                    label: 'Mois longue durée',
                    value: (strategy.longTermMonths ?? 0).toDouble(),
                    onChanged: (v) => onStrategyChanged(
                      RentalStrategy.seasonalMix(
                        longTermMonths: v.round(),
                        longTermMonthlyRent: strategy.longTermMonthlyRent ?? 500,
                        shortTermMonths: strategy.shortTermMonths ?? 3,
                        shortTermNightlyRate: strategy.shortTermNightlyRate ?? 80,
                        shortTermOccupancyRatePercent:
                            strategy.shortTermOccupancyRatePercent ?? 60,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactNumberField(
                    label: 'Loyer longue durée (€)',
                    value: strategy.longTermMonthlyRent ?? 0,
                    onChanged: (v) => onStrategyChanged(
                      RentalStrategy.seasonalMix(
                        longTermMonths: strategy.longTermMonths ?? 9,
                        longTermMonthlyRent: v,
                        shortTermMonths: strategy.shortTermMonths ?? 3,
                        shortTermNightlyRate: strategy.shortTermNightlyRate ?? 80,
                        shortTermOccupancyRatePercent:
                            strategy.shortTermOccupancyRatePercent ?? 60,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CompactNumberField(
                    label: 'Mois courte durée',
                    value: (strategy.shortTermMonths ?? 0).toDouble(),
                    onChanged: (v) => onStrategyChanged(
                      RentalStrategy.seasonalMix(
                        longTermMonths: strategy.longTermMonths ?? 9,
                        longTermMonthlyRent: strategy.longTermMonthlyRent ?? 500,
                        shortTermMonths: v.round(),
                        shortTermNightlyRate: strategy.shortTermNightlyRate ?? 80,
                        shortTermOccupancyRatePercent:
                            strategy.shortTermOccupancyRatePercent ?? 60,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactNumberField(
                    label: 'Tarif/nuit été (€)',
                    value: strategy.shortTermNightlyRate ?? 0,
                    onChanged: (v) => onStrategyChanged(
                      RentalStrategy.seasonalMix(
                        longTermMonths: strategy.longTermMonths ?? 9,
                        longTermMonthlyRent: strategy.longTermMonthlyRent ?? 500,
                        shortTermMonths: strategy.shortTermMonths ?? 3,
                        shortTermNightlyRate: v,
                        shortTermOccupancyRatePercent:
                            strategy.shortTermOccupancyRatePercent ?? 60,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case RentalStrategyKind.colocation:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < strategy.rooms.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _CompactNumberField(
                        label: strategy.rooms[i].label,
                        value: strategy.rooms[i].monthlyRent,
                        onChanged: (v) {
                          final rooms = [...strategy.rooms];
                          rooms[i] = RentalRoom(
                            id: rooms[i].id,
                            label: rooms[i].label,
                            monthlyRent: v,
                          );
                          onStrategyChanged(RentalStrategy.colocation(rooms: rooms));
                        },
                      ),
                    ),
                    if (strategy.rooms.length > 1)
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 12),
                        onPressed: () {
                          final rooms = [...strategy.rooms]..removeAt(i);
                          onStrategyChanged(RentalStrategy.colocation(rooms: rooms));
                        },
                      ),
                  ],
                ),
              ),
            TextButton(
              onPressed: () {
                final rooms = [
                  ...strategy.rooms,
                  RentalRoom(
                    label: 'Chambre ${strategy.rooms.length + 1}',
                    monthlyRent: 450,
                  ),
                ];
                onStrategyChanged(RentalStrategy.colocation(rooms: rooms));
              },
              child: const shadcn.Text('+ Ajouter une chambre'),
            ),
          ],
        );
    }
  }
}

// ---------------------------------------------------------------------
// Petits composants d'affichage
// ---------------------------------------------------------------------

class _ProfitabilityStats extends StatelessWidget {
  final List<(String, String, String)> items;
  const _ProfitabilityStats({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        for (final item in items)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              shadcn.Text(item.$1).muted().small(),
              const SizedBox(height: 4),
              shadcn.Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: item.$2,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' ${item.$3}'),
                  ],
                ),
              ).muted(),
            ],
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _StatChip({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(label).muted().xSmall(),
        const SizedBox(height: 2),
        shadcn.Text(value).semiBold().large(),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Interrupteur simple — mêmes composants privés que
// `simulations_loan_screen.dart` (dupliqués volontairement, non partagés
// entre écrans dans ce dépôt).
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

/// Champ numérique compact, sans chevrons ni suffixe — pour les formulaires
/// denses (unités locatives, chambres).
class _CompactNumberField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _CompactNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_CompactNumberField> createState() => _CompactNumberFieldState();
}

class _CompactNumberFieldState extends State<_CompactNumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.round().toString());
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _CompactNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value.round().toString();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(widget.label).muted().xSmall(),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (text) {
            final parsed = parseDecimal(text);
            if (parsed != null) widget.onChanged(parsed);
          },
        ),
      ],
    );
  }
}

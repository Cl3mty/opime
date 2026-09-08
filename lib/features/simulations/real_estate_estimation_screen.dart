import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../core/simulations/simulation_state_repository.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/toggle_button_style.dart';
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

  /// Unité de location par défaut (bien loué en entier) — titre localisé
  /// plutôt que statique : le modèle `RentalUnit` vit sans `BuildContext`.
  RentalUnit get _defaultUnit => RentalUnit(
        label: AppLocalizations.of(context)
            .simulations_estimation_unit_default_label,
        strategy: RentalStrategy.longTerm(monthlyRent: 800),
      );
  late List<RentalUnit> _units;

  bool _unitsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `_defaultUnit` lit `AppLocalizations` : interdit dans `initState`,
    // autorisé ici (appelé avant le premier `build`). Ne réinitialise qu'une
    // fois — un changement de locale ne doit pas écraser les unités du
    // brouillon de l'utilisateur.
    if (!_unitsInitialized) {
      _unitsInitialized = true;
      _units = [_defaultUnit];
    }
  }

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
          for (final u in unitsJson)
            RentalUnit.fromJson(u as Map<String, dynamic>),
        ];
      }
      _travaux = (data['travaux'] as num?)?.toDouble() ?? _travaux;
      _fraisNotairePercent =
          (data['fraisNotairePercent'] as num?)?.toDouble() ??
          _fraisNotairePercent;
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
    final montantEmprunte = (_coutTotalProjet - _loanParams.apport).clamp(
      0.0,
      double.infinity,
    );
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
    final l10n = AppLocalizations.of(context);
    final loan = _simulateLoan();
    final result = _usage == _UsageType.locatif
        ? _simulateProfitability(loan)
        : null;
    final hidden = widget.amountVisibility.hidden;

    return FrostedCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final left = _buildInputsContent(l10n);
          final right = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMapSection(l10n),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              _buildResultsContent(l10n, result, loan, hidden),
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

  Widget _buildMapSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(l10n.simulations_estimation_property_address).semiBold().small(),
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
              style: toggleUnselectedStyle(context),
              child: shadcn.Text(l10n.simulations_estimation_price_per_sqm),
            ),
            SelectedButton(
              value: _mapMetric == HeatmapMetric.rentPerSqm,
              onChanged: (_) =>
                  setState(() => _mapMetric = HeatmapMetric.rentPerSqm),
              selectedStyle: const ButtonStyle.primary(),
              style: toggleUnselectedStyle(context),
              child: shadcn.Text(l10n.simulations_estimation_rent_per_sqm),
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

  Widget _buildInputsContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(l10n.simulations_estimation_property_usage).muted().small(),
        const SizedBox(height: 8),
        ButtonGroup(
          children: [
            SelectedButton(
              value: _usage == _UsageType.locatif,
              onChanged: (_) => _update(() => _usage = _UsageType.locatif),
              selectedStyle: const ButtonStyle.primary(),
              style: toggleUnselectedStyle(context),
              child: shadcn.Text(l10n.simulations_estimation_usage_locatif),
            ),
            SelectedButton(
              value: _usage == _UsageType.residence,
              onChanged: (_) => _update(() => _usage = _UsageType.residence),
              selectedStyle: const ButtonStyle.primary(),
              style: toggleUnselectedStyle(context),
              child: shadcn.Text(l10n.simulations_estimation_usage_residence),
            ),
          ],
        ),
        const SizedBox(height: 16),
        shadcn.Text(l10n.simulations_estimation_property_type).muted().small(),
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
              style: toggleUnselectedStyle(context),
              child: shadcn.Text(l10n.simulations_estimation_type_maison),
            ),
            SelectedButton(
              value: _propertyType == PropertyTypeFilter.appartement,
              onChanged: (_) {
                _update(() => _propertyType = PropertyTypeFilter.appartement);
                _fetchEstimate();
                _fetchRent();
              },
              selectedStyle: const ButtonStyle.primary(),
              style: toggleUnselectedStyle(context),
              child: shadcn.Text(l10n.simulations_estimation_type_appartement),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.simulations_estimation_field_surface,
          suffix: 'm²',
          value: _surfaceM2,
          step: 1,
          onChanged: (v) => _update(() => _surfaceM2 = v),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.simulations_estimation_field_price_per_sqm,
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
              Expanded(
                child: shadcn.Text(l10n.simulations_estimation_rental_units).semiBold().small(),
              ),
              IconButton.ghost(
                icon: const Icon(LucideIcons.plus, size: 16),
                onPressed: () => _update(
                  () => _units = [
                    ..._units,
                    RentalUnit(
                      label: l10n.simulations_estimation_unit_number(_units.length + 1),
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
              l10n: l10n,
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
        shadcn.Text(l10n.simulations_estimation_financing).semiBold().small(),
        const SizedBox(height: 12),
        _NumberField(
          label: l10n.simulations_estimation_field_travaux,
          suffix: '€',
          value: _travaux,
          step: 1000,
          onChanged: (v) => _update(() => _travaux = v),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.simulations_estimation_field_frais_notaire,
          suffix: '%',
          value: _fraisNotairePercent,
          step: 0.5,
          decimals: 1,
          onChanged: (v) => _update(() => _fraisNotairePercent = v),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.simulations_estimation_field_charges_annuelles,
          suffix: '€/an',
          value: _chargesAnnuelles,
          step: 100,
          onChanged: (v) => _update(() => _chargesAnnuelles = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: shadcn.Text(l10n.simulations_estimation_cash_purchase).small(),
            ),
            _SimpleSwitch(
              value: _cashPurchase,
              onChanged: (v) => _update(() => _cashPurchase = v),
            ),
          ],
        ),
        if (!_cashPurchase) ...[
          const SizedBox(height: 12),
          shadcn.Text(
            l10n.simulations_estimation_derived_loan_amount(
              displayEuros((_coutTotalProjet - _loanParams.apport).clamp(0.0, double.infinity), widget.amountVisibility.hidden),
            ),
          ).muted().small(),
          const SizedBox(height: 4),
          shadcn.Text(
            l10n.simulations_estimation_loan_info(
              displayEuros(_loanParams.apport, widget.amountVisibility.hidden),
              _loanParams.tauxInteret.toStringAsFixed(2),
              _loanParams.dureeAnnees,
              displayEuros(_loanParams.assuranceMensuelle, widget.amountVisibility.hidden),
            ),
          ).muted().xSmall(),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlineButton(
                onPressed: _useConfiguredLoan,
                leading: const Icon(LucideIcons.link),
                child: shadcn.Text(l10n.simulations_estimation_use_configured_loan),
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
    AppLocalizations l10n,
    RealEstateProfitabilityResult? result,
    LoanResult? loan,
    bool hidden,
  ) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(l10n.simulations_estimation_estimated_price).muted(),
        const SizedBox(height: 8),
        shadcn.Text(
          displayEuros(_prixAchat, hidden),
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        if (_loadingEstimate)
          shadcn.Text(l10n.simulations_estimation_estimation_in_progress).muted().small()
        else if (_priceEstimate != null)
          shadcn.Text(
            l10n.simulations_estimation_comparable_sales_info(
              _priceEstimate!.sampleSize,
              _priceEstimate!.radiusKmUsed != null
                  ? l10n.simulations_estimation_within_radius(
                      _priceEstimate!.radiusKmUsed!.toStringAsFixed(1),
                    )
                  : l10n.simulations_estimation_whole_township,
              _priceEstimate!.yearsUsed.join('-'),
            ),
          ).muted().small()
        else if (_address != null)
          shadcn.Text(
            l10n.simulations_estimation_no_comparable_sales,
          ).muted().small(),
        if (_loadingRent) ...[
          const SizedBox(height: 4),
          shadcn.Text(l10n.simulations_estimation_rent_estimation_in_progress).muted().small(),
        ] else if (_rentEstimate != null) ...[
          const SizedBox(height: 4),
          shadcn.Text.rich(
            TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(text: l10n.simulations_estimation_estimated_rent_label),
                TextSpan(
                  text: '${_rentEstimate!.loyerPredM2.toStringAsFixed(1)} €/m²',
                  style: TextStyle(fontWeight: FontWeight.bold, color: accent),
                ),
                TextSpan(
                  text: _rentEstimate!.predictionType == 'commune'
                      ? l10n.simulations_estimation_rent_zone_commune
                      : l10n.simulations_estimation_rent_zone_expanded,
                ),
              ],
            ),
          ).muted().small(),
        ],
        const SizedBox(height: 24),
        if (result != null) ...[
          _ProfitabilityStats(
            items: [
              (
                l10n.simulations_estimation_gross_rental_income,
                displayEuros(result.revenuLocatifAnnuelBrut, hidden),
                '/an',
              ),
              (
                l10n.simulations_estimation_net_rental_income,
                displayEuros(result.revenuLocatifAnnuelNet, hidden),
                '/an',
              ),
              if (!_cashPurchase)
                (
                  l10n.simulations_estimation_loan_payment,
                  displayEuros(result.mensualiteCredit, hidden),
                  '/mois',
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (result.autofinance ? Colors.green : Colors.red)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(
                color: result.autofinance ? Colors.green : Colors.red,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  result.autofinance
                      ? LucideIcons.circleCheck
                      : LucideIcons.triangleAlert,
                  color: result.autofinance ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      shadcn.Text(
                        result.autofinance
                            ? l10n.simulations_estimation_project_self_financed
                            : l10n.simulations_estimation_project_not_self_financed,
                      ).semiBold(),
                      shadcn.Text(
                        l10n.simulations_estimation_monthly_cash_flow(
                          displayEuros(result.cashFlowMensuel, hidden),
                        ),
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
                label: l10n.simulations_estimation_gross_yield,
                value: '${result.rendementBrutPercent.toStringAsFixed(2)} %',
                accent: accent,
              ),
              _StatChip(
                label: l10n.simulations_estimation_net_yield,
                value: '${result.rendementNetPercent.toStringAsFixed(2)} %',
                accent: accent,
              ),
              _StatChip(
                label: l10n.simulations_estimation_total_project_cost,
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
                label: l10n.simulations_estimation_total_project_cost,
                value: displayEuros(_coutTotalProjet, hidden),
                accent: accent,
              ),
              if (loan != null)
                _StatChip(
                  label: l10n.simulations_estimation_loan_payment,
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
  final AppLocalizations l10n;

  const _RentalUnitEditor({
    super.key,
    required this.unit,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    required this.l10n,
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
              Expanded(child: shadcn.Text(unit.label).semiBold().small()),
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
            placeholder: shadcn.Text(l10n.simulations_estimation_strategy),
            onChanged: (kind) {
              if (kind == null) return;
              onChanged(
                unit.copyWith(
                  strategy: _defaultStrategyFor(l10n, kind, unit.strategy),
                ),
              );
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
          _buildStrategyFields(
            unit.strategy,
            (s) => onChanged(unit.copyWith(strategy: s)),
          ),
        ],
      ),
    );
  }

  String _strategyLabel(RentalStrategyKind kind) => switch (kind) {
    RentalStrategyKind.longTerm => l10n.simulations_estimation_strategy_long_term,
    RentalStrategyKind.shortTerm => l10n.simulations_estimation_strategy_short_term,
    RentalStrategyKind.seasonalMix => l10n.simulations_estimation_strategy_seasonal_mix,
    RentalStrategyKind.colocation => l10n.simulations_estimation_strategy_colocation,
  };

  static RentalStrategy _defaultStrategyFor(
    AppLocalizations l10n,
    RentalStrategyKind kind,
    RentalStrategy current,
  ) => switch (kind) {
    RentalStrategyKind.longTerm => RentalStrategy.longTerm(
      monthlyRent: current.monthlyRent ?? 500,
    ),
    RentalStrategyKind.shortTerm => RentalStrategy.shortTerm(
      nightlyRate: current.nightlyRate ?? 70,
      occupancyRatePercent: current.occupancyRatePercent ?? 60,
    ),
    RentalStrategyKind.seasonalMix => RentalStrategy.seasonalMix(
      longTermMonths: current.longTermMonths ?? 9,
      longTermMonthlyRent: current.longTermMonthlyRent ?? 500,
      shortTermMonths: current.shortTermMonths ?? 3,
      shortTermNightlyRate: current.shortTermNightlyRate ?? 80,
      shortTermOccupancyRatePercent:
          current.shortTermOccupancyRatePercent ?? 60,
    ),
    RentalStrategyKind.colocation => RentalStrategy.colocation(
      rooms: current.rooms.isEmpty
          ? [
              RentalRoom(
                label: l10n.simulations_estimation_room_default_label,
                monthlyRent: 450,
              ),
            ]
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
          label: l10n.simulations_estimation_field_monthly_rent,
          value: strategy.monthlyRent ?? 0,
          onChanged: (v) =>
              onStrategyChanged(RentalStrategy.longTerm(monthlyRent: v)),
        );
      case RentalStrategyKind.shortTerm:
        return Row(
          children: [
            Expanded(
              child: _CompactNumberField(
                label: l10n.simulations_estimation_field_nightly_rate,
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
                label: l10n.simulations_estimation_field_occupancy,
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
                    label: l10n.simulations_estimation_field_long_term_months,
                    value: (strategy.longTermMonths ?? 0).toDouble(),
                    onChanged: (v) => onStrategyChanged(
                      RentalStrategy.seasonalMix(
                        longTermMonths: v.round(),
                        longTermMonthlyRent:
                            strategy.longTermMonthlyRent ?? 500,
                        shortTermMonths: strategy.shortTermMonths ?? 3,
                        shortTermNightlyRate:
                            strategy.shortTermNightlyRate ?? 80,
                        shortTermOccupancyRatePercent:
                            strategy.shortTermOccupancyRatePercent ?? 60,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactNumberField(
                    label: l10n.simulations_estimation_field_long_term_rent,
                    value: strategy.longTermMonthlyRent ?? 0,
                    onChanged: (v) => onStrategyChanged(
                      RentalStrategy.seasonalMix(
                        longTermMonths: strategy.longTermMonths ?? 9,
                        longTermMonthlyRent: v,
                        shortTermMonths: strategy.shortTermMonths ?? 3,
                        shortTermNightlyRate:
                            strategy.shortTermNightlyRate ?? 80,
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
                    label: l10n.simulations_estimation_field_short_term_months,
                    value: (strategy.shortTermMonths ?? 0).toDouble(),
                    onChanged: (v) => onStrategyChanged(
                      RentalStrategy.seasonalMix(
                        longTermMonths: strategy.longTermMonths ?? 9,
                        longTermMonthlyRent:
                            strategy.longTermMonthlyRent ?? 500,
                        shortTermMonths: v.round(),
                        shortTermNightlyRate:
                            strategy.shortTermNightlyRate ?? 80,
                        shortTermOccupancyRatePercent:
                            strategy.shortTermOccupancyRatePercent ?? 60,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactNumberField(
                    label: l10n.simulations_estimation_field_summer_nightly_rate,
                    value: strategy.shortTermNightlyRate ?? 0,
                    onChanged: (v) => onStrategyChanged(
                      RentalStrategy.seasonalMix(
                        longTermMonths: strategy.longTermMonths ?? 9,
                        longTermMonthlyRent:
                            strategy.longTermMonthlyRent ?? 500,
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
                          onStrategyChanged(
                            RentalStrategy.colocation(rooms: rooms),
                          );
                        },
                      ),
                    ),
                    if (strategy.rooms.length > 1)
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 12),
                        onPressed: () {
                          final rooms = [...strategy.rooms]..removeAt(i);
                          onStrategyChanged(
                            RentalStrategy.colocation(rooms: rooms),
                          );
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
                    label: l10n.simulations_estimation_room_number(strategy.rooms.length + 1),
                    monthlyRent: 450,
                  ),
                ];
                onStrategyChanged(RentalStrategy.colocation(rooms: rooms));
              },
              child: shadcn.Text(l10n.simulations_estimation_add_room),
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
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
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
  const _StatChip({
    required this.label,
    required this.value,
    required this.accent,
  });

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
                style: const TextStyle(
                  fontSize: 20,
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

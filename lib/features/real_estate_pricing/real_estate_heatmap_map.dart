import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/money_format.dart';
import '../../l10n/app_localizations.dart';
import 'commune_boundaries_client.dart';
import 'commune_boundaries_repository.dart';
import 'department_boundaries_client.dart';
import 'department_boundaries_repository.dart';
import 'dvf_department_cache_repository.dart';
import 'geo_dvf_client.dart';
import 'price_estimator.dart' show PropertyTypeFilter;
import 'real_estate_address_picker.dart' show RealEstateAddressPickerController;
import 'real_estate_heatmap_data.dart';
import 'rent_price_client.dart';
import 'rent_price_repository.dart';

/// Métrique affichée par [RealEstateHeatmapMap].
enum HeatmapMetric { pricePerSqm, rentPerSqm }

/// Palier de granularité affiché, dérivé du zoom courant (voir
/// [_communeMinZoom]/[_gridMinZoom]) — du plus large au plus fin.
enum _Tier { department, commune, grid }

/// Bornes de référence du dégradé vert → rouge (voir
/// [heatmapColorFor]) — fixes plutôt que calculées sur les valeurs du jour,
/// pour rester lisibles d'un chargement à l'autre.
const _priceGreenAt = 1000.0;
const _priceRedAt = 8000.0;
const _rentGreenAt = 8.0;
const _rentRedAt = 25.0;

/// Centre approximatif de la France métropolitaine.
const _franceCenter = LatLng(46.6, 2.4);

/// Zoom appliqué quand une adresse est sélectionnée — assez proche pour
/// situer le marqueur, déjà dans la plage du palier Commune (voir
/// [_communeMinZoom]) pour afficher directement une granularité utile
/// autour de l'adresse choisie.
const _addressZoom = 10.0;

/// Zoom à partir duquel le palier Commune remplace le palier Département,
/// et à partir duquel le palier Grille (le plus fin, prix de vente
/// uniquement) remplace à son tour le palier Commune.
const _communeMinZoom = 9.0;
const _gridMinZoom = 13.0;

/// Côté approximatif (mètres) d'une cellule de la grille fine — voir
/// [aggregateGridSalePrices].
const _gridCellSizeMeters = 150.0;

/// Carte de chaleur nationale (prix de vente ou loyer au m²) — [metric] est
/// piloté par l'appelant (voir `real_estate_estimation_screen.dart`,
/// sélecteur "Prix au m² / Loyer au m²"), tout comme [propertyType] (piloté
/// par le même sélecteur "Type de bien" que le reste de l'onglet, pas un
/// second dans cette carte). Un marqueur pour l'adresse en cours de
/// [addressController] (recherche toujours visible au-dessus de la carte,
/// voir l'écran appelant) est superposé au dégradé si une adresse a été
/// choisie.
///
/// La granularité affichée s'adapte au zoom courant (voir [_Tier]) :
/// département en vue nationale/régionale, commune en vue ville, grille fine
/// (résolution native des ventes DVF, pas de source de données
/// supplémentaire) en vue rue — le loyer, dont la commune est déjà la
/// granularité native de la source (`rent_price_client.dart`), reste au
/// palier Commune même au zoom le plus serré, sans grille.
///
/// Le loyer est quasi instantané (deux fichiers nationaux déjà en cache
/// après le premier chargement, voir `rent_price_repository.dart`) ; le prix
/// de vente nécessite jusqu'à une centaine de requêtes (une par département,
/// voir `GeoDvfClient.fetchDepartment`), lancées par lots en parallèle et
/// mises en cache (`DvfDepartmentCacheRepository`) — seul le tout premier
/// chargement est lent, y compris pour zoomer ensuite sur les paliers
/// Commune/Grille (qui relisent ce même cache, aucun appel réseau
/// supplémentaire hormis les frontières communales, elles aussi mises en
/// cache par département).
class RealEstateHeatmapMap extends StatefulWidget {
  final String vaultPath;
  final HeatmapMetric metric;
  final PropertyTypeFilter propertyType;
  final RealEstateAddressPickerController addressController;

  const RealEstateHeatmapMap({
    super.key,
    required this.vaultPath,
    required this.metric,
    required this.propertyType,
    required this.addressController,
  });

  @override
  State<RealEstateHeatmapMap> createState() => _RealEstateHeatmapMapState();
}

class _RealEstateHeatmapMapState extends State<RealEstateHeatmapMap> {
  static const _batchSize = 10;

  late final DepartmentBoundariesService _boundariesService =
      DepartmentBoundariesService(
        client: DepartmentBoundariesClient(),
        cache: DepartmentBoundariesRepository(widget.vaultPath),
      );
  late final CommuneBoundariesService _communeBoundariesService =
      CommuneBoundariesService(
        client: CommuneBoundariesClient(),
        cache: CommuneBoundariesRepository(widget.vaultPath),
      );
  late final GeoDvfClient _dvfClient = GeoDvfClient();
  late final DvfDepartmentCacheRepository _dvfDeptCache =
      DvfDepartmentCacheRepository(widget.vaultPath);
  late final RentPriceRepository _rentCache = RentPriceRepository(widget.vaultPath);
  late final RentPriceService _rentService = RentPriceService(
    client: RentPriceClient(),
    cache: _rentCache,
  );

  final MapController _mapController = MapController();
  StreamSubscription<MapEvent>? _mapEventSub;
  Timer? _viewportDebounce;

  final LayerHitNotifier<String> _deptHitNotifier = ValueNotifier(null);
  final LayerHitNotifier<String> _communeHitNotifier = ValueNotifier(null);
  final LayerHitNotifier<String> _gridHitNotifier = ValueNotifier(null);

  List<DepartmentBoundary>? _boundaries;
  final Map<String, LatLngBounds> _deptBoundsCache = {};
  Map<String, double> _values = {};
  bool _loadingBoundaries = true;
  bool _loadingValues = false;
  int _loadedCount = 0;
  int _totalCount = 0;
  String? _selectedDeptCode;
  LatLng? _lastKnownMarker;

  _Tier _tier = _Tier.department;
  final Map<String, List<CommuneBoundary>> _communeBoundariesByDept = {};
  final Set<String> _loadingCommuneDepts = {};
  Map<String, double> _communeValues = {};
  String? _selectedCommuneCode;

  /// Table nationale des loyers déjà chargée par [_loadValues] (palier
  /// Département) — retenue ici (pas seulement agrégée par département) car
  /// le palier Commune y lit directement, sans nouvelle requête (le loyer
  /// est déjà à sa granularité communale native).
  Map<String, RentEstimate>? _nationalRentTable;

  Map<String, GridCell> _gridCells = {};
  bool _loadingGrid = false;
  String? _selectedGridCellKey;

  /// Requête en cours : ignore une réponse devenue obsolète si la métrique
  /// change avant la fin du chargement précédent.
  int _loadEpoch = 0;

  @override
  void initState() {
    super.initState();
    _lastKnownMarker = widget.addressController.marker;
    _deptHitNotifier.addListener(_onDeptHit);
    _communeHitNotifier.addListener(_onCommuneHit);
    _gridHitNotifier.addListener(_onGridHit);
    widget.addressController.addListener(_onAddressChanged);
    _mapEventSub = _mapController.mapEventStream.listen(_onMapEvent);
    _loadBoundaries();
  }

  @override
  void didUpdateWidget(covariant RealEstateHeatmapMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metric != widget.metric ||
        oldWidget.propertyType != widget.propertyType) {
      _loadValues();
      setState(() {
        _communeBoundariesByDept.clear();
        _communeValues = {};
        _loadingCommuneDepts.clear();
        _gridCells = {};
      });
      if (_tier != _Tier.department) _onViewportSettled();
    }
    if (oldWidget.addressController != widget.addressController) {
      oldWidget.addressController.removeListener(_onAddressChanged);
      widget.addressController.addListener(_onAddressChanged);
    }
  }

  @override
  void dispose() {
    _viewportDebounce?.cancel();
    _mapEventSub?.cancel();
    _deptHitNotifier.removeListener(_onDeptHit);
    _deptHitNotifier.dispose();
    _communeHitNotifier.removeListener(_onCommuneHit);
    _communeHitNotifier.dispose();
    _gridHitNotifier.removeListener(_onGridHit);
    _gridHitNotifier.dispose();
    widget.addressController.removeListener(_onAddressChanged);
    super.dispose();
  }

  void _onAddressChanged() {
    final marker = widget.addressController.marker;
    if (marker == _lastKnownMarker) return;
    _lastKnownMarker = marker;
    if (marker != null) _mapController.move(marker, _addressZoom);
    if (mounted) setState(() {});
  }

  /// Un événement de la carte (pan, zoom molette, animation...) peut en
  /// déclencher beaucoup en rafale pendant un geste — un simple debounce
  /// (même principe que `RealEstateAddressPickerController.onQueryChanged`)
  /// attend que la vue se stabilise avant de recalculer le palier et de
  /// lancer d'éventuels chargements, plutôt que de le faire à chaque frame.
  void _onMapEvent(MapEvent event) {
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 350), _onViewportSettled);
  }

  void _onViewportSettled() {
    if (!mounted || _boundaries == null || _boundaries!.isEmpty) return;
    final zoom = _mapController.camera.zoom;
    final newTier = zoom >= _gridMinZoom
        ? _Tier.grid
        : zoom >= _communeMinZoom
            ? _Tier.commune
            : _Tier.department;
    if (newTier != _tier) setState(() => _tier = newTier);
    if (newTier == _Tier.department) return;

    final visibleBounds = _mapController.camera.visibleBounds;
    final visibleDeptCodes = [
      for (final boundary in _boundaries!)
        if ((_deptBoundsCache[boundary.code] ??= _boundsFor(boundary))
            .isOverlapping(visibleBounds))
          boundary.code,
    ];
    if (newTier == _Tier.commune) {
      unawaited(_loadCommuneTierData(visibleDeptCodes));
    } else {
      unawaited(_loadGridTierData(visibleDeptCodes, visibleBounds));
    }
  }

  static LatLngBounds _boundsFor(DepartmentBoundary boundary) =>
      LatLngBounds.fromPoints([for (final ring in boundary.polygons) ...ring]);

  void _onDeptHit() {
    final result = _deptHitNotifier.value;
    setState(() {
      _selectedDeptCode = result == null || result.hitValues.isEmpty
          ? null
          : result.hitValues.first;
    });
  }

  void _onCommuneHit() {
    final result = _communeHitNotifier.value;
    setState(() {
      _selectedCommuneCode = result == null || result.hitValues.isEmpty
          ? null
          : result.hitValues.first;
    });
  }

  void _onGridHit() {
    final result = _gridHitNotifier.value;
    setState(() {
      _selectedGridCellKey = result == null || result.hitValues.isEmpty
          ? null
          : result.hitValues.first;
    });
  }

  Future<void> _loadBoundaries() async {
    final boundaries = await _boundariesService.load();
    if (!mounted) return;
    setState(() {
      _boundaries = boundaries ?? const [];
      _loadingBoundaries = false;
    });
    unawaited(_loadValues());
  }

  Future<void> _loadValues() async {
    final boundaries = _boundaries;
    if (boundaries == null || boundaries.isEmpty) return;
    final epoch = ++_loadEpoch;
    setState(() {
      _loadingValues = true;
      _values = {};
      _loadedCount = 0;
      _totalCount = widget.metric == HeatmapMetric.pricePerSqm ? boundaries.length : 0;
    });

    if (widget.metric == HeatmapMetric.rentPerSqm) {
      final type = widget.propertyType == PropertyTypeFilter.maison
          ? RentPropertyType.maison
          : RentPropertyType.appartement;
      final table = await _rentService.loadNational(type);
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _nationalRentTable = table;
        _values = table == null ? {} : aggregateDepartmentRents(table);
        _loadingValues = false;
      });
      return;
    }

    final year = DateTime.now().year - 1;
    final codes = [for (final b in boundaries) b.code];
    final result = <String, double>{};
    for (var i = 0; i < codes.length; i += _batchSize) {
      if (epoch != _loadEpoch) return;
      final batch = codes.skip(i).take(_batchSize);
      final entries = await Future.wait([
        for (final code in batch) _fetchDepartmentPrice(code, year),
      ]);
      if (!mounted || epoch != _loadEpoch) return;
      for (final entry in entries) {
        if (entry.value != null) result[entry.key] = entry.value!;
      }
      setState(() {
        _values = {...result};
        _loadedCount += batch.length;
      });
    }
    if (!mounted || epoch != _loadEpoch) return;
    setState(() => _loadingValues = false);
  }

  Future<MapEntry<String, double?>> _fetchDepartmentPrice(
    String deptCode,
    int year,
  ) async {
    final sales = await _loadDepartmentSales(deptCode, year);
    if (sales == null) return MapEntry(deptCode, null);
    return MapEntry(deptCode, aggregateDepartmentSalePrice(sales, widget.propertyType));
  }

  /// Ventes DVF d'un département — lit d'abord le cache disque
  /// ([DvfDepartmentCacheRepository], persistant entre deux montages de ce
  /// widget), ne télécharge que si absent. Point d'entrée unique réutilisé
  /// par le palier Département (agrégat immédiat, ventes brutes non
  /// conservées en mémoire) et par les paliers Commune/Grille (qui relisent
  /// ce même cache pour les départements visibles, sans nouvel appel
  /// réseau).
  Future<List<DvfSale>?> _loadDepartmentSales(String deptCode, int year) async {
    final cached = await _dvfDeptCache.load(deptCode, year);
    if (cached != null) return cached;
    final fetched = await _dvfClient.fetchDepartment(deptCode: deptCode, year: year);
    if (fetched == null) return null;
    await _dvfDeptCache.save(deptCode, year, fetched);
    return fetched;
  }

  /// Charge les frontières et valeurs communales des départements visibles
  /// non encore chargés/en cours de chargement — un département à la fois,
  /// le nombre de départements visibles à ce niveau de zoom restant faible
  /// (typiquement 1 à 4).
  Future<void> _loadCommuneTierData(List<String> deptCodes) async {
    final year = DateTime.now().year - 1;
    for (final deptCode in deptCodes) {
      if (_communeBoundariesByDept.containsKey(deptCode) ||
          _loadingCommuneDepts.contains(deptCode)) {
        continue;
      }
      if (!mounted) return;
      setState(() => _loadingCommuneDepts.add(deptCode));

      final boundaries = await _communeBoundariesService.loadForDepartment(deptCode);
      final communeValues = <String, double>{};
      if (widget.metric == HeatmapMetric.pricePerSqm) {
        final sales = await _loadDepartmentSales(deptCode, year);
        if (sales != null) {
          communeValues.addAll(aggregateCommuneSalePrices(sales, widget.propertyType));
        }
      } else {
        final table = _nationalRentTable;
        if (table != null && boundaries != null) {
          for (final commune in boundaries) {
            final estimate = table[commune.code];
            if (estimate != null) communeValues[commune.code] = estimate.loyerPredM2;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _loadingCommuneDepts.remove(deptCode);
        if (boundaries != null) _communeBoundariesByDept[deptCode] = boundaries;
        _communeValues = {..._communeValues, ...communeValues};
      });
    }
  }

  /// Palier le plus fin : recalcule la grille sur les ventes déjà en cache
  /// des départements visibles — pas de granularité plus fine que la
  /// commune pour le loyer (voir la documentation de [RealEstateHeatmapMap]),
  /// cette méthode n'a donc d'effet que pour le prix de vente.
  Future<void> _loadGridTierData(
    List<String> deptCodes,
    LatLngBounds visibleBounds,
  ) async {
    if (widget.metric != HeatmapMetric.pricePerSqm) return;
    if (!mounted) return;
    setState(() => _loadingGrid = true);
    final year = DateTime.now().year - 1;
    final allSales = <DvfSale>[];
    for (final deptCode in deptCodes) {
      final sales = await _loadDepartmentSales(deptCode, year);
      if (sales != null) allSales.addAll(sales);
    }
    if (!mounted) return;
    setState(() {
      _gridCells = aggregateGridSalePrices(
        allSales,
        widget.propertyType,
        cellSizeMeters: _gridCellSizeMeters,
        referenceLatitude: (visibleBounds.north + visibleBounds.south) / 2,
      );
      _loadingGrid = false;
    });
  }

  /// Palier effectivement rendu — le loyer n'a pas de palier Grille (la
  /// commune est déjà sa granularité native), donc reste au palier Commune
  /// même si le zoom courant appellerait une grille pour le prix.
  _Tier get _renderTier =>
      _tier == _Tier.grid && widget.metric == HeatmapMetric.rentPerSqm
          ? _Tier.commune
          : _tier;

  (double, double) get _colorBounds => widget.metric == HeatmapMetric.pricePerSqm
      ? (_priceGreenAt, _priceRedAt)
      : (_rentGreenAt, _rentRedAt);

  String _formatValue(double value) => widget.metric == HeatmapMetric.pricePerSqm
      ? '${formatEuros(value)}/m²'
      : '${value.toStringAsFixed(1)} €/m²';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final marker = widget.addressController.marker;
    final renderTier = _renderTier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingValues && widget.metric == HeatmapMetric.pricePerSqm) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _totalCount == 0 ? null : _loadedCount / _totalCount,
          ),
          const SizedBox(height: 4),
          shadcn.Text(
            l10n.real_estate_pricing_heatmap_loading_department_prices(
              _loadedCount,
              _totalCount,
            ),
          ).muted().xSmall(),
        ],
        if (renderTier == _Tier.commune && _loadingCommuneDepts.isNotEmpty) ...[
          const SizedBox(height: 8),
          shadcn.Text(
            l10n.real_estate_pricing_heatmap_loading_communes,
          ).muted().xSmall(),
        ],
        if (renderTier == _Tier.grid && _loadingGrid) ...[
          const SizedBox(height: 8),
          shadcn.Text(
            l10n.real_estate_pricing_heatmap_loading_grid,
          ).muted().xSmall(),
        ],
        if (_tier == _Tier.grid && widget.metric == HeatmapMetric.rentPerSqm) ...[
          const SizedBox(height: 8),
          shadcn.Text(
            l10n.real_estate_pricing_heatmap_rent_commune_only,
          ).muted().xSmall(),
        ],
        const SizedBox(height: 10),
        _buildLegend(theme),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 420,
            child: Stack(
              children: [
                _loadingBoundaries
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: marker ?? _franceCenter,
                          initialZoom: marker != null ? _addressZoom : 5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.opime.app',
                          ),
                          PolygonLayer<String>(
                            hitNotifier: _deptHitNotifier,
                            polygons: [
                              for (final boundary in _boundaries ?? const [])
                                for (final ring in boundary.polygons)
                                  Polygon<String>(
                                    points: ring,
                                    color: _colorForDept(boundary.code),
                                    borderStrokeWidth: 0.5,
                                    borderColor: theme.colorScheme.background,
                                    hitValue: boundary.code,
                                  ),
                            ],
                          ),
                          if (renderTier == _Tier.commune)
                            PolygonLayer<String>(
                              hitNotifier: _communeHitNotifier,
                              polygons: [
                                for (final communes in _communeBoundariesByDept.values)
                                  for (final commune in communes)
                                    for (final ring in commune.polygons)
                                      Polygon<String>(
                                        points: ring,
                                        color: _colorForCommune(commune.code),
                                        borderStrokeWidth: 0.4,
                                        borderColor: theme.colorScheme.background,
                                        hitValue: commune.code,
                                      ),
                              ],
                            ),
                          if (renderTier == _Tier.grid)
                            PolygonLayer<String>(
                              hitNotifier: _gridHitNotifier,
                              polygons: [
                                for (final entry in _gridCells.entries)
                                  Polygon<String>(
                                    points: entry.value.corners,
                                    color: heatmapColorFor(
                                      entry.value.medianPricePerSqm,
                                      greenAt: _priceGreenAt,
                                      redAt: _priceRedAt,
                                    ).withValues(alpha: 0.75),
                                    borderStrokeWidth: 1,
                                    borderColor: theme.colorScheme.background,
                                    hitValue: entry.key,
                                  ),
                              ],
                            ),
                          RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                                onTap: () {},
                              ),
                            ],
                          ),
                          if (marker != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: marker,
                                  width: 32,
                                  height: 32,
                                  child: Icon(
                                    LucideIcons.mapPin,
                                    color: theme.colorScheme.primary,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                _buildTooltip(theme, l10n, renderTier),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _colorForDept(String deptCode) {
    final value = _values[deptCode];
    if (value == null) return const Color(0xFFD1D5DB); // gris : pas de donnée
    final (greenAt, redAt) = _colorBounds;
    return heatmapColorFor(value, greenAt: greenAt, redAt: redAt).withValues(alpha: 0.75);
  }

  Color _colorForCommune(String communeCode) {
    final value = _communeValues[communeCode];
    if (value == null) return const Color(0xFFD1D5DB);
    final (greenAt, redAt) = _colorBounds;
    return heatmapColorFor(value, greenAt: greenAt, redAt: redAt).withValues(alpha: 0.75);
  }

  Widget _buildLegend(ThemeData theme) {
    final (greenAt, redAt) = _colorBounds;
    return Row(
      children: [
        shadcn.Text(_formatValue(greenAt)).muted().xSmall(),
        const SizedBox(width: 6),
        Container(
          width: 140,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFFEAB308), Color(0xFFEF4444)],
            ),
          ),
        ),
        const SizedBox(width: 6),
        shadcn.Text('> ${_formatValue(redAt)}').muted().xSmall(),
      ],
    );
  }

  /// Tooltip du dernier élément touché — priorité au palier le plus fin
  /// actuellement rendu (grille > commune > département), plutôt qu'au
  /// dernier événement de tap toutes couches confondues (la couche
  /// Département reste toujours montée en-dessous, voir [build]).
  Widget _buildTooltip(ThemeData theme, AppLocalizations l10n, _Tier renderTier) {
    if (renderTier == _Tier.grid && _selectedGridCellKey != null) {
      final cell = _gridCells[_selectedGridCellKey];
      if (cell != null) {
        return _tooltipCard(
          theme,
          title: l10n.real_estate_pricing_heatmap_neighborhood_tooltip_title(
            _gridCellSizeMeters.round(),
          ),
          value: _formatValue(cell.medianPricePerSqm),
          subtitle: l10n.real_estate_pricing_heatmap_sale_count(cell.sampleSize),
        );
      }
    }
    if (renderTier == _Tier.commune && _selectedCommuneCode != null) {
      final code = _selectedCommuneCode!;
      final commune = _communeBoundariesByDept.values
          .expand((communes) => communes)
          .where((c) => c.code == code)
          .firstOrNull;
      final value = _communeValues[code];
      return _tooltipCard(
        theme,
        title: commune?.name ?? code,
        value: value == null
            ? l10n.real_estate_pricing_heatmap_no_data
            : _formatValue(value),
      );
    }
    if (_selectedDeptCode != null) {
      final code = _selectedDeptCode!;
      final boundary = (_boundaries ?? const []).where((b) => b.code == code).firstOrNull;
      final value = _values[code];
      return _tooltipCard(
        theme,
        title: boundary?.name ?? code,
        value: value == null
            ? l10n.real_estate_pricing_heatmap_no_data
            : _formatValue(value),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _tooltipCard(
    ThemeData theme, {
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Positioned(
      top: 8,
      left: 8,
      child: SurfaceCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              shadcn.Text(title).semiBold().small(),
              shadcn.Text(value).muted().xSmall(),
              if (subtitle != null) shadcn.Text(subtitle).muted().xSmall(),
            ],
          ),
        ),
      ),
    );
  }
}

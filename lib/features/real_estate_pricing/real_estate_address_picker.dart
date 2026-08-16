import 'dart:async' show Timer;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import 'ban_client.dart';

/// Adresse retenue par [RealEstateAddressPickerController] — sous-ensemble
/// de [BanAddressSuggestion] utile aux appelants (l'estimation de prix n'a
/// besoin que du code commune et des coordonnées, voir
/// `real_estate_price_service.dart`).
class RealEstateAddressPickResult {
  final String label;
  final double lat;
  final double lon;
  final String cityCode;

  const RealEstateAddressPickResult({
    required this.label,
    required this.lat,
    required this.lon,
    required this.cityCode,
  });
}

/// Centre de la France métropolitaine — position par défaut de la carte tant
/// qu'aucune adresse n'a été choisie.
const _defaultCenter = LatLng(46.6, 2.4);

/// Source unique de vérité partagée entre [RealEstateAddressSearchField] et
/// [RealEstateAddressMap] — un champ de recherche et une carte peuvent ainsi
/// rester synchronisés (recherche → carte, clic carte → champ) sans être
/// imbriqués dans un seul widget, pour permettre de les positionner
/// indépendamment (voir `real_estate_estimation_screen.dart`, où la
/// recherche reste affichée en permanence au-dessus de la zone carte, quel
/// que soit le mode d'affichage de celle-ci).
class RealEstateAddressPickerController extends ChangeNotifier {
  final BanClient banClient;
  final TextEditingController textController;

  RealEstateAddressPickerController({
    BanClient? banClient,
    RealEstateAddressPickResult? initialValue,
  }) : banClient = banClient ?? BanClient(),
       textController = TextEditingController(text: initialValue?.label ?? ''),
       _marker = initialValue == null
           ? null
           : LatLng(initialValue.lat, initialValue.lon);

  /// Appelé à chaque adresse retenue (sélection d'une suggestion ou clic
  /// carte suivi d'un géocodage inverse réussi).
  ValueChanged<RealEstateAddressPickResult>? onChanged;

  Timer? _debounce;
  List<BanAddressSuggestion> suggestions = const [];
  bool searching = false;
  LatLng? _marker;
  LatLng? get marker => _marker;

  /// Évite qu'une mise à jour programmatique du champ (après sélection ou
  /// clic carte) relance une recherche sur le libellé qu'on vient d'y
  /// écrire soi-même.
  bool _suppressNextQueryChange = false;

  void _setTextSilently(String text) {
    _suppressNextQueryChange = true;
    textController.text = text;
  }

  void onQueryChanged(String text) {
    if (_suppressNextQueryChange) {
      _suppressNextQueryChange = false;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(text));
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      suggestions = const [];
      notifyListeners();
      return;
    }
    searching = true;
    notifyListeners();
    final results = await banClient.search(query);
    searching = false;
    suggestions = results ?? const [];
    notifyListeners();
  }

  void selectSuggestion(BanAddressSuggestion suggestion) {
    _setTextSilently(suggestion.label);
    _marker = LatLng(suggestion.lat, suggestion.lon);
    suggestions = const [];
    notifyListeners();
    onChanged?.call(
      RealEstateAddressPickResult(
        label: suggestion.label,
        lat: suggestion.lat,
        lon: suggestion.lon,
        cityCode: suggestion.cityCode,
      ),
    );
  }

  /// Restaure une adresse déjà connue (ex : rechargée depuis
  /// `SimulationStateRepository`) sans redéclencher de recherche ni
  /// notifier [onChanged] (qui persisterait inutilement une valeur qui
  /// vient justement d'en être relue).
  void setAddressSilently(RealEstateAddressPickResult value) {
    _setTextSilently(value.label);
    _marker = LatLng(value.lat, value.lon);
    notifyListeners();
  }

  Future<void> handleMapTap(LatLng point) async {
    _marker = point;
    notifyListeners();
    final suggestion = await banClient.reverseGeocode(
      lat: point.latitude,
      lon: point.longitude,
    );
    if (suggestion == null) return;
    _setTextSilently(suggestion.label);
    notifyListeners();
    onChanged?.call(
      RealEstateAddressPickResult(
        label: suggestion.label,
        lat: suggestion.lat,
        lon: suggestion.lon,
        cityCode: suggestion.cityCode,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    textController.dispose();
    super.dispose();
  }
}

/// Champ de recherche d'adresse (auto-complétion BAN) — n'affiche aucune
/// carte, pour pouvoir rester visible en permanence au-dessus d'une zone
/// carte dont le contenu peut changer (voir [RealEstateAddressPickerController]).
class RealEstateAddressSearchField extends StatelessWidget {
  final RealEstateAddressPickerController controller;

  const RealEstateAddressSearchField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller.textController,
              placeholder: const shadcn.Text('Rechercher une adresse...'),
              onChanged: controller.onQueryChanged,
              features: [
                InputFeature.leading(
                  Icon(
                    LucideIcons.mapPin,
                    size: 16,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                InputFeature.clear(),
              ],
            ),
            if (controller.searching)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(),
              ),
            if (controller.suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: controller.suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = controller.suggestions[index];
                    return Clickable(
                      onPressed: () => controller.selectSuggestion(suggestion),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: shadcn.Text(
                          suggestion.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ).small(),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Carte 2D interactive (tuiles OpenStreetMap) centrée sur l'adresse en
/// cours de [RealEstateAddressPickerController] — un clic sur la carte
/// déclenche un géocodage inverse qui met à jour le contrôleur partagé
/// (donc, entre autres, [RealEstateAddressSearchField] s'il est affiché à
/// côté).
class RealEstateAddressMap extends StatefulWidget {
  final RealEstateAddressPickerController controller;
  final double mapHeight;

  const RealEstateAddressMap({
    super.key,
    required this.controller,
    this.mapHeight = 260,
  });

  @override
  State<RealEstateAddressMap> createState() => _RealEstateAddressMapState();
}

class _RealEstateAddressMapState extends State<RealEstateAddressMap> {
  final MapController _mapController = MapController();
  LatLng? _lastKnownMarker;

  @override
  void initState() {
    super.initState();
    _lastKnownMarker = widget.controller.marker;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final marker = widget.controller.marker;
    if (marker != _lastKnownMarker) {
      _lastKnownMarker = marker;
      if (marker != null) _mapController.move(marker, 15);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marker = widget.controller.marker;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: widget.mapHeight,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: marker ?? _defaultCenter,
            initialZoom: marker != null ? 15 : 5,
            onTap: (tapPosition, point) => widget.controller.handleMapTap(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.opime.app',
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
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
      ),
    );
  }
}

/// Sélecteur d'adresse combinant recherche et carte, empilées — pour les
/// usages compacts (ex : `investment_reestimate_dialog.dart`) où les deux
/// n'ont pas besoin d'être positionnées indépendamment. Crée et possède son
/// propre [RealEstateAddressPickerController] en interne.
class RealEstateAddressMapPicker extends StatefulWidget {
  final RealEstateAddressPickResult? initialValue;
  final ValueChanged<RealEstateAddressPickResult> onChanged;
  final BanClient? banClient;
  final double mapHeight;

  const RealEstateAddressMapPicker({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.banClient,
    this.mapHeight = 260,
  });

  @override
  State<RealEstateAddressMapPicker> createState() =>
      _RealEstateAddressMapPickerState();
}

class _RealEstateAddressMapPickerState
    extends State<RealEstateAddressMapPicker> {
  late final RealEstateAddressPickerController _controller =
      RealEstateAddressPickerController(
        banClient: widget.banClient,
        initialValue: widget.initialValue,
      )..onChanged = widget.onChanged;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RealEstateAddressSearchField(controller: _controller),
        const SizedBox(height: 10),
        RealEstateAddressMap(controller: _controller, mapHeight: widget.mapHeight),
      ],
    );
  }
}

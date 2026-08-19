import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/ui/frosted_card.dart';
import '../../core/ui/toggle_button_style.dart';
import '../real_estate_pricing/dvf_cache_repository.dart';
import '../real_estate_pricing/geo_dvf_client.dart';
import '../real_estate_pricing/price_estimator.dart';
import '../real_estate_pricing/real_estate_address_picker.dart';
import '../real_estate_pricing/real_estate_price_service.dart';
import 'investments_models.dart';

/// Ouvre le dialogue "Réestimer la valeur (€/m²)" d'un bien immobilier
/// détenu — réutilise le même pipeline que l'onglet Simulation > Estimation
/// (`real_estate_pricing/`, `real_estate_price_service.dart`). Action
/// explicite déclenchée par l'utilisateur uniquement : aucune estimation
/// n'est jamais faite automatiquement (voir `price_refresh_service.dart`,
/// qui exclut toujours `immobilier` du rafraîchissement global).
Future<void> showRealEstateReestimateDialog(
  BuildContext context, {
  required String vaultPath,
  required Investment investment,
  required ValueChanged<Investment> onEstimated,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ReestimateDialog(
      vaultPath: vaultPath,
      investment: investment,
      onEstimated: onEstimated,
    ),
  );
}

class _ReestimateDialog extends StatefulWidget {
  final String vaultPath;
  final Investment investment;
  final ValueChanged<Investment> onEstimated;

  const _ReestimateDialog({
    required this.vaultPath,
    required this.investment,
    required this.onEstimated,
  });

  @override
  State<_ReestimateDialog> createState() => _ReestimateDialogState();
}

class _ReestimateDialogState extends State<_ReestimateDialog> {
  late RealEstateAddressPickResult? _address = _initialAddress();
  late double _surfaceM2 = widget.investment.surfaceM2 ?? 0;
  PropertyTypeFilter _propertyType = PropertyTypeFilter.appartement;
  bool _loading = false;
  String? _error;

  RealEstateAddressPickResult? _initialAddress() {
    final investment = widget.investment;
    if (investment.addressCityCode == null ||
        investment.addressLat == null ||
        investment.addressLon == null) {
      return null;
    }
    return RealEstateAddressPickResult(
      label: investment.addressLabel ?? '',
      lat: investment.addressLat!,
      lon: investment.addressLon!,
      cityCode: investment.addressCityCode!,
    );
  }

  Future<void> _confirm() async {
    final address = _address;
    if (address == null || _surfaceM2 <= 0) {
      setState(() => _error = 'Renseigne une adresse et une surface.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final service = RealEstatePriceService(
      client: GeoDvfClient(),
      cache: DvfCacheRepository(widget.vaultPath),
    );
    final estimate = await service.estimate(
      citycode: address.cityCode,
      lat: address.lat,
      lon: address.lon,
      propertyType: _propertyType,
    );
    if (!mounted) return;
    if (estimate == null) {
      setState(() {
        _loading = false;
        _error = 'Aucune vente comparable trouvée pour cette adresse.';
      });
      return;
    }
    widget.onEstimated(
      widget.investment.copyWith(
        surfaceM2: _surfaceM2,
        addressLabel: address.label,
        addressCityCode: address.cityCode,
        addressLat: address.lat,
        addressLon: address.lon,
        estimatedPricePerSqm: estimate.medianPricePerSqm,
        estimatedValueAt: DateTime.now(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: shadcn.Text(
                          'Réestimer la valeur (€/m²)',
                        ).large().semiBold(),
                      ),
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RealEstateAddressMapPicker(
                    initialValue: _address,
                    onChanged: (result) => setState(() => _address = result),
                  ),
                  const SizedBox(height: 16),
                  ButtonGroup(
                    children: [
                      SelectedButton(
                        value: _propertyType == PropertyTypeFilter.maison,
                        selectedStyle: const ButtonStyle.primary(),
                        style: toggleUnselectedStyle(context),
                        onChanged: (_) => setState(
                          () => _propertyType = PropertyTypeFilter.maison,
                        ),
                        child: const shadcn.Text('Maison'),
                      ),
                      SelectedButton(
                        value: _propertyType == PropertyTypeFilter.appartement,
                        selectedStyle: const ButtonStyle.primary(),
                        style: toggleUnselectedStyle(context),
                        onChanged: (_) => setState(
                          () => _propertyType = PropertyTypeFilter.appartement,
                        ),
                        child: const shadcn.Text('Appartement'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  shadcn.Text('Surface (m²)').muted().small(),
                  const SizedBox(height: 6),
                  TextField(
                    controller: TextEditingController(
                      text: _surfaceM2 == 0
                          ? ''
                          : _surfaceM2.round().toString(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (text) {
                      final parsed = double.tryParse(text.replaceAll(',', '.'));
                      if (parsed != null) _surfaceM2 = parsed;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    shadcn.Text(_error!).small(),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    onPressed: _loading ? null : _confirm,
                    leading: _loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.mapPin),
                    child: const shadcn.Text('Estimer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

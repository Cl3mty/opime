import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/simulations/simulation_state_repository.dart';
import 'real_estate_estimation_screen.dart';
import 'simulations_loan_screen.dart';

/// Onglet "Immobilier" de Simulation : regroupe "Estimation" et "Prêt" sous
/// un seul item de navigation, avec un `TabList` interne — même
/// fonctionnement que "Fiscalité" (IR/IFI, voir
/// `simulations_taxation_screen.dart`), plutôt que deux items de sidebar
/// séparés.
class RealEstateSimulationScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;

  const RealEstateSimulationScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<RealEstateSimulationScreen> createState() =>
      _RealEstateSimulationScreenState();
}

class _RealEstateSimulationScreenState
    extends State<RealEstateSimulationScreen> {
  int _tabIndex = 0;
  late final SimulationStateRepository _stateRepo;

  @override
  void initState() {
    super.initState();
    _stateRepo = SimulationStateRepository(widget.vaultPath);
    _loadState();
  }

  Future<void> _loadState() async {
    final data = await _stateRepo.read('immobilier');
    if (!mounted) return;
    setState(() {
      final tabValue = data['tabIndex'];
      if (tabValue is int) {
        _tabIndex = tabValue.clamp(0, 1);
      } else if (tabValue is num) {
        _tabIndex = tabValue.round().clamp(0, 1);
      }
    });
  }

  Future<void> _saveState() {
    return _stateRepo.write('immobilier', {'tabIndex': _tabIndex});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TabList(
                index: _tabIndex,
                onChanged: (value) {
                  setState(() => _tabIndex = value);
                  _saveState();
                },
                children: const [
                  TabItem(child: shadcn.Text('Estimation')),
                  TabItem(child: shadcn.Text('Prêt')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tabIndex == 0
                ? RealEstateEstimationScreen(
                    vaultPath: widget.vaultPath,
                    amountVisibility: widget.amountVisibility,
                  )
                : LoanSimulationScreen(
                    vaultPath: widget.vaultPath,
                    amountVisibility: widget.amountVisibility,
                  ),
          ),
        ],
      ),
    );
  }
}

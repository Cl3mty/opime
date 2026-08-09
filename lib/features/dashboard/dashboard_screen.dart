import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import 'dashboard_dummy_data.dart';
import 'widgets/patrimoine_card.dart';
import 'widgets/performance_card.dart';
import 'widgets/top_assets_row.dart';

/// Tableau de bord : patrimoine net (graphique + évolution), performance,
/// et meilleurs actifs — structure visuelle inspirée de Finary, sur des
/// données d'exemple ([dashboardSampleData]) en attendant le vrai module
/// Patrimoine (transactions, import, calcul de performance réel).
class DashboardScreen extends StatelessWidget {
  final AmountVisibilityController amountVisibility;

  const DashboardScreen({super.key, required this.amountVisibility});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: amountVisibility,
      builder: (context, _) {
        final hidden = amountVisibility.hidden;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 800;
              final patrimoineCard = PatrimoineCard(
                data: dashboardSampleData,
                hidden: hidden,
              );
              final performanceCard = PerformanceCard(
                data: dashboardSampleData,
              );

              final topRow = narrow
                  ? Column(
                      children: [
                        SizedBox(height: 420, child: patrimoineCard),
                        const SizedBox(height: 16),
                        SizedBox(height: 260, child: performanceCard),
                      ],
                    )
                  : SizedBox(
                      height: 420,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 2, child: patrimoineCard),
                          const SizedBox(width: 16),
                          Expanded(child: performanceCard),
                        ],
                      ),
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  topRow,
                  const SizedBox(height: 24),
                  TopAssetsRow(assets: dashboardSampleData.topAssets),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

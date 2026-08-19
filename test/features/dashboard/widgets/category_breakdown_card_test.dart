import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:opime/features/dashboard/widgets/category_breakdown_card.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  PatrimoineCategory category() => PatrimoineCategory(
    id: 'actifs_actions_fonds',
    label: 'Actions & Fonds',
    icon: LucideIcons.trendingUp,
    color: const Color(0xFF000000),
    tier: AllocationTier.fondation,
    description: '',
    accounts: const [
      PatrimoineAccount(
        id: 'acc-1',
        name: 'PEA Boursorama',
        valeur: 1000,
        plusValueAbs: 50,
        plusValuePercent: 5,
      ),
    ],
  );

  testWidgets('les catégories sont dépliées par défaut, sans avoir à cliquer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: CategoryBreakdownCard(
            title: 'Actifs',
            categories: [category()],
            hidden: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PEA Boursorama'), findsOneWidget);
  });

  testWidgets('cliquer le chevron replie la catégorie', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: CategoryBreakdownCard(
            title: 'Actifs',
            categories: [category()],
            hidden: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('PEA Boursorama'), findsOneWidget);

    // Le premier chevron trouvé est un clone invisible dans l'en-tête des
    // colonnes (`_HeaderRow`, `maintainState: true` pour réserver l'espace
    // sans afficher un vrai chevron) : le vrai bouton d'expansion est le
    // suivant.
    await tester.tap(find.byIcon(LucideIcons.chevronRight).last);
    await tester.pumpAndSettle();

    expect(find.text('PEA Boursorama'), findsNothing);
  });
}

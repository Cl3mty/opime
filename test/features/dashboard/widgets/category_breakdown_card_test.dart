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
            period: DashboardPeriod.all,
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
            period: DashboardPeriod.all,
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

  testWidgets(
    'un compte exclu du patrimoine global affiche le badge sous son nom',
    (tester) async {
      final excludedCategory = PatrimoineCategory(
        id: 'actifs_autres',
        label: 'Autres',
        icon: LucideIcons.gem,
        color: const Color(0xFF000000),
        tier: AllocationTier.opportuniste,
        description: '',
        accounts: const [
          PatrimoineAccount(
            id: 'acc-1',
            name: 'Montres',
            valeur: 1000,
            plusValueAbs: 50,
            plusValuePercent: 5,
            excludedFromPatrimoine: true,
          ),
        ],
      );

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryBreakdownCard(
              title: 'Actifs',
              categories: [excludedCategory],
              hidden: false,
              period: DashboardPeriod.all,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Montres'), findsOneWidget);
      expect(find.text('Hors patrimoine global'), findsOneWidget);
    },
  );

  group('bascule Par compte / Par investissement', () {
    PatrimoineCategory categoryByAccount() => PatrimoineCategory(
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

    PatrimoineCategory categoryByInvestment() => PatrimoineCategory(
      id: 'actifs_actions_fonds',
      label: 'Actions & Fonds',
      icon: LucideIcons.trendingUp,
      color: const Color(0xFF000000),
      tier: AllocationTier.fondation,
      description: '',
      accounts: const [
        PatrimoineAccount(
          id: 'inv-1',
          name: 'Amundi MSCI World',
          valeur: 600,
          plusValueAbs: 30,
          plusValuePercent: 5,
        ),
        PatrimoineAccount(
          id: 'inv-2',
          name: 'TotalEnergies',
          valeur: 400,
          plusValueAbs: 20,
          plusValuePercent: 5,
        ),
      ],
    );

    testWidgets(
      'sans categoriesByInvestment : pas de switch, vue par compte seule',
      (tester) async {
        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: CategoryBreakdownCard(
                title: 'Actifs',
                categories: [categoryByAccount()],
                hidden: false,
                period: DashboardPeriod.all,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Par compte'), findsNothing);
        expect(find.text('Par investissement'), findsNothing);
        expect(find.text('PEA Boursorama'), findsOneWidget);
      },
    );

    testWidgets(
      'avec categoriesByInvestment : le switch bascule entre les deux vues',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: CategoryBreakdownCard(
                title: 'Actifs',
                categories: [categoryByAccount()],
                categoriesByInvestment: [categoryByInvestment()],
                hidden: false,
                period: DashboardPeriod.all,
              ),
            ),
          ),
        );
        await tester.pump();

        // Par défaut : vue par compte.
        expect(find.text('PEA Boursorama'), findsOneWidget);
        expect(find.text('Amundi MSCI World'), findsNothing);

        await tester.tap(find.text('Par investissement'));
        await tester.pump();

        expect(find.text('PEA Boursorama'), findsNothing);
        expect(find.text('Amundi MSCI World'), findsOneWidget);
        expect(find.text('TotalEnergies'), findsOneWidget);

        await tester.tap(find.text('Par compte'));
        await tester.pump();

        expect(find.text('PEA Boursorama'), findsOneWidget);
        expect(find.text('Amundi MSCI World'), findsNothing);
      },
    );
  });

  group('colonnes Valeur/Évolution/+- value', () {
    testWidgets('l\'en-tête affiche "Valeur" (plus "Montant")', (
      tester,
    ) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryBreakdownCard(
              title: 'Actifs',
              categories: [category()],
              hidden: false,
              period: DashboardPeriod.all,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Valeur'), findsOneWidget);
      expect(find.text('Montant'), findsNothing);
      expect(find.text('+/- value'), findsOneWidget);
    });

    testWidgets(
      'les colonnes Évolution/+- value suivent la période passée en prop',
      (tester) async {
        final categoryWithPeriod = PatrimoineCategory(
          id: 'actifs_actions_fonds',
          label: 'Actions & Fonds',
          icon: LucideIcons.trendingUp,
          color: const Color(0xFF000000),
          tier: AllocationTier.fondation,
          description: '',
          accounts: [
            PatrimoineAccount(
              id: 'acc-1',
              name: 'PEA Boursorama',
              valeur: 1000,
              plusValueAbs: 50,
              plusValuePercent: 5,
              periodChangeFor: (period) => period == DashboardPeriod.all
                  ? (euros: 777.0, percent: 10.0)
                  : (euros: 222.0, percent: 2.0),
              periodPnlFor: (period) => period == DashboardPeriod.all
                  ? (euros: 888.0, percent: 8.0)
                  : (euros: 333.0, percent: 1.5),
            ),
          ],
        );

        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: CategoryBreakdownCard(
                title: 'Actifs',
                categories: [categoryWithPeriod],
                hidden: false,
                period: DashboardPeriod.all,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.textContaining('777'), findsWidgets);
        expect(find.textContaining('888'), findsWidgets);

        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: CategoryBreakdownCard(
                title: 'Actifs',
                categories: [categoryWithPeriod],
                hidden: false,
                period: DashboardPeriod.month1,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.textContaining('222'), findsWidgets);
        expect(find.textContaining('333'), findsWidgets);
      },
    );

    testWidgets(
      'une catégorie de passif (prêt) n\'affiche pas du tout la colonne '
      '"+/- value" — pas seulement des « — », la notion de performance '
      'hors flux n\'a pas de sens pour une dette',
      (tester) async {
        final liabilityCategory = PatrimoineCategory(
          id: 'passifs_prets_immobiliers',
          label: 'Prêts immobiliers',
          icon: LucideIcons.house,
          color: const Color(0xFF000000),
          tier: AllocationTier.croissance,
          description: '',
          accounts: const [
            PatrimoineAccount(
              id: 'loan-1',
              name: 'Prêt maison',
              valeur: 150000,
              plusValueAbs: -5000,
              plusValuePercent: -3.2,
            ),
          ],
        );

        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: CategoryBreakdownCard(
                title: 'Passifs',
                categories: [liabilityCategory],
                hidden: false,
                showPru: false,
                period: DashboardPeriod.all,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('+/- value'), findsNothing);
        expect(find.text('Évolution'), findsOneWidget);
      },
    );
  });
}

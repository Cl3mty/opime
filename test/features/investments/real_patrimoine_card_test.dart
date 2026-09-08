import 'package:flutter_test/flutter_test.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/core/money_format.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:opime/features/dashboard/widgets/patrimoine_chart_widgets.dart'
    show CategoryMultiSelect;
import 'package:opime/features/investments/real_patrimoine_card.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// [RealPatrimoineCard] ne fait plus aucune E/S depuis que sa période est
/// passée en prop contrôlée (`periodIndex`/`onPeriodChanged`, voir son
/// commentaire de classe) : contrairement à d'autres écrans du Dashboard,
/// aucun vault ni `tester.runAsync` n'est nécessaire ici — même principe que
/// `category_breakdown_card_test.dart`, qui teste un widget frère sans E/S.
void main() {
  PatrimoineCategory category({
    String id = 'actifs_actions_fonds',
    String label = 'Actions & Fonds',
    double montant = 1000,
  }) => PatrimoineCategory(
    id: id,
    label: label,
    // Volontairement distinct de `LucideIcons.trendingUp`/`trendingDown`
    // (utilisées par la ligne de variation) pour ne pas fausser les
    // assertions sur ces icônes.
    icon: LucideIcons.house,
    color: const Color(0xFF8B5CF6),
    tier: AllocationTier.fondation,
    description: '',
    accounts: [
      PatrimoineAccount(
        name: label,
        valeur: montant,
        plusValueAbs: 0,
        plusValuePercent: 0,
      ),
    ],
  );

  Widget buildCard({
    required List<PatrimoineCategory> actifs,
    Map<String, List<NetWorthPoint>> Function(DashboardPeriod)?
    actifsHistoryFor,
    List<NetWorthPoint> Function(DashboardPeriod)? totalPassifHistoryFor,
    int periodIndex = 5,
    ValueChanged<int>? onPeriodChanged,
  }) {
    return ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      
      home: Scaffold(
        child: RealPatrimoineCard(
          actifs: actifs,
          actifsHistoryFor: actifsHistoryFor ?? (_) => {},
          totalPassifHistoryFor: totalPassifHistoryFor ?? (_) => const [],
          hidden: false,
          periodIndex: periodIndex,
          onPeriodChanged: onPeriodChanged ?? (_) {},
        ),
      ),
    );
  }

  testWidgets(
    'affiche le montant total et une tendance positive à partir des '
    'points fournis',
    (tester) async {
      await tester.pumpWidget(
        buildCard(
          actifs: [category()],
          actifsHistoryFor: (period) => {
            'actifs_actions_fonds': [
              NetWorthPoint(DateTime.utc(2026, 1, 1), 800),
              NetWorthPoint(DateTime.utc(2026, 8, 1), 1000),
            ],
          },
        ),
      );
      await tester.pump();

      expect(find.text(displayEuros(1000, false)), findsOneWidget);
      expect(find.byIcon(LucideIcons.trendingUp), findsOneWidget);
      expect(find.byIcon(LucideIcons.trendingDown), findsNothing);
    },
  );

  testWidgets('une tendance négative affiche l\'icône de baisse', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(
        actifs: [category()],
        actifsHistoryFor: (period) => {
          'actifs_actions_fonds': [
            NetWorthPoint(DateTime.utc(2026, 1, 1), 1000),
            NetWorthPoint(DateTime.utc(2026, 8, 1), 800),
          ],
        },
      ),
    );
    await tester.pump();

    expect(find.byIcon(LucideIcons.trendingDown), findsOneWidget);
    expect(find.byIcon(LucideIcons.trendingUp), findsNothing);
  });

  group('états vides', () {
    testWidgets(
      'aucune donnée nulle part : message dédié, pas de graphique',
      (tester) async {
        await tester.pumpWidget(buildCard(actifs: [category()]));
        await tester.pump();

        expect(find.text('Pas encore de données.'), findsOneWidget);
        expect(
          find.text('Pas assez de données sur cette période'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'des données existent globalement mais pas assez de points pour la '
      'période/sélection courante : EmptySelectionAmount plutôt que le '
      'message "aucune donnée"',
      (tester) async {
        await tester.pumpWidget(
          buildCard(
            actifs: [category()],
            actifsHistoryFor: (period) => {
              // Un seul point : `totalPoints.length < 2` reste vrai, mais
              // `hasAnyData` (historique non vide) l'est aussi.
              'actifs_actions_fonds': [
                NetWorthPoint(DateTime.utc(2026, 8, 1), 1000),
              ],
            },
          ),
        );
        await tester.pump();

        expect(
          find.text('Pas assez de données sur cette période'),
          findsOneWidget,
        );
        expect(find.text('Pas encore de données.'), findsNothing);
      },
    );
  });

  group('PeriodTabs (sélecteur de période contrôlé par le parent)', () {
    testWidgets(
      'affiche les 6 libellés de DashboardPeriod, celui à periodIndex '
      'sélectionné',
      (tester) async {
        await tester.pumpWidget(
          buildCard(actifs: [category()], periodIndex: 2),
        );
        await tester.pump();

        for (final period in DashboardPeriod.values) {
          expect(find.text(period.label), findsOneWidget);
        }
      },
    );

    testWidgets(
      'taper un autre libellé de période déclenche onPeriodChanged avec '
      'le bon index',
      (tester) async {
        int? changedTo;
        await tester.pumpWidget(
          buildCard(
            actifs: [category()],
            periodIndex: 5,
            onPeriodChanged: (i) => changedTo = i,
          ),
        );
        await tester.pump();

        // Index 2 = '1M' (voir DashboardPeriod.values).
        await tester.tap(find.text('1M'));
        await tester.pump();

        expect(changedTo, 2);
      },
    );

    testWidgets(
      'periodIndex étant une prop contrôlée, re-pomper avec un nouvel '
      'index change bien la période effectivement utilisée pour '
      'actifsHistoryFor (donc le montant affiché)',
      (tester) async {
        final calledWithPeriods = <DashboardPeriod>[];
        Map<String, List<NetWorthPoint>> Function(DashboardPeriod) historyFor(
          double allValue,
          double month1Value,
        ) => (period) {
          calledWithPeriods.add(period);
          final value = period == DashboardPeriod.month1
              ? month1Value
              : allValue;
          return {
            'actifs_actions_fonds': [
              NetWorthPoint(DateTime.utc(2026, 1, 1), value - 100),
              NetWorthPoint(DateTime.utc(2026, 8, 1), value),
            ],
          };
        };

        await tester.pumpWidget(
          buildCard(
            actifs: [category()],
            actifsHistoryFor: historyFor(1000, 500),
            periodIndex: 5,
          ),
        );
        await tester.pump();
        expect(find.text(displayEuros(1000, false)), findsOneWidget);
        expect(calledWithPeriods.last, DashboardPeriod.all);

        await tester.pumpWidget(
          buildCard(
            actifs: [category()],
            actifsHistoryFor: historyFor(1000, 500),
            periodIndex: 2,
          ),
        );
        await tester.pump();
        expect(find.text(displayEuros(500, false)), findsOneWidget);
        expect(calledWithPeriods.last, DashboardPeriod.month1);
      },
    );
  });

  group('bascule Patrimoine net / Patrimoine brut', () {
    testWidgets(
      '"Patrimoine net" est le mode par défaut, sans sélecteur de '
      'classes visible',
      (tester) async {
        await tester.pumpWidget(
          buildCard(
            actifs: [category()],
            actifsHistoryFor: (period) => {
              'actifs_actions_fonds': [
                NetWorthPoint(DateTime.utc(2026, 1, 1), 800),
                NetWorthPoint(DateTime.utc(2026, 8, 1), 1000),
              ],
            },
          ),
        );
        await tester.pump();

        expect(find.text('Patrimoine net'), findsOneWidget);
        expect(find.byType(CategoryMultiSelect), findsNothing);
      },
    );

    testWidgets(
      'basculer vers "Patrimoine brut" fait apparaître le sélecteur de '
      'classes (CategoryMultiSelect), toutes sélectionnées par défaut',
      (tester) async {
        await tester.pumpWidget(
          buildCard(
            actifs: [category()],
            actifsHistoryFor: (period) => {
              'actifs_actions_fonds': [
                NetWorthPoint(DateTime.utc(2026, 1, 1), 800),
                NetWorthPoint(DateTime.utc(2026, 8, 1), 1000),
              ],
            },
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Patrimoine net'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Patrimoine brut').last);
        await tester.pumpAndSettle();

        expect(find.text('Patrimoine brut'), findsWidgets);
        expect(find.byType(CategoryMultiSelect), findsOneWidget);
        // Une seule catégorie fournie, donc toutes sélectionnées : le
        // multi-select affiche "Tout" plutôt que la liste des libellés —
        // vérifié à l'intérieur de CategoryMultiSelect pour ne pas être
        // ambigu avec le libellé "Tout" de PeriodTabs (DashboardPeriod.all).
        expect(
          find.descendant(
            of: find.byType(CategoryMultiSelect),
            matching: find.text('Tout'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}

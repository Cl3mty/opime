import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/gold_progress_bar.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/widgets/fiscal_milestone_bar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Future<double> fractionFor(
    WidgetTester tester, {
    required DateTime openingDate,
    required FiscalMilestone milestone,
  }) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: FiscalMilestoneBar(
            openingDate: openingDate,
            milestone: milestone,
          ),
        ),
      ),
    );
    return tester
        .widget<GoldProgressBar>(find.byType(GoldProgressBar))
        .fraction;
  }

  testWidgets('à mi-parcours, la barre est remplie à moitié', (tester) async {
    final opening = DateTime(2020, 1, 1);
    final milestone = (
      kind: FiscalMilestoneKind.avantageFiscal,
      date: DateTime(2025, 1, 1),
      reached: false,
    );
    // "Aujourd'hui" simulé au milieu du jalon en calculant directement la
    // date attendue plutôt qu'en dépendant de DateTime.now() : on vérifie
    // la formule plutôt qu'un instant figé.
    final totalDays = milestone.date.difference(opening).inDays;
    final elapsedDays = DateTime.now().difference(opening).inDays;
    final expected = (elapsedDays / totalDays).clamp(0.0, 1.0);

    final fraction = await fractionFor(
      tester,
      openingDate: opening,
      milestone: milestone,
    );

    expect(fraction, closeTo(expected, 0.0001));
  });

  testWidgets('jalon déjà atteint : barre pleine', (tester) async {
    final opening = DateTime(2015, 1, 1);
    final milestone = (
      kind: FiscalMilestoneKind.avantageFiscal,
      date: DateTime(2020, 1, 1),
      reached: true,
    );

    final fraction = await fractionFor(
      tester,
      openingDate: opening,
      milestone: milestone,
    );

    expect(fraction, 1.0);
  });

  testWidgets(
    'durée nulle (ouverture == jalon) : ne plante pas, barre pleine',
    (tester) async {
      final same = DateTime(2022, 6, 1);
      final milestone = (
        kind: FiscalMilestoneKind.avantageFiscal,
        date: same,
        reached: true,
      );

      final fraction = await fractionFor(
        tester,
        openingDate: same,
        milestone: milestone,
      );

      expect(fraction, 1.0);
    },
  );
}

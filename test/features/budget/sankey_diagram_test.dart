import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:opime/features/budget/sankey_diagram.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;

void main() {
  Widget wrap(Widget child) => ShadcnApp(
    locale: const Locale('fr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      shadcnLocalizationsFrDelegate,
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: Scaffold(child: child),
  );

  testWidgets('nœuds/liens simples : rendu sans exception', (tester) async {
    final a = SankeyNode(label: 'A', column: 0, color: const Color(0xFF22C55E));
    final b = SankeyNode(label: 'B', column: 1, color: const Color(0xFFEF4444));

    await tester.pumpWidget(
      wrap(SizedBox(
        width: 400,
        child: SankeyDiagram(
          nodes: [a, b],
          links: [SankeyLink(source: a, target: b, value: 100)],
          hidden: false,
        ),
      )),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets(
    'sans nœud : affiche le message vide plutôt qu\'un graphique cassé',
    (tester) async {
      await tester.pumpWidget(
        wrap(SankeyDiagram(
          nodes: const [],
          links: const [],
          hidden: false,
          emptyMessage: 'Rien à afficher.',
        )),
      );

      expect(find.text('Rien à afficher.'), findsOneWidget);
    },
  );

  testWidgets(
    'un nœud sans lien (minValue seul) garde sa hauteur plutôt que de '
    's\'effondrer à 0',
    (tester) async {
      final lone = SankeyNode(
        label: 'Seul',
        column: 0,
        color: const Color(0xFF22C55E),
        minValue: 500,
      );

      await tester.pumpWidget(
        wrap(SizedBox(
          width: 300,
          child: SankeyDiagram(nodes: [lone], links: const [], hidden: false),
        )),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(lone.value, 500);
    },
  );
}

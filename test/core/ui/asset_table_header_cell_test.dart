import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/asset_table_header_cell.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  group(
    'assetTableColumnExplanations (garde-fou contre une colonne oubliée)',
    () {
      // Chaque libellé de colonne réellement utilisé dans
      // `category_breakdown_card.dart`, `category_detail_screen.dart` et
      // `positions_table.dart` (tableau spot + sous-tableau à effet de
      // levier) — si l'un de ces fichiers renomme un en-tête sans mettre à
      // jour la map, ce test échoue plutôt que de laisser une bulle
      // orpheline ou manquante passer inaperçue.
      const usedColumnLabels = [
        'Valeur',
        'Évolution',
        '+/- value',
        'PRU',
        'Quantité',
        'Cours',
        'Taille',
        'Entrée',
        'Montant',
        'PnL (ROE)',
      ];

      for (final label in usedColumnLabels) {
        test('"$label" a une explication', () {
          expect(assetTableColumnExplanations[label], isNotNull);
          expect(assetTableColumnExplanations[label], isNotEmpty);
        });
      }
    },
  );

  group('AssetTableHeaderCell', () {
    Future<void> pump(WidgetTester tester, String label) => tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: Align(
            alignment: Alignment.topLeft,
            child: AssetTableHeaderCell(label, width: 96),
          ),
        ),
      ),
    );

    testWidgets(
      'affiche l\'explication au survol pour un libellé connu de la map',
      (tester) async {
        await pump(tester, 'Valeur');

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        await gesture.moveTo(tester.getCenter(find.text('Valeur')));
        // `Tooltip` (shadcn_flutter) attend 500 ms de survol avant de
        // s'afficher (`Hover.waitDuration`), puis anime son apparition —
        // sondage par petits pas plutôt qu'un seul grand saut de durée,
        // plus robuste face aux animations internes du package.
        final explanation = find.text(assetTableColumnExplanations['Valeur']!);
        for (var i = 0; i < 20 && explanation.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(explanation, findsOneWidget);
      },
    );

    testWidgets(
      'un libellé sans entrée dans la map reste un texte nu, sans '
      'Tooltip — pas d\'obligation d\'en avoir une pour chaque colonne',
      (tester) async {
        await pump(tester, 'Une colonne inconnue');
        await tester.pump();

        expect(find.text('Une colonne inconnue'), findsOneWidget);
        expect(find.byType(Tooltip), findsNothing);
      },
    );
  });
}

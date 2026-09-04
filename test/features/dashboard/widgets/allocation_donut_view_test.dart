import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:opime/features/dashboard/widgets/allocation_blocks_view.dart'
    show AllocationSlice;
import 'package:opime/features/dashboard/widgets/allocation_donut_view.dart';
import 'package:opime/features/dashboard/widgets/allocation_hover_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  const slices = [
    AllocationSlice(id: 'a', label: 'Alpha', color: Colors.blue, percent: 70),
    AllocationSlice(
      id: 'b',
      label: 'Beta',
      color: Colors.orange,
      percent: 30,
    ),
  ];

  Widget buildDonut() => ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      
    home: Scaffold(
      child: Center(
        child: SizedBox(
          width: 400,
          height: 400,
          child: AllocationDonutView(slices: slices, total: 1000, hidden: false),
        ),
      ),
    ),
  );

  testWidgets(
    'régression : survoler l\'anneau doit surligner la bonne part dès la '
    'première frame où le curseur s\'y trouve, même sans mouvement '
    'supplémentaire après coup — l\'anneau peut apparaître SOUS un curseur '
    'déjà immobile (ouverture de la page, bascule d\'onglet...), un cas où '
    'Flutter ne déclenche que `onEnter`, jamais `onHover`',
    (tester) async {
      // Mesure la géométrie réelle de l'anneau (dépend de la mise en page,
      // pas figée arbitrairement) en le construisant une première fois.
      await tester.pumpWidget(buildDonut());
      await tester.pump();
      final ringRect = tester.getRect(find.byType(AspectRatio));
      final center = ringRect.center;
      final radius = ringRect.shortestSide / 2;
      // Juste au-dessus du centre (12 h, sur le trait) : le point de départ
      // du balayage — toujours dans la première part ("Alpha", 70 %).
      final target = Offset(center.dx, center.dy - radius);

      // Démonte l'anneau (widget de remplacement, sans MouseRegion) puis
      // positionne la souris sur `target` — le curseur ne bougera plus
      // ensuite, reproduisant "la souris est déjà là quand le widget
      // apparaît".
      await tester.pumpWidget(
        ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      home: Scaffold(child: Center(child: SizedBox(width: 400, height: 400)))),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: target);
      await tester.pump();

      // Le donut réapparaît sous ce curseur immobile — une seule frame,
      // aucun `gesture.moveTo` après coup.
      await tester.pumpWidget(buildDonut());
      await tester.pump();

      // Le tooltip de survol (distinct de la légende, toujours visible et
      // qui contient aussi "Alpha") confirme que la part est bien
      // surlignée, pas seulement présente dans la liste.
      final tooltip = find.byType(AllocationHoverTooltip);
      expect(tooltip, findsOneWidget);
      expect(tester.widget<AllocationHoverTooltip>(tooltip).label, 'Alpha');
    },
  );

  testWidgets(
    'régression : survoler la moitié INTÉRIEURE de l\'anneau visible '
    'déclenche bien le survol — `_DonutPainter` dessine le trait centré '
    'sur `radius - strokeWidth / 2` (le bord extérieur affleure `radius` '
    'sans déborder de la boîte), la zone de détection doit suivre cette '
    'même ligne médiane plutôt que `radius` brut, sinon la moitié '
    'intérieure du trait réellement dessiné ne répond jamais au survol',
    (tester) async {
      await tester.pumpWidget(buildDonut());
      await tester.pump();
      final ringRect = tester.getRect(find.byType(AspectRatio));
      final center = ringRect.center;
      final radius = ringRect.shortestSide / 2;
      // `strokeWidth` suit exactement `_DonutPainter`/`_updateHover`
      // (`radius * 0.34`) : le trait réellement dessiné va donc de
      // `radius * 0.66` à `radius` — un point à `radius * 0.75` tombe dans
      // sa moitié intérieure ([0.66, 0.83]), hors de l'ancienne zone de
      // détection (décalée vers l'extérieur, [0.83, 1.17]), dans la
      // nouvelle (alignée sur le trait réel, [0.66, 1.0]).
      final target = Offset(center.dx, center.dy - radius * 0.75);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      await gesture.moveTo(target);
      await tester.pump();

      final tooltip = find.byType(AllocationHoverTooltip);
      expect(tooltip, findsOneWidget);
      expect(tester.widget<AllocationHoverTooltip>(tooltip).label, 'Alpha');
    },
  );
}

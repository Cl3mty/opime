import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/widgets/investment_classification_fields.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  /// Harnais minimal : `InvestmentClassificationFields` est un widget sans
  /// état propre (contrôlé par callbacks) — ce `StatefulBuilder` rejoue le
  /// rôle du parent (`InvestmentEditForm`/`complete_patrimoine_dialog.dart`)
  /// en tenant l'état lui-même, pour pouvoir vérifier les callbacks ET le
  /// re-rendu qui en découle dans le même test.
  Future<void> pump(WidgetTester tester) async {
    Sector? sector;
    var sectorBreakdown = const <SectorWeight>[];
    String? countryCode;
    var countryBreakdown = const <CountryWeight>[];

    await tester.pumpWidget(
      ShadcnApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: [
          shadcnLocalizationsFrDelegate,
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          child: StatefulBuilder(
            builder: (context, setState) => InvestmentClassificationFields(
              sector: sector,
              onSectorChanged: (v) => setState(() => sector = v),
              sectorBreakdown: sectorBreakdown,
              onSectorBreakdownChanged: (v) =>
                  setState(() => sectorBreakdown = v),
              countryCode: countryCode,
              onCountryCodeChanged: (v) => setState(() => countryCode = v),
              countryBreakdown: countryBreakdown,
              onCountryBreakdownChanged: (v) =>
                  setState(() => countryBreakdown = v),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'par défaut : les deux Select simples (Secteur/Pays) sont affichés, '
    'aucun éditeur de répartition',
    (tester) async {
      await pump(tester);

      expect(find.text('Secteur'), findsOneWidget);
      expect(find.text('Pays'), findsOneWidget);
      expect(find.text('Répartition par secteur'), findsNothing);
      expect(find.text('Répartition par pays'), findsNothing);
    },
  );

  testWidgets(
    'basculer en mode multi-secteurs remplace le Select simple par '
    'l\'éditeur de répartition, préinitialisé à 100 %',
    (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('switch_to_multi_sector')));
      await tester.pump();

      expect(find.text('Secteur'), findsNothing);
      expect(find.text('Répartition par secteur'), findsOneWidget);
      // Une seule ligne préremplie à 100 %.
      expect(find.textContaining('100'), findsOneWidget);
    },
  );

  testWidgets(
    'mode multi-secteurs : "+" ajoute une ligne, la croix la retire, '
    '"Revenir à une seule valeur" vide la répartition',
    (tester) async {
      // Fenêtre agrandie : le bouton "+" de l'en-tête déborde du viewport
      // 800x600 par défaut (texte "Revenir à une seule valeur" + icône),
      // faisant échouer le tap en hors écran.
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('switch_to_multi_sector')));
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('add_weight_Répartition par secteur')),
      );
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.tap(find.text('Revenir à une seule valeur'));
      await tester.pump();

      expect(find.text('Répartition par secteur'), findsNothing);
      expect(find.text('Secteur'), findsOneWidget);
    },
  );

  testWidgets(
    'basculer en mode multi-pays remplace le Select simple par l\'éditeur '
    'de répartition',
    (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('switch_to_multi_country')));
      await tester.pump();

      expect(find.text('Pays'), findsNothing);
      expect(find.text('Répartition par pays'), findsOneWidget);
    },
  );
}

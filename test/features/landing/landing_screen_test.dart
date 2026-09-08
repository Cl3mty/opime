import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/app/theme_controller.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/landing/landing_screen.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  // Le `ThemeController` persiste via `shared_preferences` (voir
  // `toggleLightDark`) : sans mock, son `getInstance()` attend indéfiniment
  // en environnement de test. La landing utilise un controller frais dans
  // son test de bascule, donc on initialise le mock au niveau de la suite.
  SharedPreferences.setMockInitialValues({});
  final themeController = ThemeController();
  // Forcé en sombre : la plupart des tests ci-dessous portent sur le
  // contenu/la navigation de la page, pas sur la bascule de thème (qui a son
  // propre test dédié plus bas avec un contrôleur séparé) — sans ce forçage,
  // le thème "système" par défaut résoudrait en clair dans l'environnement
  // de test et le carousel afficherait les captures claires, cassant les
  // assertions sur les noms d'assets sombres (`screenshot_xxx.png`).
  setUp(() => themeController.setMode(ThemeMode.dark));
  Widget wrap(Widget child) => ShadcnApp(
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr'), Locale('en')],
    localizationsDelegates: [
      shadcnLocalizationsFrDelegate,
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: child,
  );

  testWidgets(
    'affiche le titre héro et les appels à l\'action, tous relient au '
    "même callback d'entrée dans l'app",
    (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        wrap(
          LandingScreen(
            onGetStarted: () => tapCount++,
            themeController: themeController,
          ),
        ),
      );
      // `pumpAndSettle` ne convient pas ici : le halo animé de la zone héro
      // (`_HeroGlow`) boucle indéfiniment (`repeat(reverse: true)`) et ne
      // "se stabilise" donc jamais. On avance plutôt d'une durée fixe,
      // largement suffisante pour que toutes les entrées échelonnées
      // (`_FadeSlideIn`, jusqu'à 500ms de délai + 500ms de transition)
      // soient terminées.
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('Ton patrimoine, enfin sous contrôle.'), findsOneWidget);
      expect(find.text('Commencer gratuitement'), findsWidgets);
      expect(find.text("Ouvrir l'application"), findsOneWidget);

      await tester.tap(find.text("Ouvrir l'application"));
      await tester.pump();

      expect(tapCount, 1);
    },
  );

  testWidgets(
    '"Découvrir les fonctionnalités" fait défiler jusqu\'à la section '
    'fonctionnalités sans planter',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          LandingScreen(onGetStarted: () {}, themeController: themeController),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));

      // Le bouton peut être hors de la petite fenêtre de test par défaut
      // (800×600) avant tout défilement.
      await tester.ensureVisible(find.text('Découvrir les fonctionnalités'));
      await tester.pump();
      await tester.tap(find.text('Découvrir les fonctionnalités'));
      // Même remarque que le test précédent : `_HeroGlow` empêche
      // `pumpAndSettle`, l'animation de défilement (`Scrollable
      // .ensureVisible`, 500ms) est donc attendue par une durée fixe.
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text('Tout ce qu\'il faut pour piloter tes finances'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'affiche le bandeau "100 %" et la section communauté avec son lien '
    'GitHub',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          LandingScreen(onGetStarted: () {}, themeController: themeController),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('100%'), findsNWidgets(3));
      expect(find.text('Tes données'), findsOneWidget);
      expect(find.text('Gratuit'), findsOneWidget);
      expect(find.text('Moderne & ergonomique'), findsOneWidget);

      await tester.ensureVisible(find.text('Façonne Opime avec moi'));
      await tester.pump();

      expect(find.text('Voter pour une fonctionnalité'), findsOneWidget);
    },
  );

  // Vérifie la présence d'une des 4 vraies captures d'écran (voir
  // `assets/landing/` et `_appScreenshots` dans `landing_screen.dart`) —
  // `Image.asset` ne peint pas de texte trouvable par `find.text`, on
  // identifie donc la diapositive affichée par le chemin de son asset.
  Finder screenshot(WidgetTester tester, String name) => find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == 'assets/landing/$name.png',
  );

  // `_MacWindowTitleBar` est privée à `landing_screen.dart` (autre
  // bibliothèque) : repérée ici par sa hauteur fixe (34, unique dans cette
  // page) plutôt que par son type, pour vérifier que sa couleur suit bien
  // le thème choisi (voir la doc de tête de `_MacWindowTitleBar`).
  Color? macWindowTitleBarColor(WidgetTester tester) {
    final finder = find.byWidgetPredicate(
      (widget) => widget is Container && widget.constraints?.maxHeight == 34,
    );
    return tester.widget<Container>(finder).color;
  }

  testWidgets(
    'le carousel du héro affiche les vraies captures d\'écran de l\'app et '
    'se navigue via les puces',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          LandingScreen(onGetStarted: () {}, themeController: themeController),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));

      // Diapositive par défaut : tableau de bord (voir l'ordre de
      // `_appScreenshots`).
      expect(screenshot(tester, 'screenshot_dashboard'), findsOneWidget);

      // Ciblées par clé d'index (voir `ValueKey('landing_carousel_dot_...')`
      // dans `landing_screen.dart`) : le callback est invoqué directement
      // plutôt que via `tester.tap`, la puce étant minuscule (7×7, 20×7
      // pour celle active) et hors de l'écran par défaut du test
      // (800×600), ce qui rend le calcul du point de clic peu fiable ici.
      // Ce qu'on veut vérifier — le déclenchement de la navigation et son
      // effet — ne dépend pas de la réussite d'un vrai hit-test.
      Future<void> goToDot(int index) async {
        final dot = find.byKey(ValueKey('landing_carousel_dot_$index'));
        tester.widget<GestureDetector>(dot).onTap!();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await goToDot(2); // budget (Ventilation)
      expect(screenshot(tester, 'screenshot_budget'), findsOneWidget);

      await goToDot(3); // simulation (Patrimoine, Monte-Carlo)
      expect(screenshot(tester, 'screenshot_simulation'), findsOneWidget);

      await goToDot(1); // projets
      expect(screenshot(tester, 'screenshot_projects'), findsOneWidget);
    },
  );

  testWidgets('le carousel du héro défile automatiquement sans interaction', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        LandingScreen(onGetStarted: () {}, themeController: themeController),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(screenshot(tester, 'screenshot_dashboard'), findsOneWidget);

    // Passé le délai de défilement automatique (voir `_AppMockupState
    // ._autoPlayInterval`, 5s), la diapositive suivante s'affiche sans
    // qu'on ait interagi avec les puces/flèches. Avancé par petits pas
    // plutôt qu'un unique grand `pump` : `flutter_test` avance alors une
    // horloge simulée (`FakeAsync`) qui déclenche bien le `Timer
    // .periodic` sous-jacent, mais un pas plus fin laisse aussi le temps
    // à l'animation de changement de page (500ms) de se dérouler.
    for (var i = 0; i < 130; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(screenshot(tester, 'screenshot_projects'), findsOneWidget);
  });

  testWidgets(
    'la section Télécharger propose le logiciel de l\'OS détecté en premier, '
    'avec l\'alternative "directement dans le navigateur" dans la même carte',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var tapCount = 0;
      await tester.pumpWidget(
        wrap(
          LandingScreen(
            onGetStarted: () => tapCount++,
            themeController: themeController,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text("Télécharge Opime pour macOS"), findsOneWidget);
      expect(find.text('Télécharger pour macOS'), findsOneWidget);
      expect(find.text('ou pour Windows'), findsOneWidget);
      expect(find.text('ou pour Linux'), findsOneWidget);
      // Le lien de navigation "Télécharger" (barre du haut) est un texte
      // distinct de "Télécharger pour macOS" (bouton de la section) : pas
      // d'ambiguïté entre les deux.
      expect(find.text('Télécharger'), findsOneWidget);

      // Carte Télécharger + "directement dans le navigateur" fusionnées :
      // l'alternative navigateur est dans la même carte, pas dans une
      // section séparée.
      await tester.ensureVisible(find.text('Commencer maintenant'));
      await tester.pump();
      await tester.tap(find.text('Commencer maintenant'));
      await tester.pump();
      expect(tapCount, 1);

      // Remis à `null` avant la fin du test (et non via `tearDown`/
      // `addTearDown`, qui s'exécutent trop tard) : le contrôle
      // d'invariants de `flutter_test` vérifie que ce drapeau de debug est
      // revenu à `null` dès la fin du corps du test lui-même.
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'la section Télécharger bascule sur Windows quand c\'est l\'OS détecté',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.pumpWidget(
        wrap(
          LandingScreen(onGetStarted: () {}, themeController: themeController),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('Télécharge Opime pour Windows'), findsOneWidget);
      expect(find.text('Télécharger pour Windows'), findsOneWidget);
      expect(find.text('ou pour macOS'), findsOneWidget);
      expect(find.text('ou pour Linux'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'la barre du haut expose une bascule clair/sombre qui force le thème',
    (tester) async {
      // Démarre en clair de façon déterministe (plutôt que "système") pour
      // vérifier que la bascule passe bien au sombre et inversement.
      final forced = ThemeController();
      await forced.setMode(ThemeMode.light);
      await tester.pumpWidget(
        wrap(LandingScreen(onGetStarted: () {}, themeController: forced)),
      );
      await tester.pump(const Duration(milliseconds: 1200));

      // Testé en fenêtre étroite comme les autres tests (800×600) : le
      // libellé passe en icône seule, mais le bouton reste présent et
      // cliquable (repéré par son icône lune). Le callback est invoqué
      // directement plutôt que via `tester.tap` (qui déclencherait un
      // `pumpAndSettle` bloquant à cause du halo animé infini du héro).
      expect(find.byIcon(LucideIcons.moon), findsOneWidget);

      final toggle = tester.widget<GhostButton>(find.byType(GhostButton).first);
      toggle.onPressed!();
      await tester.pump();

      expect(forced.mode, ThemeMode.dark);
      expect(find.byIcon(LucideIcons.sun), findsOneWidget);

      final toggle2 = tester.widget<GhostButton>(
        find.byType(GhostButton).first,
      );
      toggle2.onPressed!();
      await tester.pump();
      expect(forced.mode, ThemeMode.light);
    },
  );

  testWidgets(
    'le carousel du héro affiche les captures en thème clair quand le '
    'thème résout au clair',
    (tester) async {
      final forced = ThemeController();
      await forced.setMode(ThemeMode.light);
      await tester.pumpWidget(
        wrap(LandingScreen(onGetStarted: () {}, themeController: forced)),
      );
      await tester.pump(const Duration(milliseconds: 1200));

      expect(screenshot(tester, 'screenshot_dashboard_light'), findsOneWidget);
      expect(screenshot(tester, 'screenshot_dashboard'), findsNothing);
      // La barre de titre "façon macOS" au-dessus du carousel (voir
      // `_MacWindowTitleBar`) doit elle aussi passer en clair — sinon une
      // barre sombre resterait incongrue au-dessus d'une capture claire.
      expect(macWindowTitleBarColor(tester), const Color(0xFFE4E4E4));

      await forced.setMode(ThemeMode.dark);
      await tester.pump();

      expect(screenshot(tester, 'screenshot_dashboard'), findsOneWidget);
      expect(screenshot(tester, 'screenshot_dashboard_light'), findsNothing);
      expect(macWindowTitleBarColor(tester), const Color(0xFF1E1E1E));
    },
  );
}

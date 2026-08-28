import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/features/dashboard/category_detail_screen.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:opime/features/investments/autres_photo_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

// PNG 1×1 transparent minimal — un `Image.file` a besoin de vrais octets
// décodables pour ne pas retomber silencieusement sur son `errorBuilder`
// (les initiales), contrairement à `AutresPhotoRepository`, qui ne valide
// que l'extension du fichier, pas son contenu.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

void main() {
  PatrimoineAccount investment() => const PatrimoineAccount(
    id: 'inv-1',
    name: 'Amundi MSCI World',
    valeur: 1000,
    quantite: 10,
    plusValueAbs: 50,
    plusValuePercent: 5,
  );

  PatrimoineAccount account() => PatrimoineAccount(
    id: 'acc-1',
    name: 'PEA',
    valeur: 1000,
    plusValueAbs: 50,
    plusValuePercent: 5,
    investments: [investment()],
  );

  PatrimoineCategory category() => PatrimoineCategory(
    id: 'actifs_actions_fonds',
    label: 'Actions & Fonds',
    icon: LucideIcons.trendingUp,
    color: const Color(0xFF000000),
    tier: AllocationTier.fondation,
    description: '',
    accounts: [investment()],
  );

  PatrimoineCategory liabilityCategory() => PatrimoineCategory(
    id: 'passifs_prets_immobiliers',
    label: 'Prêts immobiliers',
    icon: LucideIcons.house,
    color: const Color(0xFF000000),
    tier: AllocationTier.croissance,
    description: '',
    accounts: [
      const PatrimoineAccount(
        id: 'loan-1',
        name: 'Prêt maison',
        valeur: 150000,
        plusValueAbs: -5000,
        plusValuePercent: -3.2,
      ),
    ],
  );

  Widget buildScreen({
    ValueChanged<PatrimoineAccount>? onAccountOpen,
    bool defaultExpanded = false,
  }) {
    return ShadcnApp(
      home: Scaffold(
        child: CategoryDetailScreen(
          category: category(),
          amountVisibility: AmountVisibilityController(),
          distributionByAccount: [account()],
          onAccountTap: (_) {},
          onAccountEdit: (_) {},
          onAccountDelete: (_) async {},
          onAccountOpen: onAccountOpen,
          defaultExpanded: defaultExpanded,
        ),
      ),
    );
  }

  testWidgets(
    'sans onAccountOpen : menu "⋮", ligne inerte au clic (pas de page à '
    'ouvrir), dépli via le chevron dédié uniquement',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byIcon(LucideIcons.ellipsisVertical), findsOneWidget);

      // Cliquer le titre ne fait plus rien : pas de page à ouvrir, et le
      // dépli ne passe plus par la ligne complète.
      await tester.tap(find.text('PEA'));
      await tester.pumpAndSettle();
      expect(find.text('Amundi MSCI World'), findsNothing);

      // Seul le chevron dédié (leading) déplie le compte.
      await tester.tap(find.byIcon(LucideIcons.chevronRight).first);
      await tester.pumpAndSettle();
      expect(find.text('Amundi MSCI World'), findsOneWidget);

      // Un chevron par ligne cliquable : le compte (expand) + la position.
      expect(find.byIcon(LucideIcons.chevronRight), findsNWidgets(2));
    },
  );

  testWidgets(
    'avec onAccountOpen : pas de menu "⋮", le clic sur la ligne (titre '
    'compris) déclenche le callback, le dépli reste séparé (chevron dédié)',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      PatrimoineAccount? opened;
      await tester.pumpWidget(buildScreen(onAccountOpen: (a) => opened = a));
      await tester.pump();

      expect(find.byIcon(LucideIcons.ellipsisVertical), findsNothing);
      // Un seul chevron : plus de chevron d'ouverture dédié en bout de
      // ligne (voir la doc de `_AccountAccordionTile`), cette action passe
      // maintenant par le clic sur la ligne elle-même — seul reste le
      // chevron d'expansion (leading).
      expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);

      await tester.tap(find.text('PEA'));
      await tester.pump();

      expect(opened?.id, 'acc-1');
      // Le clic sur la ligne n'a pas déplié le compte (action désormais
      // distincte) : la position ne s'est pas révélée.
      expect(find.text('Amundi MSCI World'), findsNothing);

      // Le chevron dédié, lui, déplie bien le compte.
      await tester.tap(find.byIcon(LucideIcons.chevronRight));
      await tester.pumpAndSettle();
      expect(find.text('Amundi MSCI World'), findsOneWidget);
      // La ligne de position n'a pas de chevron propre (elle ouvre une
      // popup, pas une page) : toujours un seul chevron dans l'arbre.
      expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
    },
  );

  testWidgets(
    'accordéon de banque : ligne inerte au clic (pas de page à ouvrir '
    'pour une banque), dépli via le chevron dédié uniquement',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Deux comptes à la même banque : seul ce cas affiche l'accordéon de
      // banque (voir `_buildAccountAccordions`, qui saute ce niveau pour
      // un compte isolé sans banque distincte).
      final accounts = [
        PatrimoineAccount(
          id: 'acc-1',
          name: 'PEA',
          bankName: 'Bourso',
          valeur: 1000,
          plusValueAbs: 50,
          plusValuePercent: 5,
          investments: [investment()],
        ),
        PatrimoineAccount(
          id: 'acc-2',
          name: 'CTO',
          bankName: 'Bourso',
          valeur: 500,
          plusValueAbs: 10,
          plusValuePercent: 2,
        ),
      ];
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryDetailScreen(
              category: category(),
              amountVisibility: AmountVisibilityController(),
              distributionByAccount: accounts,
              onAccountTap: (_) {},
              defaultExpanded: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Cliquer le nom de la banque ne fait rien : pas de page à ouvrir.
      await tester.tap(find.text('Bourso'));
      await tester.pumpAndSettle();
      expect(find.text('PEA'), findsNothing);

      // Le chevron dédié, lui, déplie la banque (révèle ses comptes).
      await tester.tap(find.byIcon(LucideIcons.chevronRight).first);
      await tester.pumpAndSettle();
      expect(find.text('PEA'), findsOneWidget);
      expect(find.text('CTO'), findsOneWidget);
    },
  );

  testWidgets('defaultExpanded true déplie les accordéons sans interaction, '
      'false les garde repliés', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildScreen(defaultExpanded: true));
    await tester.pump();
    expect(find.text('Amundi MSCI World'), findsOneWidget);

    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.text('Amundi MSCI World'), findsNothing);
  });

  testWidgets(
    'CategoryDetailScreen sans defaultExpanded renseigné : déplié par '
    'défaut (comportement par défaut de tous les accordéons du logiciel)',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryDetailScreen(
              category: category(),
              amountVisibility: AmountVisibilityController(),
              distributionByAccount: [account()],
              onAccountTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Amundi MSCI World'), findsOneWidget);
    },
  );

  testWidgets(
    'le montant affiché en tête est category.montant (la valeur réelle '
    'aujourd\'hui), pas le dernier point de l\'historique — écart réel pour '
    'un passif dont la courbe projette jusqu\'à l\'échéance (~0 €), voir '
    '`RealPassifDetailScreen`',
    (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryDetailScreen(
              category: category(),
              amountVisibility: AmountVisibilityController(),
              onAccountTap: (_) {},
              // Historique vide à dessein : `points.last.value` vaudrait 0,
              // alors que category.montant (via l'unique investissement à
              // 1000 €) doit rester le montant affiché.
              historyForPeriod: (_) => const [],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1 000 €'), findsWidgets);
    },
  );

  testWidgets(
    'showChangePercent: false masque le "(±X %)" sous le montant, sans '
    'masquer la variation absolue en euros',
    (tester) async {
      final points = [
        NetWorthPoint(DateTime.utc(2025, 1, 1), 1000),
        NetWorthPoint(DateTime.utc(2025, 6, 1), 400),
      ];
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryDetailScreen(
              category: category(),
              amountVisibility: AmountVisibilityController(),
              onAccountTap: (_) {},
              historyForPeriod: (_) => points,
              showChangePercent: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Sans showChangePercent: false, ce serait "-600 € (-60.00 %)" —
      // seul le "-60.00 %" doit disparaître, pas le "-600 €" ni les
      // pourcentages d'autre nature affichés ailleurs sur l'écran (ex :
      // plus-value latente d'une position, part de l'allocation).
      expect(find.textContaining('-60.00'), findsNothing);
      expect(find.textContaining('-600'), findsOneWidget);
    },
  );

  testWidgets(
    'catégorie de passif (prêt) : pas de colonnes Quantité/Cours, ni en '
    'en-tête ni sur la ligne de compte — un prêt n\'a ni unité ni cours de '
    'marché, contrairement à un actif',
    (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryDetailScreen(
              category: liabilityCategory(),
              amountVisibility: AmountVisibilityController(),
              onAccountTap: (_) {},
              accountsCardTitle: 'Passifs',
              showAvatar: false,
              showChangePercent: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Quantité'), findsNothing);
      expect(find.text('Cours'), findsNothing);
      expect(find.text('Valeur'), findsOneWidget);
    },
  );

  testWidgets(
    'catégorie d\'actif : les colonnes Quantité et Cours restent affichées',
    (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryDetailScreen(
              category: category(),
              amountVisibility: AmountVisibilityController(),
              onAccountTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Quantité'), findsOneWidget);
      expect(find.text('Cours'), findsOneWidget);
    },
  );

  group('indicateur de fraîcheur du cours (colonne Cours)', () {
    Future<void> pumpCategory(
      WidgetTester tester,
      PatrimoineAccount investment,
    ) {
      return tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryDetailScreen(
              category: PatrimoineCategory(
                id: 'actifs_actions_fonds',
                label: 'Actions & Fonds',
                icon: LucideIcons.trendingUp,
                color: const Color(0xFF000000),
                tier: AllocationTier.fondation,
                description: '',
                accounts: [investment],
              ),
              amountVisibility: AmountVisibilityController(),
              onAccountTap: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets(
      'cours estimé à la main (manualPriceAt) : icône crayon, pas la '
      'coche verte "à jour"',
      (tester) async {
        await pumpCategory(
          tester,
          PatrimoineAccount(
            id: 'inv-1',
            name: 'Montre de collection',
            valeur: 1000,
            cours: 950,
            manualPriceAt: DateTime(2026, 1, 15),
            plusValueAbs: 50,
            plusValuePercent: 5,
          ),
        );
        await tester.pump();

        expect(find.byIcon(LucideIcons.pencilLine), findsOneWidget);
        expect(find.byIcon(LucideIcons.badgeCheck), findsNothing);

        final tooltipFinder = find.ancestor(
          of: find.byIcon(LucideIcons.pencilLine),
          matching: find.byType(Tooltip),
        );
        final tooltipWidget = tester.widget<Tooltip>(tooltipFinder);
        final tooltipContent = tooltipWidget.tooltip(
          tester.element(tooltipFinder),
        );
        await tester.pumpWidget(
          ShadcnApp(home: Scaffold(child: tooltipContent)),
        );
        expect(
          find.text('Cours estimé à la main le 15/01/2026.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'cours récupéré aujourd\'hui (lastPriceDate) : coche verte "à jour", '
      'jamais l\'icône crayon même si manualPriceAt est aussi renseigné',
      (tester) async {
        final today = DateTime.now();
        await pumpCategory(
          tester,
          PatrimoineAccount(
            id: 'inv-1',
            name: 'Amundi MSCI World',
            valeur: 1000,
            cours: 100,
            lastPriceDate: DateTime(today.year, today.month, today.day),
            plusValueAbs: 50,
            plusValuePercent: 5,
          ),
        );
        await tester.pump();

        expect(find.byIcon(LucideIcons.badgeCheck), findsOneWidget);
        expect(find.byIcon(LucideIcons.pencilLine), findsNothing);
      },
    );
  });

  group('photo d\'un objet "Autres"', () {
    PatrimoineAccount watch() => const PatrimoineAccount(
      id: 'inv-1',
      name: 'Rolex Submariner',
      valeur: 9500,
      plusValueAbs: 1500,
      plusValuePercent: 18.75,
    );

    PatrimoineCategory autresCategory() => PatrimoineCategory(
      id: 'actifs_autres',
      label: 'Autres',
      icon: LucideIcons.gem,
      color: const Color(0xFF000000),
      tier: AllocationTier.opportuniste,
      description: '',
      accounts: [watch()],
    );

    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_category_detail_photo_test',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    testWidgets(
      'sans photo importée : l\'avatar affiche les initiales du libellé',
      (tester) async {
        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: CategoryDetailScreen(
                category: autresCategory(),
                amountVisibility: AmountVisibilityController(),
                onAccountTap: (_) {},
                vaultPath: tempDir.path,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('RS'), findsOneWidget);
      },
    );

    testWidgets(
      'une photo déjà importée pour cet investissement s\'affiche à la '
      'place des initiales',
      (tester) async {
        await tester.runAsync(() async {
          await AutresPhotoRepository(tempDir.path).importPhoto(
            'inv-1',
            _onePixelPng,
            sourceName: 'rolex.jpg',
          );
        });

        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: CategoryDetailScreen(
                category: autresCategory(),
                amountVisibility: AmountVisibilityController(),
                onAccountTap: (_) {},
                vaultPath: tempDir.path,
              ),
            ),
          ),
        );
        // Chargement de la photo (E/S disque réelle, lancée dans initState) :
        // il faut réellement laisser tourner la boucle d'évènements pour
        // qu'elle avance, `pump()` seul ne suffit pas — voir
        // `complete_patrimoine_dialog_test.dart`'s pattern équivalent.
        await tester.runAsync(() async {
          for (var i = 0; i < 40; i++) {
            if (find.byType(Image).evaluate().isNotEmpty) return;
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
          }
        });

        expect(find.text('RS'), findsNothing);
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets(
      'sans vaultPath renseigné : l\'avatar reste aux initiales, pas '
      'd\'erreur (aucune photo ne peut être chargée)',
      (tester) async {
        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: CategoryDetailScreen(
                category: autresCategory(),
                amountVisibility: AmountVisibilityController(),
                onAccountTap: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('RS'), findsOneWidget);
      },
    );
  });
}

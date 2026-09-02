import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/core/ui/asset_table_header_cell.dart';
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
          allocationByAccount: [account()],
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
    'régression : en vue "Par actif", un même actif (BTC) détenu sur deux '
    'comptes ne forme qu\'un seul bloc du graphique d\'allocation, pas deux '
    '— même quand allocationByInvestment (fusion par ticker/ISIN) est '
    'fourni',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // `category.accounts` : la vue "par actif" non fusionnée
      // (`buildRealCategories`) — une ligne par investissement PAR COMPTE,
      // donc deux lignes "BTC" ici (Binance et Coinbase).
      final cryptoCategory = PatrimoineCategory(
        id: 'actifs_crypto',
        label: 'Crypto',
        icon: LucideIcons.bitcoin,
        color: const Color(0xFF000000),
        tier: AllocationTier.opportuniste,
        description: '',
        accounts: const [
          PatrimoineAccount(
            id: 'inv-btc-binance',
            name: 'BTC',
            valeur: 4000,
            plusValueAbs: 500,
            plusValuePercent: 14,
          ),
          PatrimoineAccount(
            id: 'inv-btc-coinbase',
            name: 'BTC',
            valeur: 2000,
            plusValueAbs: 200,
            plusValuePercent: 11,
          ),
        ],
      );
      // `allocationByInvestment` : la fusion par ticker
      // (`buildRealCategoriesByInvestment`) — une seule ligne "BTC" au
      // montant sommé (4000 + 2000).
      const mergedBtc = [
        PatrimoineAccount(
          id: 'merged_BTC',
          name: 'BTC',
          valeur: 6000,
          plusValueAbs: 700,
          plusValuePercent: 13,
        ),
      ];

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryDetailScreen(
              category: cryptoCategory,
              amountVisibility: AmountVisibilityController(),
              allocationByAccount: const [],
              allocationByInvestment: mergedBtc,
              onAccountTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Par actif'));
      await tester.pumpAndSettle();

      expect(find.textContaining('BTC •'), findsOneWidget);
    },
  );

  testWidgets(
    'régression : l\'avatar d\'une position crypto connue de la police '
    '(BTC) affiche son logo réel avec fontPackage renseigné — sans lui, '
    'Flutter ne retrouve pas la police "CryptocurrencyIcons" du package et '
    'affiche un glyphe "non défini" (un gros point d\'interrogation) '
    'plutôt que le logo',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cryptoCategory = PatrimoineCategory(
        id: 'actifs_crypto',
        label: 'Crypto',
        icon: LucideIcons.bitcoin,
        color: const Color(0xFF000000),
        tier: AllocationTier.opportuniste,
        description: '',
        accounts: const [
          PatrimoineAccount(
            id: 'inv-btc',
            name: 'BTC',
            valeur: 4000,
            plusValueAbs: 500,
            plusValuePercent: 14,
            avatarCryptoSymbol: 'BTC',
          ),
        ],
      );

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryDetailScreen(
              category: cryptoCategory,
              amountVisibility: AmountVisibilityController(),
              onAccountTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final cryptoLogo = find.byWidgetPredicate(
        (w) => w is Icon && w.icon?.fontPackage == 'crypto_icons',
      );
      expect(cryptoLogo, findsOneWidget);
      expect(tester.widget<Icon>(cryptoLogo).icon?.fontFamily, 'CryptocurrencyIcons');
    },
  );

  testWidgets(
    'un ticker crypto inconnu de la police (sans logo) retombe sur les '
    'initiales, pas sur un glyphe cassé',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cryptoCategory = PatrimoineCategory(
        id: 'actifs_crypto',
        label: 'Crypto',
        icon: LucideIcons.bitcoin,
        color: const Color(0xFF000000),
        tier: AllocationTier.opportuniste,
        description: '',
        accounts: const [
          PatrimoineAccount(
            id: 'inv-avax',
            name: 'AVAX',
            valeur: 1000,
            plusValueAbs: 100,
            plusValuePercent: 10,
            avatarCryptoSymbol: 'AVAX',
          ),
        ],
      );

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: CategoryDetailScreen(
              category: cryptoCategory,
              amountVisibility: AmountVisibilityController(),
              onAccountTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon?.fontPackage == 'crypto_icons',
        ),
        findsNothing,
      );
      // `PatrimoineAccount.initials` (`initialsFor`) : un seul mot ne
      // garde qu'une lettre, contrairement à `Avatar.getInitials`.
      expect(find.text('A'), findsOneWidget);
    },
  );

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
              allocationByAccount: accounts,
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
              allocationByAccount: [account()],
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
    'catégorie de passif (prêt) : pas de colonnes Quantité/Cours ni '
    '"+/- value", ni en en-tête ni sur la ligne de compte — un prêt n\'a ni '
    'unité ni cours de marché, et la performance hors flux n\'a pas de sens '
    'pour une dette',
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
      expect(find.text('Évolution'), findsOneWidget);
      expect(find.text('+/- value'), findsNothing);
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

  group(
    'allocationSliceColor (dégradé des lignes d\'une même catégorie)',
    () {
      const base = Color(0xFF8B5CF6);

      test('la première ligne (index 0) garde exactement la couleur de base', () {
        expect(allocationSliceColor(base, 0), base);
      });

      test('chaque ligne suivante est un peu plus claire que la précédente', () {
        // On compare via la luminosité (HSLColor.lightness), plus fiable
        // qu'une comparaison de canaux bruts pour vérifier "plus clair".
        final l0 = HSLColor.fromColor(allocationSliceColor(base, 0)).lightness;
        final l1 = HSLColor.fromColor(allocationSliceColor(base, 1)).lightness;
        final l2 = HSLColor.fromColor(allocationSliceColor(base, 2)).lightness;
        expect(l1, greaterThan(l0));
        expect(l2, greaterThan(l1));
      });

      test(
        'plafonné avant le blanc pur — une catégorie avec de nombreuses '
        'lignes ne finit jamais par des couleurs blanches indiscernables '
        'du fond de la carte',
        () {
          // Avant le plafond (t = 0,16 × i non borné), la 10ᵉ ligne
          // (i = 9) atteignait déjà t = 1,44 > 1, donc du blanc pur.
          final farLine = allocationSliceColor(base, 9);
          final veryFarLine = allocationSliceColor(base, 30);

          expect(farLine, isNot(Colors.white));
          // Au-delà du plafond, toutes les lignes suivantes convergent
          // vers la même teinte la plus claire (pas de nouveau blanchiment
          // au-delà), plutôt que de continuer à blanchir indéfiniment.
          expect(veryFarLine, farLine);
        },
      );
    },
  );

  group('colonne "+/- value" (PnL period-aware, en plus d\'"Évolution")', () {
    testWidgets(
      'l\'en-tête affiche "+/- value" en plus de "Valeur"/"Évolution"',
      (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pump();

        expect(find.text('Valeur'), findsOneWidget);
        expect(find.text('Évolution'), findsOneWidget);
        expect(find.text('+/- value'), findsOneWidget);
      },
    );

    testWidgets(
      'une ligne compte affiche les euros de periodChangeFor/periodPnlFor '
      'pour la période sélectionnée (par défaut "Tout")',
      (tester) async {
        final accountWithPeriod = PatrimoineAccount(
          id: 'acc-1',
          name: 'PEA',
          valeur: 1000,
          plusValueAbs: 50,
          plusValuePercent: 5,
          periodChangeFor: (period) => period == DashboardPeriod.all
              ? (euros: 654.0, percent: 10.0)
              : (euros: 111.0, percent: 2.0),
          periodPnlFor: (period) => period == DashboardPeriod.all
              ? (euros: 321.0, percent: 8.0)
              : (euros: 222.0, percent: 1.5),
        );
        final categoryWithPeriod = PatrimoineCategory(
          id: 'actifs_actions_fonds',
          label: 'Actions & Fonds',
          icon: LucideIcons.trendingUp,
          color: const Color(0xFF000000),
          tier: AllocationTier.fondation,
          description: '',
          accounts: const [],
        );

        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: CategoryDetailScreen(
                category: categoryWithPeriod,
                amountVisibility: AmountVisibilityController(),
                allocationByAccount: [accountWithPeriod],
                onAccountTap: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // Défaut de `_periodIndex` (5, "Tout") : les colonnes reflètent le
        // scénario `DashboardPeriod.all` de la closure.
        expect(find.textContaining('654'), findsWidgets);
        expect(find.textContaining('321'), findsWidgets);
      },
    );

    testWidgets(
      'survoler l\'en-tête "Valeur" affiche son explication (bulle '
      'partagée — voir asset_table_header_cell_test.dart)',
      (tester) async {
        // Fenêtre de test agrandie : sinon l'en-tête du tableau, plus bas
        // que le graphique/la carte Allocation, tombe hors du viewport
        // 800x600 par défaut et n'est pas atteignable par le survol.
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildScreen());
        await tester.pump();

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();
        await gesture.moveTo(tester.getCenter(find.text('Valeur').first));

        final explanation = find.text(assetTableColumnExplanations['Valeur']!);
        for (var i = 0; i < 20 && explanation.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(explanation, findsOneWidget);
      },
    );
  });
}

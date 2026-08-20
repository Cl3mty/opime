import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/features/dashboard/category_detail_screen.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
    'sans onAccountOpen : menu "⋮" et chevrons de position inchangés',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byIcon(LucideIcons.ellipsisVertical), findsOneWidget);

      await tester.tap(find.text('PEA'));
      await tester.pumpAndSettle();

      // Un chevron par ligne cliquable : le compte (expand) + la position.
      expect(find.byIcon(LucideIcons.chevronRight), findsNWidgets(2));
    },
  );

  testWidgets(
    'avec onAccountOpen : chevron à la place du menu, pas de chevron sur '
    'la position, tap déclenche le callback',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      PatrimoineAccount? opened;
      await tester.pumpWidget(buildScreen(onAccountOpen: (a) => opened = a));
      await tester.pump();

      expect(find.byIcon(LucideIcons.ellipsisVertical), findsNothing);
      // Chevron d'expansion (leading) + chevron d'ouverture (trailing,
      // dernier dans l'arbre de la ligne) : le dernier est celui qui
      // déclenche onAccountOpen.
      expect(find.byIcon(LucideIcons.chevronRight), findsNWidgets(2));

      await tester.tap(find.byIcon(LucideIcons.chevronRight).last);
      await tester.pump();

      expect(opened?.id, 'acc-1');

      // Déplier le compte : la ligne de position n'a pas de chevron propre
      // (seuls les 2 de la ligne de compte restent).
      await tester.tap(find.text('PEA'));
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.chevronRight), findsNWidgets(2));
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
}

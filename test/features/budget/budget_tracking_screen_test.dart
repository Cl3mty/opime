import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/features/budget/budget_recurring_templates_models.dart';
import 'package:opime/features/budget/budget_recurring_templates_repository.dart';
import 'package:opime/features/budget/budget_tracking_screen.dart';
import 'package:opime/features/dashboard/widgets/allocation_hover_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

void main() {
  late Directory tempDir;

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// `BudgetTrackingScreen` lit son vault (`BudgetTrackingRepository`/
  /// `BudgetCategoriesRepository`) via de vrais appels `dart:io`, qui ne se
  /// résolvent pas de façon fiable sous un simple `tester.pump()` répété
  /// (zone `FakeAsync` de `testWidgets`, voir la documentation de
  /// `tester.runAsync`) — il faut laisser tourner l'event loop réel via
  /// `runAsync` avec de vraies pauses, en pompant à l'intérieur jusqu'à ce
  /// que l'écran ait fini de charger (repéré ici par l'apparition du
  /// premier "Ajouter").
  Future<void> pumpScreen(WidgetTester tester, {bool reuseVault = false}) async {
    if (!reuseVault) {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_budget_tracking_',
        );
      });
    }

    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: BudgetTrackingScreen(
            vaultPath: tempDir.path,
            amountVisibility: AmountVisibilityController(),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if (find.text('Ajouter').evaluate().isNotEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    expect(
      find.text('Ajouter'),
      findsWidgets,
      reason: 'le chargement du vault vide aurait dû se terminer',
    );
  }

  /// Le champ Budget d'une ligne nouvellement créée : unique sur tout
  /// l'écran tant qu'un seul item existe (les autres catégories démarrent
  /// vides, sans ligne — voir `_CategoryCard`), identifiable via son
  /// placeholder plutôt qu'un id généré (donc imprévisible dans un test).
  Finder findBudgetField() => find.byWidgetPredicate((widget) {
    if (widget is! TextField) return false;
    final placeholder = widget.placeholder;
    return placeholder is shadcn.Text && placeholder.data == 'Budget';
  });

  Finder findRealiteField() => find.byWidgetPredicate((widget) {
    if (widget is! TextField) return false;
    final placeholder = widget.placeholder;
    return placeholder is shadcn.Text && placeholder.data == 'Réalité';
  });

  /// Le donut de la carte Répartition — identifiable par le nom de son
  /// painter (privé à `budget_tracking_screen.dart`, donc comparé par nom
  /// de type plutôt que référencé directement depuis ce fichier de test).
  Finder findDistributionDonut() => find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_DonutPainter',
  );

  Finder findIconButton(IconData icon) => find.byWidgetPredicate((widget) {
    if (widget is! IconButton) return false;
    final child = widget.icon;
    return child is Icon && child.icon == icon;
  });

  bool isEnabled(WidgetTester tester, Finder finder) =>
      tester.widget<IconButton>(finder).onPressed != null;

  testWidgets(
    'une expression arithmétique tapée dans une cellule Budget est '
    'calculée en direct et reflétée dans les totaux',
    (tester) async {
      await pumpScreen(tester);

      // Ajoute une ligne dans REVENUS (premier "Ajouter" du haut de page).
      await tester.tap(find.text('Ajouter').first);
      await tester.pump();

      final budgetField = findBudgetField();
      expect(budgetField, findsOneWidget);

      await tester.enterText(budgetField, '40+10');
      await tester.pump();

      // Le total "TOTAL" de la carte REVENUS (et le sommaire) reflètent
      // 50 dès que l'expression devient valide, sans attendre de quitter
      // le champ.
      expect(find.text('50 €'), findsWidgets);
    },
  );

  testWidgets(
    'une expression incomplète ne remet pas le montant à 0 pendant la '
    'frappe ; le champ affiche le résultat calculé (2 décimales) une fois '
    'quitté, puis réaffiche la formule tapée en sélection si on le '
    'reprend, pour permettre de la corriger',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Ajouter').first);
      await tester.pump();

      final budgetField = findBudgetField();
      await tester.enterText(budgetField, '40');
      await tester.pump();
      expect(find.text('40 €'), findsWidgets);

      // "40+" est incomplet : ne doit pas écraser les 40 déjà propagés
      // (une autre catégorie, elle, affiche légitimement "0 €" — seul le
      // maintien de "40 €" pour REVENUS compte ici).
      await tester.enterText(budgetField, '40+');
      await tester.pump();
      expect(find.text('40 €'), findsWidgets);

      await tester.enterText(budgetField, '40+10');
      await tester.pump();
      expect(find.text('50 €'), findsWidgets);

      // Quitter le champ (perte du focus) réévalue et réaffiche le
      // résultat calculé, avec 2 décimales, comme un tableur qui remplace
      // une formule par son résultat.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      final controller = tester.widget<TextField>(budgetField).controller!;
      expect(controller.text, '50.00');

      // Reprendre le focus réaffiche la formule d'origine (pas "50.00"),
      // sélectionnée en entier — prête à être corrigée ou remplacée.
      await tester.tap(budgetField);
      await tester.pump();
      expect(controller.text, '40+10');
      expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
    },
  );

  testWidgets(
    'Répartition : survoler le donut isole la section (tooltip label + '
    'pourcentage), même comportement que la carte Allocation du Dashboard',
    (tester) async {
      await pumpScreen(tester);

      // Ajoute une ligne dans FACTURES (2e "Ajouter") avec un montant
      // Réalité : seule ligne du mois, elle occupe 100 % de la
      // Répartition (Factures/Dépenses/Invest·Épargne/Projets/Dettes).
      await tester.tap(find.text('Ajouter').at(1));
      await tester.pump();
      await tester.enterText(findRealiteField(), '500');
      await tester.pump();

      expect(find.byType(AllocationHoverTooltip), findsNothing);

      final donut = findDistributionDonut();
      expect(donut, findsOneWidget);
      final size = tester.getSize(donut);
      final center = tester.getCenter(donut);
      final radius = math.min(size.width, size.height) / 2 - 4;
      // À l'intérieur de la bande de survol détectée par `_updateHover`
      // ([radius - strokeWidth, radius]) — voir sa doc dans
      // `budget_tracking_screen.dart`.
      final onRing = center - Offset(0, radius - 5);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: onRing);
      await tester.pump();
      await gesture.moveTo(onRing);
      await tester.pump();

      expect(find.byType(AllocationHoverTooltip), findsOneWidget);
      final tooltip = tester.widget<AllocationHoverTooltip>(
        find.byType(AllocationHoverTooltip),
      );
      expect(tooltip.label, 'Factures');
      expect(tooltip.percent, 100);

      // Sortir du donut fait disparaître la bulle.
      await gesture.moveTo(const Offset(0, 0));
      await tester.pump();
      expect(find.byType(AllocationHoverTooltip), findsNothing);
    },
  );

  testWidgets(
    'la formule tapée dans une cellule reste consultable après avoir '
    'quitté puis rouvert la page (pas seulement pendant la session en '
    'cours) — persistée avec le résultat, pas juste gardée en mémoire',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Ajouter').first);
      await tester.pump();
      await tester.enterText(findBudgetField(), '40+10');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Laisse le temps à l'écriture disque (déclenchée sans être
      // attendue par `_update`) de se terminer avant de démonter l'écran.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );

      // Quitte la page (démonte tout l'écran, donc son état en mémoire —
      // simule une navigation ailleurs dans l'app) puis y revient sur le
      // même vault (donc le même mois).
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpScreen(tester, reuseVault: true);

      final budgetField = findBudgetField();
      expect(budgetField, findsOneWidget);
      // Au repos, seul le résultat est affiché.
      expect(find.text('50 €'), findsWidgets);

      // Sélectionner la cellule doit encore montrer la décomposition du
      // calcul ("40+10"), pas seulement son résultat — c'est précisément
      // ce qu'un remontage complet du widget faisait perdre avant que la
      // formule ne soit persistée dans `TrackingItem`.
      await tester.tap(budgetField);
      await tester.pump();
      final controller = tester.widget<TextField>(budgetField).controller!;
      expect(controller.text, '40+10');
    },
  );

  testWidgets(
    'quitter la cellule persiste la vraie formule sur disque, pas le '
    'résultat calculé qui vient de la remplacer à l\'écran — remplacer '
    '"40+10" par "50,00" au repos redéclenche onChanged (shadcn_flutter '
    'notifie tout changement de texte du controller, y compris '
    'programmatique) : sans garde-fou, ce second appel écrase la vraie '
    'formule juste persistée par "50,00"',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Ajouter').first);
      await tester.pump();
      await tester.enterText(findBudgetField(), '40+10');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      final now = DateTime.now();
      final path =
          '${tempDir.path}/budget/tracking/'
          '${now.year}_${now.month.toString().padLeft(2, '0')}.json';
      var fileContent = '';
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          final file = File(path);
          if (await file.exists()) {
            fileContent = await file.readAsString();
            if (fileContent.contains('budgetFormula')) return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });

      expect(fileContent, contains('"budgetFormula": "40+10"'));
      expect(fileContent, isNot(contains('"budgetFormula": "50')));
    },
  );

  testWidgets(
    'Annuler/Rétablir : sans historique, les deux boutons sont désactivés',
    (tester) async {
      await pumpScreen(tester);

      expect(isEnabled(tester, findIconButton(LucideIcons.undo2)), isFalse);
      expect(isEnabled(tester, findIconButton(LucideIcons.redo2)), isFalse);
    },
  );

  testWidgets(
    'supprimer une ligne puis Annuler la restitue telle quelle (nom, '
    'montant, formule) — le cas d\'usage visé : une suppression accidentelle',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Ajouter').first);
      await tester.pump();
      await tester.enterText(findBudgetField(), '40+10');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text('50 €'), findsWidgets);

      await tester.tap(find.byIcon(LucideIcons.trash2));
      await tester.pump();
      expect(findBudgetField(), findsNothing);
      expect(find.text('50 €'), findsNothing);

      final undoButton = findIconButton(LucideIcons.undo2);
      expect(isEnabled(tester, undoButton), isTrue);
      await tester.tap(undoButton);
      await tester.pump();

      expect(findBudgetField(), findsOneWidget);
      expect(find.text('50 €'), findsWidgets);
      await tester.tap(findBudgetField());
      await tester.pump();
      expect(
        tester.widget<TextField>(findBudgetField()).controller!.text,
        '40+10',
        reason: 'la formule doit revenir avec le reste de la ligne',
      );

      // Rétablir refait la suppression.
      final redoButton = findIconButton(LucideIcons.redo2);
      expect(isEnabled(tester, redoButton), isTrue);
      await tester.tap(redoButton);
      await tester.pump();
      expect(findBudgetField(), findsNothing);
    },
  );

  testWidgets(
    'une nouvelle modification après un Annuler vide la pile Rétablir '
    '(comportement standard d\'un historique annuler/rétablir)',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Ajouter').first);
      await tester.pump();
      await tester.tap(findIconButton(LucideIcons.undo2));
      await tester.pump();
      expect(isEnabled(tester, findIconButton(LucideIcons.redo2)), isTrue);

      await tester.tap(find.text('Ajouter').first);
      await tester.pump();
      expect(isEnabled(tester, findIconButton(LucideIcons.redo2)), isFalse);
    },
  );

  testWidgets(
    'changer de mois repart sur un historique vide, même s\'il y avait '
    'des annulations possibles sur le mois précédent',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Ajouter').first);
      await tester.pump();
      expect(isEnabled(tester, findIconButton(LucideIcons.undo2)), isTrue);

      await tester.tap(find.byIcon(LucideIcons.chevronRight));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          if (find.text('Ajouter').evaluate().isNotEmpty) return;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });

      expect(isEnabled(tester, findIconButton(LucideIcons.undo2)), isFalse);
      expect(isEnabled(tester, findIconButton(LucideIcons.redo2)), isFalse);
    },
  );

  testWidgets(
    'raccourci clavier ⌘Z/Ctrl+Z : annule la dernière modification sans '
    'passer par le bouton',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Ajouter').first);
      await tester.pump();
      expect(findBudgetField(), findsOneWidget);

      final modifier = Platform.isMacOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();

      expect(findBudgetField(), findsNothing);
    },
  );

  /// La ligne du menu déroulant de catégorie portant [label] — un
  /// `MenuButton` dont le texte est [label], utilisé comme ancre pour
  /// retrouver ses boutons crayon/corbeille (`trailing`).
  Finder findCategoryMenuRow(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(MenuButton)).first;

  /// `showDropdown`/`showOverlay` (menu de catégorie) ne se résolvent pas
  /// de façon fiable sous un simple `pump()` — même pattern que
  /// `pumpScreen` : de vraies pauses via `runAsync`, en pompant jusqu'à ce
  /// que [ready] devienne vrai.
  Future<void> pumpUntil(WidgetTester tester, bool Function() ready) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if (ready()) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
  }

  /// Le contenu du menu déroulant de catégorie (une fois ouvert) vit dans
  /// l'`Overlay` racine de l'app, pas dans le `SingleChildScrollView` de
  /// l'écran — sa position résolue peut déborder du viewport de test selon
  /// où la ligne éditée se trouve dans la page, ce qu'aucun défilement
  /// préalable du contenu de la page ne corrige (l'overlay ne fait pas
  /// partie de ce qui défile). Plutôt que de dépendre d'un tap
  /// géométriquement valide, on invoque directement les callbacks des
  /// widgets concernés — la même technique déjà en place ailleurs dans ce
  /// dépôt pour du contenu difficile à hit-tester dans un overlay (voir
  /// `test/features/notifications/news_panel_test.dart`).
  Future<void> tapGestureDetectorNear(WidgetTester tester, String label) async {
    final gd = tester.widget<GestureDetector>(
      find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first,
    );
    gd.onTap!();
    await tester.pump();
  }

  /// Un vrai tap sur une `MenuButton` appelle `onPressed` PUIS, si
  /// `autoClose` (par défaut), `MenuGroupData.closeAll()` (voir
  /// `_MenuButtonState` dans le package shadcn_flutter — la fermeture n'est
  /// pas un simple effet de bord de `onPressed`, il faut la déclencher
  /// explicitement pour reproduire fidèlement ce qu'un tap ferait).
  Future<void> pressCategoryMenuRow(WidgetTester tester, String label) async {
    final context = tester.element(find.text(label));
    final row = tester.widget<MenuButton>(findCategoryMenuRow(label));
    row.onPressed!(context);
    Data.maybeOf<MenuGroupData>(context)?.closeAll();
    // La fermeture est animée : plusieurs pumps sont nécessaires pour que
    // l'overlay soit effectivement retiré de l'arbre de widgets.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pressIconButton(WidgetTester tester, Finder finder) async {
    tester.widget<IconButton>(finder).onPressed!();
    await tester.pump();
  }

  testWidgets(
    'catégories (Factures/Dépenses) : renommer une catégorie via le crayon '
    'du picker met aussi à jour l\'étiquette déjà affichée sur les lignes '
    'qui l\'utilisaient, sans devoir la resélectionner',
    (tester) async {
      await pumpScreen(tester);

      // Ajoute une ligne dans FACTURES (2e "Ajouter") et lui assigne la
      // catégorie par défaut "Assurance".
      await tester.tap(find.text('Ajouter').at(1));
      await tester.pump();
      await tapGestureDetectorNear(tester, 'Catégorie');
      await pumpUntil(tester, () => find.text('Assurance').evaluate().isNotEmpty);
      await pressCategoryMenuRow(tester, 'Assurance');
      await pumpUntil(tester, () => find.text('Catégorie').evaluate().isEmpty);
      expect(find.text('Assurance'), findsOneWidget);

      // Rouvre le picker (chip affiche maintenant "Assurance") et renomme
      // la catégorie via le crayon plutôt que de la resélectionner.
      await tapGestureDetectorNear(tester, 'Assurance');
      await pumpUntil(
        tester,
        () => findIconButton(LucideIcons.pencil).evaluate().isNotEmpty,
      );
      final pencil = find.descendant(
        of: findCategoryMenuRow('Assurance'),
        matching: findIconButton(LucideIcons.pencil),
      );
      await pressIconButton(tester, pencil);

      final editField = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'Assurance',
      );
      expect(editField, findsOneWidget);
      await tester.enterText(editField, 'Assurances');
      await pressIconButton(tester, findIconButton(LucideIcons.check));
      await pumpUntil(tester, () => find.text('Assurances').evaluate().isNotEmpty);

      // La liste de catégories a été renommée...
      expect(find.text('Assurances'), findsOneWidget);
      // ...et la ligne qui portait "Assurance" affiche maintenant
      // "Assurances" sans action supplémentaire.
      expect(find.text('Assurance'), findsNothing);
    },
  );

  testWidgets(
    'catégories (Factures/Dépenses) : supprimer une catégorie via la '
    'corbeille la retire du picker et vide l\'étiquette des lignes qui '
    'l\'utilisaient (repassent en "non catégorisé")',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Ajouter').at(1));
      await tester.pump();
      await tapGestureDetectorNear(tester, 'Catégorie');
      await pumpUntil(tester, () => find.text('Abonnements').evaluate().isNotEmpty);
      await pressCategoryMenuRow(tester, 'Abonnements');
      await pumpUntil(tester, () => find.text('Catégorie').evaluate().isEmpty);
      expect(find.text('Abonnements'), findsOneWidget);

      await tapGestureDetectorNear(tester, 'Abonnements');
      await pumpUntil(
        tester,
        () => findIconButton(LucideIcons.trash2).evaluate().isNotEmpty,
      );
      final trash = find.descendant(
        of: findCategoryMenuRow('Abonnements'),
        matching: findIconButton(LucideIcons.trash2),
      );
      await pressIconButton(tester, trash);
      await pumpUntil(tester, () => find.text('Catégorie').evaluate().isNotEmpty);

      // La ligne repasse sur le placeholder "Catégorie" : plus aucune
      // trace d'"Abonnements" nulle part sur l'écran.
      expect(find.text('Catégorie'), findsOneWidget);
      expect(find.text('Abonnements'), findsNothing);
    },
  );

  testWidgets(
    'lignes récurrentes : le bouton dédié de la carte REVENUS ouvre son '
    'dialogue de gestion',
    (tester) async {
      await pumpScreen(tester);

      await pressIconButton(tester, findIconButton(LucideIcons.repeat).first);
      await pumpUntil(
        tester,
        () => find
            .text('Aucune ligne récurrente pour l\'instant.')
            .evaluate()
            .isNotEmpty,
      );

      expect(find.text('Lignes récurrentes — REVENUS'), findsOneWidget);
      expect(
        find.text('Aucune ligne récurrente pour l\'instant.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'lignes récurrentes : en ajouter une puis l\'appliquer crée une '
    'nouvelle ligne dans le mois courant',
    (tester) async {
      await pumpScreen(tester);

      await pressIconButton(tester, findIconButton(LucideIcons.repeat).first);
      await pumpUntil(
        tester,
        () => find
            .text('Aucune ligne récurrente pour l\'instant.')
            .evaluate()
            .isNotEmpty,
      );

      await tester.enterText(find.byType(TextField).first, 'Salaire');
      await tester.enterText(find.byType(TextField).at(1), '2500');
      await pressIconButton(tester, findIconButton(LucideIcons.plus).last);
      // "Salaire" seul est ambigu : le champ nom fraîchement tapé contient
      // aussi ce texte tant qu'il n'a pas été vidé par `_add()` — attendre
      // la disparition du texte d'état vide est un signal univoque que la
      // liste des templates (pas juste le champ de saisie) contient bien
      // la nouvelle ligne.
      await pumpUntil(
        tester,
        () => find
            .text('Aucune ligne récurrente pour l\'instant.')
            .evaluate()
            .isEmpty,
      );
      expect(
        find.text('Aucune ligne récurrente pour l\'instant.'),
        findsNothing,
      );
      expect(findIconButton(LucideIcons.trash2), findsOneWidget);

      final applyButton = tester.widget<PrimaryButton>(
        find.ancestor(
          of: find.text('Appliquer maintenant'),
          matching: find.byType(PrimaryButton),
        ),
      );
      expect(
        applyButton.onPressed,
        isNotNull,
        reason: 'le bouton "Appliquer maintenant" ne devrait pas être désactivé',
      );
      await tester.tap(find.text('Appliquer maintenant'));
      await pumpUntil(
        tester,
        () => find.text('Lignes récurrentes — REVENUS').evaluate().isEmpty,
      );
      expect(
        find.text('Lignes récurrentes — REVENUS'),
        findsNothing,
        reason: 'le dialogue devrait être refermé après "Appliquer maintenant"',
      );

      // Le dialogue est refermé, la ligne "Salaire" existe désormais dans
      // le mois courant.
      expect(find.text('Salaire'), findsOneWidget);

      // Laisse le temps à l'écriture disque (déclenchée sans être attendue
      // par `_update`) de se terminer avant de démonter l'écran — même
      // précaution que le test de persistance des formules plus haut.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );

      // Quitte la page puis y revient sur le même vault : si la ligne
      // n'était que dans l'état en mémoire (jamais réellement persistée),
      // elle disparaîtrait ici.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpScreen(tester, reuseVault: true);

      expect(find.text('Salaire'), findsOneWidget);
    },
  );

  testWidgets(
    'un mois neuf avec des lignes récurrentes déjà enregistrées affiche la '
    'relance, et "Ajouter" les applique toutes en une fois',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_budget_tracking_',
        );
        final templatesRepo = BudgetRecurringTemplatesRepository(
          tempDir.path,
        );
        await templatesRepo.add(
          RecurringTemplate(
            name: 'Loyer',
            amount: 900,
            section: BudgetSection.facture,
          ),
        );
        await templatesRepo.add(
          RecurringTemplate(
            name: 'Salaire',
            amount: 2500,
            section: BudgetSection.revenue,
          ),
        );
      });

      await pumpScreen(tester, reuseVault: true);

      expect(
        find.textContaining('lignes récurrentes disponibles'),
        findsOneWidget,
      );
      expect(find.text('Loyer'), findsNothing);

      await tester.tap(find.text('Ajouter au mois'));
      await pumpUntil(tester, () => find.text('Loyer').evaluate().isNotEmpty);

      expect(find.text('Loyer'), findsOneWidget);
      expect(find.text('Salaire'), findsOneWidget);
      expect(
        find.textContaining('lignes récurrentes disponibles'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'un mois neuf sans ligne récurrente enregistrée n\'affiche aucune '
    'relance',
    (tester) async {
      await pumpScreen(tester);

      expect(
        find.textContaining('lignes récurrentes disponibles'),
        findsNothing,
      );
      expect(
        find.textContaining('ligne récurrente disponible'),
        findsNothing,
      );
    },
  );
}

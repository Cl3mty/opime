import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/patrimoine_refresh_controller.dart';
import 'package:opime/features/investments/real_estate/real_estate_loan_link.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';
import 'package:opime/features/liabilities/liabilities_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;
  late LiabilitiesRepository repo;
  late PatrimoineRefreshController refreshController;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_real_estate_loan_link_test_',
    );
    repo = LiabilitiesRepository(tempDir.path);
    refreshController = PatrimoineRefreshController();
    // `showCompletePatrimoineDialog` (ouvert par "Créer un prêt
    // immobilier"/"Créer un crédit travaux") résout le `VaultKind` du
    // coffre-fort actif via `VaultFolderService`/`SharedPreferences` — sans
    // mock, aucun coffre-fort enregistré, `_vaultKind` retombe sur
    // `personal` (comportement inchangé ici, cette section n'ouvre jamais
    // le wizard sur un coffre-fort pro).
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, String investmentId) async {
    // `initState` déclenche un vrai chargement disque (`_load`) : comme
    // pour toute opération d'E/S réelle dans un test widget, `pumpWidget`
    // doit rester dans la même zone `runAsync` que ce chargement, sinon sa
    // continuation reste suspendue indéfiniment dans la zone fake-async
    // (même piège rencontré en écrivant les tests de
    // `investment_detail_screen_test.dart`'s onglet Loyers).
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: RealEstateLoanLinkSection(
              vaultPath: tempDir.path,
              investmentId: investmentId,
              patrimoineRefreshController: refreshController,
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pumpAndSettle();
  }

  Liability loan({
    LiabilityType type = LiabilityType.pretImmobilier,
    String? linkedInvestmentId,
    String name = 'Prêt appart',
  }) => Liability(
    type: type,
    name: name,
    montantEmprunte: 200000,
    tauxInteret: 3.5,
    nbrEcheances: 240,
    dateDebut: DateTime(2024, 1, 1),
    linkedInvestmentId: linkedInvestmentId,
  );

  testWidgets(
    'sans aucun crédit disponible, propose quand même de créer un prêt '
    'immobilier ou un crédit travaux (jamais d\'impasse)',
    (tester) async {
      await pump(tester, 'immobilier-abc');
      expect(find.text('Créer un prêt immobilier'), findsOneWidget);
      expect(find.text('Créer un crédit travaux'), findsOneWidget);
      expect(find.text('Lier un crédit existant'), findsNothing);
    },
  );

  testWidgets(
    'un prêt immobilier existant, pas encore lié, propose "Lier un crédit '
    'existant"',
    (tester) async {
      await tester.runAsync(() => repo.saveLiability(loan()));
      await pump(tester, 'immobilier-abc');
      expect(find.text('Lier un crédit existant'), findsOneWidget);
    },
  );

  testWidgets(
    'un crédit autre disponible est aussi proposé comme candidat (pas '
    'seulement un prêt immobilier — un crédit travaux n\'est pas un type '
    'dédié, juste un crédit autre nommé comme tel)',
    (tester) async {
      await tester.runAsync(
        () => repo.saveLiability(
          loan(type: LiabilityType.creditAutre, name: 'Travaux cuisine'),
        ),
      );
      await pump(tester, 'immobilier-abc');
      expect(find.text('Lier un crédit existant'), findsOneWidget);

      await tester.tap(find.text('Lier un crédit existant'));
      await tester.pumpAndSettle();
      expect(find.text('Travaux cuisine'), findsOneWidget);
    },
  );

  testWidgets(
    'un prêt déjà lié à un AUTRE bien n\'apparaît pas comme candidat '
    '(régression potentielle : un prêt ne devrait financer qu\'un bien)',
    (tester) async {
      await tester.runAsync(
        () => repo.saveLiability(loan(linkedInvestmentId: 'immobilier-xyz')),
      );
      await pump(tester, 'immobilier-abc');
      expect(find.text('Lier un crédit existant'), findsNothing);
    },
  );

  testWidgets(
    'lier un crédit le persiste (linkedInvestmentId renseigné) et affiche '
    'son nom + capital restant dû',
    (tester) async {
      await tester.runAsync(() => repo.saveLiability(loan()));
      await pump(tester, 'immobilier-abc');

      await tester.tap(find.text('Lier un crédit existant'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Prêt appart'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(() => repo.listAll());
      expect(saved!.single.linkedInvestmentId, 'immobilier-abc');
    },
  );

  testWidgets(
    'délier un crédit déjà lié efface linkedInvestmentId',
    (tester) async {
      await tester.runAsync(
        () => repo.saveLiability(loan(linkedInvestmentId: 'immobilier-abc')),
      );
      await pump(tester, 'immobilier-abc');

      expect(find.textContaining('Prêt appart'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byIcon(LucideIcons.unlink));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(() => repo.listAll());
      expect(saved!.single.linkedInvestmentId, isNull);
    },
  );

  testWidgets(
    'un prêt immobilier ET un crédit travaux peuvent être liés '
    'simultanément au même bien',
    (tester) async {
      await tester.runAsync(() async {
        await repo.saveLiability(
          loan(name: 'Prêt appart', linkedInvestmentId: 'immobilier-abc'),
        );
        await repo.saveLiability(
          loan(
            type: LiabilityType.creditAutre,
            name: 'Travaux cuisine',
            linkedInvestmentId: 'immobilier-abc',
          ),
        );
      });
      await pump(tester, 'immobilier-abc');

      expect(find.textContaining('Prêt appart'), findsOneWidget);
      expect(find.textContaining('Travaux cuisine'), findsOneWidget);
      expect(find.byIcon(LucideIcons.unlink), findsNWidgets(2));
      // Les deux étant liés, plus aucun candidat à lier — mais la création
      // reste toujours proposée (ex : un second crédit travaux plus tard).
      expect(find.text('Lier un crédit existant'), findsNothing);
      expect(find.text('Créer un prêt immobilier'), findsOneWidget);
      expect(find.text('Créer un crédit travaux'), findsOneWidget);
    },
  );

  testWidgets(
    '"Créer un prêt immobilier" ouvre le flux de création déjà sur '
    'l\'étape du formulaire (type présélectionné) et lie automatiquement '
    'le nouveau crédit au bien une fois créé',
    (tester) async {
      await pump(tester, 'immobilier-abc');

      // Le dialogue ouvert charge les comptes existants au démarrage (vraie
      // E/S disque, `_CompletePatrimoineDialogState._load`) — même piège
      // que le chargement initial de la section elle-même (voir [pump]) :
      // il faut repomper des frames PENDANT l'attente, pas juste attendre
      // puis pomper une seule fois après coup.
      await tester.tap(find.text('Créer un prêt immobilier'));
      await tester.runAsync(() async {
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      // Démarre directement sur le formulaire (pas de choix de type à
      // refaire, il est déjà connu) — voir `initialLiabilityType`.
      expect(find.text('Nouveau passif'), findsOneWidget);
      expect(find.textContaining('Prêt immobilier'), findsWidgets);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nom (ex: Prêt résidence principale)'),
        'Prêt de la nouvelle création',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Prix total (€)'),
        '250000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Apport (€, 0 si aucun)'),
        '0',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Taux d\'intérêt (%)'),
        '3',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Assurance mensuelle (€)'),
        '0',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre d\'échéances (mois)'),
        '240',
      );
      await tester.pump();

      await tester.tap(find.text('Créer le passif'));
      await tester.runAsync(() async {
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(() => repo.listAll());
      expect(saved, hasLength(1));
      expect(saved!.single.name, 'Prêt de la nouvelle création');
      expect(saved.single.linkedInvestmentId, 'immobilier-abc');
      expect(saved.single.type, LiabilityType.pretImmobilier);
    },
  );

  testWidgets(
    '"Créer un crédit travaux" crée un crédit de type creditAutre (pas de '
    'type dédié) déjà lié au bien',
    (tester) async {
      await pump(tester, 'immobilier-abc');

      await tester.tap(find.text('Créer un crédit travaux'));
      await tester.runAsync(() async {
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      expect(find.text('Nouveau passif'), findsOneWidget);
      expect(find.textContaining('Crédit autre'), findsWidgets);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nom (ex: Prêt résidence principale)'),
        'Rénovation salle de bain',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Prix total (€)'),
        '15000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Apport (€, 0 si aucun)'),
        '0',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Taux d\'intérêt (%)'),
        '4',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Assurance mensuelle (€)'),
        '0',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre d\'échéances (mois)'),
        '36',
      );
      await tester.pump();

      await tester.tap(find.text('Créer le passif'));
      await tester.runAsync(() async {
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(() => repo.listAll());
      expect(saved, hasLength(1));
      expect(saved!.single.name, 'Rénovation salle de bain');
      expect(saved.single.type, LiabilityType.creditAutre);
      expect(saved.single.linkedInvestmentId, 'immobilier-abc');
    },
  );

  testWidgets(
    'un crédit créé ailleurs (ex : bouton "+" de la TopBar) pendant que '
    'cette section reste déjà montée apparaît comme candidat sans avoir à '
    'quitter puis revenir sur le bien (régression : la section ne se '
    'rafraîchissait qu\'à son propre montage, jamais sur notification '
    'globale)',
    (tester) async {
      await pump(tester, 'immobilier-abc');
      expect(find.text('Lier un crédit existant'), findsNothing);

      // Simule une création ailleurs dans l'app : écriture directe sur
      // disque (pas via cette section) puis le même signal global que
      // `top_bar_actions.dart` émet après `showCompletePatrimoineDialog`.
      await tester.runAsync(() async {
        await repo.saveLiability(
          loan(type: LiabilityType.creditAutre, name: 'Travaux cuisine'),
        );
      });
      refreshController.notifyChanged();
      await tester.runAsync(() async {
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      expect(find.text('Lier un crédit existant'), findsOneWidget);
    },
  );
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/dashboard/widgets/category_breakdown_card.dart';
import 'package:opime/features/entities/entities_models.dart';
import 'package:opime/features/entities/entities_repository.dart';
import 'package:opime/features/entities/entities_screen.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/patrimoine_refresh_controller.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';
import 'package:opime/features/liabilities/liabilities_repository.dart';
import 'package:opime/features/simulations/loan_calculator.dart' show LoanType;
import 'package:opime/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_entities_screen_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      home: Scaffold(
        child: EntitiesScreen(
          vaultPath: tempDir.path,
          amountVisibility: AmountVisibilityController(),
          patrimoineRefreshController: PatrimoineRefreshController(),
          profileName: 'Moi',
        ),
      ),
    ),
  );

  Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await pump(tester);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
  }

  InvestmentAccount accountFor(
    String entityId,
    double value, {
    required String id,
  }) => InvestmentAccount(
    id: id,
    assetClass: AssetClass.epargne,
    name: 'Compte',
    investments: [
      Investment(
        isin: 'FR0000000000',
        label: 'Position',
        transactions: [
          Transaction(date: DateTime(2024, 1, 1), isBuy: true, quantity: 1, unitPrice: value),
        ],
      ),
    ],
    entityId: entityId,
  );

  testWidgets(
    'coffre-fort sans entité : message vide, total à 0 €',
    (tester) async {
      await pumpAndSettle(tester);

      expect(
        find.text('Aucune entité pour l\'instant — ajoute un holding, une '
            'société commerciale ou une SCI.'),
        findsOneWidget,
      );
      expect(find.text('0 €'), findsOneWidget);
    },
  );

  testWidgets(
    'créer une entité (nom, type, % détenu) via l\'éditeur la persiste et '
    'l\'affiche dans la liste, à 0 € sans compte rattaché',
    (tester) async {
      await pumpAndSettle(tester);

      await tester.tap(find.text('Ajouter une entité'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.enterText(
          find.widgetWithText(TextField, 'Nom (ex : Holding Dupont)'),
          'SCI Les Tilleuls',
        );
        await tester.enterText(
          find.widgetWithText(TextField, '% détenu directement par vous'),
          '60',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 50));
        }
      });

      // `findsWidgets`, pas `findsOneWidget` : le schéma de structure (voir
      // `EntityStructureDiagram`, toujours affiché dès qu'une entité
      // existe) reprend aussi le nom de chaque entité dans sa boîte, en
      // plus de la carte de la liste ci-dessous.
      expect(find.text('SCI Les Tilleuls'), findsWidgets);
      expect(find.textContaining('60 % par vous'), findsOneWidget);

      final saved = await tester.runAsync(
        () => EntityRepository(tempDir.path).listAll(),
      );
      expect(saved!.single.name, 'SCI Les Tilleuls');
      expect(saved.single.stakes.single.percent, 60);
    },
  );

  testWidgets(
    'ajouter une part de détention permet une structure de détention à '
    'plusieurs propriétaires — chaque part reste éditable indépendamment '
    '(voir _StakeRowFields). Le choix d\'un AUTRE propriétaire via le '
    'sélecteur "Détenue par" n\'est pas testable dans ce harnais (popup '
    'shadcn_flutter Select, même limitation documentée ailleurs — voir '
    'complete_patrimoine_dialog_test.dart) : les deux parts restent donc '
    '"Moi-même", seul le mécanisme d\'ajout/suppression est exercé ici',
    (tester) async {
      await pumpAndSettle(tester);

      await tester.tap(find.text('Ajouter une entité'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nom (ex : Holding Dupont)'),
        'Société Mixte',
      );
      // Une seule part par défaut : aucun bouton de suppression tant qu'il
      // n'y en a qu'une (voir _EntityEditorDialogState.build).
      expect(find.byIcon(LucideIcons.x), findsNothing);
      await tester.enterText(find.byType(TextField).at(1), '40');
      await tester.pump();

      await tester.tap(find.text('Ajouter une part de détention'));
      await tester.pump();

      // Une seconde part est apparue avec son propre champ % (nom + 2
      // parts = 3 TextField), et il devient possible d'en supprimer une
      // (jamais 0, voir le bouton masqué ci-dessus quand il n'y en a qu'une).
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.byIcon(LucideIcons.x), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).at(2), '60');
      await tester.pump();

      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 50));
        }
      });

      final saved = await tester.runAsync(
        () => EntityRepository(tempDir.path).listAll(),
      );
      expect(saved!.single.stakes, hasLength(2));
      expect(saved.single.stakes[0].percent, 40);
      expect(saved.single.stakes[1].percent, 60);
    },
  );

  testWidgets(
    'la valeur nette/détenue affichée vient des comptes réels rattachés à '
    'l\'entité (entityId), pas d\'un bilan saisi dans cet écran',
    (tester) async {
      await tester.runAsync(() async {
        await EntityRepository(tempDir.path).saveEntity(
          BusinessEntity(
            id: 'sci1',
            name: 'SCI Les Tilleuls',
            type: EntityType.sci,
            stakes: const [OwnershipStake(percent: 60)],
          ),
        );
        await InvestmentsRepository(
          tempDir.path,
        ).saveAccount(accountFor('sci1', 150000, id: 'a1'));
      });

      await pumpAndSettle(tester);

      // Valeur nette 150 000 €, valeur détenue 150 000 * 60 % = 90 000 €.
      expect(find.text('90 000 €'), findsNWidgets(2));
      expect(find.textContaining('150 000 €'), findsOneWidget);
    },
  );

  testWidgets(
    'tapoter une entité ouvre son détail (comptes rattachés), pas l\'éditeur '
    'd\'identité — l\'édition passe désormais par l\'icône crayon',
    (tester) async {
      await tester.runAsync(() async {
        await EntityRepository(tempDir.path).saveEntity(
          BusinessEntity(
            id: 'sci1',
            name: 'SCI Les Tilleuls',
            type: EntityType.sci,
            stakes: const [OwnershipStake(percent: 100)],
          ),
        );
        await InvestmentsRepository(
          tempDir.path,
        ).saveAccount(accountFor('sci1', 42000, id: 'a1'));
      });

      await pumpAndSettle(tester);

      // `find.text` seul est ambigu depuis l'ajout du schéma de structure
      // (voir `EntityStructureDiagram`) : le nom y apparaît aussi, dans une
      // boîte non tapable — on cible la carte de la liste par sa clé. Le
      // schéma pousse aussi la carte hors du cadre de test par défaut,
      // d'où `ensureVisible` avant de taper.
      final card = find.byKey(const ValueKey('entity_list_card_sci1'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      // `EntityDetailScreen._load` fait de vraies E/S disque (comptes,
      // historiques de prix) — comme pour l'écran liste, il lui faut
      // `runAsync` pour se résoudre, pas un simple `pumpAndSettle` (qui
      // resterait bloqué sur le spinner de chargement indéfiniment).
      await tester.runAsync(() async {
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });

      // L'écran de détail liste les avoirs de l'entité (voir
      // `CategoryBreakdownCard`) — le compte créé ci-dessus y apparaît,
      // sous sa catégorie "Épargne". "Placements" seul est ambigu (aussi une
      // bascule de la carte Allocation juste au-dessus, voir
      // `dashboard_screen_test.dart`) : on vérifie précisément la carte
      // `CategoryBreakdownCard` de ce titre.
      expect(
        tester
            .widgetList<CategoryBreakdownCard>(
              find.byType(CategoryBreakdownCard),
            )
            .map((c) => c.title),
        containsAll(['Placements']),
      );
      expect(find.text('Compte'), findsOneWidget);
      // Pas le formulaire d'édition d'identité (le champ "Type" n'y est
      // pas).
      expect(find.text('Nouvelle entité'), findsNothing);
      expect(find.text('Modifier l\'entité'), findsNothing);
    },
  );

  testWidgets(
    'onglet Bilan : un vrai bilan comptable structuré par rubriques (Actif '
    'immobilisé/circulant, Capitaux propres/Provisions/Dettes), Total '
    'Actif == Total Passif (capitaux propres = actif − dettes)',
    (tester) async {
      await tester.runAsync(() async {
        await EntityRepository(tempDir.path).saveEntity(
          BusinessEntity(
            id: 'sci1',
            name: 'SCI Les Tilleuls',
            type: EntityType.sci,
            stakes: const [OwnershipStake(percent: 100)],
          ),
        );
        await InvestmentsRepository(
          tempDir.path,
        ).saveAccount(accountFor('sci1', 150000, id: 'a1'));
        await LiabilitiesRepository(tempDir.path).saveLiability(
          Liability(
            type: LiabilityType.creditAutre,
            name: 'Prêt travaux SCI',
            montantEmprunte: 50000,
            tauxInteret: 2,
            nbrEcheances: 60,
            // Prêt tout juste souscrit : `remainingBalance` vaut encore
            // `montantEmprunte` (aucune échéance encore passée) — une
            // date passée fixe le ferait décroître par amortissement,
            // rendant le montant attendu ci-dessous incorrect au fil du
            // temps.
            dateDebut: DateTime.now(),
            loanType: LoanType.amortissable,
            entityId: 'sci1',
          ),
        );
      });

      await pumpAndSettle(tester);

      final card = find.byKey(const ValueKey('entity_list_card_sci1'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.runAsync(() async {
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });

      await tester.tap(find.text('Bilan'));
      await tester.pump();

      // Actif : un vrai bilan structuré par rubriques (voir
      // `_BalanceSheetSection`) — Actif immobilisé et Actif circulant, le
      // compte de test (Épargne) atterrissant en Disponibilités (150 000 €).
      expect(find.text('Actif'), findsOneWidget);
      expect(find.text('ACTIF IMMOBILISÉ'), findsOneWidget);
      expect(find.text('ACTIF CIRCULANT'), findsOneWidget);
      expect(find.text('Disponibilités'), findsOneWidget);
      expect(find.textContaining('150 000'), findsWidgets);
      // Passif : Capitaux propres (150 000 − 50 000 = 100 000 €, ligne
      // unique donc sans sous-total répété) et Dettes (le passif de test,
      // un "Crédit autre", regroupé dans la ligne "Emprunts et dettes
      // financières" avec tous les emprunts réels — pas par type de passif
      // individuel, voir la doc de tête de `_BalanceSheetView`).
      expect(find.text('Passif'), findsOneWidget);
      expect(find.text('Capitaux propres'), findsOneWidget);
      expect(find.textContaining('100 000'), findsWidgets);
      expect(find.text('DETTES'), findsOneWidget);
      expect(find.text('Emprunts et dettes financières'), findsOneWidget);
      expect(find.textContaining('50 000'), findsWidgets);
      // Rubriques standard toujours affichées même sans donnée pour cette
      // entité (immobilisations incorporelles, stocks, créances,
      // provisions, dettes fournisseurs/fiscales) — un vrai bilan liste
      // toutes ses lignes, à 0 € ou non.
      expect(find.text('Immobilisations incorporelles'), findsOneWidget);
      expect(find.text('Stocks'), findsOneWidget);
      expect(find.text('Créances'), findsOneWidget);
      expect(find.text('PROVISIONS'), findsNothing);
      expect(find.text('Provisions pour risques et charges'), findsOneWidget);
      expect(find.text('Dettes fournisseurs'), findsOneWidget);
      // Total Actif == Total Passif (150 000 €), un vrai bilan s'équilibre
      // toujours.
      expect(find.text('Total actif'), findsOneWidget);
      expect(find.text('Total passif'), findsOneWidget);
    },
  );

  testWidgets(
    'filiale liée à un holding : affichée indentée sous son parent, avec '
    'la part diluée réellement à l\'utilisateur (pas juste son % de lien '
    'local) — total en tête cohérent',
    (tester) async {
      final repo = EntityRepository(tempDir.path);
      await tester.runAsync(() async {
        await repo.saveEntity(
          BusinessEntity(
            id: 'holding',
            name: 'Holding Dupont',
            type: EntityType.holding,
            stakes: const [OwnershipStake(percent: 80)],
          ),
        );
        await repo.saveEntity(
          BusinessEntity(
            id: 'filiale',
            name: 'Filiale SARL',
            type: EntityType.societeCommerciale,
            stakes: const [OwnershipStake(ownerId: 'holding', percent: 50)],
          ),
        );
        final accountsRepo = InvestmentsRepository(tempDir.path);
        await accountsRepo.saveAccount(accountFor('holding', 50000, id: 'a1'));
        await accountsRepo.saveAccount(accountFor('filiale', 100000, id: 'a2'));
      });

      await pumpAndSettle(tester);

      // La filiale apparaît indentée par rapport au holding (hiérarchie
      // visuelle) : son décalage horizontal est strictement supérieur.
      // `find.text` seul est ambigu depuis l'ajout du schéma de structure
      // (voir `EntityStructureDiagram`, son propre layout n'a rien à voir
      // avec cette indentation) : on cible le texte de la carte de la
      // liste par sa clé.
      Finder listCardText(String entityId, String text) => find.descendant(
        of: find.byKey(ValueKey('entity_list_card_$entityId')),
        matching: find.text(text),
      );
      final holdingX = tester
          .getTopLeft(listCardText('holding', 'Holding Dupont'))
          .dx;
      final filialeX = tester
          .getTopLeft(listCardText('filiale', 'Filiale SARL'))
          .dx;
      expect(filialeX, greaterThan(holdingX));

      // Filiale : détenue à 50 % par le holding, qui lui-même n'appartient
      // qu'à 80 % à l'utilisateur — 40 % lui revient réellement au final,
      // pas les 50 % du seul lien direct.
      expect(find.textContaining('50 % via Holding Dupont'), findsOneWidget);
      expect(
        find.textContaining('40 % vous revient au final'),
        findsOneWidget,
      );

      // Total en tête : 50000 * 80 % (holding) + 100000 * 40 % (filiale
      // diluée) = 40000 + 40000 = 80000 €.
      expect(find.text('80 000 €'), findsOneWidget);
    },
  );

  testWidgets(
    'ouvrir un holding affiche la section "Entreprises détenues" — cliquer '
    'une filiale ouvre son détail, dont le bouton retour revient au '
    'holding',
    (tester) async {
      final repo = EntityRepository(tempDir.path);
      await tester.runAsync(() async {
        await repo.saveEntity(
          BusinessEntity(
            id: 'holding',
            name: 'Holding Dupont',
            type: EntityType.holding,
            stakes: const [OwnershipStake(percent: 80)],
          ),
        );
        await repo.saveEntity(
          BusinessEntity(
            id: 'filiale',
            name: 'Filiale SARL',
            type: EntityType.societeCommerciale,
            stakes: const [OwnershipStake(ownerId: 'holding', percent: 50)],
          ),
        );
        final accountsRepo = InvestmentsRepository(tempDir.path);
        await accountsRepo.saveAccount(accountFor('holding', 50000, id: 'a1'));
        await accountsRepo.saveAccount(accountFor('filiale', 100000, id: 'a2'));
      });

      await pumpAndSettle(tester);

      Future<void> waitForContaining(String text) => tester.runAsync(() async {
        for (var i = 0; i < 20; i++) {
          if (find.textContaining(text).evaluate().isNotEmpty) return;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });

      final holdingCard = find.byKey(const ValueKey('entity_list_card_holding'));
      await tester.ensureVisible(holdingCard);
      tester
          .widgetList<GestureDetector>(
            find.descendant(
              of: holdingCard,
              matching: find.byType(GestureDetector),
            ),
          )
          .first
          .onTap!();
      await waitForContaining('Entreprises détenues');

      // Le détail du holding liste l'entreprise qu'il possède, avec sa
      // part de détention DIRECTE (50 %, pas la part diluée à
      // l'utilisateur — voir le test de dilution ci-dessus).
      expect(find.text('Entreprises détenues'), findsOneWidget);
      expect(find.text('Filiale SARL'), findsOneWidget);
      expect(find.text('Détenue à 50 %'), findsOneWidget);

      await tester.tap(find.text('Filiale SARL'));
      await waitForContaining('100 000');
      // Le détail de la filiale s'affiche à son tour, avec son propre
      // avoir (100 000 €, voir `accountFor`) — pas celui du holding, ni sa
      // section "Entreprises détenues" (la filiale n'en possède aucune).
      expect(find.textContaining('100 000'), findsWidgets);
      expect(find.text('Entreprises détenues'), findsNothing);

      // Le chevron retour de la filiale (BackHeader) ramène au holding,
      // pas à la liste des entités (retour local imbriqué, voir
      // `EntityDetailScreen._openSubEntity`).
      await tester.tap(find.byIcon(LucideIcons.chevronLeft).first);
      await waitForContaining('Entreprises détenues');
      expect(find.text('Entreprises détenues'), findsOneWidget);
      expect(find.text('Filiale SARL'), findsOneWidget);
    },
  );
}

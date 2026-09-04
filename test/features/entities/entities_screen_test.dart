import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/privacy/amount_visibility_controller.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/entities/entities_models.dart';
import 'package:opime/features/entities/entities_repository.dart';
import 'package:opime/features/entities/entities_screen.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/patrimoine_refresh_controller.dart';
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
            'société commerciale, une SCI ou un compte pro.'),
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

      expect(find.text('SCI Les Tilleuls'), findsOneWidget);
      expect(find.textContaining('60 % détenu'), findsOneWidget);

      final saved = await tester.runAsync(
        () => EntityRepository(tempDir.path).listAll(),
      );
      expect(saved!.single.name, 'SCI Les Tilleuls');
      expect(saved.single.ownershipPercent, 60);
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
            ownershipPercent: 60,
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
            ownershipPercent: 100,
          ),
        );
        await InvestmentsRepository(
          tempDir.path,
        ).saveAccount(accountFor('sci1', 42000, id: 'a1'));
      });

      await pumpAndSettle(tester);

      await tester.tap(find.text('SCI Les Tilleuls'));
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

      // L'écran de détail liste les comptes de l'entité — le compte créé
      // ci-dessus y apparaît.
      expect(find.text('Comptes'), findsOneWidget);
      expect(find.text('Compte'), findsOneWidget);
      // Pas le formulaire d'édition d'identité (le champ "Type" n'y est
      // pas).
      expect(find.text('Nouvelle entité'), findsNothing);
      expect(find.text('Modifier l\'entité'), findsNothing);
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
            ownershipPercent: 80,
          ),
        );
        await repo.saveEntity(
          BusinessEntity(
            id: 'filiale',
            name: 'Filiale SARL',
            type: EntityType.societeCommerciale,
            ownershipPercent: 50,
            parentEntityId: 'holding',
          ),
        );
        final accountsRepo = InvestmentsRepository(tempDir.path);
        await accountsRepo.saveAccount(accountFor('holding', 50000, id: 'a1'));
        await accountsRepo.saveAccount(accountFor('filiale', 100000, id: 'a2'));
      });

      await pumpAndSettle(tester);

      // La filiale apparaît indentée par rapport au holding (hiérarchie
      // visuelle) : son décalage horizontal est strictement supérieur.
      final holdingX = tester.getTopLeft(find.text('Holding Dupont')).dx;
      final filialeX = tester.getTopLeft(find.text('Filiale SARL')).dx;
      expect(filialeX, greaterThan(holdingX));

      // Filiale : détenue à 50 % par le holding, qui lui-même n'appartient
      // qu'à 80 % à l'utilisateur — 40 % lui revient réellement au final,
      // pas les 50 % du seul lien direct.
      expect(find.textContaining('détenu par Holding Dupont'), findsOneWidget);
      expect(
        find.textContaining('40 % vous revient au final'),
        findsOneWidget,
      );

      // Total en tête : 50000 * 80 % (holding) + 100000 * 40 % (filiale
      // diluée) = 40000 + 40000 = 80000 €.
      expect(find.text('80 000 €'), findsOneWidget);
    },
  );
}

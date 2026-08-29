import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investment_detail_screen.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/real_estate/rent_models.dart';
import 'package:opime/features/investments/widgets/transaction_widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets(
    'modifier le libellé d\'un bien immobilier reporte tous les autres '
    'champs (surface, adresse, estimation, exclusion du patrimoine) — '
    'régression : une reconstruction manuelle de Investment dans '
    '_commitEditInvestment les effaçait silencieusement',
    (tester) async {
      final investment = Investment(
        isin: 'immobilier-xyz789',
        label: 'Appartement Lyon 6e',
        realEstateType: RealEstateType.locationLongueDureeNue,
        surfaceM2: 65,
        addressLabel: '12 rue de la République, Lyon',
        addressCityCode: '69386',
        addressLat: 45.76,
        addressLon: 4.84,
        estimatedPricePerSqm: 4200,
        estimatedValueAt: DateTime(2026, 1, 1),
        excludedFromPatrimoine: true,
        transactions: [
          Transaction(date: DateTime(2020, 1, 1), isBuy: true, quantity: 1, unitPrice: 250000),
        ],
      );
      final account = InvestmentAccount(
        assetClass: AssetClass.immobilier,
        envelope: AccountEnvelope.residenceSecondaire,
        name: 'Biens immobiliers',
        investments: [investment],
      );
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_investment_detail_test',
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: InvestmentDetailView(
              vaultPath: tempDir.path,
              account: account,
              investment: investment,
              hidden: false,
              onBack: () {},
              onChanged: () async {},
              profileName: 'Moi',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Une transaction existe sur cette position : son propre "⋮" de
      // ligne s'ajoute à celui du menu de la position — celui de la
      // position est le premier dans l'arbre (en-tête, avant la liste des
      // transactions).
      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      // Immobilier : un seul champ dans le formulaire d'édition, le
      // libellé (pas d'identifiant éditable, voir InvestmentEditForm).
      await tester.enterText(
        find.byType(TextField).first,
        'Appartement Lyon 6e (rénové)',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      final savedInvestment = saved!.single.investments.single;
      expect(savedInvestment.label, 'Appartement Lyon 6e (rénové)');
      expect(savedInvestment.surfaceM2, 65);
      expect(savedInvestment.addressLabel, '12 rue de la République, Lyon');
      expect(savedInvestment.addressCityCode, '69386');
      expect(savedInvestment.estimatedPricePerSqm, 4200);
      expect(savedInvestment.estimatedValueAt, DateTime(2026, 1, 1));
      expect(savedInvestment.excludedFromPatrimoine, isTrue);
      expect(savedInvestment.realEstateType, RealEstateType.locationLongueDureeNue);
    },
  );

  testWidgets(
    'modifier une position "Autres" et vider son identifiant saisi par '
    'erreur régénère un identifiant plutôt que de bloquer l\'enregistrement '
    '(régression : le champ vide était auparavant simplement rejeté)',
    (tester) async {
      final investment = Investment(
        isin: 'REF-123',
        label: 'Rolex Submariner',
        transactions: const [],
      );
      final account = InvestmentAccount(
        assetClass: AssetClass.autres,
        envelope: AccountEnvelope.montre,
        name: 'Montres',
        investments: [investment],
      );
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_investment_detail_test',
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: InvestmentDetailView(
              vaultPath: tempDir.path,
              account: account,
              investment: investment,
              hidden: false,
              onBack: () {},
              onChanged: () async {},
              profileName: 'Moi',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aucune transaction sur cette position : le seul "⋮" présent est
      // celui du menu de la position elle-même.
      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      // Libellé, puis identifiant (voir le nouvel ordre des champs) : on
      // vide l'identifiant saisi par erreur.
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), '');
      // L'enregistrement écrit réellement sur disque (`dart:io`) : sans
      // `runAsync`, cette écriture asynchrone ne se résout pas dans la zone
      // fake-async du test — voir le même motif ailleurs dans la suite
      // (ex : `stock_account_screen_test.dart`).
      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      final savedInvestment = saved!.single.investments.single;
      expect(savedInvestment.label, 'Rolex Submariner');
      expect(isGeneratedIdentifier(savedInvestment.isin), isTrue);
    },
  );

  testWidgets(
    'un identifiant auto-généré (voir isGeneratedIdentifier) ne s\'affiche '
    'jamais tel quel : ni en lecture, ni préremplissant le champ en édition '
    '(régression : fuite d\'un id technique interne, ex. "autre-a1b2c3")',
    (tester) async {
      final investment = Investment(
        isin: placeholderIsinFor(AssetClass.autres),
        label: 'Rolex Submariner',
        transactions: const [],
      );
      final account = InvestmentAccount(
        assetClass: AssetClass.autres,
        envelope: AccountEnvelope.montre,
        name: 'Montres',
        investments: [investment],
      );
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_investment_detail_test',
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: InvestmentDetailView(
              vaultPath: tempDir.path,
              account: account,
              investment: investment,
              hidden: false,
              onBack: () {},
              onChanged: () async {},
              profileName: 'Moi',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Lecture : l'id technique n'apparaît nulle part à l'écran.
      expect(find.text(investment.isin), findsNothing);

      // Édition : le champ identifiant s'ouvre vide, pas préremplit avec
      // l'id technique.
      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      final identifierField = tester.widget<TextField>(
        find.byType(TextField).at(1),
      );
      expect(identifierField.controller?.text, isEmpty);
    },
  );

  testWidgets(
    'la date d\'une transaction reste centrée tant qu\'aucune transaction '
    'de la position n\'a de commentaire, et repasse à gauche dès qu\'une '
    'seule en a un (voir TransactionRow.centerDate)',
    (tester) async {
      final investment = Investment(
        isin: 'FR0012345678',
        label: 'TotalEnergies',
        transactions: [
          Transaction(
            date: DateTime(2024, 1, 10),
            isBuy: true,
            quantity: 5,
            unitPrice: 50,
          ),
          Transaction(
            date: DateTime(2024, 2, 20),
            isBuy: true,
            quantity: 3,
            unitPrice: 55,
            note: 'Renforcement position',
          ),
        ],
      );
      final account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO',
        bankName: 'Bourse Direct',
        investments: [investment],
      );
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_investment_detail_test',
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: InvestmentDetailView(
              vaultPath: tempDir.path,
              account: account,
              investment: investment,
              hidden: false,
              onBack: () {},
              onChanged: () async {},
              profileName: 'Moi',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Une des deux transactions porte un commentaire : les deux lignes
      // basculent sur une date alignée à gauche, pas seulement celle qui
      // porte le commentaire.
      final rows = tester.widgetList<TransactionRow>(
        find.byType(TransactionRow),
      );
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.centerDate == false), isTrue);
    },
  );

  testWidgets('sans aucun commentaire sur la position, la date reste centrée', (
    tester,
  ) async {
    final investment = Investment(
      isin: 'FR0012345678',
      label: 'TotalEnergies',
      transactions: [
        Transaction(
          date: DateTime(2024, 1, 10),
          isBuy: true,
          quantity: 5,
          unitPrice: 50,
        ),
      ],
    );
    final account = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      bankName: 'Bourse Direct',
      investments: [investment],
    );
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_investment_detail_test',
      );
      await InvestmentsRepository(tempDir.path).saveAccount(account);
    });

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: InvestmentDetailView(
            vaultPath: tempDir.path,
            account: account,
            investment: investment,
            hidden: false,
            onBack: () {},
            onChanged: () async {},
            profileName: 'Moi',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = tester.widget<TransactionRow>(find.byType(TransactionRow));
    expect(row.centerDate, isTrue);
  });

  group('onglets Loyers/Travaux/Documents (immobilier uniquement)', () {
    testWidgets(
      'un bien immobilier affiche les onglets Loyers/Travaux/Documents, '
      'un investissement non immobilier ne les affiche pas',
      (tester) async {
        final property = Investment(
          isin: 'immobilier-abc',
          label: 'Appartement Lyon 6e',
          realEstateType: RealEstateType.locationLongueDureeNue,
          transactions: [
            Transaction(date: DateTime(2020, 1, 1), isBuy: true, quantity: 1, unitPrice: 250000),
          ],
        );
        final immobilierAccount = InvestmentAccount(
          assetClass: AssetClass.immobilier,
          envelope: AccountEnvelope.residenceSecondaire,
          name: 'Biens immobiliers',
          investments: [property],
        );
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_investment_detail_test',
          );
          await InvestmentsRepository(tempDir.path).saveAccount(immobilierAccount);
        });

        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: InvestmentDetailView(
                vaultPath: tempDir.path,
                account: immobilierAccount,
                investment: property,
                hidden: false,
                onBack: () {},
                onChanged: () async {},
                profileName: 'Moi',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // "Loyers" apparaît deux fois : le libellé de l'onglet et l'en-tête
        // de son contenu (l'onglet "Loyers" est actif par défaut).
        expect(find.text('Loyers'), findsNWidgets(2));
        expect(find.text('Travaux'), findsOneWidget);
        expect(find.text('Documents'), findsOneWidget);
      },
    );

    testWidgets(
      'ajouter une période de loyer la persiste sur le bien et l\'affiche '
      'dans la liste',
      (tester) async {
        final property = Investment(
          isin: 'immobilier-abc',
          label: 'Appartement Lyon 6e',
          realEstateType: RealEstateType.locationLongueDureeNue,
          transactions: const [],
        );
        final account = InvestmentAccount(
          assetClass: AssetClass.immobilier,
          envelope: AccountEnvelope.residenceSecondaire,
          name: 'Biens immobiliers',
          investments: [property],
        );
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_investment_detail_test',
          );
          await InvestmentsRepository(tempDir.path).saveAccount(account);
        });

        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: InvestmentDetailView(
                vaultPath: tempDir.path,
                account: account,
                investment: property,
                hidden: false,
                onBack: () {},
                onChanged: () async {},
                profileName: 'Moi',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Onglet "Loyers" déjà actif par défaut.
        expect(find.text('Aucun loyer suivi pour l\'instant.'), findsOneWidget);

        // L'ensemble ouverture + saisie + validation reste dans un seul
        // `runAsync` : `_openAddDialog`'s `await showDialog(...)` doit être
        // évalué dans la même zone réelle (pas fake-async) que la suite de
        // sa continuation — sinon la sauvegarde disque déclenchée après la
        // fermeture du dialogue (dans `onAdd`) reste suspendue indéfiniment,
        // capturée dans la zone fake-async où l'`await` a été initialement
        // évalué (régression rencontrée en écrivant ce test).
        await tester.runAsync(() async {
          await tester.tap(find.text('Ajouter une période'));
          await tester.pump();
          await tester.pump();

          await tester.enterText(find.byType(TextField).first, '800');
          await tester.pump();

          await tester.tap(find.widgetWithText(PrimaryButton, 'Ajouter'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();

        // Le dialogue est bien refermé (un seul "Ajouter une période"
        // restant : le bouton). L'écran lui-même ne se rafraîchit pas tout
        // seul ici (`onChanged` est un no-op dans ce test, comme pour les
        // autres tests de ce fichier) : la vérification porte sur ce qui a
        // été persisté sur disque, pas sur le rendu.
        expect(find.text('Ajouter une période'), findsOneWidget);

        final saved = await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).listAll(),
        );
        final savedProperty = saved!.single.investments.single;
        expect(savedProperty.rentPeriods, hasLength(1));
        expect(savedProperty.rentPeriods.single.amountDue, 800);
        expect(savedProperty.rentPeriods.single.isPaid, isFalse);
      },
    );

    testWidgets(
      'le bouton "Télécharger la quittance" n\'apparaît que sur une '
      'période marquée payée (une quittance suppose un paiement reçu, '
      'voir RentPeriod.isPaid)',
      (tester) async {
        final property = Investment(
          isin: 'immobilier-abc',
          label: 'Appartement Lyon 6e',
          realEstateType: RealEstateType.locationLongueDureeNue,
          transactions: const [],
          rentPeriods: [
            RentPeriod(
              periodStart: DateTime(2026, 3, 1),
              periodEnd: DateTime(2026, 3, 31),
              amountDue: 750,
              tenantName: 'Jean Dupont',
            ),
            RentPeriod(
              periodStart: DateTime(2026, 4, 1),
              periodEnd: DateTime(2026, 4, 30),
              amountDue: 750,
              amountPaid: 750,
              paidAt: DateTime(2026, 4, 2),
              tenantName: 'Jean Dupont',
            ),
          ],
        );
        final account = InvestmentAccount(
          assetClass: AssetClass.immobilier,
          envelope: AccountEnvelope.residenceSecondaire,
          name: 'Biens immobiliers',
          investments: [property],
        );
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_investment_detail_test',
          );
          await InvestmentsRepository(tempDir.path).saveAccount(account);
        });

        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: InvestmentDetailView(
                vaultPath: tempDir.path,
                account: account,
                investment: property,
                hidden: false,
                onBack: () {},
                onChanged: () async {},
                profileName: 'Camille Martin',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Deux périodes affichées, une seule payée : un seul bouton de
        // téléchargement doit apparaître (pas de PDF pour un loyer impayé).
        expect(find.byIcon(LucideIcons.fileDown), findsOneWidget);
      },
    );
  });
}

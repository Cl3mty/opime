import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/stock_account_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;
  late InvestmentAccount account;

  Future<void> setUpVault(WidgetTester tester) async {
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_stock_account_test',
      );
      final repo = InvestmentsRepository(tempDir.path);
      account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO Bourso',
        bankName: 'Bourso',
        investments: [
          Investment(
            isin: 'US0378331005',
            label: 'Apple',
            symbol: 'AAPL',
            transactions: [
              Transaction(
                date: DateTime(2024, 1, 10),
                isBuy: true,
                quantity: 5,
                unitPrice: 150,
              ),
            ],
          ),
        ],
      );
      await repo.saveAccount(account);
    });
  }

  Widget buildScreen() {
    return ShadcnApp(
      home: Scaffold(
        child: StockAccountScreen(
          vaultPath: tempDir.path,
          account: account,
          hidden: false,
          bankNames: const ['Bourso'],
          onBack: () {},
          onChanged: () {},
        ),
      ),
    );
  }

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('affiche la table des positions par défaut', (tester) async {
    await setUpVault(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Positions'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
  });

  testWidgets(
    'l\'onglet Transactions affiche l\'historique avec le nom de la position',
    (tester) async {
      await setUpVault(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.text('Transactions'));
      await tester.pump();

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Ajouter une transaction'), findsOneWidget);
    },
  );

  testWidgets('cliquer une position ouvre sa popup de détail', (tester) async {
    await setUpVault(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await tester.tap(find.text('Apple'));
    await tester.pump();

    // L'ISIN apparaît à la fois dans la table (derrière la popup) et dans
    // la popup elle-même — seule la stat "Quantité détenue" (sans cours
    // résolu ici, pas de TWR/MWR) est propre à la popup.
    expect(find.text('US0378331005'), findsWidgets);
    expect(find.text('Quantité détenue'), findsOneWidget);
  });

  testWidgets(
    'le "+" de l\'onglet Transactions crée une nouvelle position et sa '
    'première transaction',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO Bourso',
          bankName: 'Bourso',
          investments: const [],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.text('Transactions'));
      await tester.pump();
      await tester.tap(find.text('Ajouter une transaction'));
      await tester.pump();

      // Compte vide : le formulaire de nouvelle position (ISIN + libellé)
      // est déjà affiché par défaut, pas de sélection à faire. Ordre des
      // champs texte dans la popup : identifiant, libellé, quantité, prix.
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'FR0000131104');
      await tester.enterText(textFields.at(1), 'BNP Paribas');
      await tester.enterText(textFields.at(2), '3');
      await tester.enterText(textFields.at(3), '60');
      await tester.runAsync(() async {
        await tester.tap(find.text('Ajouter la transaction'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      final savedAccount = saved!.single;
      expect(savedAccount.investments, hasLength(1));
      final investment = savedAccount.investments.single;
      expect(investment.isin, 'FR0000131104');
      expect(investment.label, 'BNP Paribas');
      expect(investment.transactions, hasLength(1));
      expect(investment.transactions.single.quantity, 3);
      expect(investment.transactions.single.unitPrice, 60);
    },
  );

  testWidgets(
    'fonctionne aussi pour un compte crypto (nouveau format généralisé '
    'au-delà d\'Actions & Fonds)',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.crypto,
          name: 'Ledger',
          investments: [
            Investment(
              isin: 'BTC',
              label: 'BTC',
              transactions: [
                Transaction(
                  date: DateTime(2024, 3, 1),
                  isBuy: true,
                  quantity: 0.1,
                  unitPrice: 40000,
                ),
              ],
            ),
          ],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('BTC'), findsWidgets);

      await tester.tap(find.text('BTC').first);
      await tester.pump();
      expect(find.text('Quantité détenue'), findsOneWidget);
    },
  );

  testWidgets(
    'l\'import IBKR n\'apparaît dans le menu du compte que pour une '
    'enveloppe CTO',
    (tester) async {
      await setUpVault(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
      await tester.pump();
      expect(find.text('Importer un relevé (IBKR)'), findsOneWidget);
    },
  );

  testWidgets(
    'menu du compte : "Exclure du patrimoine" persiste le drapeau sur le '
    'compte entier',
    (tester) async {
      await setUpVault(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
      await tester.pumpAndSettle();
      expect(find.text('Exclure du patrimoine'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Exclure du patrimoine'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      expect(saved!.single.excludedFromPatrimoine, isTrue);
    },
  );

  testWidgets(
    'menu du compte : un compte déjà exclu propose "Réintégrer au '
    'patrimoine"',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO exclu',
          excludedFromPatrimoine: true,
          investments: const [],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
      await tester.pump();
      expect(find.text('Réintégrer au patrimoine'), findsOneWidget);
      expect(find.text('Exclure du patrimoine'), findsNothing);
    },
  );

  testWidgets(
    'l\'import IBKR n\'apparaît pas pour un compte Actions & Fonds en PEA',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.pea,
          name: 'PEA Bourso',
          bankName: 'Bourso',
          investments: const [],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
      await tester.pump();
      expect(find.text('Importer un relevé (IBKR)'), findsNothing);
    },
  );

  testWidgets(
    'un onglet Documents apparaît à côté de Positions/Transactions pour un '
    'compte Actions & Fonds, avec les documents généraux du compte',
    (tester) async {
      await setUpVault(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Documents'), findsOneWidget);
      await tester.tap(find.text('Documents'));
      await tester.pump();

      expect(find.text('Aucun document pour l\'instant.'), findsOneWidget);
    },
  );

  testWidgets(
    'pas d\'onglet Documents pour un compte métaux précieux (documents '
    'rattachés à une transaction, pas au compte)',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.metauxPrecieux,
          envelope: AccountEnvelope.coffrePersonnel,
          name: 'Coffre',
          investments: const [],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Positions'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Documents'), findsNothing);
    },
  );

  testWidgets(
    'un onglet Documents apparaît pour un compte "Autres" (montres, '
    'voitures de collection...), en plus des documents par transaction',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.autres,
          envelope: AccountEnvelope.montre,
          name: 'Montre',
          investments: const [],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.text('Documents'));
      await tester.pump();

      expect(find.text('Aucun document pour l\'instant.'), findsOneWidget);
    },
  );

  testWidgets(
    'la colonne "Cours" d\'un compte "Autres" affiche "—" sans cours '
    'manuel renseigné, puis le cours manuel une fois estimé',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.autres,
          envelope: AccountEnvelope.montre,
          name: 'Montre',
          investments: [
            Investment(
              isin: 'autre-1',
              label: 'Rolex Submariner',
              transactions: [
                Transaction(
                  date: DateTime(2022, 1, 1),
                  isBuy: true,
                  quantity: 1,
                  unitPrice: 8000,
                ),
              ],
            ),
          ],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Rolex Submariner'), findsOneWidget);
      expect(find.text('Cours'), findsOneWidget);
      // Sans cours manuel encore renseigné : "—" à la fois dans la colonne
      // Cours et dans la colonne +/- value (aucune plus-value calculable).
      expect(find.text('—'), findsWidgets);
    },
  );

  testWidgets(
    'la colonne "Cours" d\'un compte "Autres" affiche le cours manuel une '
    'fois renseigné, et la colonne "Valeur" ce cours × la quantité détenue '
    '(2 montres identiques)',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.autres,
          envelope: AccountEnvelope.montre,
          name: 'Montres',
          investments: [
            Investment(
              isin: 'autre-1',
              label: 'Rolex Submariner (paire)',
              manualPrice: 9500,
              manualPriceAt: DateTime(2026, 1, 1),
              transactions: [
                Transaction(
                  date: DateTime(2022, 1, 1),
                  isBuy: true,
                  quantity: 2,
                  unitPrice: 8000,
                ),
              ],
            ),
          ],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Cours : le cours manuel tel quel. Valeur : 9 500 × 2 = 19 000 €.
      expect(find.text('9 500 €'), findsOneWidget);
      expect(find.text('19 000 €'), findsOneWidget);
    },
  );

  testWidgets(
    'créer une transaction depuis la popup d\'une position Actions & '
    'Fonds propose d\'y attacher des documents',
    (tester) async {
      await setUpVault(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.text('Apple'));
      await tester.pump();
      await tester.tap(find.text('Ajouter une transaction'));
      await tester.pump();

      expect(find.text('Aucun document pour l\'instant.'), findsOneWidget);
    },
  );

  testWidgets(
    'créer une transaction pour une position existante depuis l\'onglet '
    'Transactions propose aussi d\'y attacher des documents',
    (tester) async {
      await setUpVault(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.text('Transactions'));
      await tester.pump();
      await tester.tap(find.text('Ajouter une transaction'));
      await tester.pump();

      // Le compte n'a qu'une position (Apple) : déjà sélectionnée par
      // défaut dans le menu déroulant "Position", pas besoin de la choisir.
      expect(find.text('Aucun document pour l\'instant.'), findsOneWidget);
    },
  );

  testWidgets(
    'modifier une transaction "Autres" existante depuis l\'onglet '
    'Transactions propose d\'y attacher un document a posteriori',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.autres,
          envelope: AccountEnvelope.montre,
          name: 'Montre',
          investments: [
            Investment(
              isin: 'autre-1',
              label: 'Rolex Submariner',
              transactions: [
                Transaction(
                  date: DateTime(2022, 1, 1),
                  isBuy: true,
                  quantity: 1,
                  unitPrice: 8000,
                ),
              ],
            ),
          ],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.text('Transactions'));
      await tester.pumpAndSettle();
      // Deux icônes "⋮" : celle du menu du compte, puis celle de la seule
      // ligne de transaction affichée.
      await tester.ensureVisible(
        find.byIcon(LucideIcons.ellipsisVertical).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      // "Documents" et "Aucun document pour l'instant." apparaissent aussi
      // dans l'onglet "Documents" du compte (monté en arrière-plan) — au
      // moins une occurrence suffit à confirmer que la section s'affiche
      // bien dans le formulaire d'édition de la transaction.
      expect(find.text('Documents'), findsWidgets);
      expect(find.text('Aucun document pour l\'instant.'), findsWidgets);
    },
  );

  testWidgets(
    'créer une toute nouvelle position depuis l\'onglet Transactions ne '
    'propose pas d\'y attacher des documents (elle n\'existe pas encore)',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO Bourso',
          bankName: 'Bourso',
          investments: const [],
        );
        await InvestmentsRepository(tempDir.path).saveAccount(account);
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.text('Transactions'));
      await tester.pump();
      await tester.tap(find.text('Ajouter une transaction'));
      await tester.pump();

      expect(find.text('Aucun document pour l\'instant.'), findsNothing);
    },
  );

  testWidgets('fonctionne aussi pour un compte épargne (position en devise)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_stock_account_test',
      );
      account = InvestmentAccount(
        assetClass: AssetClass.epargne,
        envelope: AccountEnvelope.livretA,
        name: 'Livret A',
        bankName: 'Boursorama',
        investments: [
          Investment(
            isin: 'EUR',
            label: 'EUR',
            transactions: [
              Transaction(
                date: DateTime(2024, 1, 1),
                isBuy: true,
                quantity: 1500,
                unitPrice: 1,
              ),
            ],
          ),
        ],
      );
      await InvestmentsRepository(tempDir.path).saveAccount(account);
    });

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(find.text('EUR'), findsWidgets);
  });
}

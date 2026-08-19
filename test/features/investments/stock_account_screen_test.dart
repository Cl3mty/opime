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

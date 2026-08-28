import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/widgets/account_transactions_tab.dart';
import 'package:opime/features/investments/widgets/transaction_widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    InvestmentAccount account, {
    String vaultPath = '/tmp/unused-in-this-test',
    Future<void> Function()? onChanged,
  }) {
    return tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: AccountTransactionsTab(
            vaultPath: vaultPath,
            account: account,
            hidden: false,
            onChanged: onChanged ?? () async {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'une paire vente/achat liée (arbitrage) se fusionne en une seule '
    'ArbitrageTransactionRow, les autres transactions restent des '
    'TransactionRow individuelles',
    (tester) async {
      final sourceInvestment = Investment(
        isin: 'FR0000131104',
        label: 'TotalEnergies',
        transactions: [
          Transaction(
            id: 'buy_initial',
            date: DateTime(2024, 1, 1),
            isBuy: true,
            quantity: 10,
            unitPrice: 50,
          ),
          Transaction(
            id: 'arb_sell',
            date: DateTime(2024, 6, 1),
            isBuy: false,
            quantity: 10,
            unitPrice: 60,
            type: TransactionType.arbitrage,
            linkedTransactionId: 'arb_buy',
          ),
        ],
      );
      final destInvestment = Investment(
        isin: 'FR0000120271',
        label: 'Air Liquide',
        transactions: [
          Transaction(
            id: 'arb_buy',
            date: DateTime(2024, 6, 1),
            isBuy: true,
            quantity: 4,
            unitPrice: 150,
            type: TransactionType.arbitrage,
            linkedTransactionId: 'arb_sell',
          ),
        ],
      );
      final account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.assuranceVie,
        name: 'AV',
        investments: [sourceInvestment, destInvestment],
      );

      await pump(tester, account);

      // Une seule ligne fusionnée pour la paire d'arbitrage...
      expect(find.byType(ArbitrageTransactionRow), findsOneWidget);
      expect(find.text('TotalEnergies → Air Liquide'), findsOneWidget);
      // ... et une seule ligne classique pour l'achat initial non lié.
      expect(find.byType(TransactionRow), findsOneWidget);

      // Les colonnes de date des deux types de ligne doivent partager la
      // même largeur réservée pour la colonne des montants (voir
      // `_amountsGroupWidth`) — sans quoi leurs dates ne s'alignent pas
      // verticalement dans la liste.
      final arbitrageDateX = tester
          .getTopLeft(find.text('01/06/2024'))
          .dx;
      final normalDateX = tester.getTopLeft(find.text('01/01/2024')).dx;
      expect(arbitrageDateX, normalDateX);
    },
  );

  testWidgets(
    'sans transaction, le message habituel reste affiché',
    (tester) async {
      await pump(
        tester,
        InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO',
          investments: const [],
        ),
      );

      expect(find.text('Aucune transaction pour l\'instant.'), findsOneWidget);
      expect(find.byType(ArbitrageTransactionRow), findsNothing);
      expect(find.byType(TransactionRow), findsNothing);
    },
  );

  group('Modifier l\'arbitrage', () {
    late Directory tempDir;
    late InvestmentsRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_account_transactions_tab_test_',
      );
      repo = InvestmentsRepository(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    testWidgets(
      'passe par un seul formulaire "Modifier l\'arbitrage" — les deux '
      'transactions restent liées et taguées arbitrage après enregistrement '
      '(pas le piège de deux éditions "Vente"/"Achat" séparées qui les '
      'détachait silencieusement)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sourceInvestment = Investment(
          isin: 'FR0000131104',
          label: 'TotalEnergies',
          transactions: [
            // Achat initial établissant la position, sans quoi l'arbitrage
            // "vendrait" une quantité jamais détenue (quantité négative).
            Transaction(
              id: 'buy_initial',
              date: DateTime(2024, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 40,
            ),
            Transaction(
              id: 'arb_sell',
              date: DateTime(2024, 6, 1),
              isBuy: false,
              quantity: 10,
              unitPrice: 60,
              type: TransactionType.arbitrage,
              linkedTransactionId: 'arb_buy',
            ),
          ],
        );
        final destInvestment = Investment(
          isin: 'FR0000120271',
          label: 'Air Liquide',
          transactions: [
            Transaction(
              id: 'arb_buy',
              date: DateTime(2024, 6, 1),
              isBuy: true,
              quantity: 4,
              unitPrice: 150,
              type: TransactionType.arbitrage,
              linkedTransactionId: 'arb_sell',
            ),
          ],
        );
        final account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.assuranceVie,
          name: 'AV',
          investments: [sourceInvestment, destInvestment],
        );
        await tester.runAsync(() => repo.saveAccount(account));

        var changedCount = 0;
        await pump(
          tester,
          account,
          vaultPath: tempDir.path,
          onChanged: () async {
            changedCount++;
          },
        );

        // Deux lignes désormais (la paire fusionnée + l'achat initial) :
        // la paire, plus récente, trie en premier.
        await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Modifier l\'arbitrage'));
        await tester.pumpAndSettle();

        // Un seul formulaire, pas deux — jamais "Modifier la vente"/
        // "Modifier l'achat" à choisir séparément. (Le libellé "TotalEnergies
        // → Air Liquide" apparaît deux fois : une fois sur la ligne fusionnée
        // en arrière-plan, une fois en sous-titre de ce formulaire.)
        expect(find.text('Modifier l\'arbitrage'), findsWidgets);
        expect(find.text('TotalEnergies → Air Liquide'), findsWidgets);

        // Change uniquement le prix de vente (index 1 : Quantité(0), Prix
        // de vente(1), Prix d'achat(2)).
        await tester.enterText(find.byType(TextField).at(1), '70');
        await tester.pump();

        await tester.runAsync(() async {
          await tester.tap(find.text('Enregistrer'));
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
          }
        });
        await tester.pumpAndSettle();

        expect(changedCount, 1);
        final all = await tester.runAsync(repo.listAll);
        final reloadedSource = all!.firstWhere((a) => a.id == account.id);
        final reloadedSell = reloadedSource.investments
            .firstWhere((i) => i.id == sourceInvestment.id)
            .transactions
            .firstWhere((t) => t.id == 'arb_sell');
        final reloadedBuy = reloadedSource.investments
            .firstWhere((i) => i.id == destInvestment.id)
            .transactions
            .single;

        // Toujours liées et taguées arbitrage — pas détachées en deux
        // transactions "Vente"/"Achat" ordinaires.
        expect(reloadedSell.type, TransactionType.arbitrage);
        expect(reloadedBuy.type, TransactionType.arbitrage);
        expect(reloadedSell.linkedTransactionId, reloadedBuy.id);
        expect(reloadedBuy.linkedTransactionId, reloadedSell.id);
        // La modification a bien pris (nouveau prix de vente, quantité
        // achetée recalculée en conséquence).
        expect(reloadedSell.unitPrice, 70);
        expect(reloadedBuy.quantity, (10 * 70) / 150);

        // La fusion reste effective après l'édition.
        expect(find.byType(ArbitrageTransactionRow), findsOneWidget);
      },
    );
  });
}

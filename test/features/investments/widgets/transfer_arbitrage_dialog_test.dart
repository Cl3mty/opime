import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/documents_section.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/widgets/transfer_arbitrage_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

void main() {
  late Directory tempDir;
  late InvestmentsRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_transfer_arbitrage_test_',
    );
    repo = InvestmentsRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Ouvre le dialogue via un bouton déclencheur — `showTransferDialog`/
  /// `showArbitrageDialog` appellent directement `showDialog`, il faut donc
  /// un `context` descendant d'un `Navigator`, fourni ici par un `Builder`.
  Widget buildTrigger({
    required bool transfer,
    required InvestmentAccount sourceAccount,
    required Investment sourceInvestment,
    required Future<void> Function() onChanged,
  }) {
    return ShadcnApp(
      home: Scaffold(
        child: Builder(
          builder: (context) => OutlineButton(
            onPressed: () => transfer
                ? showTransferDialog(
                    context,
                    vaultPath: tempDir.path,
                    sourceAccount: sourceAccount,
                    sourceInvestment: sourceInvestment,
                    onChanged: onChanged,
                  )
                : showArbitrageDialog(
                    context,
                    vaultPath: tempDir.path,
                    sourceAccount: sourceAccount,
                    sourceInvestment: sourceInvestment,
                    onChanged: onChanged,
                  ),
            child: const shadcn.Text('ouvrir'),
          ),
        ),
      ),
    );
  }

  /// Ouvre le dialogue et pompe jusqu'à ce que `ready()` soit vrai — le tap
  /// ET l'attente doivent partager le MÊME `runAsync` : `tester.tap`
  /// déclenche `initState`, qui en mode transfert lance un vrai appel
  /// `dart:io` (`InvestmentsRepository.listAll()`, voir `_loadAccounts`)
  /// de façon synchrone dans la zone active au moment du tap. Si ce tap a
  /// lieu HORS `runAsync`, le `Future` correspondant naît dans la zone
  /// fake-async du test et ne se résout jamais quel que soit le nombre de
  /// `runAsync` lancés ensuite pour l'attendre — deadlock garanti (10 min
  /// de timeout par test observés avant ce correctif). N'utilise pas non
  /// plus `pumpAndSettle` : le `CircularProgressIndicator` du chargement ne
  /// "s'installe" jamais tant que la vraie I/O n'a pas répondu.
  Future<void> openDialogAndWaitFor(
    WidgetTester tester,
    bool Function() ready,
  ) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('ouvrir'));
      for (var i = 0; i < 60; i++) {
        if (ready()) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pump();
  }

  Future<void> submitAndSettle(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(PrimaryButton, label));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  /// Relit l'état persisté après soumission — un vrai appel `dart:io` fait
  /// directement dans le corps du test (donc dans sa zone fake-async)
  /// n'aurait jamais résolu (même cause que dans [openDialogAndWaitFor]).
  Future<T> readAsync<T>(WidgetTester tester, Future<T> Function() read) =>
      tester.runAsync(read).then((value) => value as T);

  /// Le viewport de test par défaut (800x600) est plus bas que le contenu
  /// du dialogue (champs + explication + boutons) : le bouton de
  /// soumission se retrouve hors écran et `tap()` échoue au hit-test.
  /// L'app cible le desktop (fenêtres bien plus hautes) — élargir la
  /// surface de test reflète l'usage réel plutôt que de scroller
  /// manuellement jusqu'au bouton.
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Transfert', () {
    testWidgets(
      'nouvelle position sur le compte destination : PRU et quantité '
      'conservés, identité du titre reprise, transactions croisées',
      (tester) async {
        useLargeSurface(tester);
        final sourceInvestment = Investment(
          isin: 'FR0000131104',
          label: 'TotalEnergies',
          transactions: [
            Transaction(
              date: DateTime(2024, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 50,
            ),
          ],
        );
        final sourceAccount = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO A',
          investments: [sourceInvestment],
        );
        final destAccount = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.pea,
          name: 'PEA B',
          investments: const [],
        );
        await tester.runAsync(() async {
          await repo.saveAccount(sourceAccount);
          await repo.saveAccount(destAccount);
        });

        var changedCount = 0;
        await tester.pumpWidget(
          buildTrigger(
            transfer: true,
            sourceAccount: sourceAccount,
            sourceInvestment: sourceInvestment,
            onChanged: () async {
              changedCount++;
            },
          ),
        );
        // Un seul autre compte : présélectionné automatiquement, aucune
        // position de même ISIN dans le compte destination -> "+ Nouvelle
        // position" retenue par défaut avec ISIN/libellé pré-remplis.
        await openDialogAndWaitFor(
          tester,
          () => find.text('+ Nouvelle position').evaluate().isNotEmpty,
        );

        expect(find.text('PEA B'), findsOneWidget);

        await submitAndSettle(tester, 'Transférer');

        expect(changedCount, 1);
        final all = await readAsync(tester, repo.listAll);
        final reloadedSource = all.firstWhere((a) => a.id == sourceAccount.id);
        final reloadedDest = all.firstWhere((a) => a.id == destAccount.id);

        expect(reloadedSource.investments.single.quantityHeld, 0);
        final sellTxn = reloadedSource.investments.single.transactions.last;
        expect(sellTxn.isBuy, isFalse);
        expect(sellTxn.quantity, 10);
        expect(sellTxn.unitPrice, 50); // PRU d'origine : 500 / 10
        expect(sellTxn.type, TransactionType.transfer);

        expect(reloadedDest.investments, hasLength(1));
        final destInvestment = reloadedDest.investments.single;
        expect(destInvestment.isin, 'FR0000131104');
        expect(destInvestment.label, 'TotalEnergies');
        expect(destInvestment.quantityHeld, 10);
        expect(destInvestment.pru, 50); // PRU conservé, pas le cours du marché
        final buyTxn = destInvestment.transactions.single;
        expect(buyTxn.isBuy, isTrue);
        expect(buyTxn.type, TransactionType.transfer);
        expect(buyTxn.linkedTransactionId, sellTxn.id);
        expect(sellTxn.linkedTransactionId, buyTxn.id);
      },
    );

    testWidgets(
      'transfert partiel : la quantité restante sur la source est correcte',
      (tester) async {
        useLargeSurface(tester);
        final sourceInvestment = Investment(
          isin: 'FR0000131104',
          label: 'TotalEnergies',
          transactions: [
            Transaction(
              date: DateTime(2024, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 50,
            ),
          ],
        );
        final sourceAccount = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO A',
          investments: [sourceInvestment],
        );
        final destAccount = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.pea,
          name: 'PEA B',
          investments: const [],
        );
        await tester.runAsync(() async {
          await repo.saveAccount(sourceAccount);
          await repo.saveAccount(destAccount);
        });

        await tester.pumpWidget(
          buildTrigger(
            transfer: true,
            sourceAccount: sourceAccount,
            sourceInvestment: sourceInvestment,
            onChanged: () async {},
          ),
        );
        await openDialogAndWaitFor(
          tester,
          () => find.text('+ Nouvelle position').evaluate().isNotEmpty,
        );

        // Quantité (premier TextField du dialogue) : 10 -> 4, transfert
        // partiel.
        await tester.enterText(find.byType(TextField).first, '4');
        await tester.pump();
        await submitAndSettle(tester, 'Transférer');

        final all = await readAsync(tester, repo.listAll);
        final reloadedSource = all.firstWhere((a) => a.id == sourceAccount.id);
        final reloadedDest = all.firstWhere((a) => a.id == destAccount.id);
        expect(reloadedSource.investments.single.quantityHeld, 6);
        expect(reloadedDest.investments.single.quantityHeld, 4);
      },
    );

    testWidgets(
      'position destination existante de même ISIN : présélectionnée, '
      'la transaction s\'ajoute à la position existante',
      (tester) async {
        useLargeSurface(tester);
        final sourceInvestment = Investment(
          isin: 'FR0000131104',
          label: 'TotalEnergies',
          transactions: [
            Transaction(
              date: DateTime(2024, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 50,
            ),
          ],
        );
        final sourceAccount = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO A',
          investments: [sourceInvestment],
        );
        final existingDestInvestment = Investment(
          isin: 'FR0000131104',
          label: 'TotalEnergies',
          transactions: [
            Transaction(
              date: DateTime(2023, 1, 1),
              isBuy: true,
              quantity: 5,
              unitPrice: 40,
            ),
          ],
        );
        final destAccount = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.pea,
          name: 'PEA B',
          investments: [existingDestInvestment],
        );
        await tester.runAsync(() async {
          await repo.saveAccount(sourceAccount);
          await repo.saveAccount(destAccount);
        });

        await tester.pumpWidget(
          buildTrigger(
            transfer: true,
            sourceAccount: sourceAccount,
            sourceInvestment: sourceInvestment,
            onChanged: () async {},
          ),
        );
        // Présélection automatique de la position existante de même ISIN :
        // le libellé apparaît dans le `Select`, "+ Nouvelle position" n'est
        // pas affiché (les champs d'identité restent masqués).
        await openDialogAndWaitFor(
          tester,
          () => find.text('TotalEnergies').evaluate().length >= 2,
        );
        expect(find.text('+ Nouvelle position'), findsNothing);

        await submitAndSettle(tester, 'Transférer');

        final all = await readAsync(tester, repo.listAll);
        final reloadedDest = all.firstWhere((a) => a.id == destAccount.id);
        // Toujours une seule position (pas de doublon créé), avec les deux
        // transactions (l'historique existant + l'arrivée du transfert).
        expect(reloadedDest.investments, hasLength(1));
        expect(reloadedDest.investments.single.transactions, hasLength(2));
        expect(reloadedDest.investments.single.quantityHeld, 15);
      },
    );
  });

  group('Arbitrage', () {
    testWidgets(
      'le produit de la vente finance exactement l\'achat (montant vente '
      '== montant achat), les deux positions dans le même compte',
      (tester) async {
        useLargeSurface(tester);
        final sourceInvestment = Investment(
          isin: 'FR0000131104',
          label: 'Fonds Euro',
          manualPrice: 60,
          transactions: [
            Transaction(
              date: DateTime(2024, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 50,
            ),
          ],
        );
        final account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.assuranceVie,
          name: 'AV C',
          investments: [sourceInvestment],
        );
        await tester.runAsync(() async {
          await repo.saveAccount(account);
        });

        await tester.pumpWidget(
          buildTrigger(
            transfer: false,
            sourceAccount: account,
            sourceInvestment: sourceInvestment,
            onChanged: () async {},
          ),
        );
        // Pas d'appel réseau/disque en mode arbitrage (pas de sélecteur de
        // compte) : la section "+ Nouvelle position" est déjà affichée par
        // défaut au premier pump, mais ISIN/libellé restent VIDES (le
        // pré-remplissage automatique est réservé au transfert, où le titre
        // ne change pas) — il faut les saisir manuellement.
        await openDialogAndWaitFor(
          tester,
          () => find.text('+ Nouvelle position').evaluate().isNotEmpty,
        );
        expect(find.text('+ Nouvelle position'), findsOneWidget);
        final textFields = find.byType(TextField);
        // Ordre du formulaire : Quantité(0), Prix de vente(1), puis les
        // champs d'identité de la nouvelle position — Libellé(2) avant
        // Isin(3) (voir `InvestmentIdentityFields`) — et enfin le Prix
        // d'achat de la destination(4).
        await tester.enterText(textFields.at(2), 'Fonds Actions Monde');
        await tester.enterText(textFields.at(3), 'FR0000000001');
        await tester.enterText(textFields.at(4), '30');
        await tester.pump();

        expect(
          find.textContaining('quantité achetée : 20'),
          findsOneWidget,
        );

        await submitAndSettle(tester, 'Arbitrer');

        final all = await readAsync(tester, repo.listAll);
        final reloadedAccount = all.single;
        expect(reloadedAccount.investments, hasLength(2));

        final reloadedSource = reloadedAccount.investments.firstWhere(
          (i) => i.id == sourceInvestment.id,
        );
        expect(reloadedSource.quantityHeld, 0);
        final sellTxn = reloadedSource.transactions.last;
        expect(sellTxn.isBuy, isFalse);
        expect(sellTxn.quantity, 10);
        expect(sellTxn.unitPrice, 60);
        expect(sellTxn.type, TransactionType.arbitrage);

        final destInvestment = reloadedAccount.investments.firstWhere(
          (i) => i.id != sourceInvestment.id,
        );
        expect(destInvestment.label, 'Fonds Actions Monde');
        expect(destInvestment.quantityHeld, 20);
        final buyTxn = destInvestment.transactions.single;
        expect(buyTxn.isBuy, isTrue);
        expect(buyTxn.unitPrice, 30);
        expect(buyTxn.type, TransactionType.arbitrage);
        expect(buyTxn.linkedTransactionId, sellTxn.id);
        expect(sellTxn.linkedTransactionId, buyTxn.id);

        // Montant vente == montant achat : propriété qui définit
        // l'arbitrage (ni apport ni retrait de cash).
        expect(sellTxn.quantity * sellTxn.unitPrice, 600);
        expect(buyTxn.quantity * buyTxn.unitPrice, 600);
      },
    );
  });

  group('Documents', () {
    testWidgets(
      'un document ajouté avant validation est persisté immédiatement sur '
      'la position source, rattaché à la transaction de vente réelle une '
      'fois le transfert validé',
      (tester) async {
        useLargeSurface(tester);
        final sourceInvestment = Investment(
          isin: 'FR0000131104',
          label: 'TotalEnergies',
          transactions: [
            Transaction(
              date: DateTime(2024, 1, 1),
              isBuy: true,
              quantity: 10,
              unitPrice: 50,
            ),
          ],
        );
        final sourceAccount = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO A',
          investments: [sourceInvestment],
        );
        final destAccount = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.pea,
          name: 'PEA B',
          investments: const [],
        );
        await tester.runAsync(() async {
          await repo.saveAccount(sourceAccount);
          await repo.saveAccount(destAccount);
        });

        await tester.pumpWidget(
          buildTrigger(
            transfer: true,
            sourceAccount: sourceAccount,
            sourceInvestment: sourceInvestment,
            onChanged: () async {},
          ),
        );
        await openDialogAndWaitFor(
          tester,
          () => find.text('+ Nouvelle position').evaluate().isNotEmpty,
        );

        // Appelle directement le callback `onAdd` du `DocumentsSection` —
        // contourne le vrai sélecteur de fichier natif (`FilePicker`, non
        // simulable en test), pour vérifier uniquement le câblage de
        // persistance de ce dialogue.
        final documentsSection = tester.widget<DocumentsSection>(
          find.byType(DocumentsSection),
        );
        final fixedTransactionId = documentsSection.fixedTransactionId;
        expect(fixedTransactionId, isNotNull);
        await tester.runAsync(
          () => documentsSection.onAdd(
            'confirmation.pdf',
            Uint8List.fromList([1, 2, 3]),
            fixedTransactionId,
            'Confirmation de transfert',
          ),
        );
        await tester.pump();

        // Persisté avant même la validation du transfert.
        final beforeSubmit = await readAsync(tester, repo.listAll);
        final sourceBeforeSubmit = beforeSubmit
            .firstWhere((a) => a.id == sourceAccount.id)
            .investments
            .single;
        expect(sourceBeforeSubmit.documents, hasLength(1));
        expect(sourceBeforeSubmit.documents.single.fileName, 'confirmation.pdf');
        expect(
          sourceBeforeSubmit.documents.single.note,
          'Confirmation de transfert',
        );
        expect(
          sourceBeforeSubmit.documents.single.transactionId,
          fixedTransactionId,
        );

        await submitAndSettle(tester, 'Transférer');

        final all = await readAsync(tester, repo.listAll);
        final reloadedSource = all.firstWhere((a) => a.id == sourceAccount.id);
        final sellTxn = reloadedSource.investments.single.transactions.last;
        // La transaction de vente réellement créée porte l'id pré-généré
        // auquel le document avait été rattaché avant même sa création.
        expect(sellTxn.id, fixedTransactionId);
        expect(
          reloadedSource.investments.single.documents.single.transactionId,
          sellTxn.id,
        );
      },
    );
  });
}

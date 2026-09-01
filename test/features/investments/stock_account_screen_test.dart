import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/opime_date_picker.dart';
import 'package:opime/features/investments/autres_photo_avatar.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/stock_account_screen.dart';
import 'package:opime/features/investments/transaction_price_currency.dart';
import 'package:opime/features/investments/widgets/transaction_widgets.dart';
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
    // Actions & Fonds : Apple a un vrai ISIN, affiché sous le libellé.
    expect(find.text('US0378331005'), findsOneWidget);
  });

  testWidgets('la table des positions n\'affiche pas d\'identifiant pour un '
      'investissement sans vrai ISIN (référence "Autres" laissée vide, ou '
      'fonds PEE/PEG sans ISIN public), mais en affiche un pour un objet '
      '"Autres" avec une vraie référence saisie', (tester) async {
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
            // Généré automatiquement (référence laissée vide à la
            // création) : rien d'utile à copier/afficher.
            isin: 'autre-1',
            label: 'Rolex sans référence',
            transactions: [
              Transaction(
                date: DateTime(2022, 1, 1),
                isBuy: true,
                quantity: 1,
                unitPrice: 8000,
              ),
            ],
          ),
          Investment(
            // Référence saisie par l'utilisateur (numéro de série réel).
            isin: 'SN-123456',
            label: 'Omega avec référence',
            transactions: [
              Transaction(
                date: DateTime(2022, 1, 1),
                isBuy: true,
                quantity: 1,
                unitPrice: 5000,
              ),
            ],
          ),
        ],
      );
      await InvestmentsRepository(tempDir.path).saveAccount(account);
    });

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(find.text('Rolex sans référence'), findsOneWidget);
    expect(find.text('autre-1'), findsNothing);
    expect(find.text('Omega avec référence'), findsOneWidget);
    expect(find.text('SN-123456'), findsOneWidget);
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
    // Actions & Fonds : pas d'avatar photo cliquable, réservé à "Autres".
    expect(find.byType(AutresPhotoAvatar), findsNothing);
  });

  testWidgets('la popup d\'un objet "Autres" affiche un avatar cliquable pour '
      'importer une photo (initiales par défaut)', (tester) async {
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

    await tester.tap(find.text('Rolex Submariner'));
    await tester.pump();

    expect(find.byType(AutresPhotoAvatar), findsOneWidget);
    // Pas encore de photo importée : initiales dérivées du libellé.
    expect(find.text('RS'), findsOneWidget);
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
      // champs texte dans la popup : libellé, identifiant, quantité, prix.
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'BNP Paribas');
      await tester.enterText(textFields.at(1), 'FR0000131104');
      await tester.enterText(textFields.at(2), '3');
      await tester.enterText(textFields.at(3), '60');
      // Formulaire de nouvelle position (ISIN + libellé) + commentaire
      // facultatif : plus haut que la fenêtre de test par défaut, le
      // bouton de validation doit être scrollé en vue avant le tap.
      await tester.ensureVisible(find.text('Ajouter la transaction'));
      await tester.pump();
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
    'un objet "Autres" accepte un prix d\'achat de 0 (reçu en cadeau)',
    (tester) async {
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.autres,
          envelope: AccountEnvelope.montre,
          name: 'Montres',
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

      // Libellé en premier (voir le test précédent) : l'identifiant, laissé
      // vide à l'index 1, sera auto-généré à l'enregistrement.
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Montre offerte');
      await tester.enterText(textFields.at(2), '1');
      await tester.enterText(textFields.at(3), '0');
      // Formulaire de nouvelle position + commentaire facultatif : plus haut
      // que la fenêtre de test par défaut, le bouton de validation doit être
      // scrollé en vue avant le tap.
      await tester.ensureVisible(find.text('Ajouter la transaction'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Ajouter la transaction'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      final investment = saved!.single.investments.single;
      expect(investment.label, 'Montre offerte');
      expect(investment.transactions.single.unitPrice, 0);
      expect(investment.investedAmount, 0);
    },
  );

  testWidgets('un fonds détenu en PER, sans ISIN saisi, se voit générer un '
      'identifiant à la création — comme un fonds PEG/PEE (voir '
      'isinOptionalFor)', (tester) async {
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_stock_account_test',
      );
      account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.per,
        name: 'PER Linxea',
        bankName: 'Linxea',
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

    // Libellé, puis identifiant (laissé vide à l'index 1 : il sera
    // auto-généré à l'enregistrement, comme pour un fonds PEG/PEE).
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Unité de compte Actions Monde');
    await tester.enterText(textFields.at(2), '10');
    await tester.enterText(textFields.at(3), '35');
    // Formulaire de nouvelle position + commentaire facultatif : plus haut
    // que la fenêtre de test par défaut, le bouton de validation doit être
    // scrollé en vue avant le tap.
    await tester.ensureVisible(find.text('Ajouter la transaction'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Ajouter la transaction'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    final saved = await tester.runAsync(
      () => InvestmentsRepository(tempDir.path).listAll(),
    );
    final investment = saved!.single.investments.single;
    expect(investment.label, 'Unité de compte Actions Monde');
    expect(isGeneratedIdentifier(investment.isin), isTrue);
  });

  testWidgets(
    'un compte-titres n\'accepte pas un prix d\'achat de 0 (pas de cadeau '
    'pour une action)',
    (tester) async {
      await setUpVault(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.text('Transactions'));
      await tester.pump();
      await tester.tap(find.text('Ajouter une transaction'));
      await tester.pump();

      // Le compte a déjà une position (Apple), déjà sélectionnée par
      // défaut : seuls quantité et prix restent à saisir.
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '1');
      await tester.enterText(textFields.at(1), '0');
      await tester.runAsync(() async {
        await tester.tap(find.text('Ajouter la transaction'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      // Toujours une seule transaction (l'achat initial de `setUpVault`) :
      // le prix à 0 a été rejeté, rien de nouveau n'a été enregistré.
      expect(saved!.single.investments.single.transactions, hasLength(1));
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
    'ajouter une transaction sur une position crypto propose les '
    'stablecoins (USDT/USDC) en plus des devises classiques, contrairement '
    'à Actions & Fonds',
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

      await tester.tap(find.text('BTC').first);
      await tester.pump();
      await tester.tap(find.text('Ajouter une transaction'));
      await tester.pump();

      // Voir `transaction_price_currency_test.dart` : la popup du sélecteur
      // n'est pas pilotable de façon fiable en test, on vérifie donc
      // directement l'option reçue par le widget plutôt que son ouverture.
      final select = tester.widget<TransactionPriceCurrencySelect>(
        find.byType(TransactionPriceCurrencySelect),
      );
      expect(select.extraOptions, containsAll(['USDT', 'USDC']));
    },
  );

  testWidgets('l\'import IBKR n\'apparaît dans le menu du compte que pour une '
      'enveloppe CTO', (tester) async {
    await setUpVault(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pump();
    expect(find.text('Importer un relevé (IBKR)'), findsOneWidget);
  });

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

  testWidgets('menu du compte : un compte déjà exclu propose "Réintégrer au '
      'patrimoine"', (tester) async {
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
  });

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

  testWidgets('un onglet Documents apparaît pour un compte "Autres" (montres, '
      'voitures de collection...), en plus des documents par transaction', (
    tester,
  ) async {
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
  });

  testWidgets('la colonne "Cours" d\'un compte "Autres" affiche "—" sans cours '
      'manuel renseigné, puis le cours manuel une fois estimé', (tester) async {
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
  });

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
      // Le compte n'a qu'une seule position : le total du compte
      // (`AccountSummaryHeader`, qui inclut désormais l'estimation
      // manuelle — voir `Investment.displayValue`) coïncide avec la valeur
      // de cette position, d'où les deux occurrences.
      expect(find.text('19 000 €'), findsNWidgets(2));
    },
  );

  testWidgets('un fonds PEG sans ISIN (Actions & Fonds) affiche aussi le cours '
      'manuel une fois renseigné, comme "Autres"', (tester) async {
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_stock_account_test',
      );
      account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.peg,
        name: 'PEG Entreprise',
        investments: [
          Investment(
            // Identifiant auto-généré (voir `_commitCreateInvestment`) :
            // ce fonds interne n'a pas de vrai ISIN public.
            isin: 'fcpe-1',
            label: 'FCPE Diversifié Entreprise',
            manualPrice: 42,
            manualPriceAt: DateTime(2026, 1, 1),
            transactions: [
              Transaction(
                date: DateTime(2022, 1, 1),
                isBuy: true,
                quantity: 10,
                unitPrice: 35,
              ),
            ],
          ),
        ],
      );
      await InvestmentsRepository(tempDir.path).saveAccount(account);
    });

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    // Cours : le cours manuel tel quel. Valeur : 42 × 10 = 420 €.
    expect(find.text('42 €'), findsOneWidget);
    // Voir le test "Autres" ci-dessus : le total du compte coïncide avec
    // cette unique position.
    expect(find.text('420 €'), findsNWidgets(2));
  });

  testWidgets('créer une transaction depuis la popup d\'une position Actions & '
      'Fonds propose d\'y attacher des documents', (tester) async {
    // La largeur fixe de l'étiquette de type de transaction (voir
    // `_kindBadgeWidth`, pour aligner les dates entre elles) laisse moins
    // de place à la ligne de transaction existante, dont le retour à la
    // ligne pousse "Ajouter une transaction" hors du viewport par défaut.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await setUpVault(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await tester.tap(find.text('Apple'));
    await tester.pump();
    await tester.tap(find.text('Ajouter une transaction'));
    await tester.pump();

    expect(find.text('Aucun document pour l\'instant.'), findsOneWidget);
  });

  testWidgets(
    'un commentaire facultatif saisi à la création d\'une transaction est '
    'persisté et affiché à côté de l\'actif dans la liste',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await setUpVault(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.text('Apple'));
      await tester.pump();
      await tester.tap(find.text('Ajouter une transaction'));
      await tester.pump();

      // Position déjà existante : pas de champ identifiant/libellé, donc
      // quantité puis prix puis commentaire dans cet ordre.
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '2');
      await tester.enterText(textFields.at(1), '180');
      await tester.enterText(textFields.at(2), 'Renforcement position');
      await tester.ensureVisible(find.text('Ajouter la transaction'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Ajouter la transaction'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      final newTxn = saved!.single.investments.single.transactions.firstWhere(
        (t) => t.quantity == 2,
      );
      expect(newTxn.note, 'Renforcement position');

      // Affiché dans la liste de transactions de la popup, en plus petit et
      // plus clair à côté du nom de l'actif (voir `TransactionRow`).
      await tester.pumpAndSettle();
      expect(find.text('Renforcement position'), findsOneWidget);
    },
  );

  testWidgets(
    'modifier le commentaire d\'une transaction existante le met à jour '
    'dans le repository',
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
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO Bourso',
          bankName: 'Bourso',
          investments: [
            Investment(
              isin: 'US0378331005',
              label: 'Apple',
              transactions: [
                Transaction(
                  date: DateTime(2024, 1, 10),
                  isBuy: true,
                  quantity: 5,
                  unitPrice: 150,
                  note: 'Achat initial',
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
      expect(find.text('Achat initial'), findsOneWidget);

      // Deux icônes "⋮" : celle du menu du compte, puis celle de la seule
      // ligne de transaction affichée (voir le test équivalent "Autres"
      // ci-dessus).
      await tester.ensureVisible(
        find.byIcon(LucideIcons.ellipsisVertical).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      // Le commentaire déjà enregistré préremplit le champ, prêt à être
      // corrigé sans devoir retaper la transaction entière.
      final noteField = tester.widget<TextField>(find.byType(TextField).at(2));
      expect(noteField.controller?.text, 'Achat initial');

      await tester.enterText(
        find.byType(TextField).at(2),
        'Renfort suite dividende',
      );
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      // La popup se ferme après l'enregistrement (voir
      // `_EditTransactionDialogState._commit`) et l'onglet parent ne
      // recharge que via `onChanged` (`onChanged: () {}` dans ce test) :
      // seul l'état persisté est vérifiable ici, pas un ré-affichage
      // immédiat de l'onglet Transactions.
      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      expect(
        saved!.single.investments.single.transactions.single.note,
        'Renfort suite dividende',
      );
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

  testWidgets('modifier une transaction "Autres" existante depuis l\'onglet '
      'Transactions propose d\'y attacher un document a posteriori', (
    tester,
  ) async {
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
    await tester.ensureVisible(find.byIcon(LucideIcons.ellipsisVertical).last);
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
  });

  testWidgets('créer une toute nouvelle position depuis l\'onglet Transactions '
      'propose aussi d\'y attacher des documents, avant même que la position '
      'n\'existe', (tester) async {
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

    expect(find.text('Aucun document pour l\'instant.'), findsOneWidget);
  });

  testWidgets('ajouter une transaction sur un fonds PEG affiche sa date de '
      'déblocage (5 ans après la date par défaut, aujourd\'hui) dès '
      'l\'ouverture du formulaire, modifiable pour un déblocage anticipé', (
    tester,
  ) async {
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_stock_account_test',
      );
      account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.peg,
        name: 'PEG Entreprise',
        investments: [
          Investment(
            isin: 'fcpe-1',
            label: 'FCPE Diversifié Entreprise',
            transactions: [
              Transaction(
                date: DateTime(2022, 1, 1),
                isBuy: true,
                quantity: 10,
                unitPrice: 35,
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
    await tester.pump();
    await tester.tap(find.text('Ajouter une transaction'));
    await tester.pump();

    expect(find.text('Débloqué le'), findsOneWidget);
    final today = DateTime.now();
    final defaultUnlockDate = DateTime(today.year + 5, today.month, today.day);
    final unlockDatePickers = tester
        .widgetList<OpimeDatePicker>(find.byType(OpimeDatePicker))
        .where((picker) => picker.value == defaultUnlockDate);
    expect(unlockDatePickers, hasLength(1));

    // Modifiable pour un déblocage anticipé (achat de la résidence
    // principale, mariage...) : la valeur choisie prend le pas sur la
    // date calculée par défaut.
    final manualUnlockDate = DateTime(2024, 6, 15);
    final unlockDatePicker = unlockDatePickers.single;
    unlockDatePicker.onChanged!(manualUnlockDate);
    await tester.pump();
    expect(
      tester
          .widgetList<OpimeDatePicker>(find.byType(OpimeDatePicker))
          .where((picker) => picker.value == manualUnlockDate),
      hasLength(1),
    );
  });

  testWidgets(
    'les dates de l\'onglet Transactions restent alignées verticalement '
    'quelle que soit la longueur de l\'étiquette de type ("Achat" vs '
    '"Conversion de devise")',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_stock_account_test',
        );
        account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO Bourso',
          bankName: 'Bourso',
          investments: [
            Investment(
              isin: 'US0378331005',
              label: 'Apple',
              transactions: [
                Transaction(
                  date: DateTime(2024, 1, 10),
                  isBuy: true,
                  quantity: 5,
                  unitPrice: 150,
                ),
              ],
            ),
            Investment(
              isin: 'FR0000120271',
              label: 'TotalEnergies',
              transactions: [
                // Le plus long libellé de type existant (voir
                // `TransactionType.label`) : le cas qui décale le plus la
                // date sans la largeur fixe de l'étiquette.
                Transaction(
                  date: DateTime(2024, 2, 20),
                  isBuy: true,
                  quantity: 3,
                  unitPrice: 55,
                  type: TransactionType.fxConversion,
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

      final appleDateX = tester.getTopLeft(find.text('10/01/2024')).dx;
      final totalDateX = tester.getTopLeft(find.text('20/02/2024')).dx;
      expect(appleDateX, totalDateX);
    },
  );

  testWidgets('dans l\'onglet Transactions (plusieurs positions mélangées), un '
      'commentaire sur une seule transaction désactive le centrage de la '
      'date pour toutes les lignes affichées, pas seulement la sienne', (
    tester,
  ) async {
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'opime_stock_account_test',
      );
      account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO Bourso',
        bankName: 'Bourso',
        investments: [
          Investment(
            isin: 'US0378331005',
            label: 'Apple',
            transactions: [
              Transaction(
                date: DateTime(2024, 1, 10),
                isBuy: true,
                quantity: 5,
                unitPrice: 150,
              ),
            ],
          ),
          Investment(
            isin: 'FR0000120271',
            label: 'TotalEnergies',
            transactions: [
              Transaction(
                date: DateTime(2024, 2, 20),
                isBuy: true,
                quantity: 3,
                unitPrice: 55,
                note: 'Renforcement position',
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

    final rows = tester.widgetList<TransactionRow>(find.byType(TransactionRow));
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.centerDate == false), isTrue);
  });

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

  group(
    'restrictToAssetClass (contrat d\'assurance vie ouvert depuis la '
    'catégorie Immobilier parce qu\'il porte des parts de SCPI — voir '
    'accountAcceptsCrossClassInvestment)',
    () {
      Future<void> setUpMixedAssuranceVie(WidgetTester tester) async {
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_stock_account_test',
          );
          account = InvestmentAccount(
            assetClass: AssetClass.actionsEtFonds,
            envelope: AccountEnvelope.assuranceVie,
            name: 'Assurance vie Boursorama',
            bankName: 'Boursorama',
            investments: [
              Investment(
                isin: 'FR0000000scpi',
                label: 'SCPI Pierre Rendement',
                assetClass: AssetClass.immobilier,
                transactions: [
                  Transaction(
                    date: DateTime(2024, 3, 1),
                    isBuy: true,
                    quantity: 10,
                    unitPrice: 200,
                  ),
                ],
              ),
              Investment(
                isin: 'FR0000120271',
                label: 'Fonds Euro Actions Monde',
                transactions: [
                  Transaction(
                    date: DateTime(2024, 1, 15),
                    isBuy: true,
                    quantity: 50,
                    unitPrice: 100,
                  ),
                ],
              ),
            ],
          );
          await InvestmentsRepository(tempDir.path).saveAccount(account);
        });
      }

      Widget buildRestrictedScreen() => ShadcnApp(
        home: Scaffold(
          child: StockAccountScreen(
            vaultPath: tempDir.path,
            account: account,
            hidden: false,
            bankNames: const ['Boursorama'],
            onBack: () {},
            onChanged: () {},
            restrictToAssetClass: AssetClass.immobilier,
          ),
        ),
      );

      testWidgets(
        'onglet Positions : seule la SCPI apparaît, pas le fonds actions du '
        'même contrat',
        (tester) async {
          await setUpMixedAssuranceVie(tester);
          await tester.pumpWidget(buildRestrictedScreen());
          await tester.pump();

          expect(find.text('SCPI Pierre Rendement'), findsOneWidget);
          expect(find.text('Fonds Euro Actions Monde'), findsNothing);
        },
      );

      testWidgets(
        'onglet Transactions : seule la transaction de la SCPI apparaît',
        (tester) async {
          await setUpMixedAssuranceVie(tester);
          await tester.pumpWidget(buildRestrictedScreen());
          await tester.pump();

          await tester.tap(find.text('Transactions'));
          await tester.pumpAndSettle();

          expect(find.byType(TransactionRow), findsOneWidget);
          expect(find.text('SCPI Pierre Rendement'), findsOneWidget);
          expect(find.text('Fonds Euro Actions Monde'), findsNothing);
        },
      );

      testWidgets(
        'le bouton "Afficher tout le compte" révèle la position masquée, '
        'puis "Masquer le reste du compte" la masque à nouveau',
        (tester) async {
          await setUpMixedAssuranceVie(tester);
          await tester.pumpWidget(buildRestrictedScreen());
          await tester.pump();

          expect(find.text('Fonds Euro Actions Monde'), findsNothing);
          expect(find.text('Afficher tout le compte (+1)'), findsOneWidget);

          await tester.tap(find.text('Afficher tout le compte (+1)'));
          await tester.pump();

          expect(find.text('SCPI Pierre Rendement'), findsOneWidget);
          expect(find.text('Fonds Euro Actions Monde'), findsOneWidget);
          expect(find.text('Masquer le reste du compte'), findsOneWidget);

          await tester.tap(find.text('Masquer le reste du compte'));
          await tester.pump();

          expect(find.text('SCPI Pierre Rendement'), findsOneWidget);
          expect(find.text('Fonds Euro Actions Monde'), findsNothing);
          expect(find.text('Afficher tout le compte (+1)'), findsOneWidget);
        },
      );

      testWidgets(
        'sans restriction (restrictToAssetClass: null), aucun bouton — rien '
        'n\'est masqué, rien à révéler',
        (tester) async {
          await setUpMixedAssuranceVie(tester);
          await tester.pumpWidget(
            ShadcnApp(
              home: Scaffold(
                child: StockAccountScreen(
                  vaultPath: tempDir.path,
                  account: account,
                  hidden: false,
                  bankNames: const ['Boursorama'],
                  onBack: () {},
                  onChanged: () {},
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.textContaining('Afficher tout le compte'), findsNothing);
          expect(find.text('Masquer le reste du compte'), findsNothing);
        },
      );

      testWidgets(
        'symétrique : ouvert depuis la catégorie Actions & Fonds (sa '
        'catégorie propre), seul le fonds actions apparaît, pas la SCPI du '
        'même contrat',
        (tester) async {
          await setUpMixedAssuranceVie(tester);
          await tester.pumpWidget(
            ShadcnApp(
              home: Scaffold(
                child: StockAccountScreen(
                  vaultPath: tempDir.path,
                  account: account,
                  hidden: false,
                  bankNames: const ['Boursorama'],
                  onBack: () {},
                  onChanged: () {},
                  restrictToAssetClass: AssetClass.actionsEtFonds,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Fonds Euro Actions Monde'), findsOneWidget);
          expect(find.text('SCPI Pierre Rendement'), findsNothing);
        },
      );

      testWidgets(
        'restrictToAssetClass: null (utilisé par les tests qui n\'ont pas '
        'besoin de ce scoping) : les deux positions du contrat restent '
        'visibles, aucun filtre',
        (tester) async {
          await setUpMixedAssuranceVie(tester);
          await tester.pumpWidget(
            ShadcnApp(
              home: Scaffold(
                child: StockAccountScreen(
                  vaultPath: tempDir.path,
                  account: account,
                  hidden: false,
                  bankNames: const ['Boursorama'],
                  onBack: () {},
                  onChanged: () {},
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('SCPI Pierre Rendement'), findsOneWidget);
          expect(find.text('Fonds Euro Actions Monde'), findsOneWidget);
        },
      );
    },
  );

  group('Private Equity (versements/distributions en montant, sans ISIN, '
      'valorisation manuelle du fonds)', () {
    testWidgets(
      'le "+" de l\'onglet Transactions affiche "Montant versé (€)" sans '
      'prix unitaire pour un nouveau fonds, et la transaction est '
      'enregistrée avec une quantité de 1',
      (tester) async {
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_stock_account_test',
          );
          account = InvestmentAccount(
            assetClass: AssetClass.privateEquity,
            envelope: AccountEnvelope.fcprFcpi,
            name: 'Moonfare',
            bankName: 'Moonfare',
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

        expect(find.text('Montant versé (€)'), findsOneWidget);
        expect(find.text('Prix unitaire'), findsNothing);

        // Compte vide : le formulaire de nouvelle position (libellé +
        // identifiant facultatif) est déjà affiché, puis le montant.
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'Ardian Expansion Fund V');
        await tester.enterText(textFields.at(2), '10000');
        await tester.ensureVisible(find.text('Ajouter la transaction'));
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.text('Ajouter la transaction'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        final saved = await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).listAll(),
        );
        final investment = saved!.single.investments.single;
        expect(investment.label, 'Ardian Expansion Fund V');
        expect(isGeneratedIdentifier(investment.isin), isTrue);
        expect(investment.transactions, hasLength(1));
        expect(investment.transactions.single.quantity, 1);
        expect(investment.transactions.single.unitPrice, 10000);
      },
    );

    testWidgets(
      'sans valorisation renseignée, la popup l\'indique explicitement '
      '(pas de mention de cours/ISIN, sans rapport pour un fonds PE)',
      (tester) async {
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_stock_account_test',
          );
          account = InvestmentAccount(
            assetClass: AssetClass.privateEquity,
            envelope: AccountEnvelope.fcprFcpi,
            name: 'Moonfare',
            bankName: 'Moonfare',
            investments: [
              Investment(
                isin: 'pe-1',
                label: 'Ardian Expansion Fund V',
                assetClass: AssetClass.privateEquity,
                transactions: [
                  Transaction(
                    date: DateTime(2022, 1, 1),
                    isBuy: true,
                    quantity: 1,
                    unitPrice: 10000,
                  ),
                ],
              ),
            ],
          );
          await InvestmentsRepository(tempDir.path).saveAccount(account);
        });

        await tester.pumpWidget(buildScreen());
        await tester.pump();

        await tester.tap(find.text('Ardian Expansion Fund V'));
        await tester.pumpAndSettle();

        // Sans valorisation renseignée : le montant affiché correspond au
        // capital net investi, avec un rappel explicite (voir le pendant
        // "Aucun cours renseigné" pour Autres/PEG-PEE-PER) plutôt qu'une
        // mention de cours/ISIN sans rapport avec un fonds PE.
        expect(
          find.textContaining('Aucune valorisation renseignée'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'une fois une valorisation renseignée, MWR est proposé (pas TWR — '
      'aucun historique de cours), et "Capital net investi" remplace '
      'Quantité détenue/PRU',
      (tester) async {
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_stock_account_test',
          );
          account = InvestmentAccount(
            assetClass: AssetClass.privateEquity,
            envelope: AccountEnvelope.fcprFcpi,
            name: 'Moonfare',
            bankName: 'Moonfare',
            investments: [
              Investment(
                isin: 'pe-1',
                label: 'Ardian Expansion Fund V',
                assetClass: AssetClass.privateEquity,
                manualValuation: 15000,
                manualValuationAt: DateTime(2026, 1, 1),
                transactions: [
                  Transaction(
                    date: DateTime(2022, 1, 1),
                    isBuy: true,
                    quantity: 1,
                    unitPrice: 5000,
                  ),
                  Transaction(
                    date: DateTime(2023, 1, 1),
                    isBuy: true,
                    quantity: 1,
                    unitPrice: 5000,
                  ),
                ],
              ),
            ],
          );
          await InvestmentsRepository(tempDir.path).saveAccount(account);
        });

        await tester.pumpWidget(buildScreen());
        await tester.pump();

        await tester.tap(find.text('Ardian Expansion Fund V'));
        await tester.pumpAndSettle();

        expect(find.text('MWR'), findsOneWidget);
        expect(find.text('TWR'), findsNothing);
        expect(find.text('Capital net investi'), findsOneWidget);
        // Pas "PRU" seul : ce texte reste par ailleurs le titre de colonne
        // du tableau des positions, resté monté sous la popup — seul le
        // chip "Quantité détenue" (jamais un simple "Quantité") identifie
        // sans ambiguïté celui de la popup.
        expect(find.text('Quantité détenue'), findsNothing);
        expect(find.text('Valorisation'), findsOneWidget);
      },
    );

    testWidgets(
      'variante "Rémunération en actions" (BSPCE/stock-options/AGA) : le '
      '"+" affiche "Nombre de titres/options" et un champ prix (pas '
      '"Montant versé (€)" comme un fonds), et un prix nul (attribution '
      'gratuite) est accepté et enregistré tel quel',
      (tester) async {
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_stock_account_test',
          );
          account = InvestmentAccount(
            assetClass: AssetClass.privateEquity,
            envelope: AccountEnvelope.fcprFcpi,
            name: 'Ma startup',
            bankName: 'Ma startup',
            investments: [
              Investment(
                isin: 'pe-startup',
                label: 'Ma startup SAS',
                assetClass: AssetClass.privateEquity,
                privateEquityKind: PrivateEquityKind.actionsSalarie,
                transactions: const [],
              ),
            ],
          );
          await InvestmentsRepository(tempDir.path).saveAccount(account);
        });

        await tester.pumpWidget(buildScreen());
        await tester.pump();

        await tester.tap(find.text('Transactions'));
        await tester.pump();
        await tester.tap(find.text('Ajouter une transaction'));
        await tester.pump();

        // Compte non vide, une seule position : elle est sélectionnée par
        // défaut (voir `_selection` dans `add_transaction_dialog.dart`),
        // pas besoin d'ouvrir le sélecteur pour l'atteindre.
        expect(find.text('Nombre de titres/options'), findsOneWidget);
        expect(find.text('Montant versé (€)'), findsNothing);
        expect(find.text('Prix unitaire'), findsOneWidget);

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), '1000');
        await tester.enterText(textFields.at(1), '0');
        await tester.ensureVisible(find.text('Ajouter la transaction'));
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.text('Ajouter la transaction'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        final saved = await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).listAll(),
        );
        final investment = saved!.single.investments.single;
        expect(investment.transactions, hasLength(1));
        expect(investment.transactions.single.quantity, 1000);
        expect(investment.transactions.single.unitPrice, 0);
      },
    );

    testWidgets(
      'variante "Rémunération en actions" : une fois un cours estimé '
      'renseigné (manualPrice), la popup garde Quantité détenue/PRU '
      '(contrairement au mode "Fonds") et affiche "Cours estimé", pas '
      '"Valorisation"',
      (tester) async {
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_stock_account_test',
          );
          account = InvestmentAccount(
            assetClass: AssetClass.privateEquity,
            envelope: AccountEnvelope.fcprFcpi,
            name: 'Ma startup',
            bankName: 'Ma startup',
            investments: [
              Investment(
                isin: 'pe-startup',
                label: 'Ma startup SAS',
                assetClass: AssetClass.privateEquity,
                privateEquityKind: PrivateEquityKind.actionsSalarie,
                manualPrice: 8,
                manualPriceAt: DateTime(2026, 1, 1),
                transactions: [
                  Transaction(
                    date: DateTime(2024, 1, 1),
                    isBuy: true,
                    quantity: 1000,
                    unitPrice: 0,
                  ),
                ],
              ),
            ],
          );
          await InvestmentsRepository(tempDir.path).saveAccount(account);
        });

        await tester.pumpWidget(buildScreen());
        await tester.pump();

        await tester.tap(find.text('Ma startup SAS'));
        await tester.pumpAndSettle();

        expect(find.text('MWR'), findsOneWidget);
        expect(find.text('TWR'), findsNothing);
        expect(find.text('Quantité détenue'), findsOneWidget);
        expect(find.text('Capital net investi'), findsNothing);
        expect(find.text('Cours estimé'), findsOneWidget);
        expect(find.text('Valorisation'), findsNothing);
      },
    );

    testWidgets(
      'variante "Rémunération en actions" avec un vesting suivi (cliff/'
      'durée renseignés) : le chip "Acquis" affiche la quantité vestée, pas '
      'la quantité totale détenue',
      (tester) async {
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_stock_account_test',
          );
          account = InvestmentAccount(
            assetClass: AssetClass.privateEquity,
            envelope: AccountEnvelope.fcprFcpi,
            name: 'Ma startup',
            bankName: 'Ma startup',
            investments: [
              Investment(
                isin: 'pe-startup',
                label: 'Ma startup SAS',
                assetClass: AssetClass.privateEquity,
                privateEquityKind: PrivateEquityKind.actionsSalarie,
                vestingCliffMonths: 12,
                vestingDurationMonths: 12,
                transactions: [
                  // Cliff == durée : 0 % vesté avant la date du cliff, donc
                  // rien de vesté avec `DateTime.now()` (grant très récent).
                  Transaction(
                    date: DateTime.now(),
                    isBuy: true,
                    quantity: 1000,
                    unitPrice: 0,
                  ),
                ],
              ),
            ],
          );
          await InvestmentsRepository(tempDir.path).saveAccount(account);
        });

        await tester.pumpWidget(buildScreen());
        await tester.pump();

        await tester.tap(find.text('Ma startup SAS'));
        await tester.pumpAndSettle();

        expect(find.text('Acquis'), findsOneWidget);
        expect(find.text('Quantité détenue'), findsOneWidget);
      },
    );

    testWidgets(
      'variante "Rémunération en actions" sans vesting suivi (cliff/durée '
      'non renseignés) : pas de chip "Acquis" — toute la quantité est déjà '
      'considérée acquise',
      (tester) async {
        await tester.runAsync(() async {
          tempDir = await Directory.systemTemp.createTemp(
            'opime_stock_account_test',
          );
          account = InvestmentAccount(
            assetClass: AssetClass.privateEquity,
            envelope: AccountEnvelope.fcprFcpi,
            name: 'Ma startup',
            bankName: 'Ma startup',
            investments: [
              Investment(
                isin: 'pe-startup',
                label: 'Ma startup SAS',
                assetClass: AssetClass.privateEquity,
                privateEquityKind: PrivateEquityKind.actionsSalarie,
                transactions: [
                  Transaction(
                    date: DateTime(2024, 1, 1),
                    isBuy: true,
                    quantity: 1000,
                    unitPrice: 0,
                  ),
                ],
              ),
            ],
          );
          await InvestmentsRepository(tempDir.path).saveAccount(account);
        });

        await tester.pumpWidget(buildScreen());
        await tester.pump();

        await tester.tap(find.text('Ma startup SAS'));
        await tester.pumpAndSettle();

        expect(find.text('Acquis'), findsNothing);
      },
    );
  });
}

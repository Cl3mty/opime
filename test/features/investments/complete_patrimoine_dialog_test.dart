import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/complete_patrimoine_dialog.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_complete_patrimoine_test_',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpDialog(WidgetTester tester, {required AssetClass initialAssetClass}) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: Builder(
            builder: (context) => GestureDetector(
              onTap: () => showCompletePatrimoineDialog(
                context,
                vaultPath: tempDir.path,
                onCompleted: () {},
                initialAssetClass: initialAssetClass,
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    // Le chargement initial (comptes existants, logos, catégories "Autres"
    // personnalisées) est asynchrone.
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if (find.text('Quel bien ?').evaluate().isNotEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
  }

  testWidgets(
    '"Autres" saute directement l\'étape "Quel établissement ?" (elle n\'a '
    'plus de notion d\'établissement financier), et utilise un vocabulaire '
    'adapté ("bien", pas "compte")',
    (tester) async {
      await pumpDialog(tester, initialAssetClass: AssetClass.autres);

      expect(find.text('Quel établissement ?'), findsNothing);
      expect(find.text('Quel compte ?'), findsNothing);
      expect(find.text('Quel bien ?'), findsOneWidget);
    },
  );

  testWidgets(
    'créer un bien "Autres" ne demande pas de banque/établissement, le nom '
    'est saisi librement',
    (tester) async {
      await pumpDialog(tester, initialAssetClass: AssetClass.autres);

      await tester.tap(find.text('Nouveau bien'));
      await tester.pump();

      // Pas de champ "Banque" pour Autres — un seul TextField visible,
      // celui du nom.
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Rolex Submariner');
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('Créer'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      final account = saved!.single;
      expect(account.assetClass, AssetClass.autres);
      expect(account.name, 'Rolex Submariner');
      expect(account.bankName, isNull);
    },
  );

  testWidgets(
    'ajouter une pièce à l\'intérieur du bien : pas d\'ISIN exigé, une '
    'référence est générée si laissée vide',
    (tester) async {
      await pumpDialog(tester, initialAssetClass: AssetClass.autres);

      await tester.tap(find.text('Nouveau bien'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Montres de collection');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Créer'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      // Étape suivante : "Quelle pièce ?", pas "Quel investissement ?".
      expect(find.text('Quel investissement ?'), findsNothing);
      expect(find.text('Quelle pièce ?'), findsOneWidget);

      await tester.tap(find.text('Nouvelle pièce'));
      await tester.pump();

      // Le nom précède la référence (facultative, pas "ISIN").
      expect(find.text('Nom (ex : Rolex Submariner)'), findsOneWidget);
      expect(
        find.text('Référence (optionnelle : numéro de série, référence...)'),
        findsOneWidget,
      );
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));
      // Nom saisi (premier champ), référence laissée vide (second champ).
      await tester.enterText(textFields.at(0), 'Rolex Submariner Date');
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('Ajouter la pièce'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final saved = await tester.runAsync(
        () => InvestmentsRepository(tempDir.path).listAll(),
      );
      final investment = saved!.single.investments.single;
      expect(investment.label, 'Rolex Submariner Date');
      // Référence auto-générée, jamais vide (identité de l'investissement).
      expect(investment.isin, startsWith('autre-'));
    },
  );

  group('ouverture contextuelle depuis un compte/investissement déjà '
      'affiché (voir CurrentAccountFocusController)', () {
    Future<void> pumpDialogWithFocus(
      WidgetTester tester, {
      required AssetClass initialAssetClass,
      String? initialAccountId,
      String? initialInvestmentId,
      required String awaitedText,
    }) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () => showCompletePatrimoineDialog(
                  context,
                  vaultPath: tempDir.path,
                  onCompleted: () {},
                  initialAssetClass: initialAssetClass,
                  initialAccountId: initialAccountId,
                  initialInvestmentId: initialInvestmentId,
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          if (find.text(awaitedText).evaluate().isNotEmpty) return;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
    }

    testWidgets(
      'initialAccountId saute compte ET établissement pour aller '
      'directement à "Quel investissement ?" de ce compte précis',
      (tester) async {
        final account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO Bourso',
          bankName: 'Bourso',
          investments: [Investment(
            isin: 'FR0000131104',
            label: 'BNP Paribas',
            transactions: const [],
          )],
        );
        await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).saveAccount(account),
        );

        await pumpDialogWithFocus(
          tester,
          initialAssetClass: AssetClass.actionsEtFonds,
          initialAccountId: account.id,
          awaitedText: 'Quel investissement ?',
        );

        // Ni l'étape établissement, ni le choix du compte (un autre CTO
        // aurait pu être créé/choisi) : directement la position existante.
        expect(find.text('Quel établissement ?'), findsNothing);
        expect(find.text('Quel compte ?'), findsNothing);
        expect(find.text('BNP Paribas'), findsOneWidget);
      },
    );

    testWidgets(
      'à l\'étape "Quel investissement ou devise ?", créer un nouvel '
      'investissement propose le libellé avant l\'identifiant (plus '
      'intuitif : on connaît généralement le nom d\'un titre avant son ISIN)',
      (tester) async {
        final account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO Bourso',
          bankName: 'Bourso',
          investments: const [],
        );
        await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).saveAccount(account),
        );

        await pumpDialogWithFocus(
          tester,
          initialAssetClass: AssetClass.actionsEtFonds,
          initialAccountId: account.id,
          awaitedText: 'Quel investissement ?',
        );

        await tester.tap(find.text('Nouvel investissement ou devise'));
        await tester.pump();

        // Mode "Investissement" par défaut (pas "Devise") : libellé, puis
        // identifiant.
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'TotalEnergies');
        await tester.enterText(textFields.at(1), 'FR0000120271');
        await tester.runAsync(() async {
          await tester.tap(find.text('Créer l\'investissement'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        final saved = await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).listAll(),
        );
        final investment = saved!.single.investments.single;
        expect(investment.label, 'TotalEnergies');
        expect(investment.isin, 'FR0000120271');
      },
    );

    testWidgets(
      'le texte d\'exemple du libellé s\'adapte à la classe d\'actif — '
      '"Ardian Expansion Fund" pour Private Equity, pas "TotalEnergies"',
      (tester) async {
        final account = InvestmentAccount(
          assetClass: AssetClass.privateEquity,
          envelope: AccountEnvelope.fcprFcpi,
          name: 'Moonfare',
          bankName: 'Moonfare',
          investments: const [],
        );
        await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).saveAccount(account),
        );

        await pumpDialogWithFocus(
          tester,
          initialAssetClass: AssetClass.privateEquity,
          initialAccountId: account.id,
          awaitedText: 'Quel investissement ?',
        );

        // Pas "ou devise" : ce suffixe n'apparaît que pour les classes qui
        // acceptent une position en devise (Actions & Fonds), pas Private
        // Equity.
        await tester.tap(find.text('Nouvel investissement'));
        await tester.pump();

        expect(
          find.text('Libellé (ex: Ardian Expansion Fund)'),
          findsOneWidget,
        );
        expect(find.text('Libellé (ex: TotalEnergies)'), findsNothing);
      },
    );

    testWidgets(
      'Private Equity : l\'identifiant est facultatif (pas d\'ISIN pour un '
      'club deal/FCPR) — laissé vide, un identifiant technique est généré '
      'plutôt que de bloquer la création, et l\'étape transaction affiche '
      'un seul champ "Montant versé (€)", sans prix unitaire',
      (tester) async {
        final account = InvestmentAccount(
          assetClass: AssetClass.privateEquity,
          envelope: AccountEnvelope.fcprFcpi,
          name: 'Moonfare',
          bankName: 'Moonfare',
          investments: const [],
        );
        await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).saveAccount(account),
        );

        await pumpDialogWithFocus(
          tester,
          initialAssetClass: AssetClass.privateEquity,
          initialAccountId: account.id,
          awaitedText: 'Quel investissement ?',
        );

        await tester.tap(find.text('Nouvel investissement'));
        await tester.pump();

        expect(
          find.text('Identifiant (optionnel : laisse vide si le fonds n\'en '
              'a pas)'),
          findsOneWidget,
        );

        // Libellé seul, identifiant laissé vide.
        await tester.enterText(
          find.byType(TextField).first,
          'Ardian Expansion Fund V',
        );
        await tester.runAsync(() async {
          await tester.tap(find.text('Créer l\'investissement'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();

        // L'étape transaction du fonds tout juste créé : montant total,
        // pas de prix unitaire (voir usesTotalAmountTransaction).
        expect(find.text('Montant versé (€)'), findsOneWidget);
        expect(find.text('Prix unitaire'), findsNothing);

        final saved = await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).listAll(),
        );
        final investment = saved!.single.investments.single;
        expect(investment.label, 'Ardian Expansion Fund V');
        expect(isGeneratedIdentifier(investment.isin), isTrue);
        expect(investment.isin, startsWith('pe-'));
      },
    );

    testWidgets(
      'Private Equity : le sélecteur de variante ("Fonds" / "Rémunération '
      'en actions") existe à l\'étape de création d\'un nouvel '
      'investissement — l\'interaction avec le popup shadcn_flutter Select '
      'lui-même n\'est pas testable dans ce harnais (même limitation "No '
      'DrawerOverlay found" que le menu "⋮" de `position_detail_dialog.dart`, '
      'voir le plan)',
      (tester) async {
        final account = InvestmentAccount(
          assetClass: AssetClass.privateEquity,
          envelope: AccountEnvelope.fcprFcpi,
          name: 'Ma startup',
          bankName: 'Ma startup',
          investments: const [],
        );
        await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).saveAccount(account),
        );

        await pumpDialogWithFocus(
          tester,
          initialAssetClass: AssetClass.privateEquity,
          initialAccountId: account.id,
          awaitedText: 'Quel investissement ?',
        );

        await tester.tap(find.text('Nouvel investissement'));
        await tester.pump();

        expect(find.byType(Select<PrivateEquityKind>), findsOneWidget);
        // Mode par défaut "Fonds" : les champs de vesting/échéance
        // d'exercice (réservés à "Rémunération en actions") ne s'affichent
        // pas — changer de variante nécessiterait d'ouvrir le popup Select,
        // non pilotable dans ce harnais (voir la note ci-dessus).
        expect(find.text('Cliff (mois, facultatif)'), findsNothing);
        expect(
          find.text('Durée de vesting (mois, facultatif)'),
          findsNothing,
        );
        expect(
          find.text('Date limite d\'exercice (facultative)'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Private Equity "Rémunération en actions" (BSPCE/stock-options/AGA) : '
      'l\'étape transaction d\'une position déjà créée en ce mode affiche '
      '"Nombre de titres/options" et un champ prix, pas "Montant versé (€)" '
      'comme un fonds',
      (tester) async {
        final equityGrant = Investment(
          isin: 'pe-startup',
          label: 'Ma startup SAS',
          assetClass: AssetClass.privateEquity,
          privateEquityKind: PrivateEquityKind.actionsSalarie,
          transactions: const [],
        );
        final account = InvestmentAccount(
          assetClass: AssetClass.privateEquity,
          envelope: AccountEnvelope.fcprFcpi,
          name: 'Ma startup',
          bankName: 'Ma startup',
          investments: [equityGrant],
        );
        await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).saveAccount(account),
        );

        await pumpDialogWithFocus(
          tester,
          initialAssetClass: AssetClass.privateEquity,
          initialAccountId: account.id,
          initialInvestmentId: equityGrant.id,
          awaitedText: 'Ajouter une transaction',
        );

        // Contrairement au mode "Fonds" : quantité réelle de titres, un
        // champ prix visible (0 accepté pour une AGA — voir
        // allowsFreeTransactionPrice).
        expect(find.text('Nombre de titres/options'), findsOneWidget);
        expect(find.text('Montant versé (€)'), findsNothing);
        expect(find.text('Prix unitaire'), findsOneWidget);
      },
    );

    testWidgets(
      'remonter d\'une étape depuis "Quel investissement ?" atteint via '
      'initialAccountId ne plante pas (régression : null check operator '
      'used on a null value — _pendingEstablishmentName jamais renseigné '
      'par ce raccourci, contrairement au parcours normal)',
      (tester) async {
        // PER : une enveloppe "Actions & Fonds" à établissement, comme le
        // signalait l\'utilisateur.
        final account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.per,
          name: 'PER Linxea',
          bankName: 'Linxea',
          investments: [
            Investment(
              isin: 'FR0000131104',
              label: 'BNP Paribas',
              transactions: const [],
            ),
          ],
        );
        await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).saveAccount(account),
        );

        await pumpDialogWithFocus(
          tester,
          initialAssetClass: AssetClass.actionsEtFonds,
          initialAccountId: account.id,
          awaitedText: 'Quel investissement ?',
        );

        // "Retour" (chevron gauche) de l'en-tête de l'étape.
        await tester.tap(find.byIcon(LucideIcons.chevronLeft));
        await tester.pump();

        // Pas d'exception levée par le tap ci-dessus (voir aussi
        // `tester.takeException()` implicite en fin de test via
        // `TestWidgetsFlutterBinding`) : la remontée retombe sur "Quel
        // compte ?" avec l'établissement "Linxea" correctement renseigné.
        expect(find.text('Quel compte ?'), findsOneWidget);
        expect(find.text('Linxea'), findsWidgets);
      },
    );

    testWidgets(
      'initialAccountId + initialInvestmentId sautent jusqu\'à l\'étape '
      '"Ajouter une transaction" de cet investissement précis',
      (tester) async {
        final investment = Investment(
            isin: 'FR0000131104',
            label: 'BNP Paribas',
            transactions: const [],
          );
        final account = InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.cto,
          name: 'CTO Bourso',
          bankName: 'Bourso',
          investments: [investment],
        );
        await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).saveAccount(account),
        );

        await pumpDialogWithFocus(
          tester,
          initialAssetClass: AssetClass.actionsEtFonds,
          initialAccountId: account.id,
          initialInvestmentId: investment.id,
          awaitedText: 'Ajouter une transaction',
        );

        expect(find.text('Quel investissement ?'), findsNothing);
      },
    );

    testWidgets(
      'un initialAccountId introuvable (compte supprimé entre-temps) '
      'retombe simplement sur le choix du compte, sans planter',
      (tester) async {
        await pumpDialogWithFocus(
          tester,
          initialAssetClass: AssetClass.actionsEtFonds,
          initialAccountId: 'inexistant',
          awaitedText: 'Quel établissement ?',
        );

        expect(find.text('Quel établissement ?'), findsOneWidget);
      },
    );

    testWidgets(
      'un compte Actions & Fonds/Crypto propose "Position à effet de '
      'levier" à l\'étape "Quel investissement ?", qui ouvre directement '
      'le formulaire dédié (leveraged_position_dialog.dart) plutôt que les '
      'étapes investissement + transaction du spot',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final account = InvestmentAccount(
          assetClass: AssetClass.crypto,
          envelope: AccountEnvelope.plateformeEchange,
          name: 'Hyperliquid',
          investments: const [],
        );
        await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).saveAccount(account),
        );

        await pumpDialogWithFocus(
          tester,
          initialAssetClass: AssetClass.crypto,
          initialAccountId: account.id,
          awaitedText: 'Quel investissement ?',
        );

        expect(find.text('Position à effet de levier'), findsOneWidget);
        await tester.tap(find.text('Position à effet de levier'));
        await tester.pumpAndSettle();

        expect(find.text('Nouvelle position à effet de levier'), findsOneWidget);
      },
    );
  });

  group('Immobilier : plusieurs comptes distingués par enveloppe (résidence '
      'principale, locatif, SCPI en direct, crowdfunding...)', () {
    Future<void> pumpImmobilierDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () => showCompletePatrimoineDialog(
                  context,
                  vaultPath: tempDir.path,
                  onCompleted: () {},
                  initialAssetClass: AssetClass.immobilier,
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          if (find.text('Quel compte ?').evaluate().isNotEmpty) return;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
    }

    testWidgets(
      'régression : choisir Immobilier passe par "Quel compte ?" comme '
      'les autres classes sans établissement (crypto, métaux, "Autres"), '
      'au lieu de sauter directement sur un unique compte technique '
      '"Biens immobiliers" partagé par tous les biens',
      (tester) async {
        await pumpImmobilierDialog(tester);

        expect(find.text('Quel compte ?'), findsOneWidget);
        expect(find.text('Nouveau compte'), findsOneWidget);
      },
    );

    testWidgets(
      'un compte immobilier existant ("Biens immobiliers") est proposé '
      'comme option à côté de "Nouveau compte" — un nouveau bien peut '
      'ainsi vivre dans un compte séparé plutôt que d\'y être forcément '
      'ajouté',
      (tester) async {
        await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).saveAccount(
            InvestmentAccount(
              assetClass: AssetClass.immobilier,
              envelope: AccountEnvelope.autre,
              name: 'Biens immobiliers',
              investments: const [],
            ),
          ),
        );

        await pumpImmobilierDialog(tester);

        expect(find.text('Biens immobiliers'), findsOneWidget);
        expect(find.text('Nouveau compte'), findsOneWidget);
      },
    );

    testWidgets(
      'créer un nouveau compte immobilier avec l\'enveloppe par défaut '
      '(résidence principale) ne demande pas de banque/établissement — '
      'l\'immobilier n\'en a jamais, voir assetClassSupportsBankName',
      (tester) async {
        await pumpImmobilierDialog(tester);

        await tester.tap(find.text('Nouveau compte'));
        await tester.pump();

        // Un seul TextField (le nom) : pas de champ "Banque" pour la
        // résidence principale.
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Ma maison');
        await tester.pump();

        await tester.runAsync(() async {
          await tester.tap(find.text('Créer le compte'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        final saved = await tester.runAsync(
          () => InvestmentsRepository(tempDir.path).listAll(),
        );
        final account = saved!.single;
        expect(account.assetClass, AssetClass.immobilier);
        expect(account.envelope, AccountEnvelope.residencePrincipale);
        expect(account.name, 'Ma maison');
        expect(account.bankName, isNull);
      },
    );

    testWidgets(
      'régression : deux comptes assurance vie existants (SCPI) restent '
      'distinguables dans la liste — leur assureur apparaît, pas juste '
      '"Actions & Fonds · Assurance Vie" identique pour les deux',
      (tester) async {
        await tester.runAsync(() async {
          final repo = InvestmentsRepository(tempDir.path);
          await repo.saveAccount(
            InvestmentAccount(
              assetClass: AssetClass.actionsEtFonds,
              envelope: AccountEnvelope.assuranceVie,
              name: 'Assurance Vie',
              bankName: 'Boursorama',
              investments: const [],
            ),
          );
          await repo.saveAccount(
            InvestmentAccount(
              assetClass: AssetClass.actionsEtFonds,
              envelope: AccountEnvelope.assuranceVie,
              name: 'Assurance Vie',
              bankName: 'Linxea Spirica',
              investments: const [],
            ),
          );
        });

        await pumpImmobilierDialog(tester);

        expect(
          find.textContaining('Actions & Fonds · Assurance Vie · Boursorama'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Actions & Fonds · Assurance Vie · Linxea Spirica',
          ),
          findsOneWidget,
        );
      },
    );
  });
}

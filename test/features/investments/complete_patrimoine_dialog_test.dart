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
  });
}

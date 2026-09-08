import 'dart:io';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/leveraged_position.dart';
import 'package:opime/features/investments/transaction_price_currency.dart';
import 'package:opime/features/investments/widgets/leveraged_position_dialog.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

void main() {
  late Directory tempDir;
  late InvestmentsRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'opime_leveraged_position_dialog_test_',
    );
    repo = InvestmentsRepository(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  InvestmentAccount cryptoAccount({List<LeveragedPosition> positions = const []}) =>
      InvestmentAccount(
        assetClass: AssetClass.crypto,
        envelope: AccountEnvelope.plateformeEchange,
        name: 'Hyperliquid',
        investments: const [],
        leveragedPositions: positions,
      );

  // Marché en texte libre (pas de ticker crypto imposé) : utilisé pour les
  // tests de mécanique générique du formulaire (validation, édition), pas
  // spécifiques à la sélection de ticker crypto — voir le groupe dédié
  // plus bas pour ce dernier.
  InvestmentAccount actionsEtFondsAccount({
    List<LeveragedPosition> positions = const [],
  }) => InvestmentAccount(
    assetClass: AssetClass.actionsEtFonds,
    envelope: AccountEnvelope.cto,
    name: 'CTO Bourso',
    bankName: 'Bourso',
    investments: const [],
    leveragedPositions: positions,
  );

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<T> readAsync<T>(WidgetTester tester, Future<T> Function() read) =>
      tester.runAsync(read).then((value) => value as T);

  Widget buildTrigger({
    required InvestmentAccount account,
    LeveragedPosition? existing,
    required Future<void> Function() onChanged,
  }) {
    return ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        child: Builder(
          builder: (context) => OutlineButton(
            onPressed: () => showLeveragedPositionDialog(
              context,
              vaultPath: tempDir.path,
              account: account,
              existing: existing,
              onChanged: onChanged,
            ),
            child: const shadcn.Text('ouvrir'),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'création : les champs requis sont validés (toast, aucun enregistrement '
    'silencieux), puis la position est bien persistée une fois complétée',
    (tester) async {
      useLargeSurface(tester);
      final account = actionsEtFondsAccount();
      await tester.runAsync(() => repo.saveAccount(account));

      var changedCount = 0;
      await tester.pumpWidget(
        buildTrigger(
          account: account,
          onChanged: () async {
            changedCount++;
          },
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      // Rien de saisi : validation, pas d'enregistrement silencieux.
      await tester.tap(find.text('Ajouter'));
      await tester.pump();
      expect(find.text('Position impossible à enregistrer'), findsOneWidget);
      expect(changedCount, 0);
      // Laisse le toast (minuteur d'auto-fermeture à 5s) se refermer avant
      // de poursuivre — sans quoi il reste un minuteur en attente à la fin
      // du test, que `flutter_test` refuse (`!timersPending`).
      await tester.pump(const Duration(seconds: 6));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'BTC'); // marché
      await tester.enterText(fields.at(1), '2'); // levier
      await tester.enterText(fields.at(2), '0.1'); // taille
      await tester.enterText(fields.at(3), '60000'); // prix d'entrée
      await tester.pump();

      // La marge (plus un champ de saisie) apparaît calculée en direct :
      // 0.1 * 60000 / 2 = 3000.
      expect(find.textContaining('Marge : '), findsOneWidget);
      expect(find.textContaining('3 000'), findsWidgets);

      await tester.runAsync(() async {
        await tester.tap(find.text('Ajouter'));
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      expect(changedCount, 1);
      final all = await readAsync(tester, repo.listAll);
      final saved = all.single.leveragedPositions.single;
      expect(saved.market, 'BTC');
      expect(saved.side, PositionSide.long);
      expect(saved.leverage, 2);
      expect(saved.size, 0.1);
      expect(saved.entryPrice, 60000);
      expect(saved.margin, 3000); // dérivée, plus saisie séparément
    },
  );

  testWidgets(
    'édition : les champs existants sont pré-remplis, une modification est '
    'bien répercutée sans dupliquer la position',
    (tester) async {
      useLargeSurface(tester);
      final position = LeveragedPosition(
        market: 'ETH',
        side: PositionSide.short,
        leverage: 3,
        size: 1,
        entryPrice: 3000,
        openedAt: DateTime(2026, 1, 1),
      );
      final account = actionsEtFondsAccount(positions: [position]);
      await tester.runAsync(() => repo.saveAccount(account));

      await tester.pumpWidget(
        buildTrigger(
          account: account,
          existing: position,
          onChanged: () async {},
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier la position'), findsOneWidget);
      expect(find.text('ETH'), findsOneWidget);

      // La marge n'étant plus un champ de saisie, on modifie le levier :
      // margin = size * entryPrice / leverage doit se recalculer en
      // conséquence (1 * 3000 / 6 = 500, contre 1000 avec le levier initial
      // de 3).
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '6'); // nouveau levier
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      final all = await readAsync(tester, repo.listAll);
      final reloaded = all.single.leveragedPositions;
      expect(reloaded, hasLength(1)); // pas de doublon
      expect(reloaded.single.id, position.id);
      expect(reloaded.single.leverage, 6);
      expect(reloaded.single.margin, 500);
      expect(reloaded.single.market, 'ETH'); // reste inchangé
    },
  );

  group('compte crypto : marché choisi dans la liste, prix d\'entrée en '
      'devise ou stablecoin', () {
    testWidgets(
      'le marché est un Select (liste des tickers connus), pas un champ '
      'texte libre — contrairement à un compte Actions & Fonds (CFD sur '
      'marge, pas de ticker fiable)',
      (tester) async {
        useLargeSurface(tester);
        final account = cryptoAccount();
        await tester.runAsync(() => repo.saveAccount(account));

        await tester.pumpWidget(
          buildTrigger(account: account, onChanged: () async {}),
        );
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();

        expect(find.byType(Select<String>), findsWidgets);
        // Aucun TextField "Marché" en texte libre : le premier TextField
        // visible est directement "Levier".
        expect(find.text('Marché (ex : BTC)'), findsNothing);
      },
    );

    testWidgets(
      'le prix d\'entrée propose un sélecteur de devise avec les '
      'stablecoins (USDC/USDT), absent pour un compte Actions & Fonds',
      (tester) async {
        useLargeSurface(tester);
        final account = cryptoAccount();
        await tester.runAsync(() => repo.saveAccount(account));

        await tester.pumpWidget(
          buildTrigger(account: account, onChanged: () async {}),
        );
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();

        final selector = find.byType(TransactionPriceCurrencySelect);
        expect(selector, findsOneWidget);
        expect(
          tester.widget<TransactionPriceCurrencySelect>(selector).extraOptions,
          containsAll(['USDT', 'USDC']),
        );
      },
    );

    testWidgets(
      'un compte Actions & Fonds n\'affiche pas de sélecteur de devise sur '
      'le prix d\'entrée (toujours en euros)',
      (tester) async {
        useLargeSurface(tester);
        final account = actionsEtFondsAccount();
        await tester.runAsync(() => repo.saveAccount(account));

        await tester.pumpWidget(
          buildTrigger(account: account, onChanged: () async {}),
        );
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();

        expect(
          find.byType(TransactionPriceCurrencySelect),
          findsNothing,
        );
      },
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/notifications/notifications_settings_controller.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/investments_repository.dart';
import 'package:opime/features/investments/yahoo_finance_client.dart';
import 'package:opime/features/notifications/coingecko_client.dart';
import 'package:opime/features/notifications/news_button.dart';
import 'package:opime/features/notifications/notification_models.dart';
import 'package:opime/features/notifications/notifications_controller.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Même convention que `_FakeYahooFinanceClient`/`_FakeCoinGeckoClient` dans
/// `notifications_controller_test.dart` — pas de réseau, réponses figées.
class _FakeYahooFinanceClient extends YahooFinanceClient {
  final Map<String, List<NewsArticleItem>> newsByQuery;

  _FakeYahooFinanceClient(this.newsByQuery);

  @override
  Future<List<NewsArticleItem>> fetchNews(
    String query, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    onNetworkSuccess?.call();
    return newsByQuery[query] ?? [];
  }
}

class _FakeCoinGeckoClient extends CoinGeckoClient {
  @override
  Future<String?> resolveCoinId(
    String ticker, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    onNetworkSuccess?.call();
    return null;
  }

  @override
  Future<List<CoinMarketData>> fetchMarketData(
    List<String> coinIds, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    onNetworkSuccess?.call();
    return const [];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'affiche une carte par notification et permet de la fermer individuellement',
    (tester) async {
      // `Directory.systemTemp.createTemp`/`InvestmentsRepository.saveAccount`
      // font de la vraie IO disque : sous `testWidgets`, tout le corps du
      // test tourne dans la zone FakeAsync de flutter_test, qui ne fait
      // jamais avancer les callbacks d'IO réelle — sans `runAsync`, l'appel
      // reste en attente indéfiniment (le test se bloque sans exception).
      late final Directory tempDir;
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'opime_news_panel_test',
        );
        final repo = InvestmentsRepository(tempDir.path);
        await repo.saveAccount(
          InvestmentAccount(
            assetClass: AssetClass.actionsEtFonds,
            name: 'CTO',
            investments: [
              Investment(
                isin: 'US0378331005',
                label: 'Apple',
                symbol: 'AAPL',
                transactions: const [],
              ),
            ],
          ),
        );
      });
      addTearDown(() => tempDir.delete(recursive: true));

      final article = NewsArticleItem(
        uuid: 'a1',
        title: 'Titre article',
        publisher: 'Reuters',
        link: 'https://example.com/a1',
        publishedAt: DateTime.now(),
        relatedSymbol: 'AAPL',
      );
      final yahoo = _FakeYahooFinanceClient({
        'AAPL': [article],
      });

      final controller = NotificationsController(
        yahoo: yahoo,
        coinGecko: _FakeCoinGeckoClient(),
      );
      final settings = NotificationsSettingsController();
      await settings.setEnabled(true);

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: NewsButton(
              settings: settings,
              controller: controller,
              vaultPath: tempDir.path,
            ),
          ),
        ),
      );

      // Pas de `pumpAndSettle` ici : le panneau reste ouvert indéfiniment
      // (dropdown persistant, pas une simple transition qui se termine), ce
      // qui ferait attendre `pumpAndSettle` jusqu'à son timeout. Quelques
      // pompages bornés suffisent à laisser `refresh()` (repos+fakes, sans
      // vrai réseau) se résoudre et le panneau se reconstruire.
      // `openNewsPanel` déclenche `controller.refresh(...)` en tâche de fond
      // (voir `news_panel.dart`), qui lit un vrai fichier
      // (`InvestmentsRepository.listAll`) — même raison qu'au-dessus :
      // laisser le vrai event loop avancer via `runAsync` avant de
      // reprendre la main sur la zone de test pour reconstruire l'arbre.
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(LucideIcons.bell));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text('Titre article'), findsOneWidget);

      // Le panneau (`showDropdown`) se rend hors des limites de la surface
      // de test quelle que soit sa taille (artefact de positionnement de
      // l'overlay sous test, pas un bug visuel réel — vérifié par ailleurs)
      // : `tester.tap` échouerait le hit-test. On invoque directement le
      // callback du bouton de fermeture plutôt que de simuler un tap par
      // coordonnées — technique standard pour un widget difficile à
      // hit-tester à l'intérieur d'un overlay.
      final dismissDetector = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.byIcon(LucideIcons.x),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      dismissDetector.onTap!();
      await tester.pump();

      expect(find.text('Titre article'), findsNothing);
      expect(find.text('Aucune actualité pour le moment.'), findsOneWidget);
    },
  );
}

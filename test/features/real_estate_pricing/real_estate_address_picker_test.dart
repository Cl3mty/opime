import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/ban_client.dart';
import 'package:opime/features/real_estate_pricing/real_estate_address_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Aucun appel réseau réel — même convention que les autres fakes de ce
/// dépôt (`_FakeYahooFinanceClient`...).
class _FakeBanClient extends BanClient {
  final List<String> queriesReceived = [];
  final List<BanAddressSuggestion> results;

  _FakeBanClient(this.results);

  @override
  Future<List<BanAddressSuggestion>?> search(
    String query, {
    int limit = 5,
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    queriesReceived.add(query);
    onNetworkSuccess?.call();
    return results;
  }
}

void main() {
  testWidgets('la saisie déclenche une recherche et la sélection notifie onChanged', (
    tester,
  ) async {
    final fakeClient = _FakeBanClient([
      const BanAddressSuggestion(
        label: '8 Boulevard du Port 80000 Amiens',
        lat: 49.9,
        lon: 2.3,
        postcode: '80000',
        city: 'Amiens',
        cityCode: '80021',
        score: 0.97,
        type: 'housenumber',
      ),
    ]);

    RealEstateAddressPickResult? picked;

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: RealEstateAddressMapPicker(
            banClient: fakeClient,
            onChanged: (result) => picked = result,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '8 boulevard du port');
    // Débounce de 300ms avant la recherche.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(fakeClient.queriesReceived, ['8 boulevard du port']);
    expect(find.text('8 Boulevard du Port 80000 Amiens'), findsOneWidget);

    await tester.tap(find.text('8 Boulevard du Port 80000 Amiens'));
    await tester.pump();

    expect(picked, isNotNull);
    expect(picked!.cityCode, '80021');
    expect(picked!.lat, 49.9);
  });

  testWidgets('une requête trop courte ne déclenche pas de recherche', (
    tester,
  ) async {
    final fakeClient = _FakeBanClient(const []);

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: RealEstateAddressMapPicker(
            banClient: fakeClient,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(fakeClient.queriesReceived, isEmpty);
  });
}

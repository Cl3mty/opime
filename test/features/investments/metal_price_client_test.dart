import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/metal_price_client.dart';

void main() {
  test('parse les cours et prix de rachat malgré des attributs réordonnés', () {
    const html = '''
      <span data-role="spot" class="value js-cours-gramme-value">121,97 €</span>
      <tr data-kind="metal" class="align-middle cours-cpr-table-row">
        <td><h4 data-level="4"><a class="product" title="Lingot 1Kg Or">Lingot</a></h4></td>
        <td>
          <span class="compact cours-cpr-action-btn--sell">
            <span data-price="sell" class="cours-cpr-action-btn__price">120&nbsp;056.00 €</span>
          </span>
        </td>
      </tr>
    ''';

    final snapshot = MetalPriceClient.parseSnapshot(html);

    expect(snapshot, isNotNull);
    expect(snapshot!.pricePerGram, 121.97);
    expect(snapshot.productPrices, {'Lingot 1Kg Or': 120056.0});
  });

  test('retourne null quand le cours au gramme est absent', () {
    expect(MetalPriceClient.parseSnapshot('<table></table>'), isNull);
  });
}

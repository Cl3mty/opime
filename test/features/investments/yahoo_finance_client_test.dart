import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/yahoo_finance_client.dart';

void main() {
  group('YahooFinanceClient.resolveCryptoSymbol', () {
    final client = YahooFinanceClient();

    test('un simple ticker est complété en EUR', () {
      expect(client.resolveCryptoSymbol('BTC'), 'BTC-EUR');
      expect(client.resolveCryptoSymbol('eth'), 'ETH-EUR');
    });

    test('les espaces superflus sont retirés', () {
      expect(client.resolveCryptoSymbol('  btc  '), 'BTC-EUR');
    });

    test(
      'un ticker déjà au format Yahoo (TICKER-DEVISE) est conservé tel quel',
      () {
        expect(client.resolveCryptoSymbol('BTC-USD'), 'BTC-USD');
        expect(client.resolveCryptoSymbol('eth-eur'), 'ETH-EUR');
      },
    );
  });
}

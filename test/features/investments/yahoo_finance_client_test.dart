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

  group('YahooFinanceClient.countryCodeForSymbol', () {
    final client = YahooFinanceClient();

    test('suffixes reconnus, un par continent', () {
      expect(client.countryCodeForSymbol('TTE.PA'), 'FR');
      expect(client.countryCodeForSymbol('SHOP.TO'), 'CA');
      expect(client.countryCodeForSymbol('7203.T'), 'JP');
      expect(client.countryCodeForSymbol('005930.KS'), 'KR');
      expect(client.countryCodeForSymbol('9988.HK'), 'HK');
      expect(client.countryCodeForSymbol('BHP.AX'), 'AU');
      expect(client.countryCodeForSymbol('2223.SR'), 'SA');
      expect(client.countryCodeForSymbol('RELIANCE.NS'), 'IN');
    });

    test(
      'Bruxelles (.BR, Belgique) n\'est pas confondu avec Berlin (.BE, '
      'Allemagne) malgré la ressemblance avec le code ISO belge',
      () {
        expect(client.countryCodeForSymbol('ABI.BR'), 'BE');
        // Berlin (Allemagne) n'est délibérément pas dans la table — voir
        // la documentation de _yahooSuffixToCountryCode.
        expect(client.countryCodeForSymbol('FOO.BE'), isNull);
      },
    );

    test(
      'Athènes (.AT) est bien la Grèce, pas le code ISO de l\'Autriche',
      () {
        expect(client.countryCodeForSymbol('OPAP.AT'), 'GR');
      },
    );

    test('sans suffixe (place américaine) : pas de pays déduit', () {
      expect(client.countryCodeForSymbol('AAPL'), isNull);
    });

    test('suffixe inconnu : null plutôt qu\'une déduction hasardeuse', () {
      expect(client.countryCodeForSymbol('FOO.ZZ'), isNull);
    });

    test('un point en toute fin de symbole ne fait pas planter', () {
      expect(client.countryCodeForSymbol('FOO.'), isNull);
    });
  });
}

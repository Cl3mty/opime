import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/notifications/coingecko_client.dart';

void main() {
  group('CoinMarketData.fromJson', () {
    test('mappe les champs confirmés de /coins/markets', () {
      final data = CoinMarketData.fromJson({
        'id': 'bitcoin',
        'symbol': 'btc',
        'name': 'Bitcoin',
        'current_price': 54349,
        'price_change_percentage_24h_in_currency': -0.5,
        'price_change_percentage_7d_in_currency': -3.0,
      });

      expect(data.id, 'bitcoin');
      expect(data.symbol, 'BTC');
      expect(data.name, 'Bitcoin');
      expect(data.currentPrice, 54349);
      expect(data.changePercent24h, -0.5);
      expect(data.changePercent7d, -3.0);
    });

    test('champs de variation absents (paramètre non demandé) : null', () {
      final data = CoinMarketData.fromJson({
        'id': 'bitcoin',
        'symbol': 'btc',
        'name': 'Bitcoin',
        'current_price': 54349,
      });

      expect(data.changePercent24h, isNull);
      expect(data.changePercent7d, isNull);
    });
  });
}

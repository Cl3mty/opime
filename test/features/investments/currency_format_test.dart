import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/currency_format.dart';

void main() {
  test('currencySymbol : symboles connus, repli sur le code ISO', () {
    expect(currencySymbol('EUR'), '€');
    expect(currencySymbol('USD'), r'$');
    expect(currencySymbol('GBP'), '£');
    expect(currencySymbol('JPY'), '¥');
    expect(currencySymbol('CAD'), r'CA$');
    // Devise inconnue : son code ISO.
    expect(currencySymbol('XAU'), 'XAU');
  });

  test('formatPriceInCurrency : deux décimales et symbole de devise', () {
    expect(formatPriceInCurrency(173.5, 'USD'), r'173.50 $');
    expect(formatPriceInCurrency(173, 'EUR'), '173.00 €');
  });

  test('formatPriceInCurrency masque les chiffres quand hidden', () {
    final masked = formatPriceInCurrency(173.5, 'USD', hidden: true);
    expect(masked.contains('1'), isFalse);
    expect(masked.contains(r'$'), isTrue);
  });

  test('formatFxRate : quatre décimales (taux JPY ≈ 0,006 €)', () {
    expect(formatFxRate(0.92), '0.9200');
    expect(formatFxRate(0.00642), '0.0064');
  });
}

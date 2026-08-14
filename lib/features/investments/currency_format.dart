import '../../core/money_format.dart' show maskAmount;

/// Symboles d'affichage des principales devises (voir [kKnownCurrencies]).
/// Une devise inconnue retombe sur son code ISO, et l'euro (la devise de
/// compte de l'app) sur le symbole €.
String currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'EUR':
      return '€';
    case 'USD':
      return r'$';
    case 'GBP':
      return '£';
    case 'JPY':
    case 'CNY':
      return '¥';
    case 'CAD':
      return r'CA$';
    case 'AUD':
      return r'AU$';
    case 'NZD':
      return r'NZ$';
    case 'SGD':
      return 'S\$';
    case 'HKD':
      return r'HK$';
    case 'CHF':
      return 'CHF';
    default:
      return code.toUpperCase();
  }
}

/// Formatte un prix unitaire (ou un montant) dans sa devise de cotation,
/// avec deux décimales — ex : `173.5` + `USD` → `"173.50 $"`. Masqué via
/// [maskAmount] quand [hidden] (toggle "masquer les montants").
String formatPriceInCurrency(double price, String currency, {bool hidden = false}) {
  final formatted = '${price.toStringAsFixed(2)} ${currencySymbol(currency)}';
  return hidden ? maskAmount(formatted) : formatted;
}

/// Formatte un taux de change (1 devise = X €) avec quatre décimales —
/// ex : `0.9224` → `"0.9224"`. Plus de précision qu'un prix, un taux
/// JPY ≈ 0,006 € n'ayant de sens qu'au-delà du centime.
String formatFxRate(double rate) => rate.toStringAsFixed(4);

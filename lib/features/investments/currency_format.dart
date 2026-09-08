import '../../core/money_format.dart' show displayEuros, formatEuros, maskAmount;
import 'investments_models.dart' show Investment, InvestmentAccount, isCurrencyInvestment;

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

/// Affichage du dernier cours connu d'un investissement ([Investment
/// .lastPrice], suppose non `null`) — le taux de la paire (4 décimales)
/// pour une position en devise, le cours brut + son équivalent en euros
/// pour un titre coté en devise étrangère, sinon simplement en euros.
/// Utilisé par la page d'un investissement (`investment_detail_screen.dart`)
/// et la table des positions d'un compte Actions & Fonds
/// (`widgets/positions_table.dart`).
String investmentLastPriceDisplay(
  InvestmentAccount account,
  Investment investment, {
  required bool hidden,
}) {
  final price = investment.lastPrice!;
  if (isCurrencyInvestment(account, investment)) {
    return '${price.toStringAsFixed(4)} €';
  }
  final quoteCurrency = investment.quoteCurrency;
  if (quoteCurrency != null && quoteCurrency.toUpperCase() != 'EUR') {
    final display =
        '${price.toStringAsFixed(2)} ${currencySymbol(quoteCurrency)} · ≈ '
        '${formatEuros(price * (investment.lastFxRateToEur ?? 1.0))}';
    return hidden ? maskAmount(display) : display;
  }
  return displayEuros(price, hidden);
}

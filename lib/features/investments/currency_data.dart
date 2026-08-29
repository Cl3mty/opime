/// Devises proposées en liste déroulante à la création d'un investissement
/// "Épargne" plutôt qu'en texte libre (voir `investments_models.dart`'s
/// `identifierOptionsFor`), même principe que [kKnownCryptoTickers]
/// (`yahoo_finance_client.dart`) côté crypto. L'enveloppe fiscale (Livret
/// A, LDDS, LEP, PEL...) se choisit au niveau du compte
/// (`accountEnvelopesFor`) — la devise, elle, décrit dans quelle monnaie
/// l'investissement au sein de ce compte est tenu, l'immense majorité des
/// cas français restant en EUR (mise en tête de liste).
const kKnownCurrencies = [
  'EUR',
  'USD',
  'GBP',
  'CHF',
  'JPY',
  'CAD',
  'AUD',
  'CNY',
  'HKD',
  'SGD',
  'SEK',
  'NOK',
  'DKK',
  'PLN',
  'CZK',
  'NZD',
  'MXN',
  'BRL',
  'ZAR',
  'AED',
];

/// Stablecoins proposés en plus de [kKnownCurrencies] comme devise de
/// cotation d'une transaction crypto (achat/vente) — pour permettre "acheté
/// X SOL pour Y USDC", pas juste en euros. Le taux de change vers l'euro
/// (`TransactionPriceCurrencyController`) n'est pas résolu automatiquement
/// pour eux (absents de Yahoo Finance) : l'utilisateur retombe sur la
/// saisie manuelle déjà prévue pour ce cas, ~1:1 avec le dollar donc peu
/// contraignante à renseigner à la main.
const kKnownStablecoins = ['USDT', 'USDC'];

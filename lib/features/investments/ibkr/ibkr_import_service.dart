/// Fusionne le résultat du parsing d'un relevé IBKR ([IbkrParseResult]) dans
/// un [InvestmentAccount] existant : retrouve ou crée les positions (titres
/// par ISIN, cash par devise — voir `isCurrencyInvestment` dans
/// `investments_models.dart`) et y ajoute les transactions correspondantes,
/// sans dupliquer celles déjà présentes d'un import précédent.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../investments_models.dart';
import 'ibkr_statement_parser.dart';

/// Décompte des transactions ajoutées par catégorie, période couverte par
/// le relevé, et avertissements à afficher avant confirmation — voir
/// `ibkr_import_dialog.dart`.
class IbkrImportSummary {
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int securityTradesAdded;
  final int currencyConversionsAdded;
  final int dividendsAdded;
  final int withholdingTaxAdded;
  final int feesAdded;
  final int depositsAdded;
  final int withdrawalsAdded;
  final int otherFlowsAdded;
  final int duplicatesSkipped;
  final List<String> warnings;

  IbkrImportSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.securityTradesAdded,
    required this.currencyConversionsAdded,
    required this.dividendsAdded,
    required this.withholdingTaxAdded,
    required this.feesAdded,
    required this.depositsAdded,
    required this.withdrawalsAdded,
    required this.otherFlowsAdded,
    required this.duplicatesSkipped,
    required this.warnings,
  });

  int get totalTransactionsAdded =>
      securityTradesAdded +
      currencyConversionsAdded * 2 +
      dividendsAdded +
      withholdingTaxAdded +
      feesAdded +
      depositsAdded +
      withdrawalsAdded +
      otherFlowsAdded;

  bool get isEmpty => totalTransactionsAdded == 0;
}

class IbkrImportPlan {
  final InvestmentAccount mergedAccount;
  final IbkrImportSummary summary;

  IbkrImportPlan({required this.mergedAccount, required this.summary});
}

/// Id déterministe (hash du contenu brut de la ligne CSV + un suffixe pour
/// distinguer les deux `Transaction`s générées par une même ligne) : réimporter
/// la même ligne — même le même relevé exporté une seconde fois — retombe
/// sur le même id, ce qui permet de la reconnaître comme déjà présente.
String _deterministicId(String rawLine, String leg) {
  final digest = md5.convert(utf8.encode('$rawLine|$leg'));
  return 'ibkr_${digest.toString().substring(0, 20)}';
}

/// Recherche par proximité de date du taux de change EUR le plus pertinent
/// pour une devise, à partir des conversions `EUR.<devise>` présentes dans
/// le relevé lui-même (pas d'appel réseau).
class _FxLookup {
  final Map<String, List<MapEntry<DateTime, double>>> _ratesByCurrency = {};
  final Set<String> _warnedCurrencies = {};

  _FxLookup(List<IbkrCashConversionRow> conversions) {
    for (final row in conversions) {
      if (row.baseCurrency.toUpperCase() != 'EUR' || row.tradePrice == 0) {
        continue;
      }
      final currency = row.quoteCurrency.toUpperCase();
      (_ratesByCurrency[currency] ??= []).add(
        MapEntry(row.date, 1 / row.tradePrice),
      );
    }
  }

  double rateToEur(String currency, DateTime date, List<String> warnings) {
    final upper = currency.trim().toUpperCase();
    if (upper == 'EUR') return 1.0;
    final entries = _ratesByCurrency[upper];
    if (entries == null || entries.isEmpty) {
      if (_warnedCurrencies.add(upper)) {
        warnings.add(
          'Aucune conversion EUR.$upper trouvée dans le relevé : taux de '
          'change 1,0 utilisé par défaut pour les montants en $upper, à '
          'corriger manuellement si besoin.',
        );
      }
      return 1.0;
    }
    var nearest = entries.first;
    var bestDiff = nearest.key.difference(date).inDays.abs();
    for (final entry in entries) {
      final diff = entry.key.difference(date).inDays.abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        nearest = entry;
      }
    }
    return nearest.value;
  }
}

TransactionType _cashFlowType(String rawType, double amount) {
  switch (rawType) {
    case 'Dividends':
      return TransactionType.dividend;
    case 'Withholding Tax':
      return TransactionType.withholdingTax;
    case 'Other Fees':
      return TransactionType.fee;
    case 'Deposits/Withdrawals':
      return amount >= 0 ? TransactionType.deposit : TransactionType.withdrawal;
    default:
      return TransactionType.other;
  }
}

String? _cashFlowNote(IbkrCashFlowRow row, TransactionType type) {
  if (row.symbol.isNotEmpty) return '${type.label} ${row.symbol}';
  if (type == TransactionType.other) {
    return row.description.isNotEmpty
        ? '${row.rawType} — ${row.description}'
        : row.rawType;
  }
  return row.description.isNotEmpty ? row.description : null;
}

IbkrImportPlan buildIbkrImportPlan(
  InvestmentAccount account,
  IbkrParseResult parsed,
) {
  final investmentsByKey = <String, Investment>{
    for (final investment in account.investments)
      investment.isin.trim().toUpperCase(): investment,
  };
  final fx = _FxLookup(parsed.cashConversions);
  final warnings = [...parsed.warnings];
  final unknownTypeCounts = <String, int>{};

  var duplicatesSkipped = 0;
  var securityTradesAdded = 0;
  var currencyConversionsAdded = 0;
  var dividendsAdded = 0;
  var withholdingTaxAdded = 0;
  var feesAdded = 0;
  var depositsAdded = 0;
  var withdrawalsAdded = 0;
  var otherFlowsAdded = 0;
  DateTime? periodStart;
  DateTime? periodEnd;

  void trackPeriod(DateTime date) {
    if (periodStart == null || date.isBefore(periodStart!)) periodStart = date;
    if (periodEnd == null || date.isAfter(periodEnd!)) periodEnd = date;
  }

  Investment findOrCreate(String key, Investment Function() create) {
    return investmentsByKey.putIfAbsent(key, create);
  }

  /// Ajoute [transaction] à la position [key] si elle n'y est pas déjà —
  /// retourne `true` si elle a bien été ajoutée (pas un doublon).
  bool addTransaction(String key, Transaction transaction) {
    final investment = investmentsByKey[key]!;
    if (investment.transactions.any((t) => t.id == transaction.id)) {
      duplicatesSkipped++;
      return false;
    }
    investmentsByKey[key] = investment.copyWith(
      transactions: [...investment.transactions, transaction],
    );
    return true;
  }

  for (final row in parsed.trades) {
    trackPeriod(row.date);
    final securityKey = (row.isin.trim().isNotEmpty
            ? row.isin.trim()
            : row.symbol.trim())
        .toUpperCase();
    if (securityKey.isEmpty) {
      warnings.add(
        'Ligne de titre sans ISIN ni symbole ignorée (${row.description}).',
      );
      continue;
    }
    findOrCreate(
      securityKey,
      () => Investment(
        isin: row.isin.trim().isNotEmpty ? row.isin.trim() : row.symbol,
        label: row.description.isNotEmpty ? row.description : row.symbol,
        transactions: const [],
        symbol: row.symbol.isNotEmpty ? row.symbol : null,
      ),
    );
    final rate = fx.rateToEur(row.currency, row.date, warnings);
    final added = addTransaction(
      securityKey,
      Transaction(
        id: _deterministicId(row.rawLine, 'security'),
        date: row.date,
        isBuy: row.isBuy,
        quantity: row.quantity,
        unitPrice: row.tradePrice,
        currency: row.currency,
        fxRateToEur: rate,
      ),
    );
    if (added) securityTradesAdded++;

    final currencyKey = row.currency.trim().toUpperCase();
    findOrCreate(
      currencyKey,
      () => Investment(isin: currencyKey, label: currencyKey, transactions: const []),
    );
    final cashImpact = row.netCashImpact;
    addTransaction(
      currencyKey,
      Transaction(
        id: _deterministicId(row.rawLine, 'cash'),
        date: row.date,
        isBuy: cashImpact >= 0,
        quantity: cashImpact.abs(),
        unitPrice: 1,
        currency: row.currency,
        fxRateToEur: rate,
      ),
    );
  }

  for (final row in parsed.cashConversions) {
    trackPeriod(row.date);
    final baseKey = row.baseCurrency.trim().toUpperCase();
    findOrCreate(
      baseKey,
      () => Investment(isin: baseKey, label: baseKey, transactions: const []),
    );
    final baseRate = fx.rateToEur(row.baseCurrency, row.date, warnings);
    final baseAdded = addTransaction(
      baseKey,
      Transaction(
        id: _deterministicId(row.rawLine, 'base'),
        date: row.date,
        isBuy: row.baseQuantity > 0,
        quantity: row.baseQuantity.abs(),
        unitPrice: 1,
        currency: row.baseCurrency,
        fxRateToEur: baseRate,
        type: TransactionType.fxConversion,
      ),
    );

    final quoteKey = row.quoteCurrency.trim().toUpperCase();
    findOrCreate(
      quoteKey,
      () => Investment(isin: quoteKey, label: quoteKey, transactions: const []),
    );
    // Taux dérivé directement du cours de cette ligne (plus précis que la
    // recherche par proximité de date, réservée aux lignes qui n'ont pas
    // leur propre cours).
    final quoteRate = row.baseCurrency.trim().toUpperCase() == 'EUR' &&
            row.tradePrice != 0
        ? 1 / row.tradePrice
        : fx.rateToEur(row.quoteCurrency, row.date, warnings);
    addTransaction(
      quoteKey,
      Transaction(
        id: _deterministicId(row.rawLine, 'quote'),
        date: row.date,
        isBuy: row.quoteCashImpact >= 0,
        quantity: row.quoteCashImpact.abs(),
        unitPrice: 1,
        currency: row.quoteCurrency,
        fxRateToEur: quoteRate,
        type: TransactionType.fxConversion,
      ),
    );
    if (baseAdded) currencyConversionsAdded++;
  }

  for (final row in parsed.cashFlows) {
    trackPeriod(row.date);
    final type = _cashFlowType(row.rawType, row.amount);
    final currencyKey = row.currency.trim().toUpperCase();
    findOrCreate(
      currencyKey,
      () => Investment(isin: currencyKey, label: currencyKey, transactions: const []),
    );
    final added = addTransaction(
      currencyKey,
      Transaction(
        id: _deterministicId(row.rawLine, 'flow'),
        date: row.date,
        isBuy: row.amount >= 0,
        quantity: row.amount.abs(),
        unitPrice: 1,
        currency: row.currency,
        fxRateToEur: fx.rateToEur(row.currency, row.date, warnings),
        type: type,
        note: _cashFlowNote(row, type),
      ),
    );
    if (!added) continue;
    switch (type) {
      case TransactionType.dividend:
        dividendsAdded++;
        break;
      case TransactionType.withholdingTax:
        withholdingTaxAdded++;
        break;
      case TransactionType.fee:
        feesAdded++;
        break;
      case TransactionType.deposit:
        depositsAdded++;
        break;
      case TransactionType.withdrawal:
        withdrawalsAdded++;
        break;
      case TransactionType.other:
        otherFlowsAdded++;
        unknownTypeCounts.update(
          row.rawType,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        break;
      case TransactionType.fxConversion:
        break; // Jamais produit ici — seule la section conversions le fait.
    }
  }

  unknownTypeCounts.forEach((rawType, count) {
    warnings.add(
      'Type de ligne non reconnu "$rawType" : $count ligne'
      '${count > 1 ? 's' : ''} importée${count > 1 ? 's' : ''} comme '
      'mouvement de cash générique.',
    );
  });

  return IbkrImportPlan(
    mergedAccount: account.copyWith(
      investments: investmentsByKey.values.toList(),
    ),
    summary: IbkrImportSummary(
      periodStart: periodStart,
      periodEnd: periodEnd,
      securityTradesAdded: securityTradesAdded,
      currencyConversionsAdded: currencyConversionsAdded,
      dividendsAdded: dividendsAdded,
      withholdingTaxAdded: withholdingTaxAdded,
      feesAdded: feesAdded,
      depositsAdded: depositsAdded,
      withdrawalsAdded: withdrawalsAdded,
      otherFlowsAdded: otherFlowsAdded,
      duplicatesSkipped: duplicatesSkipped,
      warnings: warnings,
    ),
  );
}

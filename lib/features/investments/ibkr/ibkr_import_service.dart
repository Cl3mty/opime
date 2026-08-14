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

/// Id déterministe, calculé à partir des champs *significatifs* d'un
/// mouvement plutôt que du texte brut de sa ligne CSV : les deux formats de
/// relevé pris en charge par [parseIbkrStatement] (Flex Query, Activity
/// Statement) ne produisent jamais le même texte de ligne pour un même
/// mouvement réel (colonnes, séparateurs et précision différents), alors que
/// leurs champs significatifs (date, identifiant, sens, quantité, prix,
/// devise) coïncident. Réimporter le même relevé — ou le même mouvement
/// exporté sous l'autre format — retombe donc sur le même id, reconnu comme
/// déjà présent. [kind] distingue les différentes `Transaction`s qu'un même
/// mouvement source peut produire (ex : le titre et sa jambe de cash).
String _semanticId(String kind, List<Object> parts) {
  final normalized = parts
      .map((p) => p is double ? p.toStringAsFixed(6) : p.toString())
      .join('|');
  final digest = md5.convert(utf8.encode('$kind|$normalized'));
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
  // Certains relevés (Activity Statement) ne portent pas l'ISIN sur leurs
  // lignes de titre — voir `IbkrTradeRow.isin` et
  // `ibkr_statement_parser.dart`'s `_parseActivityTradeRow`. Avant de
  // retomber sur le symbole seul comme identifiant, on tente de le déduire
  // d'une position déjà connue du compte portant le même symbole (déjà
  // importée avec son ISIN via un autre relevé, ou corrigée manuellement
  // depuis la fiche de l'investissement — voir `investment_detail_screen.dart`'s
  // `_commitEditInvestment`).
  final symbolToKnownIsin = <String, String>{
    for (final investment in account.investments)
      if (investment.symbol != null && investment.symbol!.isNotEmpty)
        investment.symbol!.trim().toUpperCase(): investment.isin,
  };
  final fx = _FxLookup(parsed.cashConversions);
  final warnings = [...parsed.warnings];
  final unknownTypeCounts = <String, int>{};
  final warnedMissingIsinSymbols = <String>{};

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
    // 1) l'ISIN du relevé lui-même, 2) à défaut celui d'une position déjà
    // connue du compte portant le même symbole (voir [symbolToKnownIsin]),
    // 3) à défaut le symbole seul — auquel cas on avertit une fois par
    // symbole, avec le moyen de corriger (fiche de l'investissement).
    final resolvedIsin = row.isin.trim().isNotEmpty
        ? row.isin.trim()
        : symbolToKnownIsin[row.symbol.trim().toUpperCase()];
    if (resolvedIsin == null &&
        row.symbol.isNotEmpty &&
        warnedMissingIsinSymbols.add(row.symbol.trim().toUpperCase())) {
      warnings.add(
        'ISIN introuvable pour "${row.symbol}" (absent du relevé et d\'aucune '
        'position déjà connue de ce compte) : identifié par son seul '
        'symbole — vous pouvez corriger l\'identifiant depuis le menu '
        '"Modifier" de cet investissement une fois l\'import terminé.',
      );
    }
    final securityKey = (resolvedIsin ?? row.symbol.trim()).toUpperCase();
    if (securityKey.isEmpty) {
      warnings.add(
        'Ligne de titre sans ISIN ni symbole ignorée (${row.description}).',
      );
      continue;
    }
    findOrCreate(
      securityKey,
      () => Investment(
        isin: resolvedIsin ?? row.symbol,
        label: row.description.isNotEmpty ? row.description : row.symbol,
        transactions: const [],
        symbol: row.symbol.isNotEmpty ? row.symbol : null,
      ),
    );
    final rate = fx.rateToEur(row.currency, row.date, warnings);
    final added = addTransaction(
      securityKey,
      Transaction(
        id: _semanticId('security', [
          row.date.toIso8601String(),
          securityKey,
          row.isBuy,
          row.quantity,
          row.tradePrice,
          row.currency,
        ]),
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
        id: _semanticId('trade-cash', [
          row.date.toIso8601String(),
          securityKey,
          row.currency,
          cashImpact,
        ]),
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
    // La commission (et les taxes, toujours nulles en pratique pour ces
    // lignes) se déduisent du côté de la paire porté par
    // [IbkrCashConversionRow.commissionCurrency] — la devise de cotation
    // pour un relevé Flex Query, la devise de base pour un Activity
    // Statement (voir sa documentation).
    final commissionAndTaxes = row.commission + row.taxes;
    final commissionOnBase =
        row.commissionCurrency.trim().toUpperCase() ==
            row.baseCurrency.trim().toUpperCase()
        ? commissionAndTaxes
        : 0.0;
    final commissionOnQuote =
        row.commissionCurrency.trim().toUpperCase() ==
            row.quoteCurrency.trim().toUpperCase()
        ? commissionAndTaxes
        : 0.0;
    final baseImpact = row.baseQuantity + commissionOnBase;
    final quoteImpact = row.proceeds + commissionOnQuote;

    final baseKey = row.baseCurrency.trim().toUpperCase();
    findOrCreate(
      baseKey,
      () => Investment(isin: baseKey, label: baseKey, transactions: const []),
    );
    final baseRate = fx.rateToEur(row.baseCurrency, row.date, warnings);
    final baseAdded = addTransaction(
      baseKey,
      Transaction(
        id: _semanticId('fx-base', [
          row.date.toIso8601String(),
          row.baseCurrency,
          row.quoteCurrency,
          baseImpact,
        ]),
        date: row.date,
        isBuy: baseImpact > 0,
        quantity: baseImpact.abs(),
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
        id: _semanticId('fx-quote', [
          row.date.toIso8601String(),
          row.baseCurrency,
          row.quoteCurrency,
          quoteImpact,
        ]),
        date: row.date,
        isBuy: quoteImpact >= 0,
        quantity: quoteImpact.abs(),
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
        id: _semanticId('flow', [
          row.date.toIso8601String(),
          type.name,
          row.currency,
          row.amount,
          row.symbol,
        ]),
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

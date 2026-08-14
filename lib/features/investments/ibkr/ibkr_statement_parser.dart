/// Lecture d'un export CSV "Activity Statement" d'Interactive Brokers.
///
/// Ce fichier ne dépend d'aucun widget Flutter — il est testable seul. Le
/// CSV exporté par IBKR concatène en réalité deux tableaux aux colonnes
/// différentes (trades/mouvements de cash, puis dividendes/frais/retenues/
/// dépôts), chacun réintroduisant sa propre ligne d'en-tête : le parsing
/// détecte donc les sections par en-tête plutôt que de supposer un schéma
/// unique pour tout le fichier.
library;

/// Une ligne d'achat/vente d'un titre coté (`AssetClass == 'STK'`) de la
/// section "Trades / Cash Movements".
class IbkrTradeRow {
  final DateTime date;
  final String isin;
  final String symbol;
  final String description;
  final bool isBuy;

  /// Toujours positive — le sens est porté par [isBuy].
  final double quantity;
  final double tradePrice;

  /// Commission IBKR, toujours négative ou nulle.
  final double commission;
  final double taxes;

  /// Signé : négatif pour un achat (cash sorti), positif pour une vente.
  final double proceeds;
  final String currency;
  final String rawLine;

  IbkrTradeRow({
    required this.date,
    required this.isin,
    required this.symbol,
    required this.description,
    required this.isBuy,
    required this.quantity,
    required this.tradePrice,
    required this.commission,
    required this.taxes,
    required this.proceeds,
    required this.currency,
    required this.rawLine,
  });

  /// Impact net sur le solde de cash en [currency], commission et taxes
  /// comprises — correspond à la colonne `NetCash` du relevé pour une ligne
  /// titre (voir [IbkrCashConversionRow] pour la ligne de conversion, où la
  /// colonne `NetCash` du CSV n'est elle pas fiable).
  double get netCashImpact => proceeds + commission + taxes;
}

/// Une ligne de conversion de devise (`AssetClass == 'CASH'`, ex. symbole
/// `EUR.USD`) de la section "Trades / Cash Movements".
class IbkrCashConversionRow {
  final DateTime date;
  final String baseCurrency;
  final String quoteCurrency;

  /// Signé : positif = achat de [baseCurrency], négatif = vente.
  final double baseQuantity;

  /// Cours [quoteCurrency] pour 1 unité de [baseCurrency].
  final double tradePrice;
  final double commission;
  final double taxes;
  final double proceeds;
  final String rawLine;

  IbkrCashConversionRow({
    required this.date,
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.baseQuantity,
    required this.tradePrice,
    required this.commission,
    required this.taxes,
    required this.proceeds,
    required this.rawLine,
  });

  /// Impact net sur le solde de cash en [quoteCurrency] — la colonne
  /// `NetCash` du CSV vaut `0` pour ce type de ligne (IBKR la réserve aux
  /// mouvements dans une seule devise), ce calcul la reconstitue.
  double get quoteCashImpact => proceeds + commission + taxes;
}

/// Une ligne de la section "Transactions" : dividende, retenue à la source,
/// frais, dépôt/retrait — ou tout autre type non reconnu, importé quand même
/// (voir [IbkrParseResult]).
class IbkrCashFlowRow {
  final DateTime date;
  final String rawType;
  final String symbol;
  final String description;

  /// Signé : positif = entrée de cash, négatif = sortie.
  final double amount;
  final String currency;
  final String rawLine;

  IbkrCashFlowRow({
    required this.date,
    required this.rawType,
    required this.symbol,
    required this.description,
    required this.amount,
    required this.currency,
    required this.rawLine,
  });
}

class IbkrParseResult {
  final List<IbkrTradeRow> trades;
  final List<IbkrCashConversionRow> cashConversions;
  final List<IbkrCashFlowRow> cashFlows;

  /// Sections ou lignes ignorées (en-tête non reconnu, ligne illisible...),
  /// à afficher à l'utilisateur avant qu'il ne confirme l'import — jamais
  /// d'échec silencieux.
  final List<String> warnings;

  IbkrParseResult({
    required this.trades,
    required this.cashConversions,
    required this.cashFlows,
    required this.warnings,
  });
}

/// Sépare une ligne CSV en champs, guillemets compris (avec `""` comme
/// échappement d'un guillemet à l'intérieur d'un champ) — écrit à la main
/// plutôt que d'ajouter une dépendance : le format d'IBKR est simple (pas de
/// retour à la ligne à l'intérieur d'un champ).
List<String> _splitCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(char);
      }
    } else if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  fields.add(buffer.toString());
  return fields;
}

double _parseNum(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 0;
  return double.tryParse(raw.trim()) ?? 0;
}

DateTime _parseIbkrDate(String raw) {
  // "20230810" (Trades) ou "20230403;202000" (Transactions) — seule la
  // partie date importe, la précision à la journée suffit à toute l'app.
  final datePart = raw.split(';').first.trim();
  final year = int.parse(datePart.substring(0, 4));
  final month = int.parse(datePart.substring(4, 6));
  final day = int.parse(datePart.substring(6, 8));
  return DateTime(year, month, day);
}

/// Schéma de la section "Trades / Cash Movements" — identifié par la
/// présence de `TradeDate` dans sa ligne d'en-tête.
const _tradesHeaderColumn = 'TradeDate';

/// Schéma de la section "Transactions" — identifié par la présence de
/// `Date/Time` dans sa ligne d'en-tête.
const _cashFlowsHeaderColumn = 'Date/Time';

IbkrParseResult parseIbkrStatement(String content) {
  final trades = <IbkrTradeRow>[];
  final cashConversions = <IbkrCashConversionRow>[];
  final cashFlows = <IbkrCashFlowRow>[];
  final warnings = <String>[];

  Map<String, int>? currentColumns;
  String? currentSchema; // 'trades', 'cashFlows', ou null (section ignorée)

  final lines = content.split(RegExp(r'\r\n|\r|\n'));
  for (var lineNumber = 0; lineNumber < lines.length; lineNumber++) {
    final line = lines[lineNumber];
    if (line.trim().isEmpty) continue;
    final fields = _splitCsvLine(line);
    if (fields.isEmpty || fields.first != 'ClientAccountID') {
      // Pas une ligne d'en-tête : une donnée de la section en cours.
      if (currentColumns == null) {
        continue; // Avant tout en-tête reconnu — ligne ignorée silencieusement.
      }
      String? col(String name) {
        final index = currentColumns![name];
        if (index == null || index >= fields.length) return null;
        final value = fields[index];
        return value.isEmpty ? null : value;
      }

      try {
        if (currentSchema == 'trades') {
          final assetClass = col('AssetClass');
          final date = _parseIbkrDate(col('TradeDate')!);
          final commission = _parseNum(col('IBCommission'));
          final taxes = _parseNum(col('Taxes'));
          final proceeds = _parseNum(col('Proceeds'));
          final currency = col('CurrencyPrimary') ?? 'EUR';
          if (assetClass == 'STK') {
            final quantity = _parseNum(col('Quantity'));
            trades.add(
              IbkrTradeRow(
                date: date,
                isin: col('ISIN') ?? '',
                symbol: col('Symbol') ?? '',
                description: col('Description') ?? '',
                isBuy: quantity > 0,
                quantity: quantity.abs(),
                tradePrice: _parseNum(col('TradePrice')),
                commission: commission,
                taxes: taxes,
                proceeds: proceeds,
                currency: currency,
                rawLine: line,
              ),
            );
          } else if (assetClass == 'CASH') {
            final symbol = col('Symbol') ?? '';
            final parts = symbol.split('.');
            if (parts.length != 2) {
              warnings.add(
                'Ligne ${lineNumber + 1} : symbole de conversion de devise '
                'inattendu ("$symbol"), ligne ignorée.',
              );
            } else {
              cashConversions.add(
                IbkrCashConversionRow(
                  date: date,
                  baseCurrency: parts[0],
                  quoteCurrency: parts[1],
                  baseQuantity: _parseNum(col('Quantity')),
                  tradePrice: _parseNum(col('TradePrice')),
                  commission: commission,
                  taxes: taxes,
                  proceeds: proceeds,
                  rawLine: line,
                ),
              );
            }
          }
          // Autres classes d'actif (ex : options, futures) : ignorées pour
          // l'instant, pas encore de représentation dans le modèle Opime.
        } else if (currentSchema == 'cashFlows') {
          cashFlows.add(
            IbkrCashFlowRow(
              date: _parseIbkrDate(col('Date/Time')!),
              rawType: col('Type') ?? '',
              symbol: col('Symbol') ?? '',
              description: col('Description') ?? '',
              amount: _parseNum(col('Amount')),
              currency: col('CurrencyPrimary') ?? 'EUR',
              rawLine: line,
            ),
          );
        }
      } catch (_) {
        warnings.add('Ligne ${lineNumber + 1} illisible, ignorée.');
      }
      continue;
    }

    // Ligne d'en-tête : (re)détecte le schéma de la section qui commence.
    final columns = <String, int>{
      for (var i = 0; i < fields.length; i++) fields[i]: i,
    };
    if (columns.containsKey(_tradesHeaderColumn)) {
      currentColumns = columns;
      currentSchema = 'trades';
    } else if (columns.containsKey(_cashFlowsHeaderColumn)) {
      currentColumns = columns;
      currentSchema = 'cashFlows';
    } else {
      currentColumns = null;
      currentSchema = null;
      warnings.add(
        'Section non reconnue à la ligne ${lineNumber + 1} (en-tête '
        'inattendu), ignorée.',
      );
    }
  }

  return IbkrParseResult(
    trades: trades,
    cashConversions: cashConversions,
    cashFlows: cashFlows,
    warnings: warnings,
  );
}

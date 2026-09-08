/// Lecture d'un export CSV d'Interactive Brokers.
///
/// Ce fichier ne dépend d'aucun widget Flutter — il est testable seul. IBKR
/// propose deux formats d'export bien différents pour la même donnée :
///
/// - le relevé "Flex Query" personnalisé (colonnes `ClientAccountID`,
///   `TradeDate`...), qui concatène deux tableaux réintroduisant chacun leur
///   propre ligne d'en-tête ;
/// - le relevé "Activity Statement" standard (celui du bouton d'export par
///   défaut d'IBKR), où *chaque* ligne commence par un nom de section
///   (`Trades`, `Dividends`, `Fees`...) suivi de `Header`/`Data`/`SubTotal`/
///   `Total`/`Notes`, plusieurs sections pouvant réapparaître avec un schéma
///   de colonnes différent en cours de fichier (ex : `Trades` a un schéma
///   pour les titres et un autre pour les conversions de devise).
///
/// [parseIbkrStatement] détecte lequel des deux formats a été fourni et
/// route vers le bon parseur — les deux alimentent le même [IbkrParseResult].
library;

/// Une ligne d'achat/vente d'un titre coté de la section "Trades".
class IbkrTradeRow {
  final DateTime date;
  final String isin;
  final String symbol;
  final String description;
  final bool isBuy;

  /// Toujours positive — le sens est porté par [isBuy].
  final double quantity;
  final double tradePrice;

  /// Commission IBKR, toujours négative ou nulle, dans [currency].
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
  /// comprises — correspond à la colonne `NetCash` du relevé Flex Query pour
  /// une ligne titre (voir [IbkrCashConversionRow] pour la ligne de
  /// conversion, où l'équivalent de cette colonne n'est lui pas fiable).
  double get netCashImpact => proceeds + commission + taxes;
}

/// Une ligne de conversion de devise (symbole `EUR.USD`...) de la section
/// "Trades"/"Trades / Cash Movements".
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

  /// Signé, dans [quoteCurrency] : impact net sur le solde en [quoteCurrency]
  /// hors commission/taxes (voir [commissionCurrency] pour savoir de quel
  /// côté celles-ci se déduisent).
  final double proceeds;

  /// Devise dans laquelle [commission] (et [taxes]) sont exprimées — le
  /// relevé Flex Query facture la commission d'une conversion dans la devise
  /// de cotation ([quoteCurrency]), alors que le relevé Activity Statement
  /// la facture directement dans la devise de base du compte (généralement
  /// [baseCurrency]) : cette information ne se déduit donc pas des deux
  /// devises de la paire, elle doit être portée explicitement par le
  /// parseur d'origine.
  final String commissionCurrency;
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
    required this.commissionCurrency,
    required this.rawLine,
  });
}

/// Une ligne de dividende, retenue à la source, frais ou dépôt/retrait — ou
/// tout autre type non reconnu, importé quand même (voir [IbkrParseResult]).
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

  /// Sections ou lignes ignorées (en-tête non reconnu, ISIN introuvable,
  /// ligne illisible...), à afficher à l'utilisateur avant qu'il ne confirme
  /// l'import — jamais d'échec silencieux.
  final List<String> warnings;

  IbkrParseResult({
    required this.trades,
    required this.cashConversions,
    required this.cashFlows,
    required this.warnings,
  });
}

/// Sépare une ligne CSV en champs, guillemets compris (avec `""` comme
/// échappement d'un guillemet à l'intérieur d'un champ, et une virgule à
/// l'intérieur d'un champ entre guillemets — ex : `"2023-02-13, 11:37:26"`
/// ou `"-3,006"` — préservée) — écrit à la main plutôt que d'ajouter une
/// dépendance : le format d'IBKR est simple (pas de retour à la ligne à
/// l'intérieur d'un champ).
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

/// Point d'entrée : détecte lequel des deux formats d'export IBKR a été
/// fourni et route vers le bon parseur.
IbkrParseResult parseIbkrStatement(String content) {
  // Un export Activity Statement commence typiquement par un BOM UTF-8
  // (`﻿` une fois correctement décodé) devant sa première section.
  final normalized = content.startsWith('﻿')
      ? content.substring(1)
      : content;
  final lines = normalized.split(RegExp(r'\r\n|\r|\n'));
  final firstLine = lines.firstWhere(
    (l) => l.trim().isNotEmpty,
    orElse: () => '',
  );
  final firstFields = _splitCsvLine(firstLine);
  if (firstFields.isNotEmpty && firstFields.first == 'ClientAccountID') {
    return _parseFlexQueryFormat(lines);
  }
  return _parseActivityStatementFormat(lines);
}

// ---------------------------------------------------------------------------
// Format "Flex Query" personnalisé : deux tableaux, chacun réintroduisant sa
// propre ligne d'en-tête (`ClientAccountID` en premier champ).
// ---------------------------------------------------------------------------

DateTime _parseFlexQueryDate(String raw) {
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

IbkrParseResult _parseFlexQueryFormat(List<String> lines) {
  final trades = <IbkrTradeRow>[];
  final cashConversions = <IbkrCashConversionRow>[];
  final cashFlows = <IbkrCashFlowRow>[];
  final warnings = <String>[];

  Map<String, int>? currentColumns;
  String? currentSchema; // 'trades', 'cashFlows', ou null (section ignorée)

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
          final date = _parseFlexQueryDate(col('TradeDate')!);
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
                  // La commission d'une conversion se facture ici dans la
                  // devise de cotation (`CurrencyPrimary`, ex : USD pour
                  // EUR.USD) — voir [IbkrCashConversionRow.commissionCurrency].
                  commissionCurrency: parts[1],
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
              date: _parseFlexQueryDate(col('Date/Time')!),
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

// ---------------------------------------------------------------------------
// Format "Activity Statement" standard : chaque ligne commence par un nom de
// section suivi de Header/Data/SubTotal/Total/Notes.
// ---------------------------------------------------------------------------

DateTime _parseActivityDate(String raw) {
  final parts = raw.trim().split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// "2023-02-13, 11:37:26" (colonne `Date/Time`) → seule la date importe.
DateTime _parseActivityDateTime(String raw) => _parseActivityDate(raw.split(',').first);

/// Les quantités de conversion de devise de ce format utilisent la virgule
/// comme séparateur de milliers à l'intérieur du champ entre guillemets
/// (ex : `"-3,006"`) — à distinguer du séparateur de champ CSV, déjà écarté
/// par [_splitCsvLine] avant d'arriver ici.
double _parseActivityNum(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 0;
  return double.tryParse(raw.trim().replaceAll(',', '')) ?? 0;
}

/// Un symbole IBKR suivi d'un identifiant entre parenthèses, en tête de la
/// description d'un dividende/retenue à la source (ex :
/// `"KO(US1912161007) Cash Dividend..."`) — ce format ne porte pas de colonne
/// Symbol séparée pour ces sections, contrairement au Flex Query.
final _descriptionSymbolPattern = RegExp(r'^([A-Za-z0-9]+)\(');

IbkrParseResult _parseActivityStatementFormat(List<String> lines) {
  final trades = <IbkrTradeRow>[];
  final cashConversions = <IbkrCashConversionRow>[];
  final cashFlows = <IbkrCashFlowRow>[];
  final warnings = <String>[];

  // Premier passage : construit la correspondance Symbole → (ISIN, libellé)
  // depuis "Financial Instrument Information", section qui n'apparaît qu'en
  // fin de fichier — après "Trades", qui n'expose lui que le symbole (ni
  // ISIN, ni libellé). Un second passage est donc nécessaire pour résoudre
  // ces deux informations sur chaque ligne de titre.
  final symbolToIsin = <String, String>{};
  final symbolToDescription = <String, String>{};
  Map<String, int>? fiiColumns;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final fields = _splitCsvLine(line);
    if (fields.length < 2 || fields[0] != 'Financial Instrument Information') {
      continue;
    }
    if (fields[1] == 'Header') {
      fiiColumns = {for (var i = 2; i < fields.length; i++) fields[i]: i};
      continue;
    }
    if (fields[1] != 'Data' || fiiColumns == null) continue;
    String? col(String name) {
      final index = fiiColumns![name];
      if (index == null || index >= fields.length) return null;
      final value = fields[index];
      return value.isEmpty ? null : value;
    }

    final symbol = col('Symbol');
    final securityId = col('Security ID');
    if (symbol == null) continue;
    if (securityId != null) symbolToIsin[symbol] = securityId;
    final description = col('Description');
    if (description != null) symbolToDescription[symbol] = description;
  }

  // Second passage : traite chaque section reconnue. Le schéma de colonnes
  // d'une section peut changer en cours de fichier (ex : "Trades" a un
  // en-tête pour les titres puis un autre, plus loin, pour les conversions
  // de devise) — on retient donc le dernier en-tête vu par nom de section.
  final columnsBySection = <String, Map<String, int>>{};
  final unknownFlowSubtitles = <String, int>{};

  for (var lineNumber = 0; lineNumber < lines.length; lineNumber++) {
    final line = lines[lineNumber];
    if (line.trim().isEmpty) continue;
    final fields = _splitCsvLine(line);
    if (fields.length < 2) continue;
    final section = fields[0];
    final rowType = fields[1];

    if (rowType == 'Header') {
      columnsBySection[section] = {
        for (var i = 2; i < fields.length; i++) fields[i]: i,
      };
      continue;
    }
    // "SubTotal"/"Total" : agrégats affichés par IBKR, pas des mouvements —
    // ignorés. "Notes" : légal/informatif, jamais des données.
    if (rowType != 'Data') continue;

    final columns = columnsBySection[section];
    if (columns == null) continue; // Donnée avant tout en-tête de sa section.

    String? col(String name) {
      final index = columns[name];
      if (index == null || index >= fields.length) return null;
      final value = fields[index];
      return value.isEmpty ? null : value;
    }

    try {
      switch (section) {
        case 'Trades':
          _parseActivityTradeRow(
            col,
            line,
            symbolToIsin,
            symbolToDescription,
            trades,
            cashConversions,
            warnings,
            lineNumber,
          );
        case 'Deposits & Withdrawals':
          // La ligne "Total" agrégée partage le même RowType "Data" que les
          // vraies lignes mais n'a ni date ni devise — c'est ce qui la
          // distingue, pas son RowType (voir les autres sections ci-dessous).
          final date = col('Settle Date');
          final currency = col('Currency');
          if (date == null || currency == null) break;
          cashFlows.add(
            IbkrCashFlowRow(
              date: _parseActivityDate(date),
              rawType: 'Deposits/Withdrawals',
              symbol: '',
              description: col('Description') ?? '',
              amount: _parseActivityNum(col('Amount')),
              currency: currency,
              rawLine: line,
            ),
          );
        case 'Fees':
          final date = col('Date');
          final currency = col('Currency');
          if (date == null || currency == null) break; // Ligne "Total".
          final subtitle = col('Subtitle') ?? 'Other Fees';
          if (subtitle != 'Other Fees') {
            unknownFlowSubtitles.update(
              subtitle,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
          cashFlows.add(
            IbkrCashFlowRow(
              date: _parseActivityDate(date),
              rawType: 'Other Fees',
              symbol: '',
              description: col('Description') ?? '',
              amount: _parseActivityNum(col('Amount')),
              currency: currency,
              rawLine: line,
            ),
          );
        case 'Dividends':
        case 'Withholding Tax':
          // Les lignes "Total"/"Total in EUR" agrégées partagent, elles
          // aussi, le RowType "Data" mais n'ont ni date ni devise.
          final date = col('Date');
          final currency = col('Currency');
          if (date == null || currency == null) break;
          final description = col('Description') ?? '';
          final symbolMatch = _descriptionSymbolPattern.firstMatch(description);
          cashFlows.add(
            IbkrCashFlowRow(
              date: _parseActivityDate(date),
              rawType: section,
              symbol: symbolMatch?.group(1) ?? '',
              description: description,
              amount: _parseActivityNum(col('Amount')),
              currency: currency,
              rawLine: line,
            ),
          );
        default:
          // Autres sections (Net Asset Value, Cash Report, Open Positions,
          // Change in Dividend Accruals...) : purement informatives ou déjà
          // représentées par les sections ci-dessus (les écritures
          // d'accroissement de dividende, notamment, sont des provisions
          // comptables qui s'annulent — la vraie encaissement est dans
          // "Dividends"/"Withholding Tax" — les importer en plus ferait
          // double compte).
          break;
      }
    } catch (_) {
      warnings.add('Ligne ${lineNumber + 1} illisible, ignorée.');
    }
  }

  unknownFlowSubtitles.forEach((subtitle, count) {
    warnings.add(
      'Sous-catégorie de frais non reconnue "$subtitle" : $count ligne'
      '${count > 1 ? 's' : ''} importée${count > 1 ? 's' : ''} comme frais '
      'générique.',
    );
  });

  return IbkrParseResult(
    trades: trades,
    cashConversions: cashConversions,
    cashFlows: cashFlows,
    warnings: warnings,
  );
}

void _parseActivityTradeRow(
  String? Function(String) col,
  String rawLine,
  Map<String, String> symbolToIsin,
  Map<String, String> symbolToDescription,
  List<IbkrTradeRow> trades,
  List<IbkrCashConversionRow> cashConversions,
  List<String> warnings,
  int lineNumber,
) {
  final assetCategory = col('Asset Category');
  final symbol = col('Symbol') ?? '';
  final dateTime = col('Date/Time');
  if (dateTime == null) return;
  final date = _parseActivityDateTime(dateTime);
  final quantity = _parseActivityNum(col('Quantity'));
  final price = _parseActivityNum(col('T. Price'));
  final proceeds = _parseActivityNum(col('Proceeds'));
  final currency = col('Currency') ?? 'EUR';

  if (assetCategory == 'Stocks') {
    // Ce format n'a pas de colonne ISIN sur ses lignes de titre : `isin`
    // reste vide quand "Financial Instrument Information" ne le résout pas
    // — à charge de `ibkr_import_service.dart` de tenter une résolution
    // supplémentaire depuis les positions déjà connues du compte cible
    // avant de retomber sur le symbole seul (et d'avertir dans ce cas).
    trades.add(
      IbkrTradeRow(
        date: date,
        isin: symbolToIsin[symbol] ?? '',
        symbol: symbol,
        description: symbolToDescription[symbol] ?? symbol,
        isBuy: quantity > 0,
        quantity: quantity.abs(),
        tradePrice: price,
        commission: _parseActivityNum(col('Comm/Fee')),
        // Pas de colonne Taxes distincte dans ce format pour les titres.
        taxes: 0,
        proceeds: proceeds,
        currency: currency,
        rawLine: rawLine,
      ),
    );
  } else if (assetCategory == 'Forex') {
    final parts = symbol.split('.');
    if (parts.length != 2) {
      warnings.add(
        'Ligne ${lineNumber + 1} : symbole de conversion de devise inattendu '
        '("$symbol"), ligne ignorée.',
      );
      return;
    }
    cashConversions.add(
      IbkrCashConversionRow(
        date: date,
        baseCurrency: parts[0],
        quoteCurrency: parts[1],
        baseQuantity: quantity,
        tradePrice: price,
        // Ce format facture déjà la commission d'une conversion en euros
        // (`Comm in EUR`) plutôt que dans la devise de cotation — voir
        // [IbkrCashConversionRow.commissionCurrency].
        commission: _parseActivityNum(col('Comm in EUR')),
        taxes: 0,
        proceeds: proceeds,
        commissionCurrency: 'EUR',
        rawLine: rawLine,
      ),
    );
  }
  // Autres catégories (ex : options, futures) : ignorées pour l'instant.
}

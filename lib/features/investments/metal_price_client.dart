import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;

/// Pièces et lingots d'or listés sur achat-or-et-argent.fr — proposés en
/// liste déroulante à la création d'un investissement "Métaux précieux"
/// plutôt qu'en texte libre (voir `investments_models.dart`'s
/// `identifierOptionsFor`), même principe que [kKnownCryptoTickers] côté
/// crypto.
const kKnownGoldProducts = [
  'Lingot 1Kg Or',
  'Lingot 500g Or',
  'Lingot 250g Or',
  'Lingot 100g Or',
  'Lingot 50g Or',
  'Lingotin 1 Once Or',
  'Lingot 20g Or',
  'Lingot 10g Or',
  'Lingot 5g Or',
  '20 Francs Napoléon',
  '20 Francs Suisse',
  '50 Pesos Or',
  '20 Dollars US',
  'Souverain',
  'Krugerrand',
  '10 Francs Napoléon',
  'Union Latine',
  '5 Dollars US Or',
  '10 Dollars US',
  '10 Florins Or',
  '20 Francs Tunisie',
  '20 Reichsmarks',
  'Demi Souverain',
];

/// Pièces et lingots d'argent listés sur achat-or-et-argent.fr — même
/// principe que [kKnownGoldProducts].
const kKnownSilverProducts = [
  'Lingot 1 Kilo Argent',
  'Lingot 500g Argent',
  'Lingot 250g Argent',
  'Silver Eagle 1 Once',
  'Maple Leaf 1 Once Argent',
  'Krugerrand 1 Once Argent',
  '50 Francs Hercule 1974 - 1980',
  '10 Francs Hercule 1964 - 1973',
  '5 Francs Semeuse 1959-1969',
];

/// Cours d'or/argent extrait d'une page achat-or-et-argent.fr : le cours au
/// gramme (pour un identifiant libre/ancien, voir [pricePerGram]) et le
/// prix de rachat ("Vous vendez") de chaque pièce/lingot coté
/// individuellement sur la page ([productPrices], clé : le nom exact tel
/// qu'affiché — voir [kKnownGoldProducts]/[kKnownSilverProducts]).
///
/// Une pièce numismatique ne vaut pas juste son poids en métal fin : elle
/// se négocie avec une prime (ou décote) propre à chaque modèle — utiliser
/// [productPrices] plutôt que de recalculer un prix à partir de
/// [pricePerGram] et d'un poids théorique est donc nécessaire pour une
/// valorisation correcte.
class MetalPriceSnapshot {
  final double pricePerGram;
  final Map<String, double> productPrices;

  const MetalPriceSnapshot({
    required this.pricePerGram,
    required this.productPrices,
  });
}

/// Client pour le cours de l'or et de l'argent physiques, extrait de la
/// page publique achat-or-et-argent.fr — il n'existe pas d'API de cours
/// pour ces métaux comme pour les actions/cryptos (voir
/// `YahooFinanceClient`), donc pas de ticker à résoudre : une page dédiée
/// par métal, dont le cours au gramme apparaît dans un span de classe
/// `js-cours-gramme-value`, et le tableau détaillé par pièce/lingot dans
/// des lignes `<tr class="cours-cpr-table-row">` (colonne "Vous vendez",
/// classe `cours-cpr-action-btn--sell`) — stable sur les deux pages.
///
/// Même philosophie défensive que [YahooFinanceClient] : un échec (réseau,
/// changement de mise en page du site) retourne simplement `null` plutôt
/// que de propager une exception, pour ne jamais bloquer l'UI — l'app
/// retombe alors sur la dernière valorisation connue (ou le prix d'achat).
class MetalPriceClient {
  static final _gramValuePattern = RegExp(
    r'''class="[^"]*\bjs-cours-gramme-value\b[^"]*"[^>]*>\s*([^<]+?)\s*€''',
  );
  static final _rowPattern = RegExp(
    r'<tr\b(?=[^>]*\bcours-cpr-table-row\b)[^>]*>(.*?)</tr>',
    dotAll: true,
  );
  static final _nameInRowPattern = RegExp(
    r'<h4\b[^>]*>\s*<a\b[^>]*\btitle="([^"]+)"',
  );
  static final _sellPriceInRowPattern = RegExp(
    r'cours-cpr-action-btn--sell.*?cours-cpr-action-btn__price[^>]*>\s*([^<]+?)\s*€',
    dotAll: true,
  );

  Future<MetalPriceSnapshot?> fetchGoldSnapshot({
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) => _fetchSnapshot(
    'https://www.achat-or-et-argent.fr/or/cours-de-l-or',
    onNetworkError: onNetworkError,
    onNetworkSuccess: onNetworkSuccess,
  );

  Future<MetalPriceSnapshot?> fetchSilverSnapshot({
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) => _fetchSnapshot(
    'https://www.achat-or-et-argent.fr/argent/cours-de-l-argent',
    onNetworkError: onNetworkError,
    onNetworkSuccess: onNetworkSuccess,
  );

  Future<MetalPriceSnapshot?> _fetchSnapshot(
    String url, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {
          // Certains sites bloquent les requêtes sans user-agent de
          // navigateur — inoffensif, mais évite un rejet silencieux.
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
              'AppleWebKit/605.1.15',
        },
      );
      onNetworkSuccess?.call();
      if (response.statusCode != 200) return null;

      return parseSnapshot(response.body);
    } on SocketException catch (_) {
      onNetworkError?.call();
      return null;
    } on http.ClientException catch (_) {
      onNetworkError?.call();
      return null;
    } on TimeoutException catch (_) {
      onNetworkError?.call();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extrait un instantané depuis le HTML des pages de cours. Les classes et
  /// attributs peuvent être réordonnés par le site ; les expressions sont
  /// donc volontairement moins rigides que sa mise en page actuelle.
  static MetalPriceSnapshot? parseSnapshot(String html) {
    final gramMatch = _gramValuePattern.firstMatch(html);
    if (gramMatch == null) return null;
    final pricePerGram = _parseNumber(gramMatch.group(1)!);
    if (pricePerGram == null) return null;

    final productPrices = <String, double>{};
    for (final rowMatch in _rowPattern.allMatches(html)) {
      final row = rowMatch.group(1)!;
      final nameMatch = _nameInRowPattern.firstMatch(row);
      final priceMatch = _sellPriceInRowPattern.firstMatch(row);
      if (nameMatch == null || priceMatch == null) continue;
      final price = _parseNumber(priceMatch.group(1)!);
      if (price != null) productPrices[nameMatch.group(1)!] = price;
    }

    return MetalPriceSnapshot(
      pricePerGram: pricePerGram,
      productPrices: productPrices,
    );
  }

  static double? _parseNumber(String raw) => double.tryParse(
    raw
        .replaceAll('&nbsp;', '')
        .replaceAll('&#160;', '')
        .replaceAll('&#xA0;', '')
        .replaceAll(RegExp(r'[\s  ]'), '')
        .replaceAll(',', '.'),
  );
}

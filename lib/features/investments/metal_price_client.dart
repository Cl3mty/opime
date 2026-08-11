import 'dart:async' show TimeoutException;
import 'dart:convert';
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

/// Métal précieux côtés par achat-or-et-argent.fr — chaque métal a sa page
/// catalogue dédiée ([MetalPriceClient]) et son propre fichier de cache
/// journalier (`metal_price_repository.dart`).
enum MetalKind {
  or('or'),
  argent('argent');

  const MetalKind(this.fileName);

  /// Nom de fichier (sans extension) du cache local de ce métal.
  final String fileName;
}

/// Métal d'un texte identifiant un produit physique : les pièces/lingots
/// d'argent sont explicitement listés dans [kKnownSilverProducts], tout
/// texte contenant "argent"/"silver" est présumé argent, tout le reste est
/// or (le cas le plus courant).
MetalKind metalKindFor(String text) {
  if (kKnownSilverProducts.contains(text)) return MetalKind.argent;
  if (kKnownGoldProducts.contains(text)) return MetalKind.or;
  final lower = text.toLowerCase();
  return lower.contains('argent') || lower.contains('silver')
      ? MetalKind.argent
      : MetalKind.or;
}

/// Métal d'un investissement "Métaux précieux", à partir de son identifiant
/// et de son libellé — si l'un des deux est explicitement de l'argent,
/// c'est de l'argent (même logique que l'ancien `_isSilver` du service de
/// rafraîchissement des cours).
MetalKind metalKindForInvestment({
  required String isin,
  required String label,
}) {
  if (metalKindFor(label) == MetalKind.argent ||
      metalKindFor(isin) == MetalKind.argent) {
    return MetalKind.argent;
  }
  return MetalKind.or;
}

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

/// Image produit d'une pièce/lingot (face "avers", voir [image1]) et
/// identifiants du produit, extraits du catalogue `workerApi` de
/// achat-or-et-argent.fr — voir [MetalPriceClient.fetchProductImages].
/// Sert à afficher, dans les accordéons de la page "Métaux précieux", la
/// photo du produit détenu à la place de l'avatar à initiales (voir
/// `real_patrimoine_adapter.dart` et `metal_image_repository.dart`).
class MetalProductImage {
  final String id;
  final String label;
  final String imageUrl;

  const MetalProductImage({
    required this.id,
    required this.label,
    required this.imageUrl,
  });

  /// Décode la réponse JSON du catalogue (voir [MetalPriceClient
  /// .fetchProductImages]). Retourne `null` si le JSON est illisible ou
  /// d'une forme inattendue (même philosophie défensive que
  /// [MetalPriceClient.parseSnapshot]) : l'app retombe alors sur l'avatar à
  /// initiales, jamais d'erreur affichée.
  static List<MetalProductImage>? parseCatalog(String jsonBody) {
    try {
      final decoded = jsonDecode(jsonBody);
      if (decoded is! Map) return null;
      final products = decoded['products'] as List? ?? const [];
      final result = <MetalProductImage>[];
      for (final product in products) {
        if (product is! Map) continue;
        final label = product['label'] as String?;
        final id = product['id'];
        final imageUrl = product['image1'] as String?;
        if (label == null ||
            id == null ||
            imageUrl == null ||
            imageUrl.isEmpty) {
          continue;
        }
        result.add(
          MetalProductImage(
            id: id.toString(),
            label: label,
            imageUrl: imageUrl,
          ),
        );
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}

/// Client pour le cours de l'or et de l'argent physiques, extrait des pages
/// publiques achat-or-et-argent.fr — il n'existe pas d'API de cours pour ces
/// métaux comme pour les actions/cryptos (voir `YahooFinanceClient`), donc
/// pas de ticker à résoudre : une page catalogue par métal
/// (`/or/1/` pour l'or, `/argent/2/` pour l'argent), dont les anciennes
/// pages de cours dédiées (`/or/cours-de-l-or`, cours au gramme dans un span
/// `js-cours-gramme-value` + tableau `cours-cpr-table-row`) ont disparu du
/// site.
///
/// Sur ces nouvelles pages, deux sources sont utilisées :
///  * le cours du métal : carte en-tête de la page (attribut `title`,
///    ex. `Or 122 385.03 €/kg`) — on ne retient que la carte du métal
///    demandé, en €/kg (converti en €/gramme, l'unité utilisée partout
///    ailleurs dans l'app) ;
///  * le prix de rachat de chaque produit : un tableau embarqué en JSON sous
///    la forme `products: [[{id, name, price, sellPrice}, ...]],` — voir
///    [MetalPriceSnapshot.productPrices], dont `sellPrice` est la valeur de
///    revente ("Vous vendez").
///
/// Même philosophie défensive que [YahooFinanceClient] : un échec (réseau,
/// changement de mise en page du site) retourne simplement `null` plutôt
/// que de propager une exception, pour ne jamais bloquer l'UI — l'app
/// retombe alors sur la dernière valorisation connue (ou le prix d'achat).
class MetalPriceClient {
  /// Carte en-tête du cours d'un métal : `title="Or 122 385.03 €/kg"` /
  /// `title="Argent 1 812.498 €/kg"`. Chaque page affiche aussi les cartes
  /// des autres métaux (onces d'or, platine, palladium...) mais leur titre
  /// commence par un autre nom ("Once d'or", "Platine"...), ce qui les
  /// exclut — d'où un motif distinct par métal ([MetalKind]).
  static final _orHeaderPattern = RegExp(
    r'\btitle="Or\s+([\d\s.,]+?)\s+€/(kg|g)\b',
  );
  static final _argentHeaderPattern = RegExp(
    r'\btitle="Argent\s+([\d\s.,]+?)\s+€/(kg|g)\b',
  );

  /// Tableau des produits et de leurs prix, embarqué en JSON sur les pages
  /// catalogue (une seule ligne, format `products: [[{...},...]],`) — le
  /// prix de rachat demandé est `sellPrice`.
  static final _productsJsonPattern = RegExp(
    r'products:\s*(\[\[.*?\]\])\s*,',
    dotAll: true,
  );

  /// Endpoint `workerApi` du site, utilisé pour les images produits
  /// ([fetchProductImages]) — le cours au gramme et les prix de rachat,
  /// eux, viennent du HTML des pages catalogue ([fetchSnapshot]).
  static const _workerApiUrl = 'https://www.achat-or-et-argent.fr/workerApi';

  Future<MetalPriceSnapshot?> fetchGoldSnapshot({
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) => fetchSnapshot(
    MetalKind.or,
    onNetworkError: onNetworkError,
    onNetworkSuccess: onNetworkSuccess,
  );

  Future<MetalPriceSnapshot?> fetchSilverSnapshot({
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) => fetchSnapshot(
    MetalKind.argent,
    onNetworkError: onNetworkError,
    onNetworkSuccess: onNetworkSuccess,
  );

  Future<MetalPriceSnapshot?> fetchSnapshot(
    MetalKind metal, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) {
    final url = switch (metal) {
      MetalKind.or => 'https://www.achat-or-et-argent.fr/or/1/',
      MetalKind.argent => 'https://www.achat-or-et-argent.fr/argent/2/',
    };
    return _fetchSnapshot(
      url,
      metal,
      onNetworkError: onNetworkError,
      onNetworkSuccess: onNetworkSuccess,
    );
  }

  Future<MetalPriceSnapshot?> _fetchSnapshot(
    String url,
    MetalKind metal, {
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

      return parseSnapshot(response.body, metal);
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

  /// Catalogue des images produits (une photo par pièce/lingot) extrait de
  /// l'endpoint `workerApi` du site (`methode=getProducts`, `type=1` pour
  /// l'or, `type=2` pour l'argent) — les images ne sont pas embarquées sur
  /// les pages catalogue utilisées pour les cours (voir [fetchSnapshot]),
  /// il faut cet appel séparé pour récupérer [MetalProductImage.image1].
  /// `null` en cas d'échec réseau ou de réponse inattendue — l'app affiche
  /// alors l'avatar à initiales, sans jamais bloquer ni lever d'erreur.
  Future<List<MetalProductImage>?> fetchProductImages(
    MetalKind metal, {
    void Function()? onNetworkError,
    void Function()? onNetworkSuccess,
  }) async {
    final type = metal == MetalKind.or ? '1' : '2';
    try {
      final response = await http.post(
        Uri.parse(_workerApiUrl),
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
              'AppleWebKit/605.1.15',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'methode=getProducts&type=$type&limit=250',
      );
      onNetworkSuccess?.call();
      if (response.statusCode != 200) return null;
      return MetalProductImage.parseCatalog(response.body);
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

  /// Extrait un instantané depuis le HTML des pages catalogue. Les classes
  /// et attributs peuvent être réordonnés par le site ; les expressions
  /// sont donc volontairement moins rigides que sa mise en page actuelle.
  static MetalPriceSnapshot? parseSnapshot(String html, MetalKind metal) {
    final headerPattern = metal == MetalKind.or
        ? _orHeaderPattern
        : _argentHeaderPattern;
    final headerMatch = headerPattern.firstMatch(html);
    if (headerMatch == null) return null;
    final rawPrice = _parseNumber(headerMatch.group(1)!);
    if (rawPrice == null) return null;
    final pricePerGram = headerMatch.group(2) == 'kg'
        ? rawPrice / 1000
        : rawPrice;

    final productPrices = <String, double>{};
    final jsonMatch = _productsJsonPattern.firstMatch(html);
    if (jsonMatch != null) {
      try {
        final decoded = jsonDecode(jsonMatch.group(1)!) as List;
        final products = decoded.isEmpty
            ? const <dynamic>[]
            : decoded.first is List
            ? decoded.first as List
            : decoded;
        for (final product in products) {
          if (product is! Map) continue;
          final name = product['name'] as String?;
          final id = product['id'] as int?;
          final sellPrice = (product['sellPrice'] as num?)?.toDouble();
          // Pas encore de marché de revente (produit neuf tout juste sorti,
          // ou collection limitée) : `sellPrice` vaut 0, on n'en tient pas
          // compte — la valorisation retombera sur le cours au gramme.
          if (name == null || sellPrice == null || sellPrice <= 0) continue;
          productPrices[name] = sellPrice;
          // Identifiant alternatif, au cas où le nom affiché changerait
          // entre le moment du choix et celui de la valorisation.
          if (id != null) productPrices['id:$id'] = sellPrice;
        }
      } catch (_) {
        // JSON illisible : on garde au moins le cours au gramme.
      }
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

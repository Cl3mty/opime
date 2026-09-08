import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/metal_price_client.dart';

void main() {
  test('parse le cours au gramme et les prix de rachat du JSON des pages catalogue', () {
    const html = '''
      <a class="header-course-card header-course-card--1" title="Or 122 385.03 €/kg">
        <span class="header-course-card__label">Or</span>
        <span class="header-course-card__price">122 385.03<small> €/kg</small></span>
      </a>
      <script>
        window.__DATA__ = { products: [[
          {"id":38,"name":"Lingot 1Kg Or","price":124208,"sellPrice":120537},
          {"id":3557,"name":"Lingot 100g Or","price":12531,"sellPrice":11870},
          {"id":23143,"name":"Signe du Zodiaque Or : Verseau 2026","price":150,"sellPrice":0}
        ]],
          next: 1 };
      </script>
    ''';

    final snapshot = MetalPriceClient.parseSnapshot(html, MetalKind.or);

    expect(snapshot, isNotNull);
    // Le cours de la page est affiché en €/kg : converti en €/gramme.
    expect(snapshot!.pricePerGram, closeTo(122.385, 0.001));
    expect(snapshot.productPrices['Lingot 1Kg Or'], 120537);
    expect(snapshot.productPrices['Lingot 100g Or'], 11870);
    // Identifiant alternatif, au cas où le nom affiché changerait.
    expect(snapshot.productPrices['id:38'], 120537);
    // Pas encore de marché de revente (sellPrice à 0) : exclu.
    expect(
      snapshot.productPrices.containsKey('Signe du Zodiaque Or : Verseau 2026'),
      isFalse,
    );
  });

  test('parse le cours de l\'argent depuis sa page dédiée', () {
    const html = '''
      <div class="header-course-card header-course-card--2" title="Argent 1 812.498 €/kg"></div>
      <script>products: [[{"id":22,"name":"5 Francs Semeuse 1959-1969","price":21.8,"sellPrice":15.4}]],
      </script>
    ''';

    final snapshot = MetalPriceClient.parseSnapshot(html, MetalKind.argent);

    expect(snapshot, isNotNull);
    expect(snapshot!.pricePerGram, closeTo(1.812498, 0.000001));
    expect(snapshot.productPrices['5 Francs Semeuse 1959-1969'], 15.4);
  });

  test('retourne null quand le cours du métal demandé est absent', () {
    expect(MetalPriceClient.parseSnapshot('<table></table>', MetalKind.or), isNull);
  });

  test('ignore la carte d\'un autre métal sur la page', () {
    const html = '''
      <div class="header-course-card header-course-card--2" title="Argent 1 812.498 €/kg"></div>
      <script>products: [[{"id":22,"name":"5 Francs Semeuse 1959-1969","price":21.8,"sellPrice":15.4}]],
      </script>
    ''';

    // La page argent porte bien une carte "Argent" mais pas de carte "Or".
    expect(
      MetalPriceClient.parseSnapshot(html, MetalKind.or),
      isNull,
    );
  });

  test('classifie un produit/texte comme métal', () {
    expect(metalKindFor('Lingot 1Kg Or'), MetalKind.or);
    expect(metalKindFor('5 Francs Semeuse 1959-1969'), MetalKind.argent);
    expect(metalKindFor('Saisie libre argent'), MetalKind.argent);
    expect(metalKindFor('Saisie libre'), MetalKind.or);
    expect(
      metalKindForInvestment(isin: 'Pièces 1965', label: 'Coffre argent'),
      MetalKind.argent,
    );
    expect(
      metalKindForInvestment(isin: 'Lingot 100g Or', label: 'Napoléon'),
      MetalKind.or,
    );
  });

  test('parse le catalogue des images produits (workerApi getProducts)', () {
    const jsonBody = '''
      {"nbProducts":2,"products":[
        {"id":"6","label":"20 Francs Napoléon","image1":"https://cdn.example.com/pieces/au/thumbs/napoleon.webp","image2":"https://cdn.example.com/pieces/au/thumbs/napoleon-rev.webp"},
        {"id":"22","label":"5 Francs Semeuse 1959-1969","image1":"https://cdn.example.com/pieces/ag/thumbs/semeuse.webp"}
      ]}
    ''';

    final catalog = MetalProductImage.parseCatalog(jsonBody);

    expect(catalog, isNotNull);
    expect(catalog, hasLength(2));
    expect(catalog![0].id, '6');
    expect(catalog[0].label, '20 Francs Napoléon');
    expect(
      catalog[0].imageUrl,
      'https://cdn.example.com/pieces/au/thumbs/napoleon.webp',
    );
    expect(catalog[1].id, '22');
    expect(catalog[1].label, '5 Francs Semeuse 1959-1969');
  });

  test('ignore un produit sans image ou sans libellé dans le catalogue', () {
    const jsonBody = '''
      {"products":[
        {"id":"1","label":"Pièce sans image"},
        {"id":"2","image1":"https://cdn.example.com/x.webp"},
        {"id":"3","label":"Lingot 1Kg Or","image1":"https://cdn.example.com/lingot.webp"}
      ]}
    ''';

    final catalog = MetalProductImage.parseCatalog(jsonBody);

    expect(catalog, isNotNull);
    expect(catalog, hasLength(1));
    expect(catalog!.single.label, 'Lingot 1Kg Or');
  });

  test('retourne null pour un JSON de catalogue illisible', () {
    expect(MetalProductImage.parseCatalog('pas du json'), isNull);
  });
}

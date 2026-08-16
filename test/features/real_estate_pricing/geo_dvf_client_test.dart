import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/geo_dvf_client.dart';

/// En-tête exact vérifié en direct sur un vrai fichier geo-dvf — sert à
/// prouver que le parsing fonctionne sur le format réel exact.
const _realHeader =
    'id_mutation,date_mutation,numero_disposition,nature_mutation,valeur_fonciere,'
    'adresse_numero,adresse_suffixe,adresse_nom_voie,adresse_code_voie,code_postal,'
    'code_commune,nom_commune,code_departement,ancien_code_commune,ancien_nom_commune,'
    'id_parcelle,ancien_id_parcelle,numero_volume,lot1_numero,lot1_surface_carrez,'
    'lot2_numero,lot2_surface_carrez,lot3_numero,lot3_surface_carrez,lot4_numero,'
    'lot4_surface_carrez,lot5_numero,lot5_surface_carrez,nombre_lots,code_type_local,'
    'type_local,surface_reelle_bati,nombre_pieces_principales,code_nature_culture,'
    'nature_culture,code_nature_culture_speciale,nature_culture_speciale,'
    'surface_terrain,longitude,latitude';

/// Ligne exemple exacte vérifiée en direct (commune 80174, mutation de
/// terrain nu — sans type_local ni surface bâtie, donc filtrée par
/// [GeoDvfClient.parseCsv], ce que le premier test ci-dessous vérifie).
const _realSampleRow =
    '2024-975882,2024-03-25,000001,Vente,30000,,,BOIS DE LA LONGUE HAIE,B001,80500,'
    '80174,Le Cardonnois,80,,,801740000A0010,,,,,,,,,,,,,0,,,,,S,sols,,,35,2.488429,49.631668';

/// Les colonnes lues par [GeoDvfClient.parseCsv] identifiées par leur nom
/// (pas leur position) — un en-tête réduit à ces seules colonnes suffit
/// pour les fixtures synthétiques ci-dessous, sans reproduire les ~40
/// colonnes du schéma réel.
const _minimalHeader =
    'nature_mutation,valeur_fonciere,surface_reelle_bati,longitude,latitude,'
    'date_mutation,code_commune,type_local';

void main() {
  group('GeoDvfClient.parseCsv', () {
    test('fichier réel vérifié : mutation de terrain nu (sans surface bâtie) filtrée', () {
      final sales = GeoDvfClient.parseCsv('$_realHeader\n$_realSampleRow');
      expect(sales, isEmpty);
    });

    test('parse une vente exploitable (maison avec surface bâtie)', () {
      const row = 'Vente,250000,90,2.3,49.9,2024-05-10,80021,Maison';
      final sales = GeoDvfClient.parseCsv('$_minimalHeader\n$row');

      expect(sales, hasLength(1));
      final sale = sales.single;
      expect(sale.natureMutation, 'Vente');
      expect(sale.valeurFonciere, 250000);
      expect(sale.typeLocal, 'Maison');
      expect(sale.surfaceReelleBati, 90);
      expect(sale.longitude, 2.3);
      expect(sale.latitude, 49.9);
      expect(sale.codeCommune, '80021');
      expect(sale.dateMutation, DateTime.parse('2024-05-10'));
      expect(sale.pricePerSqm, closeTo(2777.78, 0.1));
    });

    test('mutation non "Vente" conservée telle quelle (le filtrage est fait par l\'estimateur)', () {
      const row = 'Échange,250000,90,2.3,49.9,2024-05-10,80021,Maison';
      final sales = GeoDvfClient.parseCsv('$_minimalHeader\n$row');
      expect(sales, hasLength(1));
      expect(sales.single.natureMutation, 'Échange');
    });

    test('type_local vide devient null', () {
      const row = 'Vente,250000,90,2.3,49.9,2024-05-10,80021,';
      final sales = GeoDvfClient.parseCsv('$_minimalHeader\n$row');
      expect(sales.single.typeLocal, isNull);
    });

    test('valeur foncière non numérique : ligne ignorée, pas de crash', () {
      const malformed = 'Vente,PAS_UN_NOMBRE,90,2.3,49.9,2024-05-10,80021,Appartement';
      final sales = GeoDvfClient.parseCsv('$_minimalHeader\n$malformed');
      expect(sales, isEmpty);
    });

    test('surface ou coordonnées absentes : ligne ignorée', () {
      const missingSurface = 'Vente,250000,,2.3,49.9,2024-05-10,80021,Maison';
      expect(GeoDvfClient.parseCsv('$_minimalHeader\n$missingSurface'), isEmpty);
    });

    test('fichier vide ou uniquement l\'en-tête donne une liste vide', () {
      expect(GeoDvfClient.parseCsv(''), isEmpty);
      expect(GeoDvfClient.parseCsv(_minimalHeader), isEmpty);
    });
  });

  group('departmentCodeFromCommuneCode', () {
    test('département métropolitain standard', () {
      expect(departmentCodeFromCommuneCode('80021'), '80');
    });

    test('Corse (2A/2B)', () {
      expect(departmentCodeFromCommuneCode('2A004'), '2A');
      expect(departmentCodeFromCommuneCode('2B033'), '2B');
    });

    test('DOM (971-976)', () {
      expect(departmentCodeFromCommuneCode('97411'), '974');
    });
  });
}

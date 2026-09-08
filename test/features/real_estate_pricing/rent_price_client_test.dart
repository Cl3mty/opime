import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/real_estate_pricing/rent_price_client.dart';

/// En-tête et lignes exactes vérifiées en direct sur l'édition 2025 de la
/// "Carte des loyers" (`pred-mai-mef-dhup.csv`).
const _header =
    '"id_zone";"INSEE_C";"LIBGEO";"EPCI";"DEP";"REG";"loypredm2";"lwr.IPm2";'
    '"upr.IPm2";"TYPPRED";"nbobs_com";"nbobs_mail";"R2_adj"';

const _row1 =
    '"1";"37099";"Druye";"243700754";"37";"24";8,95647852540627;'
    '6,94544866376119;11,5497949030441;"maille";54;494;0,75527981050117';

const _row2 =
    '"1";"37200";"Rivarennes";"200072650";"37";"24";8,95647852540627;'
    '6,94544866376119;11,5497949030441;"maille";20;494;0,75527981050117';

void main() {
  group('RentPriceClient.parseCsv', () {
    test('parse les lignes réelles vérifiées en direct', () {
      final result = RentPriceClient.parseCsv('$_header\n$_row1\n$_row2');

      expect(result, hasLength(2));
      final druye = result['37099']!;
      expect(druye.departmentCode, '37');
      expect(druye.loyerPredM2, closeTo(8.9565, 0.001));
      expect(druye.lowerBound, closeTo(6.9454, 0.001));
      expect(druye.upperBound, closeTo(11.5498, 0.001));
      expect(druye.predictionType, 'maille');
      expect(druye.sampleSize, 54);
    });

    test('virgule décimale correctement convertie en point', () {
      final result = RentPriceClient.parseCsv('$_header\n$_row1');
      expect(result['37099']!.loyerPredM2, isNot(equals(8)));
      expect(result['37099']!.loyerPredM2, greaterThan(8.9));
      expect(result['37099']!.loyerPredM2, lessThan(9.0));
    });

    test('ligne avec loyer non numérique ignorée, pas de crash', () {
      const malformed =
          '"1";"99999";"Ville";"1";"99";"1";PAS_UN_NOMBRE;1,0;2,0;"commune";10;10;0,5';
      final result = RentPriceClient.parseCsv('$_header\n$malformed');
      expect(result, isEmpty);
    });

    test('fichier vide ou uniquement l\'en-tête donne une table vide', () {
      expect(RentPriceClient.parseCsv(''), isEmpty);
      expect(RentPriceClient.parseCsv(_header), isEmpty);
    });
  });
}

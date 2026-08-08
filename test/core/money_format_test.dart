import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/core/money_format.dart';

void main() {
  group('formatEuros', () {
    test('ajoute un séparateur de milliers', () {
      expect(formatEuros(1234567), '1 234 567 €');
    });

    test('arrondit à l\'euro le plus proche', () {
      expect(formatEuros(1234.6), '1 235 €');
    });

    test('gère les montants négatifs', () {
      expect(formatEuros(-1500), '-1 500 €');
    });

    test('montant nul', () {
      expect(formatEuros(0), '0 €');
    });
  });

  group('formatEurosCompact', () {
    test('sous 1000 € : valeur brute', () {
      expect(formatEurosCompact(500), '500 €');
    });

    test('entre 1000 et 999 999 € : en k €', () {
      expect(formatEurosCompact(12500), '13 k €');
    });

    test('au-delà d\'1 000 000 € : en M€', () {
      expect(formatEurosCompact(2500000), '3 M€');
    });
  });

  group('maskAmount', () {
    test('remplace chaque chiffre par un astérisque en gardant la ponctuation', () {
      expect(maskAmount('1 234 567 €'), '* *** *** €');
    });

    test('gère le signe négatif', () {
      expect(maskAmount('-1 500 €'), '-* *** €');
    });

    test('une chaîne sans chiffre reste inchangée', () {
      expect(maskAmount('€'), '€');
    });
  });

  group('displayEuros', () {
    test('affiche le montant réel quand hidden est faux', () {
      expect(displayEuros(1234, false), formatEuros(1234));
    });

    test('masque le montant quand hidden est vrai', () {
      expect(displayEuros(1234, true), maskAmount(formatEuros(1234)));
      expect(displayEuros(1234, true), isNot(contains(RegExp(r'\d'))));
    });
  });

  group('displayEurosCompact', () {
    test('affiche le format compact réel quand hidden est faux', () {
      expect(displayEurosCompact(12500, false), formatEurosCompact(12500));
    });

    test('masque le format compact quand hidden est vrai', () {
      expect(displayEurosCompact(12500, true), isNot(contains(RegExp(r'\d'))));
    });
  });
}

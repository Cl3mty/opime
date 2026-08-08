import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/core/date_format.dart';

void main() {
  test('formate une date au format JJ/MM/AAAA', () {
    expect(formatDateDdMmYyyy(DateTime(2026, 3, 5)), '05/03/2026');
  });

  test('complète les jours et mois à un chiffre avec un zéro', () {
    expect(formatDateDdMmYyyy(DateTime(2026, 1, 9)), '09/01/2026');
  });

  test('ne complète pas l\'année', () {
    expect(formatDateDdMmYyyy(DateTime(2026, 12, 31)), '31/12/2026');
  });
}

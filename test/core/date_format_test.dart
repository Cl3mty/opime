import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/date_format.dart';

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

  test('formatDateFrLong écrit le jour en toutes lettres à la française '
      '(jour sans zéro, mois en toutes lettres) — pas le gabarit '
      'anglo-saxon "Month Day, Year" par défaut de shadcn_flutter', () {
    expect(formatDateFrLong(DateTime(2026, 4, 24)), '24 avril 2026');
  });

  test(
    'formatDateFrLong ne complète pas le jour à un chiffre avec un zéro',
    () {
      expect(formatDateFrLong(DateTime(2026, 4, 5)), '5 avril 2026');
    },
  );

  test('formatDateFrLong couvre les 12 mois', () {
    expect(formatDateFrLong(DateTime(2026, 1, 1)), '1 janvier 2026');
    expect(formatDateFrLong(DateTime(2026, 8, 1)), '1 août 2026');
    expect(formatDateFrLong(DateTime(2026, 12, 1)), '1 décembre 2026');
  });
}

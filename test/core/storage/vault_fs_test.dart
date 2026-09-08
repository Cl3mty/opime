import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/storage/vault_fs.dart';

void main() {
  group('vaultPathSegments', () {
    test('découpe un chemin vault complet sans garder le segment racine', () {
      expect(
        vaultPathSegments('/Opime/Coffre-fort/Opime'),
        ['Opime', 'Coffre-fort', 'Opime'],
      );
    });

    test('la racine seule ne produit aucun segment', () {
      expect(vaultPathSegments('/'), isEmpty);
    });

    test('un chemin vide ne produit aucun segment', () {
      expect(vaultPathSegments(''), isEmpty);
    });

    test('conserve un segment unique', () {
      expect(vaultPathSegments('Opime'), ['Opime']);
    });

    test('gère les slashs redondants et finaux', () {
      expect(vaultPathSegments('/Opime//x/'), ['Opime', 'x']);
    });

    test('sans slash de tête', () {
      expect(vaultPathSegments('a/b/c'), ['a', 'b', 'c']);
    });
  });
}
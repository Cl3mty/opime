import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/expression_calculator.dart';

void main() {
  group('evaluateAmountExpression', () {
    test('nombre simple', () {
      expect(evaluateAmountExpression('50'), 50);
      expect(evaluateAmountExpression('50.5'), 50.5);
    });

    test('les 4 opérations de base', () {
      expect(evaluateAmountExpression('50+20'), 70);
      expect(evaluateAmountExpression('50-20'), 30);
      expect(evaluateAmountExpression('5*4'), 20);
      expect(evaluateAmountExpression('20/4'), 5);
    });

    test('priorité multiplication/division sur addition/soustraction', () {
      expect(evaluateAmountExpression('2+3*4'), 14);
      expect(evaluateAmountExpression('20-4/2'), 18);
    });

    test('parenthèses', () {
      expect(evaluateAmountExpression('(2+3)*4'), 20);
      expect(evaluateAmountExpression('2*(3+4)'), 14);
    });

    test('moins unaire', () {
      expect(evaluateAmountExpression('-5+20'), 15);
      expect(evaluateAmountExpression('5*-2'), -10);
    });

    test('virgule comme séparateur décimal, même convention que '
        'parseDecimal', () {
      expect(evaluateAmountExpression('5,5+2,5'), 8);
    });

    test('espaces autour des opérateurs ignorés', () {
      expect(evaluateAmountExpression(' 50 + 20 '), 70);
    });

    test('division par zéro : null plutôt qu\'une exception ou l\'infini', () {
      expect(evaluateAmountExpression('20/0'), isNull);
    });

    test('entrée vide : null', () {
      expect(evaluateAmountExpression(''), isNull);
      expect(evaluateAmountExpression('   '), isNull);
    });

    test('expression incomplète (encore en cours de frappe) : null plutôt '
        'que de planter, pour rester utilisable dans un onChanged en '
        'temps réel', () {
      expect(evaluateAmountExpression('50+'), isNull);
      expect(evaluateAmountExpression('('), isNull);
      expect(evaluateAmountExpression('(2+3'), isNull);
    });

    test('caractères inattendus : null', () {
      expect(evaluateAmountExpression('abc'), isNull);
      expect(evaluateAmountExpression('50e20'), isNull);
    });

    test('reliquat après une expression par ailleurs valide : null (ex : '
        'une parenthèse fermante en trop)', () {
      expect(evaluateAmountExpression('50)'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/real_estate/rent_models.dart';

void main() {
  group('RentPeriod', () {
    test('isPaid reflète uniquement paidAt', () {
      final unpaid = RentPeriod(
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 1, 31),
        amountDue: 800,
      );
      expect(unpaid.isPaid, isFalse);

      final paid = unpaid.copyWith(amountPaid: 800, paidAt: DateTime(2026, 1, 5));
      expect(paid.isPaid, isTrue);
      expect(unpaid.isPaid, isFalse); // immuable, l'original ne change pas
    });

    test('round-trip JSON conserve tous les champs', () {
      final period = RentPeriod(
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 1, 31),
        amountDue: 800,
        amountPaid: 800,
        paidAt: DateTime(2026, 1, 5),
        tenantName: 'Jean Dupont',
        note: 'Virement reçu en avance',
      );
      final decoded = RentPeriod.fromJson(period.toJson());
      expect(decoded.id, period.id);
      expect(decoded.periodStart, period.periodStart);
      expect(decoded.periodEnd, period.periodEnd);
      expect(decoded.amountDue, 800);
      expect(decoded.amountPaid, 800);
      expect(decoded.paidAt, period.paidAt);
      expect(decoded.tenantName, 'Jean Dupont');
      expect(decoded.note, 'Virement reçu en avance');
    });

    test('champs facultatifs absents : clés omises, restent null au '
        'décodage', () {
      final period = RentPeriod(
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 1, 31),
        amountDue: 800,
      );
      final json = period.toJson();
      expect(json.containsKey('amountPaid'), isFalse);
      expect(json.containsKey('paidAt'), isFalse);
      expect(json.containsKey('tenantName'), isFalse);
      expect(json.containsKey('note'), isFalse);

      final decoded = RentPeriod.fromJson(json);
      expect(decoded.amountPaid, isNull);
      expect(decoded.isPaid, isFalse);
    });

    test('copyWith avec sentinelle permet d\'effacer un champ nullable '
        '(ex : dépayer une période marquée par erreur)', () {
      final paid = RentPeriod(
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 1, 31),
        amountDue: 800,
        amountPaid: 800,
        paidAt: DateTime(2026, 1, 5),
      );
      final reverted = paid.copyWith(amountPaid: null, paidAt: null);
      expect(reverted.isPaid, isFalse);
      expect(reverted.amountPaid, isNull);
    });
  });

  group('WorkItem', () {
    test('round-trip JSON conserve tous les champs', () {
      final item = WorkItem(
        label: 'Réfection toiture',
        category: 'Gros œuvre',
        amount: 4500,
        date: DateTime(2026, 3, 1),
        note: 'Devis Dupont Couverture',
        documentId: 'doc_abc123',
      );
      final decoded = WorkItem.fromJson(item.toJson());
      expect(decoded.id, item.id);
      expect(decoded.label, 'Réfection toiture');
      expect(decoded.category, 'Gros œuvre');
      expect(decoded.amount, 4500);
      expect(decoded.date, item.date);
      expect(decoded.note, 'Devis Dupont Couverture');
      expect(decoded.documentId, 'doc_abc123');
    });

    test('champs facultatifs absents : clés omises, restent null au '
        'décodage', () {
      final item = WorkItem(
        label: 'Peinture',
        amount: 800,
        date: DateTime(2026, 2, 1),
      );
      final json = item.toJson();
      expect(json.containsKey('category'), isFalse);
      expect(json.containsKey('note'), isFalse);
      expect(json.containsKey('documentId'), isFalse);

      final decoded = WorkItem.fromJson(json);
      expect(decoded.category, isNull);
      expect(decoded.documentId, isNull);
    });

    test('copyWith avec sentinelle permet de délier le document rattaché', () {
      final item = WorkItem(
        label: 'Peinture',
        amount: 800,
        date: DateTime(2026, 2, 1),
        documentId: 'doc_abc',
      );
      final unlinked = item.copyWith(documentId: null);
      expect(unlinked.documentId, isNull);
    });
  });
}

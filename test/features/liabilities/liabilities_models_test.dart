import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';
import 'package:opime/features/simulations/loan_calculator.dart';

void main() {
  group('Liability amortissement (nouveau format)', () {
    test('construit un tableau figé cohérent avec un exemple réel '
        '(prêt étudiant, différé partiel de 60 mois, 60 échéances)', () {
      final liability = Liability(
        type: LiabilityType.creditAutre,
        name: 'Pret etudiant numero 2',
        montantEmprunte: 30000,
        tauxInteret: 0.9,
        assuranceMensuelle: 12.6,
        nbrEcheances: 60,
        dateDebut: DateTime(2019, 12, 4),
        loanType: LoanType.amortissable,
        differeActif: true,
        dureeDiffereMois: 60,
        typeDiffere: DeferType.partielle,
      );

      expect(liability.amortissement, hasLength(120));

      final firstMonth = liability.amortissement.first;
      expect(firstMonth.mois, 1);
      expect(firstMonth.date, DateTime(2019, 12, 4));
      expect(firstMonth.remboursementPrincipal, closeTo(0, 0.01));
      expect(firstMonth.interet, closeTo(22.5, 0.01));
      expect(firstMonth.assurance, closeTo(12.6, 0.01));
      expect(firstMonth.mensualite, closeTo(35.1, 0.01));
      expect(firstMonth.capitalRestantDu, closeTo(30000, 0.01));

      final firstAmortizingMonth = liability.amortissement[60];
      expect(firstAmortizingMonth.mois, 61);
      expect(firstAmortizingMonth.date, DateTime(2024, 12, 4));
      expect(firstAmortizingMonth.mensualite, closeTo(524.12, 0.5));
      expect(firstAmortizingMonth.capitalRestantDu, closeTo(29511, 1));

      final lastMonth = liability.amortissement.last;
      expect(lastMonth.mois, 120);
      expect(lastMonth.capitalRestantDu, closeTo(0, 0.01));
    });

    test(
      "toJson()/fromJson() font un aller-retour fidèle, au format demandé "
      '(nom, capital, apport, TAEG, nbrEcheances hors différé, '
      'assuranceMensuelle, dateEmprunt en JJ/MM/AAAA, amortissement complet)',
      () {
        final original = Liability(
          type: LiabilityType.creditAutre,
          name: 'Pret etudiant numero 2',
          montantEmprunte: 30000,
          apport: 0,
          tauxInteret: 0.9,
          assuranceMensuelle: 12.6,
          nbrEcheances: 60,
          dateDebut: DateTime(2019, 12, 4),
          loanType: LoanType.amortissable,
          differeActif: true,
          dureeDiffereMois: 60,
          typeDiffere: DeferType.partielle,
        );

        final json = original.toJson();
        expect(json['nom'], 'Pret etudiant numero 2');
        expect(json['capital'], 30000);
        expect(json['apport'], 0);
        expect(json['TAEG'], 0.9);
        // Les 60 mensualités différées ne comptent pas dans "nbrEcheances"
        // (voir l'exemple fourni : 60 échéances + 60 mois de différé = 120
        // mois au total).
        expect(json['nbrEcheances'], 60);
        expect(json['assuranceMensuelle'], 12.6);
        expect(json['nbrEcheancesDifferees'], 60);
        expect(json['dateEmprunt'], '04/12/2019');
        expect(json['amortissement'], hasLength(120));

        final firstEntryJson = (json['amortissement'] as List).first as Map;
        expect(firstEntryJson['date'], '04/12/2019');
        expect(firstEntryJson['mois'], 1);

        final roundTripped = Liability.fromJson(json);
        expect(roundTripped.name, original.name);
        expect(roundTripped.montantEmprunte, original.montantEmprunte);
        expect(roundTripped.assuranceMensuelle, original.assuranceMensuelle);
        expect(roundTripped.nbrEcheances, original.nbrEcheances);
        expect(roundTripped.dureeDiffereMois, original.dureeDiffereMois);
        expect(roundTripped.differeActif, isTrue);
        expect(roundTripped.typeDiffere, DeferType.partielle);
        expect(roundTripped.amortissement, hasLength(120));
        expect(
          roundTripped.remainingBalance,
          closeTo(original.remainingBalance, 0.01),
        );
      },
    );

    test("copyWith régénère l'amortissement quand un paramètre de calcul "
        'change, mais le conserve tel quel pour une simple mise à jour des '
        'documents', () {
      final original = Liability(
        type: LiabilityType.creditAutre,
        name: 'Test',
        montantEmprunte: 10000,
        tauxInteret: 2,
        nbrEcheances: 60,
        dateDebut: DateTime(2024, 1, 1),
      );

      final sameSchedule = original.copyWith(name: 'Renommé');
      expect(
        identical(sameSchedule.amortissement, original.amortissement),
        isTrue,
      );

      final regenerated = original.copyWith(tauxInteret: 5);
      expect(
        identical(regenerated.amortissement, original.amortissement),
        isFalse,
      );
      expect(
        regenerated.amortissement.first.interet,
        isNot(original.amortissement.first.interet),
      );
    });

    test('nbrEcheances accepte une durée totale qui n\'est pas un multiple de '
        '12 (ex : 63 mois, sans différé)', () {
      final liability = Liability(
        type: LiabilityType.creditAutre,
        name: 'Test',
        montantEmprunte: 5000,
        tauxInteret: 1,
        nbrEcheances: 63,
        dateDebut: DateTime(2024, 1, 1),
      );

      expect(liability.amortissement, hasLength(63));
      expect(liability.years.last.year, 5);
    });
  });
}

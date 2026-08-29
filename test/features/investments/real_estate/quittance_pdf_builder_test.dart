import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/real_estate/quittance_pdf_builder.dart';
import 'package:opime/features/investments/real_estate/rent_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'buildQuittancePdfBytes produit un PDF non vide pour une période payée',
    () async {
      final period = RentPeriod(
        periodStart: DateTime(2026, 4, 1),
        periodEnd: DateTime(2026, 4, 30),
        amountDue: 850,
        amountPaid: 850,
        paidAt: DateTime(2026, 4, 3),
        tenantName: 'Jean Dupont',
      );

      final bytes = await buildQuittancePdfBytes(
        period: period,
        propertyLabel: 'Appartement Lyon 6e',
        propertyAddress: '12 rue de la République, Lyon',
        landlordName: 'Camille Martin',
        generatedAt: DateTime(2026, 4, 3),
      );

      // Un PDF valide commence toujours par cette signature.
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
  );

  test(
    'buildQuittancePdfBytes fonctionne sans adresse ni nom de locataire '
    'renseignés (repli sur le libellé du bien / "le locataire")',
    () async {
      final period = RentPeriod(
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 1, 31),
        amountDue: 600,
        amountPaid: 600,
        paidAt: DateTime(2026, 1, 2),
      );

      final bytes = await buildQuittancePdfBytes(
        period: period,
        propertyLabel: 'Studio Paris 11e',
        landlordName: 'Camille Martin',
        generatedAt: DateTime(2026, 1, 2),
      );

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
  );
}

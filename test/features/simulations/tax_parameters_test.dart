import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/simulations/tax_parameters.dart';

void main() {
  group('TaxParameters.defaults', () {
    test(
      'reproduit exactement les valeurs légales connues (barème 2024/2026) '
      '— la référence vers laquelle un "Réinitialiser" doit ramener une '
      'valeur modifiée',
      () {
        final d = TaxParameters.defaults;

        expect(d.irLimits, [11294.0, 28797.0, 82341.0, 177106.0]);
        expect(d.irRates, [0.0, 11.0, 30.0, 41.0, 45.0]);

        expect(d.ifiLimits, [
          800000.0,
          1300000.0,
          2570000.0,
          5000000.0,
          10000000.0,
        ]);
        expect(d.ifiRates, [0.0, 0.5, 0.7, 1.0, 1.25, 1.5]);
        expect(d.ifiSeuilImposition, 1300000.0);

        expect(d.demembrementBrackets, hasLength(9));
        expect(d.demembrementBrackets.first.maxAge, 20);
        expect(d.demembrementBrackets.first.pctNue, 10);
        expect(d.demembrementBrackets.last.maxAge, isNull);
        expect(d.demembrementBrackets.last.pctNue, 90);

        expect(d.directLineBrackets, hasLength(7));
        expect(d.directLineBrackets.first.upper, 8072);
        expect(d.directLineBrackets.first.rate, 0.05);
        expect(d.directLineBrackets.last.upper, double.infinity);
        expect(d.directLineBrackets.last.rate, 0.45);

        expect(d.spouseBrackets, hasLength(7));
        expect(d.spouseBrackets[1].upper, 15932);

        expect(d.abattementEnfant, 100000);
        expect(d.abattementPetitEnfant, 31865);
        expect(d.abattementConjoint, 80724);
        expect(d.pfuIrRate, 12.8);
        expect(d.pfuPsRate, 18.6);
      },
    );
  });

  group('copyWith', () {
    test('ne change que le champ demandé, le reste reste identique', () {
      final modified = TaxParameters.defaults.copyWith(
        abattementEnfant: 150000,
      );

      expect(modified.abattementEnfant, 150000);
      expect(modified.abattementPetitEnfant, TaxParameters.defaults.abattementPetitEnfant);
      expect(modified.irLimits, TaxParameters.defaults.irLimits);
    });
  });

  group('JSON round-trip', () {
    test('toJson()/fromJson() conservent toutes les valeurs, y compris '
        'les tranches non plafonnées (upper == double.infinity, maxAge == '
        'null)', () {
      final original = TaxParameters.defaults.copyWith(
        irLimits: [12000.0, 29000.0, 83000.0, 178000.0],
        abattementEnfant: 120000,
      );

      final restored = TaxParameters.fromJson(original.toJson());

      expect(restored.irLimits, original.irLimits);
      expect(restored.irRates, original.irRates);
      expect(restored.ifiLimits, original.ifiLimits);
      expect(restored.ifiSeuilImposition, original.ifiSeuilImposition);
      expect(restored.abattementEnfant, 120000);
      expect(restored.demembrementBrackets.last.maxAge, isNull);
      expect(restored.demembrementBrackets.last.pctNue, 90);
      expect(restored.directLineBrackets.last.upper, double.infinity);
      expect(restored.pfuIrRate, original.pfuIrRate);
      expect(restored.pfuPsRate, original.pfuPsRate);
    });

    test(
      'un JSON vide (profil sans personnalisation) redonne exactement '
      'TaxParameters.defaults',
      () {
        final restored = TaxParameters.fromJson(const {});
        expect(restored.irLimits, TaxParameters.defaults.irLimits);
        expect(restored.abattementEnfant, TaxParameters.defaults.abattementEnfant);
        expect(restored.pfuIrRate, TaxParameters.defaults.pfuIrRate);
        expect(restored.pfuPsRate, TaxParameters.defaults.pfuPsRate);
      },
    );
  });

  group('loadTaxParameters / saveTaxParameters (persistance par profil)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('opime_tax_params_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test(
      'sans personnalisation enregistrée, charge TaxParameters.defaults',
      () async {
        final loaded = await loadTaxParameters(tempDir.path);
        expect(loaded.irLimits, TaxParameters.defaults.irLimits);
        expect(loaded.abattementEnfant, TaxParameters.defaults.abattementEnfant);
      },
    );

    test('sauvegarder puis charger reproduit fidèlement la personnalisation', () async {
      final custom = TaxParameters.defaults.copyWith(
        abattementEnfant: 130000,
        ifiSeuilImposition: 1000000,
      );
      await saveTaxParameters(tempDir.path, custom);

      final loaded = await loadTaxParameters(tempDir.path);
      expect(loaded.abattementEnfant, 130000);
      expect(loaded.ifiSeuilImposition, 1000000);
      // Les champs non modifiés restent fidèles à la référence.
      expect(loaded.irLimits, TaxParameters.defaults.irLimits);
    });
  });
}

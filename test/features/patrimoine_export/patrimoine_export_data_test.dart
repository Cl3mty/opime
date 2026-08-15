import 'package:flutter/widgets.dart' show Color, IconData;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';
import 'package:opime/features/patrimoine_export/patrimoine_export_data.dart';
import 'package:opime/features/simulations/loan_calculator.dart';

void main() {
  PatrimoineCategory category({
    required String label,
    required List<PatrimoineAccount> accounts,
  }) => PatrimoineCategory(
    id: label,
    label: label,
    icon: const IconData(0),
    color: const Color(0xFF000000),
    tier: AllocationTier.croissance,
    description: '',
    accounts: accounts,
  );

  group('exportAssetKey', () {
    test('compte seul : id du compte', () {
      expect(exportAssetKey('acc1'), 'acc1');
    });

    test('investissement au sein d\'un compte : composite', () {
      expect(exportAssetKey('acc1', 'inv1'), 'acc1|inv1');
    });
  });

  group('buildAssetExportCategories', () {
    test('conserve seulement les investissements sélectionnés et recalcule le total', () {
      final categories = [
        category(
          label: 'Actions & Fonds',
          accounts: [
            PatrimoineAccount(
              id: 'acc1',
              name: 'CTO',
              valeur: 300,
              plusValueAbs: 50,
              plusValuePercent: 20,
              investments: [
                PatrimoineAccount(
                  id: 'inv1',
                  name: 'MSCI World',
                  quantite: 10,
                  valeur: 200,
                  pru: 15,
                  plusValueAbs: 50,
                  plusValuePercent: 33.3,
                ),
                PatrimoineAccount(
                  id: 'inv2',
                  name: 'S&P 500',
                  quantite: 5,
                  valeur: 100,
                  pru: 20,
                  plusValueAbs: 0,
                  plusValuePercent: 0,
                ),
              ],
            ),
          ],
        ),
      ];

      final result = buildAssetExportCategories(categories, {
        exportAssetKey('acc1', 'inv1'),
      });

      expect(result, hasLength(1));
      expect(result.first.allRows, hasLength(1));
      expect(result.first.allRows.first.label, 'MSCI World');
      expect(result.first.total, 200);
    });

    test('un compte sans investissement propre utilise sa propre clé', () {
      final categories = [
        category(
          label: 'Immobilier',
          accounts: [
            PatrimoineAccount(
              id: 'acc-immo',
              name: 'Résidence principale',
              valeur: 400000,
              plusValueAbs: 0,
              plusValuePercent: 0,
            ),
          ],
        ),
      ];

      final result = buildAssetExportCategories(categories, {
        exportAssetKey('acc-immo'),
      });

      expect(result, hasLength(1));
      expect(result.first.allRows.single.label, 'Résidence principale');
    });

    test('une catégorie sans aucune ligne sélectionnée est omise', () {
      final categories = [
        category(
          label: 'Crypto',
          accounts: [
            PatrimoineAccount(
              id: 'acc-wallet',
              name: 'Wallet',
              valeur: 1000,
              plusValueAbs: 0,
              plusValuePercent: 0,
            ),
          ],
        ),
      ];

      final result = buildAssetExportCategories(categories, const {});

      expect(result, isEmpty);
    });

    test('regroupe les comptes d\'une même banque sous un même établissement', () {
      final categories = [
        category(
          label: 'Épargne',
          accounts: [
            PatrimoineAccount(
              id: 'acc-lva',
              name: 'Livret A',
              bankName: 'Boursorama',
              valeur: 5000,
              plusValueAbs: 0,
              plusValuePercent: 0,
            ),
            PatrimoineAccount(
              id: 'acc-ldds',
              name: 'LDDS',
              bankName: 'Boursorama',
              valeur: 2000,
              plusValueAbs: 0,
              plusValuePercent: 0,
            ),
          ],
        ),
      ];

      final result = buildAssetExportCategories(
        categories,
        {exportAssetKey('acc-lva'), exportAssetKey('acc-ldds')},
      );

      expect(result.single.establishments, hasLength(1));
      final establishment = result.single.establishments.single;
      expect(establishment.establishmentName, 'Boursorama');
      expect(establishment.showEstablishmentHeader, isTrue);
      expect(establishment.accounts, hasLength(2));
    });

    test('un compte isolé sans banque n\'affiche pas d\'en-tête établissement', () {
      final categories = [
        category(
          label: 'Immobilier',
          accounts: [
            PatrimoineAccount(
              id: 'acc-immo',
              name: 'Résidence principale',
              valeur: 400000,
              plusValueAbs: 0,
              plusValuePercent: 0,
            ),
          ],
        ),
      ];

      final result = buildAssetExportCategories(categories, {
        exportAssetKey('acc-immo'),
      });

      final establishment = result.single.establishments.single;
      expect(establishment.showEstablishmentHeader, isFalse);
      expect(establishment.accounts.single.showAccountHeader, isFalse);
    });

    test('un compte avec investissements affiche un en-tête de compte', () {
      final categories = [
        category(
          label: 'Actions & Fonds',
          accounts: [
            PatrimoineAccount(
              id: 'acc1',
              name: 'CTO',
              valeur: 200,
              plusValueAbs: 0,
              plusValuePercent: 0,
              investments: [
                PatrimoineAccount(
                  id: 'inv1',
                  name: 'MSCI World',
                  valeur: 200,
                  plusValueAbs: 0,
                  plusValuePercent: 0,
                ),
              ],
            ),
          ],
        ),
      ];

      final result = buildAssetExportCategories(categories, {
        exportAssetKey('acc1', 'inv1'),
      });

      final account = result.single.establishments.single.accounts.single;
      expect(account.showAccountHeader, isTrue);
      expect(account.accountName, 'CTO');
    });
  });

  group('buildLiabilityExportRows', () {
    Liability liability({
      required String id,
      required LiabilityType type,
      required String name,
    }) => Liability(
      id: id,
      type: type,
      name: name,
      montantEmprunte: 100000,
      tauxInteret: 3.5,
      nbrEcheances: 240,
      dateDebut: DateTime(2020, 1, 1),
      loanType: LoanType.amortissable,
    );

    test('filtre par sélection et conserve mensualité/taux/type', () {
      final liabilities = [
        liability(id: 'l1', type: LiabilityType.pretImmobilier, name: 'Prêt maison'),
        liability(id: 'l2', type: LiabilityType.creditAutre, name: 'Crédit auto'),
      ];

      final result = buildLiabilityExportRows(liabilities, {'l1'});

      expect(result, hasLength(1));
      expect(result.single.name, 'Prêt maison');
      expect(result.single.typeLabel, 'Prêt immobilier');
      expect(result.single.tauxInteret, 3.5);
      expect(result.single.mensualite, liabilities.first.mensualite);
    });
  });

  group('buildPatrimoineExportData', () {
    test('les totaux sont cohérents avec les sous-ensembles filtrés', () {
      final categories = [
        category(
          label: 'Épargne',
          accounts: [
            PatrimoineAccount(
              id: 'acc-lva',
              name: 'Livret A',
              valeur: 5000,
              plusValueAbs: 0,
              plusValuePercent: 0,
            ),
            PatrimoineAccount(
              id: 'acc-ldds',
              name: 'LDDS',
              valeur: 2000,
              plusValueAbs: 0,
              plusValuePercent: 0,
            ),
          ],
        ),
      ];
      final liabilities = [
        Liability(
          id: 'l1',
          type: LiabilityType.pretImmobilier,
          name: 'Prêt maison',
          montantEmprunte: 100000,
          tauxInteret: 3.5,
          nbrEcheances: 240,
          dateDebut: DateTime(2020, 1, 1),
        ),
      ];

      final data = buildPatrimoineExportData(
        profileName: 'Moi',
        generatedAt: DateTime(2026, 8, 15),
        assetCategories: categories,
        selectedAssetKeys: {exportAssetKey('acc-lva')},
        liabilities: liabilities,
        selectedLiabilityIds: {'l1'},
      );

      expect(data.totalActifs, 5000);
      expect(data.totalPassifs, liabilities.first.remainingBalance);
      expect(data.patrimoineNet, 5000 - liabilities.first.remainingBalance);
    });
  });
}

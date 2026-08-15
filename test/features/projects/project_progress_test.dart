import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/liabilities/liabilities_models.dart';
import 'package:opime/features/projects/project_models.dart';
import 'package:opime/features/projects/project_progress.dart';

void main() {
  final today = DateTime.utc(2026, 8, 14);

  InvestmentAccount account({
    required String id,
    required List<Investment> investments,
  }) => InvestmentAccount(
    id: id,
    assetClass: AssetClass.actionsEtFonds,
    name: 'Compte',
    investments: investments,
  );

  Investment investment({
    required String id,
    double? lastPrice,
    double? lastFxRateToEur,
    required List<Transaction> transactions,
  }) => Investment(
    id: id,
    isin: 'FR0000120271',
    label: 'Titre',
    lastPrice: lastPrice,
    lastFxRateToEur: lastFxRateToEur,
    transactions: transactions,
  );

  Liability liability({required String id, required double montantEmprunte}) =>
      Liability(
        id: id,
        type: LiabilityType.creditAutre,
        name: 'Crédit',
        montantEmprunte: montantEmprunte,
        apport: 0,
        tauxInteret: 2,
        assuranceMensuelle: 0,
        fraisDossier: 0,
        fraisGarantie: 0,
        nbrEcheances: 60,
        dateDebut: DateTime.utc(2024, 1, 1),
      );

  group('computeProjectProgress', () {
    test('montant cible atteint : percent = 100', () {
      final inv = investment(
        id: 'inv_1',
        lastPrice: 100,
        transactions: [
          Transaction(date: DateTime.utc(2024, 1, 1), isBuy: true, quantity: 100, unitPrice: 100),
        ],
      );
      final accounts = [account(id: 'account_1', investments: [inv])];
      final project = Project(
        name: 'Projet',
        echeance: DateTime.utc(2028, 1, 1),
        montantCible: 10000,
        assetLinks: const [
          ProjectAssetLink(accountId: 'account_1', investmentId: 'inv_1'),
        ],
      );

      final progress = computeProjectProgress(
        project: project,
        accounts: accounts,
        liabilities: const [],
        today: today,
      );

      expect(progress.currentNetValue, closeTo(10000, 1e-9));
      expect(progress.percent, closeTo(100, 1e-9));
      expect(progress.timeRemaining.isNegative, isFalse);
    });

    test('montant cible dépassé : percent > 100', () {
      final inv = investment(
        id: 'inv_1',
        lastPrice: 200,
        transactions: [
          Transaction(date: DateTime.utc(2024, 1, 1), isBuy: true, quantity: 100, unitPrice: 100),
        ],
      );
      final accounts = [account(id: 'account_1', investments: [inv])];
      final project = Project(
        name: 'Projet',
        echeance: DateTime.utc(2028, 1, 1),
        montantCible: 10000,
        assetLinks: const [
          ProjectAssetLink(accountId: 'account_1', investmentId: 'inv_1'),
        ],
      );

      final progress = computeProjectProgress(
        project: project,
        accounts: accounts,
        liabilities: const [],
        today: today,
      );

      expect(progress.percent, closeTo(200, 1e-9));
    });

    test('sans montant cible : percent null, temps restant toujours renseigné', () {
      final project = Project(name: 'Retraite', echeance: DateTime.utc(2050, 1, 1));

      final progress = computeProjectProgress(
        project: project,
        accounts: const [],
        liabilities: const [],
        today: today,
      );

      expect(progress.percent, isNull);
      expect(progress.timeRemaining.inDays, greaterThan(0));
    });

    test('échéance passée : durée négative', () {
      final project = Project(name: 'Projet', echeance: DateTime.utc(2020, 1, 1));

      final progress = computeProjectProgress(
        project: project,
        accounts: const [],
        liabilities: const [],
        today: today,
      );

      expect(progress.timeRemaining.isNegative, isTrue);
    });

    test('lien mort (investissement introuvable) : contribution nulle, pas d\'exception', () {
      final project = Project(
        name: 'Projet',
        echeance: DateTime.utc(2028, 1, 1),
        montantCible: 1000,
        assetLinks: const [
          ProjectAssetLink(accountId: 'account_absent', investmentId: 'inv_absent'),
        ],
      );

      final progress = computeProjectProgress(
        project: project,
        accounts: const [],
        liabilities: const [],
        today: today,
      );

      expect(progress.currentNetValue, 0);
      expect(progress.percent, 0);
    });

    test('actifs et passifs combinés : valeur nette = actifs - passifs', () {
      final inv = investment(
        id: 'inv_1',
        lastPrice: 100,
        transactions: [
          Transaction(date: DateTime.utc(2024, 1, 1), isBuy: true, quantity: 100, unitPrice: 100),
        ],
      );
      final accounts = [account(id: 'account_1', investments: [inv])];
      final liab = liability(id: 'liab_1', montantEmprunte: 3000);
      final project = Project(
        name: 'Projet',
        echeance: DateTime.utc(2028, 1, 1),
        assetLinks: const [
          ProjectAssetLink(accountId: 'account_1', investmentId: 'inv_1'),
        ],
        liabilityLinks: const [ProjectLiabilityLink(liabilityId: 'liab_1')],
      );

      final progress = computeProjectProgress(
        project: project,
        accounts: accounts,
        liabilities: [liab],
        today: today,
      );

      expect(progress.currentNetValue, closeTo(10000 - liab.remainingBalance, 1e-6));
    });
  });

  group('hasDanglingLinks', () {
    test('false quand tous les liens se résolvent', () {
      final inv = investment(id: 'inv_1', lastPrice: 100, transactions: const []);
      final accounts = [account(id: 'account_1', investments: [inv])];
      final liab = liability(id: 'liab_1', montantEmprunte: 1000);
      final project = Project(
        name: 'Projet',
        echeance: DateTime.utc(2028, 1, 1),
        assetLinks: const [
          ProjectAssetLink(accountId: 'account_1', investmentId: 'inv_1'),
        ],
        liabilityLinks: const [ProjectLiabilityLink(liabilityId: 'liab_1')],
      );

      expect(
        hasDanglingLinks(project: project, accounts: accounts, liabilities: [liab]),
        isFalse,
      );
    });

    test('true quand un lien d\'actif ne se résout plus', () {
      final project = Project(
        name: 'Projet',
        echeance: DateTime.utc(2028, 1, 1),
        assetLinks: const [
          ProjectAssetLink(accountId: 'introuvable', investmentId: 'introuvable'),
        ],
      );

      expect(
        hasDanglingLinks(project: project, accounts: const [], liabilities: const []),
        isTrue,
      );
    });

    test('true quand un lien de passif ne se résout plus', () {
      final project = Project(
        name: 'Projet',
        echeance: DateTime.utc(2028, 1, 1),
        liabilityLinks: const [ProjectLiabilityLink(liabilityId: 'introuvable')],
      );

      expect(
        hasDanglingLinks(project: project, accounts: const [], liabilities: const []),
        isTrue,
      );
    });
  });
}

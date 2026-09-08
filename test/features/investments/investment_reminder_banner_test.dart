import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investment_reminder_banner.dart';
import 'package:opime/features/investments/investments_models.dart';

/// [computeReminders]/[filterDismissedReminders] sont le cœur testable de
/// [ReminderBanner] (voir sa doc de tête) — des fonctions pures, sans E/S,
/// séparées volontairement du scan asynchrone (repository +
/// shared_preferences) du widget lui-même. Ce dernier n'a pas de test
/// widget dédié : comme `UpdateBanner`/`PriceSyncBanner` (même famille de
/// bandeau, également sans test), un scan déclenché depuis `initState` sur
/// une E/S réelle non contrôlable ne se termine jamais de façon fiable dans
/// ce harnais (`flutter_test`) — la logique de décision, elle, est
/// entièrement couverte ici.
void main() {
  group('computeReminders', () {
    InvestmentAccount peaAccount({DateTime? openingDate}) => InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.pea,
      name: 'Bourso',
      bankName: 'Bourso',
      openingDate: openingDate,
      investments: const [],
    );

    test(
      'un compte PEA dont le jalon fiscal tombe dans la fenêtre de 60 jours '
      'déclenche un rappel',
      () {
        final now = DateTime(2026, 3, 1);
        final account = peaAccount(
          openingDate: now.subtract(const Duration(days: 5 * 365 - 30)),
        );
        final reminders = computeReminders(accounts: [account], now: now);
        expect(reminders, hasLength(1));
        expect(reminders.single.entityId, account.id);
        expect(
          reminders.single.message,
          contains('Avantage fiscal « Bourso »'),
        );
      },
    );

    test(
      'un jalon fiscal encore loin (> 60 jours) ne déclenche aucun rappel',
      () {
        final now = DateTime(2026, 3, 1);
        final account = peaAccount(openingDate: now);
        expect(computeReminders(accounts: [account], now: now), isEmpty);
      },
    );

    test(
      'un jalon fiscal déjà atteint (dans le passé) reste remonté — pas '
      'seulement les échéances à venir',
      () {
        final now = DateTime(2026, 3, 1);
        final account = peaAccount(
          openingDate: now.subtract(const Duration(days: 5 * 365 + 10)),
        );
        expect(computeReminders(accounts: [account], now: now), hasLength(1));
      },
    );

    test(
      'une position Private Equity actionsSalarie avec une échéance '
      'd\'exercice proche déclenche un rappel dédié',
      () {
        final now = DateTime(2026, 3, 1);
        final investment = Investment(
          isin: 'pe-startup',
          label: 'Ma startup SAS',
          assetClass: AssetClass.privateEquity,
          privateEquityKind: PrivateEquityKind.actionsSalarie,
          exerciseDeadline: now.add(const Duration(days: 10)),
          transactions: const [],
        );
        final account = InvestmentAccount(
          assetClass: AssetClass.privateEquity,
          envelope: AccountEnvelope.fcprFcpi,
          name: 'Ma startup',
          bankName: 'Ma startup',
          investments: [investment],
        );
        final reminders = computeReminders(accounts: [account], now: now);
        expect(reminders, hasLength(1));
        expect(reminders.single.entityId, investment.id);
        expect(
          reminders.single.message,
          contains('Échéance d\'exercice BSPCE « Ma startup SAS »'),
        );
      },
    );

    test(
      'une échéance d\'exercice ne s\'applique qu\'aux positions '
      'actionsSalarie — un fonds PE (mode par défaut) n\'en tient jamais '
      'compte',
      () {
        final now = DateTime(2026, 3, 1);
        final investment = Investment(
          isin: 'pe-fund',
          label: 'Ardian Expansion Fund',
          assetClass: AssetClass.privateEquity,
          exerciseDeadline: now.add(const Duration(days: 10)),
          transactions: const [],
        );
        final account = InvestmentAccount(
          assetClass: AssetClass.privateEquity,
          envelope: AccountEnvelope.fcprFcpi,
          name: 'Club deal',
          bankName: 'Club deal',
          investments: [investment],
        );
        expect(computeReminders(accounts: [account], now: now), isEmpty);
      },
    );

    test('plusieurs rappels sont triés par date croissante', () {
      final now = DateTime(2026, 3, 1);
      final soon = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.assuranceVie,
        name: 'AV proche',
        bankName: 'Assureur',
        openingDate: now.subtract(const Duration(days: 8 * 365 - 5)),
        investments: const [],
      );
      final later = peaAccount(
        openingDate: now.subtract(const Duration(days: 5 * 365 - 45)),
      );
      final reminders = computeReminders(accounts: [later, soon], now: now);
      expect(reminders, hasLength(2));
      expect(reminders.first.entityId, soon.id);
      expect(reminders.last.entityId, later.id);
    });

    test('un compte sans jalon fiscal applicable (CTO) ne produit rien', () {
      final now = DateTime(2026, 3, 1);
      final account = InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.cto,
        name: 'CTO',
        bankName: 'CTO',
        investments: const [],
      );
      expect(computeReminders(accounts: [account], now: now), isEmpty);
    });
  });

  group('filterDismissedReminders', () {
    InvestmentReminder reminder(String id) => InvestmentReminder(
      entityId: id,
      date: DateTime(2026, 3, 1),
      message: 'Rappel $id',
    );

    test('retire uniquement les rappels marqués masqués', () {
      final a = reminder('a');
      final b = reminder('b');
      final result = filterDismissedReminders(
        [a, b],
        isDismissed: (key) => key == a.dismissKey,
      );
      expect(result, [b]);
    });

    test('ne retire rien si aucun n\'est masqué', () {
      final reminders = [reminder('a'), reminder('b')];
      final result = filterDismissedReminders(
        reminders,
        isDismissed: (_) => false,
      );
      expect(result, reminders);
    });

    test(
      'dismissKey change si la date change — une modification de '
      'openingDate fait redevenir visible un rappel masqué pour l\'ancienne '
      'occurrence',
      () {
        final original = InvestmentReminder(
          entityId: 'acc-1',
          date: DateTime(2026, 3, 1),
          message: 'x',
        );
        final afterEdit = InvestmentReminder(
          entityId: 'acc-1',
          date: DateTime(2026, 6, 1),
          message: 'x',
        );
        expect(original.dismissKey, isNot(afterEdit.dismissKey));
      },
    );
  });
}

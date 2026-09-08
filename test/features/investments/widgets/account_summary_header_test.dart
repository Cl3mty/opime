import 'package:flutter_test/flutter_test.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/widgets/account_summary_header.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Future<void> pump(WidgetTester tester, InvestmentAccount account) {
    return tester.pumpWidget(
      ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      
        home: Scaffold(
          child: AccountSummaryHeader(account: account, hidden: false),
        ),
      ),
    );
  }

  testWidgets('PEA : le sous-titre montre la banque, pas "PEA" en double', (
    tester,
  ) async {
    await pump(
      tester,
      InvestmentAccount(
        assetClass: AssetClass.actionsEtFonds,
        envelope: AccountEnvelope.pea,
        name: AccountEnvelope.pea.label,
        bankName: 'Boursorama',
        investments: const [],
      ),
    );

    expect(find.text('Actions & Fonds · Boursorama'), findsOneWidget);
    expect(find.text('Actions & Fonds · PEA'), findsNothing);
  });

  testWidgets(
    'PEA sans banque renseignée : pas de répétition, pas de "· null"',
    (tester) async {
      await pump(
        tester,
        InvestmentAccount(
          assetClass: AssetClass.actionsEtFonds,
          envelope: AccountEnvelope.pea,
          name: AccountEnvelope.pea.label,
          investments: const [],
        ),
      );

      expect(find.text('Actions & Fonds'), findsOneWidget);
      expect(find.text('Actions & Fonds · PEA'), findsNothing);
    },
  );

  testWidgets(
    'épargne : nom (banque) différent de l\'enveloppe, sous-titre inchangé',
    (tester) async {
      await pump(
        tester,
        InvestmentAccount(
          assetClass: AssetClass.epargne,
          envelope: AccountEnvelope.livretA,
          name: 'Boursorama',
          bankName: 'Boursorama',
          investments: const [],
        ),
      );

      expect(find.text('Épargne · Livret A'), findsOneWidget);
    },
  );

  testWidgets(
    'métaux précieux physiques : nom libre différent de l\'enveloppe, '
    'sous-titre inchangé',
    (tester) async {
      await pump(
        tester,
        InvestmentAccount(
          assetClass: AssetClass.metauxPrecieux,
          envelope: AccountEnvelope.coffrePersonnel,
          name: 'Coffre maison',
          investments: const [],
        ),
      );

      expect(find.text('Métaux précieux · Coffre personnel'), findsOneWidget);
    },
  );

  testWidgets(
    'compte exclu du patrimoine global : le badge apparaît sous le '
    'sous-titre',
    (tester) async {
      await pump(
        tester,
        InvestmentAccount(
          assetClass: AssetClass.autres,
          name: 'Montres',
          excludedFromPatrimoine: true,
          investments: const [],
        ),
      );

      expect(find.text('Hors patrimoine global'), findsOneWidget);
    },
  );

  testWidgets(
    'compte non exclu : pas de badge',
    (tester) async {
      await pump(
        tester,
        InvestmentAccount(
          assetClass: AssetClass.autres,
          name: 'Montres',
          investments: const [],
        ),
      );

      expect(find.text('Hors patrimoine global'), findsNothing);
    },
  );
}

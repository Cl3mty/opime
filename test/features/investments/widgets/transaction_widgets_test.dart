import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/widgets/transaction_widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;

void main() {
  group(
    'TransactionRow dans une popup étroite (position_detail_dialog.dart)',
    () {
      testWidgets(
        'la date reste sur une seule ligne, même avec un commentaire et '
        'la largeur réduite de amountsGroupWidth utilisées par cette popup',
        (tester) async {
          // Largeur de contenu réelle de `position_detail_dialog.dart`
          // (popup à `maxWidth: 560`, padding `EdgeInsets.all(20)`).
          await tester.pumpWidget(
            ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      
              home: Scaffold(
                child: Center(
                  child: SizedBox(
                    width: 520,
                    child: TransactionRow(
                      transaction: Transaction(
                        date: DateTime(2024, 9, 16),
                        isBuy: true,
                        quantity: 3.2557,
                        unitPrice: 129.17,
                        note: 'Un commentaire assez long pour tester la place',
                      ),
                      hidden: false,
                      assetClass: AssetClass.actionsEtFonds,
                      onEdit: () {},
                      onDelete: () {},
                      // Même configuration que `position_detail_dialog.dart`.
                      centerDate: false,
                      displayTotalOnly: true,
                      amountsGroupWidth: 110,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          // Une date sur une seule ligne à `.small()` tient dans une
          // hauteur de l'ordre d'une vingtaine de logical pixels — un
          // passage à deux lignes (la régression signalée) en ferait
          // sensiblement le double.
          final dateSize = tester.getSize(find.text('16/09/2024'));
          expect(dateSize.height, lessThan(20));
        },
      );
    },
  );

  group('ManualPriceBadge', () {
    testWidgets(
      'affiche "manuel" et un tooltip donnant la date de l\'estimation',
      (tester) async {
        await tester.pumpWidget(
          ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      
            home: Scaffold(
              child: ManualPriceBadge(updatedAt: DateTime(2024, 1, 15)),
            ),
          ),
        );

        expect(find.text('manuel'), findsOneWidget);

        final tooltipWidget = tester.widget<Tooltip>(find.byType(Tooltip));
        final tooltipContent = tooltipWidget.tooltip(
          tester.element(find.byType(Tooltip)),
        );
        await tester.pumpWidget(
          ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      home: Scaffold(child: tooltipContent)),
        );

        expect(find.text('Estimé le 15/01/2024'), findsOneWidget);
      },
    );
  });
}

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/opime_date_picker.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  // Même configuration que `main.dart`'s `ShadcnApp` — voir sa doc pour
  // pourquoi les trois délégués `Global*Localizations` sont nécessaires en
  // plus de [shadcnLocalizationsFrDelegate].
  Widget wrap(Widget child) => ShadcnApp(
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr')],
    localizationsDelegates: [
      shadcnLocalizationsFrDelegate,
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: Scaffold(child: child),
  );

  group('OpimeCalendarGrid', () {
    testWidgets(
      'la grille commence la semaine le lundi, pas le dimanche — février '
      '2026 : le 1er tombe un dimanche, donc calé lundi la grille remonte '
      'jusqu\'au 26 janvier (un lundi) et affiche le 31 janvier ; calée '
      'dimanche (l\'ancien bug de shadcn_flutter) le 1er février serait la '
      'toute première case, sans aucun jour de janvier à remonter',
      (tester) async {
        DateTime? selected;
        await tester.pumpWidget(
          wrap(
            OpimeCalendarGrid(
              value: DateTime(2026, 2, 15),
              onSelected: (d) => selected = d,
            ),
          ),
        );

        expect(find.text('Février 2026'), findsOneWidget);
        // Le 31 janvier n'existe qu'en tant que jour de tête d'un calage
        // lundi (jamais en tant que jour de février, qui n'en compte que
        // 28 en 2026) — sa présence prouve directement le calage lundi.
        expect(find.text('31'), findsOneWidget);
        expect(selected, isNull);
      },
    );

    testWidgets('les en-têtes de jour sont en français, dans l\'ordre lundi → '
        'dimanche', (tester) async {
      await tester.pumpWidget(
        wrap(
          OpimeCalendarGrid(value: DateTime(2026, 4, 24), onSelected: (_) {}),
        ),
      );

      for (final label in ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('taper un jour du mois affiché le rapporte via onSelected', (
      tester,
    ) async {
      DateTime? selected;
      await tester.pumpWidget(
        wrap(
          OpimeCalendarGrid(
            value: DateTime(2026, 4, 24),
            onSelected: (d) => selected = d,
          ),
        ),
      );

      await tester.tap(find.text('15'));
      await tester.pump();

      expect(selected, DateTime(2026, 4, 15));
    });

    testWidgets(
      'les chevrons naviguent au mois précédent/suivant, avec bascule '
      'd\'année correcte',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            OpimeCalendarGrid(value: DateTime(2026, 1, 15), onSelected: (_) {}),
          ),
        );

        expect(find.text('Janvier 2026'), findsOneWidget);

        await tester.tap(find.byIcon(LucideIcons.chevronLeft));
        await tester.pump();
        expect(find.text('Décembre 2025'), findsOneWidget);

        await tester.tap(find.byIcon(LucideIcons.chevronRight));
        await tester.pump();
        await tester.tap(find.byIcon(LucideIcons.chevronRight));
        await tester.pump();
        expect(find.text('Février 2026'), findsOneWidget);
      },
    );

    testWidgets('cliquer l\'en-tête remonte jour → mois → année, comme le '
        'sélecteur de shadcn_flutter — pour atteindre rapidement une date '
        'éloignée sans cliquer "mois précédent" des dizaines de fois', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OpimeCalendarGrid(value: DateTime(2026, 4, 24), onSelected: (_) {}),
        ),
      );

      // Vue jour : l'en-tête affiche mois + année.
      expect(find.text('Avril 2026'), findsOneWidget);

      // Un clic : vue mois, l'en-tête n'affiche plus que l'année.
      await tester.tap(find.text('Avril 2026'));
      await tester.pump();
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Avril'), findsOneWidget);
      expect(find.text('Décembre'), findsOneWidget);

      // Un second clic : vue année, une page de 12 ans (2016 = (2026 ~/
      // 12) * 12, la page contenant 2026).
      await tester.tap(find.text('2026'));
      await tester.pump();
      expect(find.text('2016 – 2027'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets(
      'choisir une année redescend en vue mois pour cette année-là, puis '
      'choisir un mois redescend en vue jour pour ce mois-là',
      (tester) async {
        DateTime? selected;
        await tester.pumpWidget(
          wrap(
            OpimeCalendarGrid(
              value: DateTime(2026, 4, 24),
              onSelected: (d) => selected = d,
            ),
          ),
        );

        await tester.tap(find.text('Avril 2026'));
        await tester.pump();
        await tester.tap(find.text('2026'));
        await tester.pump();
        expect(find.text('2016 – 2027'), findsOneWidget);

        // Une date lointaine (2010), typiquement l'usage visé par ce
        // dépli — atteinte en 2 clics au lieu de dizaines de "précédent".
        await tester.tap(find.byIcon(LucideIcons.chevronLeft));
        await tester.pump();
        expect(find.text('2004 – 2015'), findsOneWidget);
        await tester.tap(find.text('2010'));
        await tester.pump();

        // Retombée en vue mois, pour 2010.
        expect(find.text('2010'), findsOneWidget);
        expect(find.text('Décembre'), findsOneWidget);

        await tester.tap(find.text('Décembre'));
        await tester.pump();

        // Retombée en vue jour, pour décembre 2010.
        expect(find.text('Décembre 2010'), findsOneWidget);

        await tester.tap(find.text('10'));
        await tester.pump();
        expect(selected, DateTime(2010, 12, 10));
      },
    );

    testWidgets(
      'en vue année, l\'en-tête n\'est plus cliquable (rien de plus haut '
      'à remonter) — seuls les chevrons changent de page',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            OpimeCalendarGrid(value: DateTime(2026, 4, 24), onSelected: (_) {}),
          ),
        );

        await tester.tap(find.text('Avril 2026'));
        await tester.pump();
        await tester.tap(find.text('2026'));
        await tester.pump();
        expect(find.text('2016 – 2027'), findsOneWidget);

        await tester.tap(find.text('2016 – 2027'));
        await tester.pump();
        expect(find.text('2016 – 2027'), findsOneWidget);
      },
    );
  });

  group('OpimeDatePicker', () {
    testWidgets(
      'affiche la date sélectionnée au format français long ("24 avril '
      '2026"), pas le gabarit anglo-saxon par défaut de shadcn_flutter',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            OpimeDatePicker(value: DateTime(2026, 4, 24), onChanged: (_) {}),
          ),
        );

        expect(find.text('24 avril 2026'), findsOneWidget);
        expect(find.textContaining('April'), findsNothing);
      },
    );

    testWidgets('affiche le texte de repli fourni sans date sélectionnée', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OpimeDatePicker(
            value: null,
            onChanged: (_) {},
            placeholder: const Text('Date de début'),
          ),
        ),
      );

      expect(find.text('Date de début'), findsOneWidget);
    });

    testWidgets(
      'ouvre une boîte de dialogue en français (Annuler/Enregistrer) avec '
      'la grille lundi → dimanche, choisir un jour puis Enregistrer '
      'propage la date via onChanged',
      (tester) async {
        DateTime? changed;
        await tester.pumpWidget(
          wrap(
            OpimeDatePicker(
              value: DateTime(2026, 4, 24),
              onChanged: (d) => changed = d,
            ),
          ),
        );

        await tester.tap(find.text('24 avril 2026'));
        await tester.pumpAndSettle();

        expect(find.text('Annuler'), findsOneWidget);
        expect(find.text('Enregistrer'), findsOneWidget);
        expect(find.text('Avril 2026'), findsOneWidget);

        await tester.tap(find.text('15'));
        await tester.pump();
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();

        expect(changed, DateTime(2026, 4, 15));
      },
    );

    testWidgets('Annuler ferme la boîte de dialogue sans appeler onChanged', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        wrap(
          OpimeDatePicker(
            value: DateTime(2026, 4, 24),
            onChanged: (_) => called = true,
          ),
        ),
      );

      await tester.tap(find.text('24 avril 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pump();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('24 avril 2026'), findsOneWidget);
    });
  });
}

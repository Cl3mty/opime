import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Preuve concrète du bug corrigé dans main.dart/app_shell.dart : un
// CallbackShortcuts posé à l'intérieur du contenu d'une route (l'ancien
// emplacement, dans AppShell) ne reçoit jamais les évènements clavier tant
// qu'une AUTRE route (une boîte de dialogue, via showDialog) a le focus —
// ces deux routes sont des branches indépendantes du même Navigator, pas
// l'une descendante de l'autre. Posé en ancêtre du Navigator (le nouvel
// emplacement, via ShadcnApp/MaterialApp's `builder`), il reste actif quel
// que soit ce qui a le focus.
//
// Reproduit ici avec MaterialApp (pas ShadcnApp) pour isoler exactement le
// mécanisme Flutter en cause, sans dépendance au reste de l'app.
const _activator = SingleActivator(LogicalKeyboardKey.keyB, control: true);

Future<void> _pressCtrlB(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
}

void main() {
  testWidgets(
    'CallbackShortcuts posé DANS le contenu de la route ne se déclenche '
    'plus une fois une boîte de dialogue ouverte (bug reproduit)',
    (tester) async {
      var fired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => CallbackShortcuts(
              bindings: {_activator: () => fired = true},
              child: Focus(
                autofocus: true,
                child: Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => const AlertDialog(
                          content: Focus(autofocus: true, child: SizedBox()),
                        ),
                      ),
                      child: const Text('Ouvrir'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await _pressCtrlB(tester);
      await tester.pump();

      expect(
        fired,
        isFalse,
        reason:
            'un CallbackShortcuts posé dans le contenu de la route "accueil" '
            'ne doit pas voir les évènements clavier une fois le focus '
            'passé à une boîte de dialogue (autre route, pas un '
            'descendant) — c\'est exactement le bug rapporté',
      );
    },
  );

  testWidgets(
    'CallbackShortcuts posé en ancêtre du Navigator (via builder) reste '
    'actif même avec une boîte de dialogue ouverte et focalisée (correctif)',
    (tester) async {
      var fired = false;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => CallbackShortcuts(
            bindings: {_activator: () => fired = true},
            child: Focus(autofocus: true, child: child!),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => const AlertDialog(
                      content: Focus(autofocus: true, child: SizedBox()),
                    ),
                  ),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await _pressCtrlB(tester);
      await tester.pump();

      expect(
        fired,
        isTrue,
        reason:
            'posé en ancêtre du Navigator, le raccourci doit rester actif '
            'même quand une boîte de dialogue a le focus',
      );
    },
  );
}

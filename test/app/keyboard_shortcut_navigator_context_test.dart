import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Preuve concrète du bug corrigé dans main.dart : le `context` reçu par
// `MaterialApp`/`ShadcnApp`'s `builder` callback est un ANCÊTRE du Navigator
// interne de l'app (voir WidgetsApp.build : `Builder(builder: (context) =>
// widget.builder!(context, routing))`, où `routing` — qui contient le
// Navigator — est *retourné par* builder, donc structurellement un
// descendant de `context`, jamais un ancêtre). Un `showDialog(context:
// context, ...)` avec ce `context` échoue silencieusement à l'exécution
// ("Navigator operation requested with a context that does not include a
// Navigator", visible seulement dans les logs, jamais à l'écran) — c'est ce
// qui rendait le raccourci ⌘P (export PDF) totalement muet. Utiliser
// `navigatorKey.currentContext` (le contexte du Navigator lui-même, donc un
// descendant valide) corrige le problème.
const _activator = SingleActivator(LogicalKeyboardKey.keyP, control: true);

Future<void> _pressCtrlP(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyP);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
}

void main() {
  testWidgets(
    'showDialog avec le BuildContext du builder de MaterialApp échoue '
    '(bug reproduit)',
    (tester) async {
      Object? caughtError;
      FlutterError.onError = (details) => caughtError = details.exception;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => CallbackShortcuts(
            bindings: {
              _activator: () {
                try {
                  showDialog<void>(
                    context: context,
                    builder: (context) => const AlertDialog(content: SizedBox()),
                  );
                } catch (e) {
                  caughtError = e;
                }
              },
            },
            child: Focus(autofocus: true, child: child!),
          ),
          home: const Scaffold(body: SizedBox()),
        ),
      );

      await _pressCtrlP(tester);
      await tester.pump();

      expect(
        caughtError,
        isNotNull,
        reason:
            'le contexte du builder de MaterialApp n\'a pas le Navigator '
            'comme ancêtre — showDialog doit échouer avec cette référence, '
            'exactement comme le raccourci ⌘P le faisait silencieusement',
      );

      FlutterError.onError = FlutterError.dumpErrorToConsole;
    },
  );

  testWidgets(
    'showDialog avec navigatorKey.currentContext réussit (correctif)',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => CallbackShortcuts(
            bindings: {
              _activator: () {
                final navigatorContext = navigatorKey.currentContext;
                if (navigatorContext == null) return;
                showDialog<void>(
                  context: navigatorContext,
                  builder: (context) =>
                      const AlertDialog(content: Text('Export')),
                );
              },
            },
            child: Focus(autofocus: true, child: child!),
          ),
          home: const Scaffold(body: SizedBox()),
        ),
      );

      await _pressCtrlP(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Export'),
        findsOneWidget,
        reason:
            'navigatorKey.currentContext est un contexte posé sous le '
            'Navigator : showDialog doit réussir et afficher le dialogue',
      );
    },
  );
}

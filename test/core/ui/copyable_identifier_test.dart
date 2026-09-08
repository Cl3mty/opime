import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/copyable_identifier.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('affiche la valeur et la copie dans le presse-papier au tap', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      ShadcnApp(
        home: const Scaffold(
          child: CopyableIdentifier(
            value: 'US0378331005',
            toastTitle: 'ISIN copié',
          ),
        ),
      ),
    );

    expect(find.text('US0378331005'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pump();

    expect(copied, 'US0378331005');

    // Le tap déclenche aussi un toast de confirmation (voir
    // `CopyableIdentifier._copy`) dont le minuteur d'auto-dismiss doit
    // s'écouler avant la fin du test, sans quoi le framework de test
    // signale un minuteur encore actif après la destruction de l'arbre de
    // widgets.
    await tester.pump(const Duration(seconds: 10));
  });
}

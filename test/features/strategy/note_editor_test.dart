import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:opime/features/strategy/note_editor.dart';
import 'package:opime/features/strategy/strategy_documents_repository.dart';
import 'package:opime/features/strategy/strategy_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;
  late StrategyRepository repo;
  late String noteId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_note_editor_');
    repo = StrategyRepository(tempDir.path);
    final note = await repo.createNote();
    noteId = note.id;
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Widget buildEditor() {
    return ShadcnApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      // Sans ces délégués (voir `main.dart`), `QuillSimpleToolbar` lève
      // `MissingFlutterQuillLocalizationException` dès son premier build.
      localizationsDelegates: [
        ...FlutterQuillLocalizations.localizationsDelegates,
        shadcnLocalizationsFrDelegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      home: Scaffold(
        child: NoteEditor(repository: repo, noteId: noteId, onSaved: () {}),
      ),
    );
  }

  // `NoteEditor` charge le contenu de la note et ses documents via de vrais
  // appels `dart:io` (voir `_load`/`_loadDocuments`) : sans ce sondage à
  // l'intérieur de `runAsync`, ils ne se résolvent pas dans la zone
  // fake-async du test (même motif qu'ailleurs dans la suite, voir
  // `complete_patrimoine_dialog_test.dart`).
  Future<void> waitFor(WidgetTester tester, String text) => tester.runAsync(
    () async {
      for (var i = 0; i < 40; i++) {
        if (find.text(text).evaluate().isNotEmpty) return;
        await Future.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    },
  );

  testWidgets(
    'le bouton "Documents" ouvre une popup listant les documents de la '
    'note (vide par défaut), fermable via "Fermer"',
    (tester) async {
      await tester.pumpWidget(buildEditor());
      await waitFor(tester, 'Documents');

      expect(find.text('Documents'), findsOneWidget);

      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.text('Aucun document pour l\'instant.'), findsOneWidget);

      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      expect(find.text('Aucun document pour l\'instant.'), findsNothing);
    },
  );

  testWidgets(
    'un document déjà attaché à la note (via le repository) apparaît dans '
    'la popup, avec son compte reflété sur le bouton',
    (tester) async {
      final documentsRepo = StrategyDocumentsRepository(repo.vaultPath);
      await tester.runAsync(
        () => documentsRepo.addDocument(
          noteId,
          'IBKR 2025.pdf',
          Uint8List.fromList([1, 2, 3]),
          name: 'Résultats annuels IBKR',
        ),
      );

      await tester.pumpWidget(buildEditor());
      await waitFor(tester, 'Documents (1)');

      expect(find.text('Documents (1)'), findsOneWidget);

      await tester.tap(find.text('Documents (1)'));
      await tester.pumpAndSettle();

      expect(find.text('IBKR 2025.pdf'), findsOneWidget);
      expect(find.text('Résultats annuels IBKR'), findsOneWidget);
    },
  );
}

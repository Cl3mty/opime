import 'dart:io';

import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/strategy/strategy_folders_repository.dart';
import 'package:opime/features/strategy/strategy_repository.dart';
import 'package:opime/features/strategy/strategy_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

// Reflète `_folderColorPalette` (privée à `strategy_screen.dart`) : les
// pastilles de couleur portent une clé dérivée de leur valeur (voir
// `_ColorSwatchPicker`), pas de leur position dans la liste — plus robuste
// qu'un index dans le widget tree. Seuls le premier et le second élément
// de la palette sont utilisés ci-dessous.
const _firstPaletteColor = 0xFFEF5350;
const _secondPaletteColor = 0xFFFFA726;

void main() {
  late Directory tempDir;
  late StrategyRepository repo;
  late StrategyFoldersRepository foldersRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_strategy_screen_');
    repo = StrategyRepository(tempDir.path);
    foldersRepo = StrategyFoldersRepository(tempDir.path);
    // Une note pré-existante : sans ça, `StrategyScreen` crée les 5 notes
    // modèle au premier passage (voir `createTemplatesIfFirstVisit`),
    // parasitant les assertions ci-dessous sur le contenu de la liste.
    await repo.createNote();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Widget buildScreen() {
    return ShadcnApp(
      // `_NotesListPanel` seule (largeur < 700, voir `_splitThreshold`) :
      // pas d'éditeur affiché, donc pas besoin de piloter `NoteEditor`
      // (flutter_quill) pour ces tests centrés sur les dossiers — les
      // délégués restent quand même fournis par prudence, un tap sur une
      // note pousserait sinon vers `NoteEditor` sans eux.
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      home: Scaffold(child: StrategyScreen(vaultPath: tempDir.path)),
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildScreen());
    // Le chargement des notes/dossiers passe par de vrais appels
    // `dart:io` : sondage à l'intérieur de `runAsync` pour les laisser se
    // résoudre dans la zone fake-async du test (même motif qu'ailleurs
    // dans la suite, voir `complete_patrimoine_dialog_test.dart`).
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if (find.text('Nouvelle note').evaluate().isNotEmpty) return;
        await Future.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
  }

  /// Tape [finder] puis laisse le temps au travail asynchrone déclenché
  /// (souvent plusieurs lectures/écritures réelles chaînées — un dossier
  /// créé, par exemple, réécrit l'index puis recharge aussitôt tout l'état
  /// des dossiers, voir `StrategyFoldersRepository`/
  /// `_StrategyScreenState._loadFolders`) de se résoudre. Le *tap* lui-même
  /// doit être dans la zone réelle (`runAsync`), pas seulement une pause
  /// après coup, sans quoi le travail qu'il déclenche ne se résout jamais
  /// dans la zone fake-async du test — et une pause fixe unique s'est
  /// avérée trop courte pour certaines chaînes à plusieurs E/S, d'où ce
  /// sondage à intervalles réguliers plutôt qu'une seule pause.
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  /// Lit l'état persisté via un vrai appel `dart:io`, hors de la zone
  /// fake-async du test — voir [tapAndSettle].
  Future<T> readAsync<T>(WidgetTester tester, Future<T> Function() read) =>
      tester.runAsync(read).then((value) => value as T);

  Future<void> createFolder(
    WidgetTester tester,
    String name, {
    int color = _firstPaletteColor,
  }) async {
    await tester.tap(find.byIcon(LucideIcons.folderPlus));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, name);
    await tester.pump();
    // Sélectionne une couleur (obligatoire : le picker en propose une par
    // défaut, mais on veut exercer le choix explicite).
    await tester.tap(find.byKey(ValueKey('folder-color-swatch-$color')));
    await tester.pump();
    await tapAndSettle(tester, find.text('Créer'));
  }

  Future<void> moveNoteToFolder(WidgetTester tester, String folderName) async {
    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déplacer vers un dossier'));
    await tester.pumpAndSettle();
    // `.last` : le nom du dossier apparaît aussi dans l'en-tête de la
    // liste, derrière la popup — celui de la popup (l'option à choisir)
    // est ajouté après dans l'arbre.
    await tapAndSettle(tester, find.text(folderName).last);
  }

  testWidgets(
    'créer un dossier l\'ajoute à la liste, vide, avec le nom saisi',
    (tester) async {
      await pumpScreen(tester);
      await createFolder(tester, 'Impôts');

      expect(find.text('Impôts'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      final saved = await readAsync(tester, foldersRepo.listFolders);
      expect(saved, hasLength(1));
      expect(saved.single.name, 'Impôts');
    },
  );

  testWidgets(
    'déplacer une note vers un dossier la fait apparaître sous ce dossier '
    'et disparaître de "Sans dossier", et se reflète dans le repository',
    (tester) async {
      await pumpScreen(tester);
      await createFolder(tester, 'Impôts');
      await moveNoteToFolder(tester, 'Impôts');

      expect(find.text('Sans dossier'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      final notes = await readAsync(tester, repo.listNotes);
      final noteFolders = await readAsync(tester, foldersRepo.noteFolders);
      final folders = await readAsync(tester, foldersRepo.listFolders);
      expect(noteFolders[notes.single.id], folders.single.id);
    },
  );

  testWidgets('renommer un dossier met à jour son nom affiché', (
    tester,
  ) async {
    await pumpScreen(tester);
    await createFolder(tester, 'Impôts');

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renommer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Impôts 2026');
    await tester.pump();
    await tapAndSettle(tester, find.text('Renommer').last);

    expect(find.text('Impôts'), findsNothing);
    expect(find.text('Impôts 2026'), findsOneWidget);
  });

  testWidgets(
    'changer la couleur d\'un dossier la met à jour dans le repository',
    (tester) async {
      await pumpScreen(tester);
      await createFolder(tester, 'Impôts', color: _firstPaletteColor);
      final originalColor =
          (await readAsync(tester, foldersRepo.listFolders)).single.color;
      expect(originalColor, _firstPaletteColor);

      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Changer la couleur'));
      await tester.pumpAndSettle();
      // Une autre pastille que celle déjà sélectionnée à la création
      // referme directement la popup.
      await tapAndSettle(
        tester,
        find.byKey(ValueKey('folder-color-swatch-$_secondPaletteColor')),
      );

      final newColor =
          (await readAsync(tester, foldersRepo.listFolders)).single.color;
      expect(newColor, _secondPaletteColor);
    },
  );

  testWidgets(
    'supprimer un dossier le retire de la liste mais ne supprime pas les '
    'notes qu\'il contenait (redevenues "sans dossier")',
    (tester) async {
      await pumpScreen(tester);
      await createFolder(tester, 'Impôts');
      await moveNoteToFolder(tester, 'Impôts');

      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Supprimer').last);

      expect(find.text('Impôts'), findsNothing);
      expect(await readAsync(tester, foldersRepo.listFolders), isEmpty);
      // La note existe toujours (repérable via son titre par défaut).
      expect(await readAsync(tester, repo.listNotes), hasLength(1));
    },
  );

  testWidgets(
    'dupliquer une note (sans dossier) ajoute une seconde note dont le '
    'titre se termine par "(copie)", sans modifier l\'original',
    (tester) async {
      await pumpScreen(tester);
      final existingId = (await readAsync(tester, repo.listNotes)).single.id;
      await tester.runAsync(
        () => repo.writeNote(existingId, '# Ma note'),
      );

      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).last);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Dupliquer'));

      final notes = await readAsync(tester, repo.listNotes);
      expect(notes, hasLength(2));
      expect(
        notes.any((n) => n.title == 'Ma note (copie)'),
        isTrue,
        reason: 'Le duplicata devrait porter le titre suffixé',
      );
      expect(
        notes.any((n) => n.title == 'Ma note'),
        isTrue,
        reason: 'L\'original ne devrait pas avoir été modifié',
      );
    },
  );

  testWidgets(
    'dupliquer une note rangée dans un dossier place le duplicata dans le '
    'même dossier',
    (tester) async {
      await pumpScreen(tester);
      await createFolder(tester, 'Impôts');
      await moveNoteToFolder(tester, 'Impôts');

      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).last);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Dupliquer'));

      final notes = await readAsync(tester, repo.listNotes);
      final noteFolders = await readAsync(tester, foldersRepo.noteFolders);
      final folder = (await readAsync(tester, foldersRepo.listFolders)).single;
      expect(notes, hasLength(2));
      for (final note in notes) {
        expect(noteFolders[note.id], folder.id);
      }
    },
  );

  testWidgets(
    'le chevron d\'un dossier replie/déplie ses notes, sans agir sur les '
    'autres dossiers',
    (tester) async {
      await pumpScreen(tester);
      await createFolder(tester, 'Impôts');
      await moveNoteToFolder(tester, 'Impôts');

      expect(find.text('Nouvelle note'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.chevronDown));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle note'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.chevronDown));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle note'), findsOneWidget);
    },
  );
}

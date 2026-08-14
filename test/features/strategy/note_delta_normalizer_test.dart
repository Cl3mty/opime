import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:opime/features/strategy/note_delta_normalizer.dart';

void main() {
  // Chaîne de nettoyage appliquée à la sauvegarde d'une note, suivie de la
  // conversion Delta -> Markdown.
  String savePipeline(Delta delta) => DeltaToMarkdown().convert(
        rebaseListIndentation(
          stripDerivedParagraphIndentation(
            stripDisallowedColorAttributes(delta),
          ),
        ),
      );

  // Vrai si le markdown relu avec CommonMark (comme à l'ouverture d'une
  // note) contient un bloc de code (Element <pre>).
  bool containsCodeBlock(String markdown) {
    final doc = md.Document(
      encodeHtml: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    final ast = doc.parseLines(markdown.split('\n'));
    final found = <bool>[];
    void walk(md.Node node) {
      if (node is md.Element && node.tag == 'pre') found.add(true);
      if (node is md.Element) {
        node.children?.forEach(walk);
      }
    }

    ast.forEach(walk);
    return found.isNotEmpty;
  }

  // Attributs de ligne d'un Delta : liste ordonnée des maps d'attributs des
  // ops terminant par un saut de ligne (une map vide si l'op n'en a pas).
  List<Map<String, dynamic>> lineAttributesOf(Delta delta) => delta
      .toList()
      .where(
        (op) =>
            op.data is String && (op.data as String).contains('\n'),
      )
      .map((op) => op.attributes ?? <String, dynamic>{})
      .toList();

  group('rebaseListIndentation', () {
    test('recalibre une liste orpheline (premier élément indenté)', () {
      final delta = Delta()
        ..insert('a', {'list': 'bullet', 'indent': 2})
        ..insert('\n', {'list': 'bullet', 'indent': 2})
        ..insert('b', {'list': 'bullet', 'indent': 3})
        ..insert('\n', {'list': 'bullet', 'indent': 3})
        ..insert('texte qui suit')
        ..insert('\n');

      final markdown = savePipeline(delta);
      expect(markdown, contains('- a\n'));
      expect(markdown, contains('    - b\n'));
      // Un premier élément à 4+ espaces deviendrait un bloc de code à la
      // relecture : ce ne doit plus être le cas après rebase.
      expect(containsCodeBlock(markdown), isFalse);
    });

    test('recalibre une liste indentée après un paragraphe', () {
      final delta = Delta()
        ..insert('contexte')
        ..insert('\n')
        ..insert('a', {'list': 'bullet', 'indent': 1})
        ..insert('\n', {'list': 'bullet', 'indent': 1})
        ..insert('b', {'list': 'bullet', 'indent': 2})
        ..insert('\n', {'list': 'bullet', 'indent': 2});

      final markdown = savePipeline(delta);
      expect(markdown, contains('- a\n'));
      expect(containsCodeBlock(markdown), isFalse);
    });

    test("préserve la profondeur relative d'une liste imbriquée valide", () {
      final delta = Delta()
        ..insert('a', {'list': 'bullet'})
        ..insert('\n', {'list': 'bullet'})
        ..insert('b', {'list': 'bullet', 'indent': 1})
        ..insert('\n', {'list': 'bullet', 'indent': 1})
        ..insert('c', {'list': 'bullet', 'indent': 2})
        ..insert('\n', {'list': 'bullet', 'indent': 2})
        ..insert('texte qui suit')
        ..insert('\n');

      final markdown = savePipeline(delta);
      expect(markdown, contains('- a\n'));
      expect(markdown, contains('    - b\n'));
      expect(markdown, contains('        - c\n'));
      expect(containsCodeBlock(markdown), isFalse);
    });

    test('est idempotent', () {
      final delta = Delta()
        ..insert('a', {'list': 'bullet', 'indent': 1})
        ..insert('\n', {'list': 'bullet', 'indent': 1})
        ..insert('b', {'list': 'bullet', 'indent': 2})
        ..insert('\n', {'list': 'bullet', 'indent': 2});

      final once = rebaseListIndentation(delta);
      final twice = rebaseListIndentation(once);
      expect(
        twice.toList().map((op) => op.attributes).toList(),
        once.toList().map((op) => op.attributes).toList(),
      );
    });

    test('laisse les listes imbriquées à partir du niveau 0 inchangées', () {
      final delta = Delta()
        ..insert('a', {'list': 'bullet'})
        ..insert('\n', {'list': 'bullet'})
        ..insert('b', {'list': 'bullet', 'indent': 1})
        ..insert('\n', {'list': 'bullet', 'indent': 1});

      final rebased = rebaseListIndentation(delta);
      final lineAttrs = lineAttributesOf(rebased);
      expect(lineAttrs[0][Attribute.list.key], 'bullet');
      expect(lineAttrs[0].containsKey(Attribute.indent.key), isFalse);
      expect(lineAttrs[1][Attribute.indent.key], 1);
    });
  });

  group('stripDerivedParagraphIndentation', () {
    test("retire l'indentation des paragraphes mais pas des listes", () {
      final delta = Delta()
        ..insert('para', {'indent': 2})
        ..insert('\n', {'indent': 2})
        ..insert('item', {'list': 'bullet', 'indent': 1})
        ..insert('\n', {'list': 'bullet', 'indent': 1});

      final stripped = stripDerivedParagraphIndentation(delta);
      final lineAttrs = lineAttributesOf(stripped);
      expect(lineAttrs[0].containsKey(Attribute.indent.key), isFalse);
      expect(lineAttrs[1][Attribute.indent.key], 1);
    });
  });

  group('applyHeadingParagraphIndentation', () {
    test('indente les paragraphes qui suivent un titre', () {
      final delta = Delta()
        ..insert('Titre', {'header': 2})
        ..insert('\n', {'header': 2})
        ..insert('paragraphe')
        ..insert('\n');

      final indented = applyHeadingParagraphIndentation(delta);
      final lineAttrs = lineAttributesOf(indented);
      expect(lineAttrs[1][Attribute.indent.key], 2);
    });

    test("n'indente pas une liste qui suit un titre", () {
      final delta = Delta()
        ..insert('Titre', {'header': 2})
        ..insert('\n', {'header': 2})
        ..insert('item', {'list': 'bullet'})
        ..insert('\n', {'list': 'bullet'});

      final indented = applyHeadingParagraphIndentation(delta);
      final lineAttrs = lineAttributesOf(indented);
      expect(lineAttrs[1].containsKey(Attribute.indent.key), isFalse);
    });
  });
}

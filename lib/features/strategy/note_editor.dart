import 'dart:async';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'note_delta_normalizer.dart';
import 'strategy_repository.dart';

class NoteEditor extends StatefulWidget {
  final StrategyRepository repository;
  final String noteId;
  final VoidCallback onSaved;

  const NoteEditor({
    super.key,
    required this.repository,
    required this.noteId,
    required this.onSaved,
  });

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  QuillController? _controller;
  Timer? _debounce;

  final FocusNode _focusNode = FocusNode();

  // Encode underline en HTML brut (<u>) car le markdown standard n'a pas de
  // syntaxe pour cet attribut.
  final DeltaToMarkdown _deltaToMarkdown = DeltaToMarkdown(
    customTextAttrsHandlers: {
      Attribute.underline.key: CustomAttributeHandler(
        beforeContent: (attribute, node, output) => output.write('<u>'),
        afterContent: (attribute, node, output) => output.write('</u>'),
      ),
    },
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final markdown = await widget.repository.readNote(widget.noteId);
    final mdToDelta = MarkdownToDelta(
      markdownDocument: md.Document(
        encodeHtml: false,
        extensionSet: md.ExtensionSet.gitHubFlavored,
      ),
    );
    final rawDelta = mdToDelta.convert(
      markdown.isEmpty ? '# Nouvelle note\n' : markdown,
    );
    final delta = applyHeadingParagraphIndentation(
      stripDisallowedColorAttributes(
        normalizeLinkedTextAttributes(applyRawHtmlFormatting(rawDelta)),
      ),
    );
    final controller = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );
    controller.changes.listen((_) => _scheduleSave());
    setState(() => _controller = controller);
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() async {
    final controller = _controller;
    if (controller == null) return;
    final delta = controller.document.toDelta();
    final cleanedDelta = rebaseListIndentation(
      stripDerivedParagraphIndentation(
        stripDisallowedColorAttributes(delta),
      ),
    );
    final markdown = _deltaToMarkdown.convert(cleanedDelta);
    await widget.repository.writeNote(widget.noteId, markdown);
    widget.onSaved();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _save();
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final accentColor = Theme.of(context).colorScheme.primary;
    // flutter_quill code en dur la couleur des blocs de code
    // (`Colors.blue.shade900`, voir `default_styles.dart`) au lieu de la
    // dériver du thème — donc tout texte importé du Markdown comme bloc de
    // code (par ex. des lignes indentées de 4 espaces, traitées comme un
    // bloc de code indenté par le parseur CommonMark) s'affiche en bleu
    // quel que soit le thème de l'app. On force explicitement sa couleur,
    // comme pour les titres.
    final foregroundColor = Theme.of(context).colorScheme.foreground;
    final headingColor100 = accentColor;
    final headingColor80 = accentColor.withValues(alpha: 0.8);
    final headingColor60 = accentColor.withValues(alpha: 0.6);
    final headingColor40 = accentColor.withValues(alpha: 0.4);
    final defaultStyles = DefaultStyles.getInstance(context);
    final defaultListStyle = defaultStyles.lists!;
    final baseIndentWidthBuilder = defaultListStyle.indentWidthBuilder;

    DefaultTextBlockStyle? headingStyle(
      DefaultTextBlockStyle? base,
      double leftIndent, {
      Color? color,
    }) {
      if (base == null) return null;
      return base.copyWith(
        style: base.style.copyWith(color: color),
        horizontalSpacing: base.horizontalSpacing.copyWith(left: leftIndent),
      );
    }

    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: QuillSimpleToolbar(
            controller: controller,
            config: const QuillSimpleToolbarConfig(
              showFontFamily: false,
              showFontSize: false,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showAlignmentButtons: true,
              showLeftAlignment: false,
              showCenterAlignment: true,
              showRightAlignment: false,
              showJustifyAlignment: false,
              showHeaderStyle: true,
              showListNumbers: true,
              showListBullets: true,
              showListCheck: true,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showLink: true,
              showUndo: true,
              showRedo: true,
              showDividers: true,
              showSearchButton: false,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: QuillEditor.basic(
              controller: controller,
              focusNode: _focusNode,
              config: QuillEditorConfig(
                placeholder: 'Écris ta stratégie...',
                customStyles: DefaultStyles(
                  h1: headingStyle(defaultStyles.h1, 0, color: headingColor100),
                  h2: headingStyle(defaultStyles.h2, 10, color: headingColor80),
                  h3: headingStyle(defaultStyles.h3, 20, color: headingColor60),
                  h4: headingStyle(defaultStyles.h4, 30, color: headingColor40),
                  h5: headingStyle(
                    defaultStyles.h5,
                    40,
                    color: foregroundColor,
                  ),
                  h6: headingStyle(
                    defaultStyles.h6,
                    50,
                    color: foregroundColor,
                  ),
                  paragraph: headingStyle(
                    defaultStyles.paragraph,
                    0,
                    color: foregroundColor,
                  ),
                  quote: headingStyle(
                    defaultStyles.quote,
                    0,
                    color: foregroundColor.withValues(alpha: 0.6),
                  ),
                  code: headingStyle(
                    defaultStyles.code,
                    0,
                    color: foregroundColor,
                  ),
                  lists: defaultListStyle.copyWith(
                    indentWidthBuilder:
                        (block, buildContext, count, numberPointWidthBuilder) {
                          final attrs = block.style.attributes;
                          if (attrs.containsKey(Attribute.list.key) ||
                              attrs.containsKey(Attribute.blockQuote.key) ||
                              attrs.containsKey(Attribute.codeBlock.key)) {
                            return baseIndentWidthBuilder(
                              block,
                              buildContext,
                              count,
                              numberPointWidthBuilder,
                            );
                          }

                          final indentLevel =
                              attrs[Attribute.indent.key]?.value as int? ?? 0;
                          return HorizontalSpacing(indentLevel * 10, 0);
                        },
                  ),
                  link: TextStyle(
                    color: accentColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

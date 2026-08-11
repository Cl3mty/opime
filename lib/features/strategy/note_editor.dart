import 'dart:async';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
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

  // Marqueurs reconnus dans le texte brut du Delta issu du markdown : le
  // parseur markdown traite le HTML inline comme du texte littéral (il ne le
  // structure pas), donc <u>/<span> survivent tels quels dans les ops texte.
  static final RegExp _tagPattern = RegExp(
    r'''<u>|</u>|<span\b[^>]*>|</span>|<a\b[^>]*>|</a>''',
    caseSensitive: false,
  );
  static final RegExp _hrefPattern = RegExp(
    r'''href=(?:"([^"]+)"|'([^']+)')''',
  );
  static final RegExp _stylePattern = RegExp(
    r'''style\s*=\s*(?:"([^"]*)"|'([^']*)')''',
  );
  static final RegExp _cssColorPattern = RegExp(
    r'''(?:^|;)\s*color\s*:\s*([^;]+)\s*(?:;|$)''',
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
    final delta = _applyHeadingParagraphIndentation(
      _stripDisallowedColorAttributes(
        _normalizeLinkedTextAttributes(_applyRawHtmlFormatting(rawDelta)),
      ),
    );
    final controller = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );
    controller.changes.listen((_) => _scheduleSave());
    setState(() => _controller = controller);
  }

  Delta _applyHeadingParagraphIndentation(Delta input) {
    final result = Delta();
    int? currentHeadingIndentLevel;
    var lineHasContent = false;

    Map<String, dynamic>? textAttributes(Map<String, dynamic>? attrs) {
      if (attrs == null || attrs.isEmpty) return null;
      final filtered = Map<String, dynamic>.from(attrs)
        ..removeWhere((key, _) => Attribute.blockKeys.contains(key));
      return filtered.isEmpty ? null : filtered;
    }

    Map<String, dynamic> lineAttributes(Map<String, dynamic>? attrs) =>
        attrs == null ? <String, dynamic>{} : Map<String, dynamic>.from(attrs);

    for (final op in input.toList()) {
      if (op.data is! String) {
        result.push(op);
        lineHasContent = true;
        continue;
      }

      final attrs = op.attributes;
      final text = op.data as String;
      final parts = text.split('\n');

      for (var index = 0; index < parts.length; index++) {
        final chunk = parts[index];
        final isLineBreak = index < parts.length - 1;

        if (chunk.isNotEmpty) {
          result.insert(chunk, textAttributes(attrs));
          lineHasContent = true;
        }

        if (!isLineBreak) continue;

        final newlineAttrs = lineAttributes(attrs);
        final headerLevel = newlineAttrs[Attribute.header.key] as int?;
        final hasDerivedIndentTarget =
            !newlineAttrs.containsKey(Attribute.header.key) &&
            !newlineAttrs.containsKey(Attribute.list.key) &&
            !newlineAttrs.containsKey(Attribute.blockQuote.key) &&
            !newlineAttrs.containsKey(Attribute.codeBlock.key);

        if (hasDerivedIndentTarget) {
          if (lineHasContent && currentHeadingIndentLevel != null) {
            newlineAttrs[Attribute.indent.key] = currentHeadingIndentLevel + 1;
          } else {
            newlineAttrs.remove(Attribute.indent.key);
          }
        }

        result.insert('\n', newlineAttrs.isEmpty ? null : newlineAttrs);

        if (headerLevel != null) {
          currentHeadingIndentLevel = headerLevel > 1 ? headerLevel - 1 : 0;
        }
        lineHasContent = false;
      }
    }

    return result;
  }

  /// Les liens gardent toujours leur couleur d'accent: on retire toute couleur
  /// inline éventuellement importée avec l'attribut link.
  Delta _normalizeLinkedTextAttributes(Delta input) {
    final result = Delta();
    for (final op in input.toList()) {
      final attrs = op.attributes;
      if (attrs == null || !attrs.containsKey(Attribute.link.key)) {
        result.push(op);
        continue;
      }

      final normalizedAttrs = Map<String, dynamic>.from(attrs)
        ..remove(Attribute.color.key);
      result.insert(op.data, normalizedAttrs.isEmpty ? null : normalizedAttrs);
    }
    return result;
  }

  // Les couleurs texte/surlignage sont désactivées dans cet éditeur.
  Delta _stripDisallowedColorAttributes(Delta input) {
    final result = Delta();
    for (final op in input.toList()) {
      final attrs = op.attributes;
      if (attrs == null || attrs.isEmpty) {
        result.push(op);
        continue;
      }

      final cleanedAttrs = Map<String, dynamic>.from(attrs)
        ..remove(Attribute.color.key)
        ..remove(Attribute.background.key);

      result.insert(op.data, cleanedAttrs.isEmpty ? null : cleanedAttrs);
    }
    return result;
  }

  Delta _stripDerivedParagraphIndentation(Delta input) {
    final result = Delta();
    for (final op in input.toList()) {
      final attrs = op.attributes;
      if (attrs == null || !attrs.containsKey(Attribute.indent.key)) {
        result.push(op);
        continue;
      }

      final shouldKeepIndent =
          attrs.containsKey(Attribute.list.key) ||
          attrs.containsKey(Attribute.blockQuote.key) ||
          attrs.containsKey(Attribute.codeBlock.key) ||
          attrs.containsKey(Attribute.header.key);
      if (shouldKeepIndent) {
        result.push(op);
        continue;
      }

      final cleanedAttrs = Map<String, dynamic>.from(attrs)
        ..remove(Attribute.indent.key);
      result.insert(op.data, cleanedAttrs.isEmpty ? null : cleanedAttrs);
    }
    return result;
  }

  String? _extractSpanColor(String tag) {
    final styleMatch = _stylePattern.firstMatch(tag);
    if (styleMatch == null) return null;

    final styleContent = styleMatch.group(1) ?? styleMatch.group(2);
    if (styleContent == null || styleContent.isEmpty) return null;

    final colorMatch = _cssColorPattern.firstMatch(styleContent);
    if (colorMatch == null) return null;

    final rawColor = colorMatch.group(1)?.trim();
    if (rawColor == null || rawColor.isEmpty) return null;

    // Conserve uniquement les couleurs hex compatibles Quill.
    final hexMatch = RegExp(
      r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$',
    ).firstMatch(rawColor);
    if (hexMatch == null) return null;

    final hex = hexMatch.group(1)!;
    if (hex.length == 3) {
      final r = hex[0];
      final g = hex[1];
      final b = hex[2];
      return '#$r$r$g$g$b$b';
    }
    return '#${hex.toLowerCase()}';
  }

  /// Retire les marqueurs <u>/<span style="color:..."> du texte et
  /// réapplique les attributs Quill correspondants aux portions concernées.
  Delta _applyRawHtmlFormatting(Delta input) {
    final result = Delta();
    // Pile des attributs "extra" actuellement actifs pendant le scan.
    final activeExtra = <MapEntry<String, dynamic>>[];

    Map<String, dynamic> currentExtra() {
      final merged = <String, dynamic>{};
      for (final entry in activeExtra) {
        merged[entry.key] = entry.value;
      }
      return merged;
    }

    void popMatching(String key) {
      for (var i = activeExtra.length - 1; i >= 0; i--) {
        if (activeExtra[i].key == key) {
          activeExtra.removeAt(i);
          return;
        }
      }
    }

    for (final op in input.toList()) {
      if (op.data is! String) {
        result.push(op);
        continue;
      }
      final text = op.data as String;
      if (!text.contains('<')) {
        final extra = currentExtra();
        final attrs = {...?op.attributes, ...extra};
        result.insert(text, attrs.isEmpty ? null : attrs);
        continue;
      }

      var lastEnd = 0;
      for (final match in _tagPattern.allMatches(text)) {
        if (match.start > lastEnd) {
          final chunk = text.substring(lastEnd, match.start);
          final attrs = {...?op.attributes, ...currentExtra()};
          result.insert(chunk, attrs.isEmpty ? null : attrs);
        }
        final tag = match.group(0)!;
        final lowerTag = tag.toLowerCase();

        if (lowerTag == '<u>') {
          activeExtra.add(const MapEntry('underline', true));
        } else if (lowerTag == '</u>') {
          popMatching('underline');
        } else if (lowerTag.startsWith('<span')) {
          final color = _extractSpanColor(tag);
          if (color != null) {
            activeExtra.add(MapEntry('color', color));
          }
        } else if (lowerTag == '</span>') {
          popMatching('color');
        } else if (lowerTag.startsWith('<a ')) {
          final hrefMatch = _hrefPattern.firstMatch(tag);
          final href = hrefMatch?.group(1) ?? hrefMatch?.group(2);
          if (href != null && href.isNotEmpty) {
            activeExtra.add(MapEntry(Attribute.link.key, href));
          }
        } else if (lowerTag == '</a>') {
          popMatching(Attribute.link.key);
        }
        lastEnd = match.end;
      }
      if (lastEnd < text.length) {
        final chunk = text.substring(lastEnd);
        final attrs = {...?op.attributes, ...currentExtra()};
        result.insert(chunk, attrs.isEmpty ? null : attrs);
      }
    }
    return result;
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() async {
    final controller = _controller;
    if (controller == null) return;
    final delta = controller.document.toDelta();
    final cleanedDelta = _stripDerivedParagraphIndentation(
      _stripDisallowedColorAttributes(delta),
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

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Transformations pures sur le Delta d'une note de stratégie, partagées
/// entre le chargement (markdown -> Delta) et la sauvegarde (Delta ->
/// markdown). Toutes les fonctions sont déterministes et idempotentes.

// Marqueurs reconnus dans le texte brut du Delta issu du markdown : le
// parseur markdown traite le HTML inline comme du texte littéral (il ne le
// structure pas), donc <u>/<span> survivent tels quels dans les ops texte.
final RegExp rawHtmlTagPattern = RegExp(
  r'''<u>|</u>|<span\b[^>]*>|</span>|<a\b[^>]*>|</a>''',
  caseSensitive: false,
);
final RegExp rawHtmlHrefPattern = RegExp(
  r'''href=(?:"([^"]+)"|'([^']+)')''',
);
final RegExp rawHtmlStylePattern = RegExp(
  r'''style\s*=\s*(?:"([^"]*)"|'([^']*)')''',
);
final RegExp rawHtmlCssColorPattern = RegExp(
  r'''(?:^|;)\s*color\s*:\s*([^;]+)\s*(?:;|$)''',
);

/// Ne conserve que les attributs inline d'un op de ligne (les attributs de
/// bloc comme list/header/indent sont portés par le '\n').
Map<String, dynamic>? inlineTextAttributes(Map<String, dynamic>? attrs) {
  if (attrs == null || attrs.isEmpty) return null;
  final filtered = Map<String, dynamic>.from(attrs)
    ..removeWhere((key, _) => Attribute.blockKeys.contains(key));
  return filtered.isEmpty ? null : filtered;
}

/// Indente les paragraphes qui suivent un titre pour hiérarchiser
/// visuellement la note (le markdown n'a pas de concept équivalent, cette
/// indentation est purement dérivée de la structure et est retirée à la
/// sauvegarde). Les titres, listes, citations et blocs de code ne sont
/// jamais touchés.
Delta applyHeadingParagraphIndentation(Delta input) {
  final result = Delta();
  int? currentHeadingIndentLevel;
  var lineHasContent = false;

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
          result.insert(chunk, inlineTextAttributes(attrs));
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
Delta normalizeLinkedTextAttributes(Delta input) {
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

// Les couleurs texte/surlignage sont désactivées dans l'éditeur de notes.
Delta stripDisallowedColorAttributes(Delta input) {
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

/// Retire l'indentation des paragraphes "dérivée" d'un titre (voir
/// [applyHeadingParagraphIndentation]). Les lignes de liste, citation, bloc
/// de code et titres conservent leur indentation.
Delta stripDerivedParagraphIndentation(Delta input) {
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

/// Le markdown ne peut pas représenter une liste dont le premier élément est
/// indenté sans parent au niveau 0 : à la relecture CommonMark, ces lignes à
/// 4+ espaces deviennent un bloc de code. Chaque "suite" contiguë de lignes
/// de liste est donc re-calibrée pour que son premier élément reparte au
/// niveau 0, en préservant les écarts de profondeur relatifs.
Delta rebaseListIndentation(Delta input) {
  final result = Delta();
  var currentListBase = 0;
  var inListRun = false;

  for (final op in input.toList()) {
    if (op.data is! String) {
      result.push(op);
      continue;
    }

    final attrs = op.attributes;
    final text = op.data as String;
    final parts = text.split('\n');

    for (var index = 0; index < parts.length; index++) {
      final chunk = parts[index];
      final isLineBreak = index < parts.length - 1;

      if (chunk.isNotEmpty) {
        // On ne reporte que les attributs inline sur le texte (les attributs
        // de bloc sont portés par le '\n').
        final textAttrs = inlineTextAttributes(attrs);
        result.insert(chunk, textAttrs);
      }

      if (!isLineBreak) continue;

      final lineAttrs =
          attrs == null ? <String, dynamic>{} : Map<String, dynamic>.from(attrs);
      final indentLevel = lineAttrs[Attribute.indent.key] as int?;

      if (lineAttrs.containsKey(Attribute.list.key)) {
        if (!inListRun) {
          currentListBase = indentLevel ?? 0;
          inListRun = true;
        }
        if (indentLevel != null) {
          final rebased = indentLevel - currentListBase;
          if (rebased <= 0) {
            lineAttrs.remove(Attribute.indent.key);
          } else {
            lineAttrs[Attribute.indent.key] = rebased;
          }
        }
      } else {
        inListRun = false;
      }

      result.insert('\n', lineAttrs.isEmpty ? null : lineAttrs);
    }
  }

  return result;
}

/// Retire les marqueurs <u>/<span style="color:..."> du texte et
/// réapplique les attributs Quill correspondants aux portions concernées.
Delta applyRawHtmlFormatting(Delta input) {
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
    for (final match in rawHtmlTagPattern.allMatches(text)) {
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
        final hrefMatch = rawHtmlHrefPattern.firstMatch(tag);
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

String? _extractSpanColor(String tag) {
  final styleMatch = rawHtmlStylePattern.firstMatch(tag);
  if (styleMatch == null) return null;

  final styleContent = styleMatch.group(1) ?? styleMatch.group(2);
  if (styleContent == null || styleContent.isEmpty) return null;

  final colorMatch = rawHtmlCssColorPattern.firstMatch(styleContent);
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

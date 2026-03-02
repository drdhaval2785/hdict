/// A utility to wrap every word in a string with HTML links for dictionary lookup.
class HtmlLookupWrapper {
  /// Wraps every alphanumeric word in the [html] string with `<a href="look_up:word">word</a>`.
  /// Preserves existing HTML tags.
  static String wrapWords(String html) {
    // tagRegExp matches tags <...>, HTML entities &...;, or non-tag/non-entity text
    final tagRegExp = RegExp(r'<[^>]*>|&[a-z0-9#]{2,10};|[^<&]+', caseSensitive: false);
    final wordRegExp = RegExp(r'([\p{L}\p{N}\p{M}]+)', unicode: true);

    final StringBuffer buffer = StringBuffer();
    final matches = tagRegExp.allMatches(html);
    
    bool inAnchor = false;

    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith('<') || (part.startsWith('&') && part.endsWith(';'))) {
        buffer.write(part);
        final lowerPart = part.toLowerCase();
        if (lowerPart.startsWith('<a ') || lowerPart == '<a>') {
          inAnchor = true;
        } else if (lowerPart == '</a>') {
          inAnchor = false;
        }
      } else {
        if (inAnchor) {
          buffer.write(part.replaceAll('\n', '<br>'));
        } else {
          final wrapped = part.replaceAllMapped(wordRegExp, (m) {
            final word = m.group(1)!;
            return '<a href="look_up:${Uri.encodeComponent(word)}" class="dict-word">$word</a>';
          });
          buffer.write(wrapped.replaceAll('\n', '<br>'));
        }
      }
    }

    return buffer.toString();
  }

  static String highlightText(
    String html,
    String query, {
    String highlightColor = '#ffeb3b',
    String textColor = 'black',
  }) {
    if (query.isEmpty) return html;

    final tagRegExp = RegExp(r'<[^>]*>|&[a-z0-9#]{2,10};|[^<&]+', caseSensitive: false);
    // Match words starting with the query. 
    // Uses \b to match at word start, then query, then any following alphanumeric chars.
    final queryRegExp = RegExp(
      '(\\b${RegExp.escape(query)}[\\w]*)',
      caseSensitive: false,
      unicode: true,
    );

    final StringBuffer buffer = StringBuffer();
    final matches = tagRegExp.allMatches(html);

    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith('<') || (part.startsWith('&') && part.endsWith(';'))) {
        buffer.write(part);
      } else {
        final highlighted = part.replaceAllMapped(queryRegExp, (m) {
          final matchedText = m.group(1)!;
          return '<mark>$matchedText</mark>';
        });
        buffer.write(highlighted);
      }
    }

    return buffer.toString();
  }

  static String underlineText(
    String html,
    String query, {
    String underlineColor = '#ffeb3b',
  }) {
    if (query.isEmpty) return html;

    final tagRegExp = RegExp(r'<[^>]*>|&[a-z0-9#]{2,10};|[^<&]+', caseSensitive: false);
    final queryRegExp = RegExp(
      RegExp.escape(query),
      caseSensitive: false,
    );

    final StringBuffer buffer = StringBuffer();
    final matches = tagRegExp.allMatches(html);

    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith('<') || (part.startsWith('&') && part.endsWith(';'))) {
        buffer.write(part);
      } else {
        final underlined = part.replaceAllMapped(queryRegExp, (m) {
          final matchedText = m.group(0)!;
          return '<mark>$matchedText</mark>';
        });
        buffer.write(underlined);
      }
    }

    return buffer.toString();
  }
}

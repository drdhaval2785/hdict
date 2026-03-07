/// A utility to wrap every word in a string with HTML links for dictionary lookup.
class HtmlLookupWrapper {
  static final RegExp _tagRegExp = RegExp(r'<[^>]*>|&[a-z0-9#]{2,10};|[^<&]+', caseSensitive: false);
  static final RegExp _wordRegExp = RegExp(r'([\p{L}\p{N}\p{M}]+)', unicode: true);
  
  /// Wraps every alphanumeric word with dictionary lookup links.
  /// Skips processing if current word is already in an anchor or if content is too large.
  static String wrapWords(String html) {
    if (html.isEmpty) return '';
    // Safety: If HTML is massive (>50KB), skip wrapping to prevent UI hang.
    if (html.length > 50000) {
      return html.replaceAll('\n', '<br>');
    }

    final StringBuffer buffer = StringBuffer();
    final matches = _tagRegExp.allMatches(html);
    
    bool inAnchor = false;

    for (final match in matches) {
      final part = match.group(0)!;
      final charCode = part.codeUnitAt(0);
      
      if (charCode == 60) { // startsWith('<')
        buffer.write(part);
        final lowerPart = part.toLowerCase();
        if (lowerPart.startsWith('<a ') || lowerPart == '<a>') {
          inAnchor = true;
        } else if (lowerPart == '</a>') {
          inAnchor = false;
        }
      } else if (charCode == 38 && part.endsWith(';')) { // startsWith('&')
        buffer.write(part);
      } else {
        if (inAnchor) {
          buffer.write(part.replaceAll('\n', '<br>'));
        } else {
          // Optimized: Only run word regex if part actually contains letters/numbers
          if (part.trim().isEmpty) {
            buffer.write(part.replaceAll('\n', '<br>'));
            continue;
          }
          final wrapped = part.replaceAllMapped(_wordRegExp, (m) {
            final word = m.group(1)!;
            // Only encode if contains special chars; most headwords are simple
            final encoded = (word.contains('%') || word.contains(' ') || word.contains('?')) 
                ? Uri.encodeComponent(word) 
                : word;
            return '<a href="look_up:$encoded" class="dict-word">$word</a>';
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

    // We still need to create a specific regex for the query, but we use the static tag regex
    final queryRegExp = RegExp(
      '(\\b${RegExp.escape(query)}[\\w]*)',
      caseSensitive: false,
      unicode: true,
    );

    final StringBuffer buffer = StringBuffer();
    final matches = _tagRegExp.allMatches(html);

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

    final queryRegExp = RegExp(
      RegExp.escape(query),
      caseSensitive: false,
    );

    final StringBuffer buffer = StringBuffer();
    final matches = _tagRegExp.allMatches(html);

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

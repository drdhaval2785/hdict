/// A utility to wrap every word in a string with HTML links for dictionary lookup.
class HtmlLookupWrapper {
  static final RegExp _tagRegExp = RegExp(r'<[^>]*>|&[a-z0-9#]{2,10};|[^<&]+', caseSensitive: false);
  static final RegExp _wordRegExp = RegExp(r'([\p{L}\p{N}\p{M}]+)', unicode: true);

  /// Processes a dictionary record in a single pass to maximize performance.
  /// Combines whitespace normalization, word wrapping, highlighting, and underlining.
  static String processRecord({
    required String html,
    required String format,
    String? typeSequence,
    required bool wrapWords,
    String? highlightQuery,
    String? underlineQuery,
    String? highlightColor,
  }) {
    if (html.isEmpty) return '';

    final highlightReg = (highlightQuery != null && highlightQuery.isNotEmpty)
        ? RegExp('(\\b${RegExp.escape(highlightQuery)}[\\w]*)', caseSensitive: false, unicode: true)
        : null;

    final underlineReg = (underlineQuery != null && underlineQuery.isNotEmpty)
        ? RegExp(RegExp.escape(underlineQuery), caseSensitive: false)
        : null;

    final StringBuffer buffer = StringBuffer();
    final matches = _tagRegExp.allMatches(html);
    
    bool inAnchor = false;
    final isStardict = format == 'stardict';

    for (final match in matches) {
      final part = match.group(0)!;
      final charCode = part.codeUnitAt(0);
      
      if (charCode == 60) { // Tag starts with <
        buffer.write(part);
        final lowerPart = part.toLowerCase();
        if (lowerPart.startsWith('<a ') || lowerPart == '<a>') {
          inAnchor = true;
        } else if (lowerPart == '</a>') {
          inAnchor = false;
        }
      } else if (charCode == 38 && part.endsWith(';')) { // Entity starts with &
        buffer.write(part);
      } else {
        // Text node: Normalize, Wrap, Highlight, Underline
        String text = part;
        
        if (!isStardict) {
          // Normalize newlines to \n
          text = text.replaceAll('\r\n', '\n');
          
          // Collapse multiple non-newline spaces, but preserve newlines
          text = text.replaceAllMapped(RegExp(r' [ ]+'), (m) => ' ');
        }

        if (wrapWords && !inAnchor && text.trim().isNotEmpty && text.length < 10000) {
          text = text.replaceAllMapped(_wordRegExp, (m) {
            final word = m.group(1)!;
            final encoded = (word.contains('%') || word.contains(' ') || word.contains('?')) 
                ? Uri.encodeComponent(word) 
                : word;
            return '<a href="look_up:$encoded" class="dict-word">$word</a>';
          });
        }

        if (highlightReg != null) {
          text = text.replaceAllMapped(highlightReg, (m) => '<mark>${m.group(1)!}</mark>');
        }

        if (underlineReg != null) {
          text = text.replaceAllMapped(underlineReg, (m) => '<mark>${m.group(0)!}</mark>');
        }

        // Convert \n to <br> as the last step for this text block
        buffer.write(text.replaceAll('\n', '<br>'));
      }
    }

    return buffer.toString().trim();
  }

  /// Deprecated: Use [processRecord] for better performance.
  static String wrapWords(String html) {
    return processRecord(html: html, format: 'html', wrapWords: true);
  }

  /// Deprecated: Use [processRecord] for better performance.
  static String highlightText(String html, String query, {String highlightColor = '#ffeb3b', String textColor = 'black'}) {
    return processRecord(html: html, format: 'html', wrapWords: false, highlightQuery: query, highlightColor: highlightColor);
  }

  /// Deprecated: Use [processRecord] for better performance.
  static String underlineText(String html, String query) {
    return processRecord(html: html, format: 'html', wrapWords: false, underlineQuery: query);
  }
}
